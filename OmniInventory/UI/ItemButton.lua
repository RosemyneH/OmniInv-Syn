-- =============================================================================
-- OmniInventory Item Button Widget
-- =============================================================================
-- Purpose: Reusable item slot button with icon, count, quality border,
-- tooltip, and click handling. Uses object pooling for efficiency.
-- =============================================================================

local addonName, Omni = ...

Omni.ItemButton = {}
local ItemButton = Omni.ItemButton

-- =============================================================================
-- Constants
-- =============================================================================

local BUTTON_SIZE = 37
local ICON_SIZE = 32
local BORDER_SIZE = 2
local ATTUNE_BAR_WIDTH = 6
local ATTUNE_MIN_HEIGHT_PERCENT = 0.2
local ATTUNE_MAX_HEIGHT_PERCENT = 0.9
-- ʕ •ᴥ•ʔ✿ Per-school resistance icons; fallback covers untyped/unknown schools ✿ ʕ •ᴥ•ʔ
local RESIST_ICON_TEXTURES = {
    Shadow = "Interface\\Icons\\Spell_Shadow_AntiShadow",
    Fire   = "Interface\\Icons\\Spell_Fire_FireArmor",
    Frost  = "Interface\\Icons\\Spell_Frost_FrostWard",
    Arcane = "Interface\\Icons\\Spell_Shadow_DetectLesserInvisibility",
    Nature = "Interface\\Icons\\Spell_Nature_ProtectionformNature",
}
local RESIST_ICON_FALLBACK = "Interface\\Icons\\Spell_Holy_MagicalSentry"

local FORGE_LEVEL_MAP = { BASE = 0, TITANFORGED = 1, WARFORGED = 2, LIGHTFORGED = 3 }
local FORGE_LEVEL_NAMES = { [0] = "BASE", [1] = "TITANFORGED", [2] = "WARFORGED", [3] = "LIGHTFORGED" }
local FORGE_LETTERS = { [1] = "T", [2] = "W", [3] = "L" }
local ConfigureSecureItemUse

local function NormalizeMouseButton(mouseButton)
    if mouseButton == "LeftButtonUp" or mouseButton == "LeftButtonDown" then
        return "LeftButton"
    end
    if mouseButton == "RightButtonUp" or mouseButton == "RightButtonDown" then
        return "RightButton"
    end
    if mouseButton == "MiddleButtonUp" or mouseButton == "MiddleButtonDown" then
        return "MiddleButton"
    end
    return mouseButton
end

local function IsSendMailComposeOpen()
    return SendMailFrame and SendMailFrame:IsShown()
end

local function PerformBlizzardContainerRightClick(bagID, slotID)
    if not bagID or not slotID or bagID < 0 or slotID < 1 then
        return false
    end
    local clickFn = _G.ContainerFrameItemButton_OnClick
    if not clickFn or not Omni.Utils or not Omni.Utils.EnsureBlizzardContainerItemButtons or not Omni.Utils.GetBlizzardBagSlotButton then
        return false
    end
    Omni.Utils:EnsureBlizzardContainerItemButtons()
    local proxy = Omni.Utils:GetBlizzardBagSlotButton(bagID, slotID)
    if not proxy then
        return false
    end
    clickFn(proxy, "RightButton")
    return true
end

function ItemButton:HandleBagSlotRightClickInventory(bagID, slotID, secureUseConfigured)
    if not bagID or not slotID or bagID < 0 or slotID < 1 then
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    if IsSendMailComposeOpen() then
        if not PerformBlizzardContainerRightClick(bagID, slotID) then
            UseContainerItem(bagID, slotID)
        end
        return true
    end
    if not secureUseConfigured then
        UseContainerItem(bagID, slotID)
        return true
    end
    return false
end

local QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 },
    [1] = { 1.00, 1.00, 1.00 },
    [2] = { 0.12, 1.00, 0.00 },
    [3] = { 0.00, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 },
    [5] = { 1.00, 0.50, 0.00 },
    [6] = { 0.90, 0.80, 0.50 },
    [7] = { 0.00, 0.80, 1.00 },
}

-- ʕ •ᴥ•ʔ✿ Hidden, ID-less limbo parent for buttons that are not currently
-- assigned to any (bag, slot). Buttons must always have a real parent so
-- their secure OnClick path doesn't dereference nil; we only reparent
-- to the bag-keyed ItemContainer at acquire time. ✿ ʕ •ᴥ•ʔ
local buttonLimbo
local function GetButtonLimbo()
    if not buttonLimbo then
        buttonLimbo = CreateFrame("Frame", "OmniItemButtonLimbo", UIParent)
        buttonLimbo:Hide()
    end
    return buttonLimbo
end

local function UpdateTooltipCompareState()
    if not GameTooltip or not GameTooltip:IsShown() then
        return
    end

    if IsShiftKeyDown() then
        if GameTooltip_ShowCompareItem then
            GameTooltip_ShowCompareItem(GameTooltip)
        end
    else
        if GameTooltip_HideShoppingTooltips then
            GameTooltip_HideShoppingTooltips(GameTooltip)
        else
            if ShoppingTooltip1 then ShoppingTooltip1:Hide() end
            if ShoppingTooltip2 then ShoppingTooltip2:Hide() end
        end
    end
end

local function GetTooltipSidePreference()
    if Omni and Omni.Data and Omni.Data.Get then
        local side = Omni.Data:Get("tooltipSide")
        if side == "left" or side == "right" then
            return side
        end
    end
    return "right"
end

