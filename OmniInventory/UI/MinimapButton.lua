-- =============================================================================
-- OmniInventory Minimap Button
-- =============================================================================
-- Purpose: Draggable minimap button to toggle inventory window
-- WoTLK 3.3.5a Compatible - Uses only native APIs
-- =============================================================================

local addonName, Omni = ...

Omni.MinimapButton = {}
local MinimapButton = Omni.MinimapButton

local button = nil
local isDragging = false

-- =============================================================================
-- Constants
-- =============================================================================

local BUTTON_RADIUS = 80  -- Distance from minimap center

-- =============================================================================
-- Creation
-- =============================================================================

function MinimapButton:Create()
    if button then return button end

    button = CreateFrame("Button", "OmniMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("HIGH") -- Ensure it's above the Minimap content
    button:SetFrameLevel(Minimap:GetFrameLevel() + 10)
    button:EnableMouse(true)
    button:SetMovable(true)

    -- Icon
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(20, 20)
    button.icon:SetPoint("CENTER")
    button.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_07")

    -- Border
    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetSize(52, 52)
    button.border:SetPoint("CENTER")
    button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Highlight
    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetSize(24, 24)
    button.highlight:SetPoint("CENTER")
    button.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Click handler
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            if Omni.Frame then
                Omni.Frame:Toggle()
            end
        elseif mouseButton == "RightButton" then
            if Omni.Settings then
                Omni.Settings:Toggle()
            end
        end
    end)

    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cFF00FF00Zen|rBags")
        GameTooltip:AddLine("Left-click: Toggle Bags", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Settings", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Dragging
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self)
        self:StartMoving() -- Use StartMoving for smoother native handling first, or custom logic
        isDragging = true
    end)

    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        isDragging = false
        MinimapButton:SavePosition()
    end)

    button:SetScript("OnUpdate", function(self)
        if isDragging then
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale

            local angle = math.atan2(cy - my, cx - mx)
            MinimapButton:SetPositionByAngle(angle)
        end
    end)

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    self:LoadPosition()

    return button
end

-- =============================================================================
-- Position Management
-- =============================================================================

function MinimapButton:SetPositionByAngle(angle)
    if not button then return end

    local x = math.cos(angle) * BUTTON_RADIUS
    local y = math.sin(angle) * BUTTON_RADIUS

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)

    -- Store angle for saving
    button.angle = angle
end

function MinimapButton:SavePosition()
    if not button or not button.angle then return end

    if not OmniInventoryDB then OmniInventoryDB = {} end
    if not OmniInventoryDB.global then OmniInventoryDB.global = {} end

    OmniInventoryDB.global.minimapAngle = button.angle
end

function MinimapButton:LoadPosition()
    if not button then return end

    local angle = 225 * (math.pi / 180)  -- Default: bottom-left

    if OmniInventoryDB and OmniInventoryDB.global and OmniInventoryDB.global.minimapAngle then
        angle = OmniInventoryDB.global.minimapAngle
    end

    self:SetPositionByAngle(angle)
end

function MinimapButton:ResetPosition()
    if OmniInventoryDB and OmniInventoryDB.global then
        OmniInventoryDB.global.minimapAngle = nil
    end
    self:LoadPosition()
end

-- =============================================================================
-- Visibility
-- =============================================================================

function MinimapButton:Show()
    if not button then self:Create() end
    button:Show()
end

function MinimapButton:Hide()
    if button then button:Hide() end
end

function MinimapButton:Toggle()
    if button and button:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- =============================================================================
-- Initialization
-- =============================================================================

function MinimapButton:Init()
    self:Create()
end

print("|cFF00FF00OmniInventory|r: Minimap Button loaded")
