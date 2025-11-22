local addonName, NS = ...

NS.Pools = {}

local pools = {}

-- Pool metatable
local PoolMeta = {}
PoolMeta.__index = PoolMeta

function PoolMeta:Acquire(...)
    local obj = next(self.inactive)
    if obj then
        self.inactive[obj] = nil
        self.active[obj] = true
    else
        obj = self.createFunc(...)
        self.total = (self.total or 0) + 1
    end
    
    if self.onAcquire then
        self.onAcquire(obj, ...)
    end
    
    return obj
end

function PoolMeta:Release(obj)
    if not obj then return end
    
    if self.onRelease then
        self.onRelease(obj)
    end
    
    self.active[obj] = nil
    self.inactive[obj] = true
    
    -- Standard cleanup
    obj:Hide()
    obj:ClearAllPoints()
    obj:SetParent(nil)
end

function PoolMeta:ReleaseAll()
    for obj in pairs(self.active) do
        self:Release(obj)
    end
end

function PoolMeta:GetStats()
    local numActive = 0
    local numInactive = 0
    
    for _ in pairs(self.active) do
        numActive = numActive + 1
    end
    
    for _ in pairs(self.inactive) do
        numInactive = numInactive + 1
    end
    
    return {
        name = self.name,
        active = numActive,
        inactive = numInactive,
        total = self.total or 0,
    }
end

-- Create a new pool
function NS.Pools:CreatePool(name, createFunc, onAcquire, onRelease)
    local pool = setmetatable({
        name = name,
        createFunc = createFunc,
        onAcquire = onAcquire,
        onRelease = onRelease,
        active = {},
        inactive = {},
        total = 0,
    }, PoolMeta)
    
    pools[name] = pool
    return pool
end

function NS.Pools:GetPool(name)
    return pools[name]
end

function NS.Pools:GetAllStats()
    local stats = {}
    for name, pool in pairs(pools) do
        stats[name] = pool:GetStats()
    end
    return stats
end

-- Initialize built-in pools
function NS.Pools:Init()
    -- Item button pool
    local buttonSerial = 0
    self:CreatePool("ItemButton",
        function()
            buttonSerial = buttonSerial + 1
            local name = "ZenBagsPooledButton" .. buttonSerial
            local btn = CreateFrame("Button", name, nil, "ContainerFrameItemButtonTemplate")
            btn:SetSize(37, 37)
            
            -- Initialize child frames (template creates these with $parent prefix)
            btn.icon = _G[name .. "Icon"]
            btn.IconBorder = _G[name .. "IconQuestTexture"] or btn:CreateTexture(nil, "OVERLAY")
            
            -- Quality border
            if not btn.QualityBorder then
                btn.QualityBorder = btn:CreateTexture(nil, "OVERLAY")
                btn.QualityBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                btn.QualityBorder:SetBlendMode("ADD")
                btn.QualityBorder:SetPoint("CENTER")
                btn.QualityBorder:SetSize(37 * 1.6, 37 * 1.6)
                btn.QualityBorder:Hide()
            end
            
            -- Register for interactions
            btn:RegisterForDrag("LeftButton")
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            
            -- Disable default OnUpdate to prevent tooltip flickering
            -- (Default OnUpdate calls OnEnter repeatedly, which fails for offline items)
            btn:SetScript("OnUpdate", nil)
            
            -- Custom Tooltip Handler (fixes offline bank items & flickering)
            btn:SetScript("OnEnter", function(self)
                if not NS.Config:Get("showTooltips") then return end
                
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                
                -- Try standard bag item first (best for live items with cooldowns etc)
                local hasItem = GameTooltip:SetBagItem(self:GetParent():GetID(), self:GetID())
                
                -- If standard failed (e.g. offline bank), fallback to link
                if not hasItem and self.itemLink then
                    GameTooltip:SetHyperlink(self.itemLink)
                end
                
                GameTooltip:Show()
                CursorUpdate(self)
            end)
            
            btn:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
                ResetCursor()
            end)
            
            return btn
        end,
        function(btn)
            -- OnAcquire
            btn:Show()
        end,
        function(btn)
            -- OnRelease
            btn:Hide()
            btn.IconBorder:Hide()
            btn.QualityBorder:Hide()
        end
    )
    
    
    -- Section header pool - clickable buttons for collapse/expand
    self:CreatePool("SectionHeader",
        function()
            local btn = CreateFrame("Button")
            btn:SetSize(350, 20)
            btn:EnableMouse(true)
            
            -- Collapse/expand icon (Texture instead of FontString)
            btn.icon = btn:CreateTexture(nil, "OVERLAY")
            btn.icon:SetSize(16, 16)
            btn.icon:SetPoint("LEFT", 0, 0)
            btn.icon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
            
            -- Category text
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLeft")
            btn.text:SetPoint("LEFT", 20, 0)
            
            return btn
        end,
        function(header)
            header:Show()
        end,
        function(header)
            header:Hide()
            header.text:SetText("")
            header.icon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up") -- Reset to default
            header:SetScript("OnClick", nil)
            header:SetScript("OnEnter", nil)
            header:SetScript("OnLeave", nil)
        end
    )
end