local function GetPreferredTooltipAnchor(button)
    local preferred = GetTooltipSidePreference()
    local anchor = preferred == "left" and "ANCHOR_LEFT" or "ANCHOR_RIGHT"
    if not button or not UIParent then
        return anchor
    end

    local parentWidth = UIParent.GetWidth and UIParent:GetWidth() or 0
    local buttonLeft = button.GetLeft and button:GetLeft() or nil
    local buttonRight = button.GetRight and button:GetRight() or nil
    local REQUIRED_TOOLTIP_GAP = 320

    if preferred == "right" and parentWidth > 0 and buttonRight then
        if (parentWidth - buttonRight) < REQUIRED_TOOLTIP_GAP then
            return "ANCHOR_LEFT"
        end
    elseif preferred == "left" and buttonLeft then
        if buttonLeft < REQUIRED_TOOLTIP_GAP then
            return "ANCHOR_RIGHT"
        end
    end

    return anchor
end

local modifierTooltipFrame = CreateFrame("Frame")
modifierTooltipFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
modifierTooltipFrame:SetScript("OnEvent", function()
    UpdateTooltipCompareState()
end)

local function GetAttuneSettings()
    local global = OmniInventoryDB and OmniInventoryDB.global
    local attune = global and global.attune
    if not attune then
        return nil
    end
    return attune
end

local function BuildAttuneSettingsToken()
    local settings = GetAttuneSettings()
    if not settings then
        return "attune:disabled"
    end

    local textColor = settings.textColor or {}
    return table.concat({
        settings.enabled and "1" or "0",
        settings.showBountyIcons and "1" or "0",
        settings.showAccountIcons and "1" or "0",
        settings.showResistIcons and "1" or "0",
        settings.showRedForNonAttunable and "1" or "0",
        settings.showProgressText and "1" or "0",
        settings.showAccountAttuneText and "1" or "0",
        settings.faeMode and "1" or "0",
        settings.forgeOutline == false and "0" or "1",
        tostring(textColor.r or 1),
        tostring(textColor.g or 1),
        tostring(textColor.b or 1),
        tostring(textColor.a or 1),
    }, ":")
end

local function GetItemIDFromLink(itemLink)
    if not itemLink then
        return nil
    end
    if Omni.API then
        local id = Omni.API:GetIdFromLink(itemLink)
        if id then
            return id
        end
    end
    local itemIdStr = string.match(itemLink, "item:(%d+)")
    if itemIdStr then
        return tonumber(itemIdStr)
    end
    return nil
end

local function GetForgeLevelFromLink(itemLink)
    if not itemLink or not _G.GetItemLinkTitanforge then
        return FORGE_LEVEL_MAP.BASE
    end
    local value = GetItemLinkTitanforge(itemLink)
    for _, known in pairs(FORGE_LEVEL_MAP) do
        if value == known then
            return value
        end
    end
    return FORGE_LEVEL_MAP.BASE
end

local function IsAttunableByCharacter(itemID)
    if not itemID or not _G.CanAttuneItemHelper then
        return false
    end
    return CanAttuneItemHelper(itemID) >= 1
end

local function IsAttunableByAccount(itemID)
    if not itemID then
        return false
    end
    if _G.IsAttunableBySomeone then
        local check = IsAttunableBySomeone(itemID)
        return check ~= nil and check ~= 0
    end
    if _G.GetItemTagsCustom and _G.bit and _G.bit.band then
        local itemTags = GetItemTagsCustom(itemID)
        if itemTags then
            return bit.band(itemTags, 96) == 64
        end
    end
    return false
end

-- ʕ •ᴥ•ʔ✿ Strictly use hyperlink attune progress API ✿ ʕ •ᴥ•ʔ
local function GetAttuneProgress(itemLink)
    if itemLink and _G.GetItemLinkAttuneProgress then
        local progress = GetItemLinkAttuneProgress(itemLink)
        if type(progress) == "number" then
            return progress
        end
    end
    return 0
end

local function IsItemBountied(itemID)
    if not itemID or not _G.GetCustomGameData then
        return false
    end
    local bountiedValue = GetCustomGameData(31, itemID)
    return (bountiedValue or 0) > 0
end

-- ʕ •ᴥ•ʔ✿ Returns the resistance school (Arcane/Fire/Nature/Frost/Shadow) or nil ✿ ʕ •ᴥ•ʔ
local function GetItemResistSchool(itemLink, itemID)
    if not itemLink or not itemID then
        return nil
    end
    if select(6, GetItemInfo(itemID)) ~= "Armor" then
        return nil
    end
    local itemName = itemLink:match("%[(.-)%]")
    if not itemName then
        return nil
    end
    local resistIndicators = { "Resistance", "Protection" }
    local resistTypes = { "Arcane", "Fire", "Nature", "Frost", "Shadow" }
    for _, indicator in ipairs(resistIndicators) do
        if string.find(itemName, indicator) then
            for _, resistType in ipairs(resistTypes) do
                if string.find(itemName, resistType) then
                    return resistType
                end
            end
        end
    end
    return nil
end

local function HideAttuneDisplay(button)
    if button.attuneBarBG then button.attuneBarBG:Hide() end
    if button.attuneBarFill then button.attuneBarFill:Hide() end
    if button.attuneText then button.attuneText:Hide() end
    if button.bountyIcon then button.bountyIcon:Hide() end
    if button.accountIcon then button.accountIcon:Hide() end
    if button.resistIcon then button.resistIcon:Hide() end
    button:SetScript("OnUpdate", nil)
end

local function GetButtonRenderSize(button)
    if not button then
        return BUTTON_SIZE
    end
    local w = button.GetWidth and button:GetWidth() or BUTTON_SIZE
    local h = button.GetHeight and button:GetHeight() or BUTTON_SIZE
    local size = math.min(w or BUTTON_SIZE, h or BUTTON_SIZE)
    if not size or size <= 0 then
        size = BUTTON_SIZE
    end
    return size
end

