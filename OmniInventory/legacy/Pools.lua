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
            -- Try to find the icon texture safely
            if not btn.icon then
                btn.icon = _G[name .. "IconTexture"] -- Standard template name
            end
            if not btn.icon then
                btn.icon = _G[name .. "Icon"] -- Fallback
            end

            if btn.icon then
                btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Crop borders
            end

            -- Strip default textures for flat look
            btn:SetNormalTexture("")
            btn:SetPushedTexture("")
            btn:SetHighlightTexture("")

            -- Create custom pixel border
            if not btn.border then
                btn.border = {}
                local function CreateLine(parent)
                    local t = parent:CreateTexture(nil, "OVERLAY")
                    t:SetTexture(0, 0, 0, 1)
                    return t
                end

                btn.border.t = CreateLine(btn)
                btn.border.t:SetPoint("TOPLEFT", -1, 1)
                btn.border.t:SetPoint("TOPRIGHT", 1, 1)
                btn.border.t:SetHeight(1)

                btn.border.b = CreateLine(btn)
                btn.border.b:SetPoint("BOTTOMLEFT", -1, -1)
                btn.border.b:SetPoint("BOTTOMRIGHT", 1, -1)
                btn.border.b:SetHeight(1)

                btn.border.l = CreateLine(btn)
                btn.border.l:SetPoint("TOPLEFT", -1, 1)
                btn.border.l:SetPoint("BOTTOMLEFT", -1, -1)
                btn.border.l:SetWidth(1)

                btn.border.r = CreateLine(btn)
                btn.border.r:SetPoint("TOPRIGHT", 1, 1)
                btn.border.r:SetPoint("BOTTOMRIGHT", 1, -1)
                btn.border.r:SetWidth(1)
            end

            -- Quality Border Helper
            btn.UpdateQuality = function(self, quality)
                local r, g, b = 0.3, 0.3, 0.3 -- Default grey
                if quality and quality > 1 then
                    r, g, b = GetItemQualityColor(quality)
                end

                -- Update border color
                self.border.t:SetTexture(r, g, b, 1)
                self.border.b:SetTexture(r, g, b, 1)
                self.border.l:SetTexture(r, g, b, 1)
                self.border.r:SetTexture(r, g, b, 1)

                -- Store for search dimming
                self.qualityR, self.qualityG, self.qualityB = r, g, b
            end

            -- Hide default IconBorder
            btn.IconBorder = _G[name .. "IconQuestTexture"] or btn:CreateTexture(nil, "OVERLAY")
            btn.IconBorder:SetTexture("")
            btn.IconBorder:Hide()

            -- Custom Empty Slot Texture
            if not btn.emptySlot then
                btn.emptySlot = btn:CreateTexture(nil, "BACKGROUND")
                btn.emptySlot:SetAllPoints()
                btn.emptySlot:SetTexture(0.15, 0.15, 0.15, 0.8) -- Dark grey square
                btn.emptySlot:Hide()
            end

            -- Item Level Text
            if not btn.ilvl then
                btn.ilvl = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                btn.ilvl:SetPoint("BOTTOMLEFT", 2, 2)
                btn.ilvl:SetJustifyH("LEFT")
                btn.ilvl:SetText("")
                btn.ilvl:SetFont(btn.ilvl:GetFont(), 10, "OUTLINE") -- Small, readable font
                btn.ilvl:SetTextColor(1, 1, 0.5) -- Light yellow
            end

            -- Register for interactions
            btn:RegisterForDrag("LeftButton")
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

            -- Dummy Overlay for Offline/Cached Items
            -- (Prevents default OnUpdate from hiding tooltips for offline items)
            local dummy = CreateFrame("Button", nil, btn)
            dummy:SetAllPoints(btn)
            dummy:RegisterForClicks("AnyUp")
            dummy:SetFrameLevel(btn:GetFrameLevel() + 5)
            dummy:Hide() -- Hidden by default

            dummy:SetScript("OnEnter", function(self)
                if not NS.Config:Get("showTooltips") then return end
                if not self.itemLink then return end

                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.itemLink)
                GameTooltip:Show()
                CursorUpdate(self)
            end)

            dummy:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
                ResetCursor()
            end)

            dummy:SetScript("OnClick", function(self, button)
                -- Pass clicks to parent if needed, or handle offline clicks
                -- For now, just consume the click to prevent errors
            end)

            btn.dummyOverlay = dummy

            -- Search Highlighting
            -- Search Highlighting
            btn.UpdateSearch = function(self, searchText)
                if not searchText or searchText == "" then
                    self:SetAlpha(1)
                    SetItemButtonDesaturated(self, false)
                    -- Restore quality color
                    local r, g, b = self.qualityR or 0.3, self.qualityG or 0.3, self.qualityB or 0.3
                    self.border.t:SetTexture(r, g, b, 1)
                    self.border.b:SetTexture(r, g, b, 1)
                    self.border.l:SetTexture(r, g, b, 1)
                    self.border.r:SetTexture(r, g, b, 1)
                    return
                end

                local matches = false
                if self.itemLink then
                    local name = GetItemInfo(self.itemLink)
                    if name and string.find(string.lower(name), string.lower(searchText), 1, true) then
                        matches = true
                    end
                end

                if matches then
                    self:SetAlpha(1)
                    SetItemButtonDesaturated(self, false)
                    -- Restore quality color
                    local r, g, b = self.qualityR or 0.3, self.qualityG or 0.3, self.qualityB or 0.3
                    self.border.t:SetTexture(r, g, b, 1)
                    self.border.b:SetTexture(r, g, b, 1)
                    self.border.l:SetTexture(r, g, b, 1)
                    self.border.r:SetTexture(r, g, b, 1)
                else
                    self:SetAlpha(0.3)
                    SetItemButtonDesaturated(self, true)
                    -- Dim border
                    self.border.t:SetTexture(0.2, 0.2, 0.2, 1)
                    self.border.b:SetTexture(0.2, 0.2, 0.2, 1)
                    self.border.l:SetTexture(0.2, 0.2, 0.2, 1)
                    self.border.r:SetTexture(0.2, 0.2, 0.2, 1)
                end
            end

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
        end
    )


    -- Section header pool - clickable buttons for collapse/expand
    self:CreatePool("SectionHeader",
        function()
            local btn = CreateFrame("Button")
            btn:SetSize(350, 20)
            btn:EnableMouse(true)

            -- Collapse/expand icon
            btn.icon = btn:CreateTexture(nil, "OVERLAY")
            btn.icon:SetSize(14, 14) -- Slightly smaller
            btn.icon:SetPoint("LEFT", 0, 0)
            btn.icon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")

            -- Category text
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLeft")
            btn.text:SetPoint("LEFT", 0, 0) -- Align with left edge

            -- Separator Line
            btn.line = btn:CreateTexture(nil, "ARTWORK")
            btn.line:SetHeight(1)
            btn.line:SetPoint("LEFT", btn.text, "RIGHT", 5, 0)
            btn.line:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
            btn.line:SetTexture(0.3, 0.3, 0.3, 0.5) -- Subtle grey line

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
