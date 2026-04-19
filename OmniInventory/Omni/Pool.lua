-- =============================================================================
-- OmniInventory Object Pool
-- =============================================================================
-- Purpose: Recycle frame objects to minimize GC churn
-- Zero allocation during normal bag open/close operations
-- =============================================================================

local addonName, Omni = ...

Omni.Pool = {}
local Pool = Omni.Pool

-- =============================================================================
-- Pool Registry
-- =============================================================================

local pools = {}  -- { poolName = { available = {}, active = {}, createFunc, resetFunc } }

-- =============================================================================
-- Pool Class
-- =============================================================================

local PoolMixin = {}

--- Acquire an object from the pool
---@return any object
function PoolMixin:Acquire()
    local obj

    if #self.available > 0 then
        -- Reuse existing object
        obj = table.remove(self.available)
    else
        -- Create new object
        obj = self.createFunc()
        self.totalCreated = self.totalCreated + 1
    end

    self.active[obj] = true
    self.activeCount = self.activeCount + 1

    return obj
end

--- Release an object back to the pool
---@param obj any
function PoolMixin:Release(obj)
    if not self.active[obj] then
        return -- Not from this pool
    end

    -- Clean the object
    if self.resetFunc then
        self.resetFunc(obj)
    end

    self.active[obj] = nil
    self.activeCount = self.activeCount - 1
    table.insert(self.available, obj)
end

--- Release all active objects back to pool
function PoolMixin:ReleaseAll()
    for obj in pairs(self.active) do
        self:Release(obj)
    end
end

--- Get pool statistics
---@return number active, number available, number totalCreated
function PoolMixin:GetStats()
    return self.activeCount, #self.available, self.totalCreated
end

--- Iterate over active objects
---@return function iterator
function PoolMixin:IterateActive()
    return pairs(self.active)
end

-- =============================================================================
-- Pool Factory
-- =============================================================================

--- Create a new object pool
---@param name string Unique pool identifier
---@param createFunc function Factory function to create new objects
---@param resetFunc function|nil Called on Release to clean the object
---@return table pool
function Pool:Create(name, createFunc, resetFunc)
    if pools[name] then
        return pools[name]
    end

    local pool = {
        name = name,
        available = {},
        active = {},
        activeCount = 0,
        totalCreated = 0,
        createFunc = createFunc,
        resetFunc = resetFunc,
    }

    -- Apply mixin
    for k, v in pairs(PoolMixin) do
        pool[k] = v
    end

    pools[name] = pool
    return pool
end

--- Get an existing pool
---@param name string
---@return table|nil pool
function Pool:Get(name)
    return pools[name]
end

--- Get global pool statistics
---@return table stats
function Pool:GetAllStats()
    local stats = {}
    for name, pool in pairs(pools) do
        local active, available, total = pool:GetStats()
        stats[name] = {
            active = active,
            available = available,
            total = total,
        }
    end
    return stats
end

--- Convenience method: Acquire from named pool
---@param name string Pool name
---@return any object or nil
function Pool:Acquire(name)
    local pool = pools[name]
    if pool then
        return pool:Acquire()
    end
    return nil
end

--- Convenience method: Release to named pool
---@param name string Pool name
---@param obj any Object to release
function Pool:Release(name, obj)
    local pool = pools[name]
    if pool then
        pool:Release(obj)
    end
end

-- ʕ •ᴥ•ʔ✿ Acquire `count` distinct objects up front, then release them all
-- back to the pool. The previous implementation acquired-then-released in a
-- tight loop, so the same single object was reused on every iteration and
-- only one button was ever actually created. ✿ ʕ •ᴥ•ʔ
function Pool:Prewarm(name, count)
    count = tonumber(count) or 0
    if count < 1 then return end
    local pool = pools[name]
    if not pool then return end

    local batch = {}
    for i = 1, count do
        local obj = pool:Acquire()
        if not obj then break end
        batch[i] = obj
    end
    for i = 1, #batch do
        pool:Release(batch[i])
    end
end

--- Print pool debug info
function Pool:Debug()
    print("|cFF00FF00OmniInventory|r: Pool Statistics")
    for name, pool in pairs(pools) do
        local active, available, total = pool:GetStats()
        print(string.format("  %s: %d active, %d available, %d total",
            name, active, available, total))
    end
end

-- =============================================================================
-- Pre-defined Pool Templates
-- =============================================================================

--- Initialize common pools
function Pool:Init()
    -- ʕ •ᴥ•ʔ✿ ItemButton pool ✿ ʕ •ᴥ•ʔ
    -- Buttons are ContainerFrameItemButtonTemplate children. Their
    -- SetParent / SetID / SetPoint are protected, so all reparenting
    -- happens at acquire time inside RenderFlowView (which is gated
    -- behind InCombatLockdown). The pool itself just creates the
    -- widget and hides it on release.
    self:Create("ItemButton",
        function()
            if Omni.ItemButton and Omni.ItemButton.Create then
                local btn = Omni.ItemButton:Create(nil)
                pcall(btn.Hide, btn)
                if not btn.omniData then btn.omniData = {} end
                return btn
            end

            local btn = CreateFrame("Button", nil, UIParent, "ItemButtonTemplate")
            pcall(btn.Hide, btn)
            return btn
        end,
        function(btn)
            if Omni.ItemButton and Omni.ItemButton.Reset then
                pcall(Omni.ItemButton.Reset, Omni.ItemButton, btn)
            end
            pcall(btn.Hide, btn)
        end
    )

    -- Category Header Pool
    self:Create("CategoryHeader",
        function()
            local header = CreateFrame("Frame", nil, UIParent)
            header:SetHeight(20)
            header:Hide()

            header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header.text:SetPoint("LEFT", 5, 0)

            header.count = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            header.count:SetPoint("RIGHT", -5, 0)
            header.count:SetTextColor(0.6, 0.6, 0.6)

            return header
        end,
        function(header)
            header:Hide()
            header:ClearAllPoints()
            header:SetParent(UIParent)
            header.text:SetText("")
            header.count:SetText("")
        end
    )
end

print("|cFF00FF00OmniInventory|r: Object Pool system loaded")