local function ApplyAttuneBarMetrics(button)
    if not button or not button.attuneBarBG or not button.attuneBarFill then
        return
    end

    local buttonSize = GetButtonRenderSize(button)
    local inset = math.max(1, math.floor(buttonSize * 0.06 + 0.5))
    local fillWidth = math.max(3, math.floor(buttonSize * 0.16 + 0.5))
    local border = 1

    button.attuneBarBG:ClearAllPoints()
    button.attuneBarBG:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", inset, inset)
    button.attuneBarBG:SetWidth(fillWidth + border * 2)

    button.attuneBarFill:ClearAllPoints()
    button.attuneBarFill:SetPoint("BOTTOMLEFT", button.attuneBarBG, "BOTTOMLEFT", border, border)
    button.attuneBarFill:SetWidth(fillWidth)
end

local function ApplyResistIconMetrics(button)
    if not button or not button.resistIcon then
        return
    end
    local buttonSize = GetButtonRenderSize(button)
    local iconSize = math.max(10, math.floor(buttonSize * 0.43 + 0.5))
    button.resistIcon:SetSize(iconSize, iconSize)
end

-- ʕ •ᴥ•ʔ✿ Forge letter indicator (T/W/L) derived from item link ✿ ʕ •ᴥ•ʔ
local function UpdateForgeDisplay(button, itemInfo)
    if not button or not button.forgeText then
        return
    end

    local itemLink = itemInfo and itemInfo.hyperlink
    if not itemLink then
        button.forgeText:Hide()
        return
    end

    local forgeLevel = GetForgeLevelFromLink(itemLink)
    local letter = FORGE_LETTERS[forgeLevel]
    if not letter then
        button.forgeText:Hide()
        return
    end

    button.forgeText:SetText(letter)

    local settings = GetAttuneSettings()
    local color = settings and settings.forgeColors
        and settings.forgeColors[FORGE_LEVEL_NAMES[forgeLevel]]
    if color then
        button.forgeText:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
    else
        button.forgeText:SetTextColor(1, 1, 1, 1)
    end

    -- ʕ •ᴥ•ʔ✿ Outline toggle: keep original font/size, only flip flags ✿ ʕ •ᴥ•ʔ
    local wantOutline = not settings or settings.forgeOutline ~= false
    if button.__forgeOutlineApplied ~= wantOutline then
        if not button.__forgeFontBase then
            local basePath, baseSize = button.forgeText:GetFont()
            button.__forgeFontBase = { path = basePath, size = baseSize or 10 }
        end
        local base = button.__forgeFontBase
        button.forgeText:SetFont(base.path, base.size, wantOutline and "OUTLINE" or "")
        button.__forgeOutlineApplied = wantOutline
    end

    button.forgeText:Show()
end

local function HideItemCooldown(button)
    if button and button.cooldown then
        button.cooldown:Hide()
    end
end

local function ShouldShowEmptyDropHighlight(button)
    if not button or not button.itemInfo or not button.itemInfo.__empty then
        return false
    end
    return CursorHasItem and CursorHasItem() and true or false
end

local function UpdateEmptyDropHighlight(button)
    if not button or not button.emptyDropHighlight then
        return
    end

    if ShouldShowEmptyDropHighlight(button) then
        button.emptyDropHighlight:Show()
    else
        button.emptyDropHighlight:Hide()
    end
end

-- =============================================================================
-- Button Creation
-- =============================================================================

local buttonCount = 0

function ItemButton:Create(parent)
    buttonCount = buttonCount + 1
    local name = "OmniItemButton" .. buttonCount

    -- ʕ •ᴥ•ʔ✿ ContainerFrameItemButtonTemplate is THE template AdiBags / Bagnon
    -- use. It carries Blizzard's own secure OnClick (ContainerFrameItemButton_
    -- OnClick) which reads bag from self:GetParent():GetID() and slot from
    -- self:GetID(), and is whitelisted to call PickupContainerItem and
    -- UseContainerItem in combat. Crucially this template does NOT promote
    -- its parent to "protected by association" the way SecureActionButton
    -- Template does, so OmniInventoryFrame stays a plain Frame and Show /
    -- Hide work in combat. We park the button on the limbo parent here and
    -- let acquire-time logic reparent it to the bag-keyed ItemContainer. ✿ ʕ •ᴥ•ʔ
    local button = CreateFrame("Button", name, parent or GetButtonLimbo(), "ContainerFrameItemButtonTemplate")
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- ʕ •ᴥ•ʔ✿ Strip the Blizzard normal/pushed/highlight skin -- our quality
    -- border owns the look. The icon, count, and cooldown frames provided
    -- by the template are wired up below. ✿ ʕ •ᴥ•ʔ
    pcall(button.SetNormalTexture, button, nil)
    pcall(button.SetPushedTexture, button, nil)
    pcall(button.SetHighlightTexture, button, nil)
    pcall(button.SetDisabledTexture, button, nil)
    if button.SetNormalTexture and _G[name .. "NormalTexture"] then
        _G[name .. "NormalTexture"]:SetAlpha(0)
    end

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.bg:SetVertexColor(0.1, 0.1, 0.1, 1)

    button.icon = _G[name .. "IconTexture"] or button:CreateTexture(nil, "ARTWORK")
    button.icon:ClearAllPoints()
    button.icon:SetPoint("TOPLEFT", 2, -2)
    button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.cooldown = _G[name .. "Cooldown"]
    if not button.cooldown then
        button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    end
    button.cooldown:ClearAllPoints()
    button.cooldown:SetPoint("TOPLEFT", button.icon, "TOPLEFT", 0, 0)
    button.cooldown:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", 0, 0)
    button.cooldown:Hide()

    local questIcon = _G[name .. "IconQuestTexture"]
    if questIcon then questIcon:Hide() end
    local stockTex = _G[name .. "Stock"]
    if stockTex then stockTex:Hide() end

    -- Quality border (our custom colored border)
    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetPoint("TOPLEFT", -1, 1)
    button.border:SetPoint("BOTTOMRIGHT", 1, -1)
    button.border:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.border:SetVertexColor(0.3, 0.3, 0.3, 1)
    button:CreateTexture(nil, "OVERLAY"):Hide()  -- Placeholder

    -- Create actual border using 4 edge textures for clean look
    button.borderTop = button:CreateTexture(nil, "OVERLAY")
    button.borderTop:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.borderTop:SetHeight(1)
    button.borderTop:SetPoint("TOPLEFT", 0, 0)
    button.borderTop:SetPoint("TOPRIGHT", 0, 0)
    button.borderTop:SetVertexColor(0.3, 0.3, 0.3, 1)

    button.borderBottom = button:CreateTexture(nil, "OVERLAY")
    button.borderBottom:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.borderBottom:SetHeight(1)
    button.borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    button.borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    button.borderBottom:SetVertexColor(0.3, 0.3, 0.3, 1)

    button.borderLeft = button:CreateTexture(nil, "OVERLAY")
    button.borderLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.borderLeft:SetWidth(1)
    button.borderLeft:SetPoint("TOPLEFT", 0, 0)
    button.borderLeft:SetPoint("BOTTOMLEFT", 0, 0)
    button.borderLeft:SetVertexColor(0.3, 0.3, 0.3, 1)

    button.borderRight = button:CreateTexture(nil, "OVERLAY")
    button.borderRight:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.borderRight:SetWidth(1)
    button.borderRight:SetPoint("TOPRIGHT", 0, 0)
    button.borderRight:SetPoint("BOTTOMRIGHT", 0, 0)
    button.borderRight:SetVertexColor(0.3, 0.3, 0.3, 1)

    -- Hide the backdrop border texture we created earlier
    button.border:Hide()

    -- New item glow using AnimationGroup
    button.glow = button:CreateTexture(nil, "OVERLAY")
    button.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    button.glow:SetBlendMode("ADD")
    button.glow:SetPoint("CENTER")
    button.glow:SetSize(BUTTON_SIZE * 1.5, BUTTON_SIZE * 1.5)
    button.glow:SetVertexColor(0.0, 1.0, 0.5, 1)
    button.glow:Hide()

    -- New item glow animation (Classic WoW compatible)
    local ag = button.glow:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local fade = ag:CreateAnimation("Alpha")
    fade:SetChange(0.5)  -- Pulse alpha by 0.5 (Classic compatible)
    fade:SetDuration(0.8)
    fade:SetSmoothing("IN_OUT")
    button.glow.anim = ag

    --[[
    if Omni.MasqueGroup then
        Omni.MasqueGroup:AddButton(button)
    end
    --]]

    -- Pawn Upgrade Arrow
    button.upgradeArrow = button:CreateTexture(nil, "OVERLAY")
    button.upgradeArrow:SetTexture("Interface\\AddOns\\Pawn\\Textures\\UpgradeArrow")
    button.upgradeArrow:SetSize(23, 23)
    button.upgradeArrow:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.upgradeArrow:Hide()

    -- Search dim overlay
    button.dimOverlay = button:CreateTexture(nil, "OVERLAY", nil, 7)
    button.dimOverlay:SetAllPoints(button.icon)
    button.dimOverlay:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.dimOverlay:SetVertexColor(0, 0, 0, 0.7)
    button.dimOverlay:Hide()

    button.emptyDropHighlight = button:CreateTexture(nil, "OVERLAY", nil, 8)
    button.emptyDropHighlight:SetAllPoints(button.icon)
    button.emptyDropHighlight:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.emptyDropHighlight:SetVertexColor(0.25, 0.85, 1, 0.35)
    button.emptyDropHighlight:Hide()

    -- Pin/Favorite icon (star in top-right corner)
    button.pinIcon = button:CreateTexture(nil, "OVERLAY")
    button.pinIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1") -- Star icon
    button.pinIcon:SetSize(14, 14)
    button.pinIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
    button.pinIcon:Hide()

    button.attuneBarBG = button:CreateTexture(nil, "OVERLAY")
    button.attuneBarBG:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.attuneBarBG:SetVertexColor(0, 0, 0, 1)
    button.attuneBarBG:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
    button.attuneBarBG:SetWidth(ATTUNE_BAR_WIDTH + 2)
    button.attuneBarBG:SetHeight(0)
    button.attuneBarBG:Hide()

    button.attuneBarFill = button:CreateTexture(nil, "OVERLAY")
    button.attuneBarFill:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.attuneBarFill:SetPoint("BOTTOMLEFT", button.attuneBarBG, "BOTTOMLEFT", 1, 1)
    button.attuneBarFill:SetWidth(ATTUNE_BAR_WIDTH)
    button.attuneBarFill:SetHeight(0)
    button.attuneBarFill:Hide()
    ApplyAttuneBarMetrics(button)

    button.attuneText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.attuneText:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
    button.attuneText:Hide()

    button.bountyIcon = button:CreateTexture(nil, "OVERLAY")
    button.bountyIcon:SetTexture("Interface/MoneyFrame/UI-GoldIcon")
    button.bountyIcon:SetSize(16, 16)
    button.bountyIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
    button.bountyIcon:Hide()

    button.accountIcon = button:CreateTexture(nil, "OVERLAY")
    button.accountIcon:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.accountIcon:SetVertexColor(0.3, 0.7, 1.0, 0.8)
    button.accountIcon:SetSize(8, 8)
    button.accountIcon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    button.accountIcon:Hide()

    button.resistIcon = button:CreateTexture(nil, "OVERLAY")
    button.resistIcon:SetTexture(RESIST_ICON_FALLBACK)
    button.resistIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.resistIcon:SetSize(16, 16)
    button.resistIcon:SetPoint("TOP", button, "TOP", 0, -2)
    button.resistIcon:Hide()

    button.forgeText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.forgeText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button.forgeText:SetJustifyH("RIGHT")
    button.forgeText:Hide()

    -- ʕ •ᴥ•ʔ✿ Template Count sits under our OVERLAY adornments; own string last ✿ ʕ •ᴥ•ʔ
    local templateCount = _G[name .. "Count"]
    if templateCount then
        templateCount:SetText("")
        templateCount:Hide()
    end
    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)
    button.count:SetJustifyH("RIGHT")
    pcall(button.count.SetDrawLayer, button.count, "OVERLAY", 127)

    button.itemInfo = nil

    -- ʕ •ᴥ•ʔ✿ HookScript on OnClick / OnEnter so the template's built-in
    -- secure ContainerFrameItemButton_OnClick (use / pickup / equip / swap /
    -- modified-clicks) and standard tooltip handler still run; ours adds
    -- the OmniInventory pin-toggle on shift+rclick and our richer tooltip
    -- compare logic on top. The template owns drag in combat too. ✿ ʕ •ᴥ•ʔ
    button:HookScript("OnMouseDown", function(self)
        ItemButton:OnMouseDown(self)
    end)

    button:HookScript("OnClick", function(self, mouseButton)
        ItemButton:OnClick(self, mouseButton)
    end)

    button:HookScript("OnEnter", function(self)
        ItemButton:OnEnter(self)
    end)

    button:HookScript("OnLeave", function(self)
        ItemButton:OnLeave(self)
    end)

    button:HookScript("OnUpdate", function(self)
        if self.__emptyDropHighlightHovering then
            UpdateEmptyDropHighlight(self)
        end
    end)

    button:HookScript("OnDragStart", function(self)
        ItemButton:OnDragStart(self)
    end)

    button:HookScript("OnReceiveDrag", function(self)
        ItemButton:OnReceiveDrag(self)
    end)

    return button
end

function ItemButton:UpdateCooldown(button)
    if not button or not button.cooldown then return end

    local bagID = button.bagID
    local slotID = button.slotID
    if not bagID or not slotID or bagID < 0 then
        HideItemCooldown(button)
        return
    end

    local start, duration, enable = GetContainerItemCooldown(bagID, slotID)
    if not start or not duration or duration <= 0 or not enable or enable == 0 then
        HideItemCooldown(button)
        return
    end

    if button.cooldown.SetCooldown then
        button.cooldown:SetCooldown(start, duration)
        button.cooldown:Show()
    elseif CooldownFrame_SetTimer then
        CooldownFrame_SetTimer(button.cooldown, start, duration, enable)
        button.cooldown:Show()
    else
        HideItemCooldown(button)
    end
end

-- =============================================================================
-- Button Update
-- =============================================================================

local function UpdateAttuneDisplay(button, itemInfo)
    ApplyAttuneBarMetrics(button)
    local buttonSize = GetButtonRenderSize(button)

    local settings = GetAttuneSettings()
    if not settings or not settings.enabled then
        HideAttuneDisplay(button)
        return
    end

    local itemLink = itemInfo and itemInfo.hyperlink
    local itemID = (itemInfo and itemInfo.itemID) or GetItemIDFromLink(itemLink)
    if not itemLink or not itemID then
        HideAttuneDisplay(button)
        return
    end

    if settings.showBountyIcons and IsItemBountied(itemID) then
        button.bountyIcon:Show()
    else
        button.bountyIcon:Hide()
    end

    local charOK = IsAttunableByCharacter(itemID)
    local accountOK = IsAttunableByAccount(itemID)
    if settings.showAccountIcons and accountOK and not charOK then
        button.accountIcon:Show()
    else
        button.accountIcon:Hide()
    end

    local resistSchool = settings.showResistIcons and GetItemResistSchool(itemLink, itemID) or nil
    if resistSchool then
        ApplyResistIconMetrics(button)
        button.resistIcon:SetTexture(RESIST_ICON_TEXTURES[resistSchool] or RESIST_ICON_FALLBACK)
        button.resistIcon:Show()
    else
        button.resistIcon:Hide()
    end

    -- ʕ •ᴥ•ʔ✿ Only items attunable by SOMEONE deserve a bar ✿ ʕ •ᴥ•ʔ
    if not accountOK then
        button.attuneBarBG:Hide()
        button.attuneBarFill:Hide()
        button.attuneText:Hide()
        button:SetScript("OnUpdate", nil)
        return
    end

    local forgeLevel = GetForgeLevelFromLink(itemLink)
    local progress = GetAttuneProgress(itemLink) or 0
    local showBar = true
    local barColor = nil

    if charOK then
        if progress >= 100 and settings.faeMode and settings.faeCompleteBarColor then
            barColor = settings.faeCompleteBarColor
        else
            local key = FORGE_LEVEL_NAMES[forgeLevel] or "BASE"
            barColor = settings.forgeColors and settings.forgeColors[key]
        end
    elseif settings.showRedForNonAttunable then
        barColor = settings.nonAttunableBarColor
    else
        showBar = false
    end

    if not showBar then
        button.attuneBarBG:Hide()
        button.attuneBarFill:Hide()
        button:SetScript("OnUpdate", nil)
        if settings.showAccountAttuneText and progress < 100 and (not charOK) and accountOK then
            button.attuneText:SetTextColor(
                settings.textColor.r,
                settings.textColor.g,
                settings.textColor.b,
                settings.textColor.a
            )
            button.attuneText:SetText("Acc")
            button.attuneText:Show()
        else
            button.attuneText:Hide()
        end
        return
    end

    local targetHeight = math.max(
        buttonSize * ATTUNE_MIN_HEIGHT_PERCENT + (progress / 100) * (buttonSize * (ATTUNE_MAX_HEIGHT_PERCENT - ATTUNE_MIN_HEIGHT_PERCENT)),
        buttonSize * ATTUNE_MIN_HEIGHT_PERCENT
    )

    if barColor and barColor.r then
        button.attuneBarFill:SetVertexColor(barColor.r, barColor.g, barColor.b, barColor.a or 1)
    else
        button.attuneBarFill:SetVertexColor(0.5, 0.5, 0.5, 1)
    end

    button.attuneBarBG:Show()
    button.attuneBarFill:Show()

    if progress >= 100 then
        button.attuneText:Hide()
    elseif settings.showProgressText and (charOK or (settings.showRedForNonAttunable and accountOK)) then
        button.attuneText:SetTextColor(
            settings.textColor.r,
            settings.textColor.g,
            settings.textColor.b,
            settings.textColor.a
        )
        button.attuneText:SetText(string.format("%.0f%%", progress))
        button.attuneText:Show()
    elseif settings.showAccountAttuneText and (not charOK) and accountOK then
        button.attuneText:SetTextColor(
            settings.textColor.r,
            settings.textColor.g,
            settings.textColor.b,
            settings.textColor.a
        )
        button.attuneText:SetText("Acc")
        button.attuneText:Show()
    else
        button.attuneText:Hide()
    end

    button.attuneBarBG:SetHeight(targetHeight + 2)
    button.attuneBarFill:SetHeight(math.max(targetHeight, 0))
    button:SetScript("OnUpdate", nil)
end

function ItemButton:SetItem(button, itemInfo)
    if not button then return end

    button.itemInfo = itemInfo

    if itemInfo and itemInfo.__empty then
        local prevSlotID = button.slotID
        button.bagID = itemInfo.bagID
        button.slotID = itemInfo.slotID
        if itemInfo.slotID and button.SetID and prevSlotID ~= itemInfo.slotID then
            pcall(button.SetID, button, itemInfo.slotID)
        end

        button.icon:SetTexture(nil)
        button.count:SetText("")
        button.count:Hide()
        pcall(button.EnableMouse, button, true)
        local grey = 0.3
        if button.borderTop then button.borderTop:SetVertexColor(grey, grey, grey, 1) end
        if button.borderBottom then button.borderBottom:SetVertexColor(grey, grey, grey, 1) end
        if button.borderLeft then button.borderLeft:SetVertexColor(grey, grey, grey, 1) end
        if button.borderRight then button.borderRight:SetVertexColor(grey, grey, grey, 1) end
        button.glow:Hide()
        button.dimOverlay:Hide()
        UpdateEmptyDropHighlight(button)
        HideAttuneDisplay(button)
        if button.forgeText then button.forgeText:Hide() end
        HideItemCooldown(button)
        button.__lastRenderKey = nil
        return
    end

    if not itemInfo then
        button.icon:SetTexture(nil)
        button.count:SetText("")
        button.count:Hide()
        pcall(button.EnableMouse, button, false)
        local grey = 0.3
        if button.borderTop then button.borderTop:SetVertexColor(grey, grey, grey, 1) end
        if button.borderBottom then button.borderBottom:SetVertexColor(grey, grey, grey, 1) end
        if button.borderLeft then button.borderLeft:SetVertexColor(grey, grey, grey, 1) end
        if button.borderRight then button.borderRight:SetVertexColor(grey, grey, grey, 1) end
        button.glow:Hide()
        button.dimOverlay:Hide()
        UpdateEmptyDropHighlight(button)
        HideAttuneDisplay(button)
        if button.forgeText then button.forgeText:Hide() end
        HideItemCooldown(button)
        button.__lastRenderKey = nil
        return
    end

    pcall(button.EnableMouse, button, true)

    local isPinned = itemInfo.itemID and Omni.Data and Omni.Data:IsPinned(itemInfo.itemID) or false
    local attuneSettings = GetAttuneSettings()
    local attuneEnabled = attuneSettings and attuneSettings.enabled
    local attuneToken = BuildAttuneSettingsToken()
    local renderKey = button.__lastRenderKey
    if renderKey
            and renderKey.hyperlink == itemInfo.hyperlink
            and renderKey.iconFileID == itemInfo.iconFileID
            and renderKey.stackCount == itemInfo.stackCount
            and renderKey.quality == itemInfo.quality
            and renderKey.isNew == itemInfo.isNew
            and renderKey.isQuickFiltered == itemInfo.isQuickFiltered
            and renderKey.itemID == itemInfo.itemID
            and renderKey.bagID == itemInfo.bagID
            and renderKey.slotID == itemInfo.slotID
            and renderKey.isPinned == isPinned
            and renderKey.attuneToken == attuneToken then
        if attuneEnabled then
            UpdateAttuneDisplay(button, itemInfo)
            UpdateForgeDisplay(button, itemInfo)
        end
        self:UpdateCooldown(button)
        return
    end

    -- Set icon
    local texture = itemInfo.iconFileID
    if texture then
        button.icon:SetTexture(texture)
    else
        button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    local count = math.max(1, tonumber(itemInfo.stackCount) or 1)
    if count > 1 then
        button.count:SetText(tostring(count))
        button.count:Show()
    else
        button.count:SetText("")
        button.count:Hide()
    end

    -- Set quality border color
    local quality = itemInfo.quality or 1
    local color = QUALITY_COLORS[quality] or QUALITY_COLORS[1]
    local r, g, b = color[1], color[2], color[3]

    if button.borderTop then button.borderTop:SetVertexColor(r, g, b, 1) end
    if button.borderBottom then button.borderBottom:SetVertexColor(r, g, b, 1) end
    if button.borderLeft then button.borderLeft:SetVertexColor(r, g, b, 1) end
    if button.borderRight then button.borderRight:SetVertexColor(r, g, b, 1) end

    -- ʕ •ᴥ•ʔ✿ ContainerFrameItemButton_OnClick reads bag from
    -- self:GetParent():GetID() and slot from self:GetID(); the parenting
    -- to the bag-keyed ItemContainer (which carries SetID(bagID)) and the
    -- SetID below are what wire this button to the secure use / pickup
    -- pipeline. Both calls are protected on this client and therefore are
    -- only safe to issue out of combat -- the render path is combat-gated
    -- in UI/Frame.lua so we never reach SetItem during lockdown. ✿ ʕ •ᴥ•ʔ
    local prevSlotID = button.slotID
    button.bagID = itemInfo.bagID
    button.slotID = itemInfo.slotID
    -- ʕ •ᴥ•ʔ✿ Skip redundant SetID in combat: the call is protected on
    -- this client, and during a combat content-refresh the slot index
    -- has not changed (we only rebind the slotID on structural renders,
    -- which are combat-gated). pcall absorbs the error regardless. ✿ ʕ •ᴥ•ʔ
    if itemInfo.slotID and button.SetID and prevSlotID ~= itemInfo.slotID then
        pcall(button.SetID, button, itemInfo.slotID)
    end

    local highlightNewItems = Omni.Data and Omni.Data:Get("highlightNewItems") == true
    if itemInfo.isNew and highlightNewItems then
        button.glow:Show()
        button.glow.anim:Play()
    else
        button.glow.anim:Stop()
        button.glow:Hide()
    end

    -- Pawn Upgrade Check (wrapped in pcall for safety)
    button.upgradeArrow:Hide()
    if PawnIsContainerItemAnUpgrade and itemInfo.bagID and itemInfo.bagID >= 0 then
        local ok, isUpgrade = pcall(PawnIsContainerItemAnUpgrade, itemInfo.bagID, itemInfo.slotID)
        if ok and isUpgrade then
            button.upgradeArrow:Show()
        end
    end

    -- Apply quick filter dimming or clear search dim
    if itemInfo.isQuickFiltered then
        button.dimOverlay:Show()
        button.icon:SetDesaturated(true)
        button.icon:SetAlpha(0.4)
    else
        button.dimOverlay:Hide()
        button.icon:SetDesaturated(false)
        button.icon:SetAlpha(1)
    end
    UpdateEmptyDropHighlight(button)

    -- Show pin icon if item is pinned
    if isPinned then
        button.pinIcon:Show()
    else
        button.pinIcon:Hide()
    end

    UpdateAttuneDisplay(button, itemInfo)
    UpdateForgeDisplay(button, itemInfo)
    self:UpdateCooldown(button)

    button.__lastRenderKey = {
        hyperlink = itemInfo.hyperlink,
        iconFileID = itemInfo.iconFileID,
        stackCount = itemInfo.stackCount,
        quality = itemInfo.quality,
        isNew = itemInfo.isNew,
        isQuickFiltered = itemInfo.isQuickFiltered,
        itemID = itemInfo.itemID,
        bagID = itemInfo.bagID,
        slotID = itemInfo.slotID,
        isPinned = isPinned,
        attuneToken = attuneToken,
    }
end

-- =============================================================================
-- Search Highlighting
-- =============================================================================

function ItemButton:SetSearchMatch(button, isMatch)
    if not button then return end

    if isMatch then
        button.dimOverlay:Hide()
        button.icon:SetDesaturated(false)
        button.icon:SetAlpha(1)
    else
        button.dimOverlay:Show()
        button.icon:SetDesaturated(true)
        button.icon:SetAlpha(0.5)
    end
end

function ItemButton:ClearSearch(button)
    if not button then return end

    button.dimOverlay:Hide()
    button.icon:SetDesaturated(false)
    button.icon:SetAlpha(1)
end

-- =============================================================================
-- Event Handlers
-- =============================================================================

-- ʕ •ᴥ•ʔ✿ Kept as a no-op so any leftover callers (eg. saved-variables
-- migration paths, the bank renderer) don't blow up. The template's
-- built-in OnClick is the secure path now. ✿ ʕ •ᴥ•ʔ
ConfigureSecureItemUse = function(button)
    if not button then return end
    button.secureUseConfigured = true
end

local function QueueOptimisticFlowRefresh(button, waitForCursorClear)
    if not button or not Omni.Frame or not Omni.Frame.RequestOptimisticFlowRefresh then
        return
    end

    local bagID = button.bagID
    local slotID = button.slotID
    if not bagID or not slotID or bagID < 0 or bagID > 4 or slotID < 1 then
        button.__omniActionStateKey = nil
        return
    end

    Omni.Frame:RequestOptimisticFlowRefresh(bagID, slotID, {
        stateKey = button.__omniActionStateKey,
        waitForCursorClear = waitForCursorClear == true,
    })
    button.__omniActionStateKey = nil
end

function ItemButton:OnMouseDown(button)
    if not button or not button.itemInfo or not Omni.Frame or not Omni.Frame.SnapshotBagSlotState then
        return
    end

    local bagID = button.bagID
    local slotID = button.slotID
    if not bagID or not slotID or bagID < 0 or bagID > 4 or slotID < 1 then
        button.__omniActionStateKey = nil
        return
    end

    button.__omniActionStateKey = Omni.Frame:SnapshotBagSlotState(bagID, slotID)
end

function ItemButton:OnPreClick() end

-- ʕ •ᴥ•ʔ✿ ContainerFrameItemButtonTemplate's XML OnClick already invokes
-- ContainerFrameItemButton_OnClick which handles use / pickup / equip /
-- shift-link / ctrl-dressup / split / right-click-use, all on Blizzard's
-- whitelisted secure path that works in combat. This hook only adds the
-- OmniInventory-specific extras: shift+rclick to toggle pin and the
-- isNew bookkeeping. We never PickupContainerItem ourselves so we don't
-- double-handle and don't trigger combat lockdown from insecure code. ✿ ʕ •ᴥ•ʔ
function ItemButton:OnClick(button, mouseButton)
    if not button then return end

    mouseButton = NormalizeMouseButton(mouseButton) or mouseButton

    if mouseButton == "RightButton" and IsShiftKeyDown()
            and button.itemInfo and button.itemInfo.itemID then
        local isPinned = Omni.Data and Omni.Data:TogglePin(button.itemInfo.itemID)
        if isPinned then
            if button.pinIcon then button.pinIcon:Show() end
            print("|cFF00FF00Omni|r: Item pinned!")
        else
            if button.pinIcon then button.pinIcon:Hide() end
            print("|cFF00FF00Omni|r: Item unpinned.")
        end
        if Omni.Frame and not (InCombatLockdown and InCombatLockdown()) then
            Omni.Frame:UpdateLayout()
        end
        if Omni.BankFrame and Omni.BankFrame.UpdateLayout
                and not (InCombatLockdown and InCombatLockdown()) then
            Omni.BankFrame:UpdateLayout()
        end
        button.__omniActionStateKey = nil
        return
    end

    if button.itemInfo and button.itemInfo.isNew then
        button.itemInfo.isNew = false
        if button.glow then button.glow:Hide() end
        button.glowAnimating = false
        if Omni.Categorizer and button.itemInfo.itemID then
            Omni.Categorizer:ClearNewItem(button.itemInfo.itemID)
        end
    end

    QueueOptimisticFlowRefresh(button, CursorHasItem and CursorHasItem())
    UpdateEmptyDropHighlight(button)
end

function ItemButton:OnEnter(button)
    if not button or not button.itemInfo then return end

    local bagID = button.bagID
    local slotID = button.slotID

    GameTooltip:SetOwner(button, GetPreferredTooltipAnchor(button))

    if bagID and bagID >= 0 then
        -- Standard online item
        GameTooltip:SetBagItem(bagID, slotID)
    elseif button.itemInfo.hyperlink then
        -- Offline/Bank item
        GameTooltip:SetHyperlink(button.itemInfo.hyperlink)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Bank Item (Offline)", 0.5, 0.5, 0.5)
    end

    -- Hook for Auctionator (if it doesn't hook automatically)
    if Auctionator and Auctionator.ShowTooltip then
         -- Auctionator usually hooks SetBagItem/SetHyperlink, but we can allow extra logic here if needed
    end

    GameTooltip:Show()
    UpdateTooltipCompareState()
    if bagID and bagID >= 0 and slotID and MerchantFrame and MerchantFrame:IsShown() and (not CursorHasItem or not CursorHasItem()) then
        if ShowContainerSellCursor then
            ShowContainerSellCursor(bagID, slotID)
        elseif CursorUpdate then
            CursorUpdate(button)
        end
    elseif CursorUpdate then
        CursorUpdate(button)
    end

    -- Highlight in search
    if Omni.Frame and Omni.Frame.HighlightItem then
        Omni.Frame:HighlightItem(button.itemInfo)
    end

    button.__emptyDropHighlightHovering = true
    UpdateEmptyDropHighlight(button)
end

function ItemButton:OnLeave(button)
    button.__emptyDropHighlightHovering = false
    if button.emptyDropHighlight then
        button.emptyDropHighlight:Hide()
    end
    GameTooltip:Hide()
    if ResetCursor then
        ResetCursor()
    end
end

-- ʕ •ᴥ•ʔ✿ ContainerFrameItemButtonTemplate already handles OnDragStart and
-- OnReceiveDrag through its built-in scripts (PickupContainerItem on the
-- template's own bag/slot resolution). Our hooks would double-pickup and
-- swap the item with whatever the cursor still carries -- so they no-op. ✿ ʕ •ᴥ•ʔ
function ItemButton:OnDragStart(button)
    QueueOptimisticFlowRefresh(button, true)
end
function ItemButton:OnReceiveDrag() end

-- =============================================================================
-- Reset (for pool release)
-- =============================================================================

function ItemButton:Reset(button)
    if not button then return end

    button.itemInfo = nil
    button.__lastRenderKey = nil
    button.__omniActionStateKey = nil
    button.__emptyDropHighlightHovering = false
    button.bagID = nil
    button.slotID = nil
    if button.icon then button.icon:SetTexture(nil) end
    if button.count then
        button.count:SetText("")
        button.count:Hide()
    end

    local grey = 0.3
    if button.borderTop then button.borderTop:SetVertexColor(grey, grey, grey, 1) end
    if button.borderBottom then button.borderBottom:SetVertexColor(grey, grey, grey, 1) end
    if button.borderLeft then button.borderLeft:SetVertexColor(grey, grey, grey, 1) end
    if button.borderRight then button.borderRight:SetVertexColor(grey, grey, grey, 1) end

    if button.glow and button.glow.anim then button.glow.anim:Stop() end
    if button.glow then button.glow:Hide() end
    if button.dimOverlay then button.dimOverlay:Hide() end
    if button.pinIcon then button.pinIcon:Hide() end
    if button.emptyDropHighlight then button.emptyDropHighlight:Hide() end
    HideAttuneDisplay(button)
    if button.forgeText then button.forgeText:Hide() end
    HideItemCooldown(button)
    if button.icon then
        button.icon:SetDesaturated(false)
        button.icon:SetAlpha(1)
    end

    pcall(button.Hide, button)
end

-- ʕ •ᴥ•ʔ✿ Guild bank uses plain Buttons; create attune/forge layers via
-- GuildBankFrame.EnsureGuildSlotDecorationFrames then call here. ✿ ʕ •ᴥ•ʔ
function ItemButton:UpdateGuildBankSlotDecorations(button, itemInfo)
    if not button then return end
    UpdateAttuneDisplay(button, itemInfo or {})
    UpdateForgeDisplay(button, itemInfo or {})
end

print("|cFF00FF00OmniInventory|r: ItemButton loaded")
