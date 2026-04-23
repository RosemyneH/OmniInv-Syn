-- =============================================================================
-- OmniInventory Configuration Panel
-- =============================================================================
-- Purpose: Simple standalone options frame called via /oi config
-- Features: Scale slider, Sort mode, View mode, Reset position
-- =============================================================================

local addonName, Omni = ...

Omni.Settings = {}
local Settings = Omni.Settings
local optionsFrame = nil

local function RefreshAllInventory()
    if Omni.Frame then
        Omni.Frame:UpdateLayout()
    end
    if Omni.BankFrame and Omni.BankFrame.UpdateLayout then
        Omni.BankFrame:UpdateLayout()
    end
end

local function FormatScalePercent(value)
    return string.format("%d%%", math.floor((value or 1) * 100 + 0.5))
end

local function FormatGapPixels(value)
    return string.format("%d px", math.floor((value or 0) + 0.5))
end

local function IsSettingEditLocked()
    return InCombatLockdown and InCombatLockdown()
end

local function GetTooltipSide()
    if Omni and Omni.Data and Omni.Data.Get then
        local side = Omni.Data:Get("tooltipSide")
        if side == "left" or side == "right" then
            return side
        end
    end
    return "right"
end

local function SetTooltipSide(side)
    local normalized = (side == "left") and "left" or "right"
    if Omni and Omni.Data and Omni.Data.Set then
        Omni.Data:Set("tooltipSide", normalized)
    else
        OmniInventoryDB = OmniInventoryDB or {}
        OmniInventoryDB.global = OmniInventoryDB.global or {}
        OmniInventoryDB.global.tooltipSide = normalized
    end
end

local colorPickerCloseRefreshPending = false

local function RegisterColorPickerCloseRefresh()
    if not ColorPickerFrame or ColorPickerFrame.__OmniInvColorPickerHide then return end
    ColorPickerFrame.__OmniInvColorPickerHide = true
    ColorPickerFrame:HookScript("OnHide", function()
        if colorPickerCloseRefreshPending then
            colorPickerCloseRefreshPending = false
            RefreshAllInventory()
        end
    end)
end

local function GetAttuneSettings()
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.global = OmniInventoryDB.global or {}
    OmniInventoryDB.global.attune = OmniInventoryDB.global.attune or {}
    local attune = OmniInventoryDB.global.attune

    if attune.enabled == nil then attune.enabled = true end
    if attune.showProgressText == nil then attune.showProgressText = true end
    if attune.showBountyIcons == nil then attune.showBountyIcons = true end
    if attune.showAccountIcons == nil then attune.showAccountIcons = false end
    if attune.showResistIcons == nil then attune.showResistIcons = true end
    if attune.showRedForNonAttunable == nil then attune.showRedForNonAttunable = true end
    if attune.faeMode == nil then attune.faeMode = true end

    attune.nonAttunableBarColor = attune.nonAttunableBarColor or { r = 1.000, g = 0.267, b = 0.392, a = 1.0 }
    attune.textColor            = attune.textColor            or { r = 0.941, g = 0.886, b = 0.878, a = 1.0 }
    attune.faeCompleteBarColor  = attune.faeCompleteBarColor  or { r = 0.502, g = 0.949, b = 0.329, a = 1.0 }
    if attune.forgeOutline == nil then attune.forgeOutline = true end

    -- ʕ •ᴥ•ʔ✿ Forge tier color defaults mirror Data.lua so the picker always has a table to mutate ✿ ʕ •ᴥ•ʔ
    attune.forgeColors = attune.forgeColors or {}
    attune.forgeColors.BASE        = attune.forgeColors.BASE        or { r = 0.000, g = 1.000, b = 0.000, a = 1.0 }
    attune.forgeColors.TITANFORGED = attune.forgeColors.TITANFORGED or { r = 0.468, g = 0.532, b = 1.000, a = 1.0 }
    attune.forgeColors.WARFORGED   = attune.forgeColors.WARFORGED   or { r = 0.872, g = 0.206, b = 0.145, a = 1.0 }
    attune.forgeColors.LIGHTFORGED = attune.forgeColors.LIGHTFORGED or { r = 1.000, g = 1.000, b = 0.506, a = 1.0 }

    return attune
end

-- ʕ •ᴥ•ʔ✿ Section header palette — distinct tints so categories read at a glance ✿ ʕ •ᴥ•ʔ
local SECTION_COLORS = {
    view   = { 0.85, 0.90, 1.00 },
    sort   = { 0.85, 0.90, 1.00 },
    misc   = { 0.78, 0.88, 1.00 },
    attune = { 1.00, 0.82, 0.00 },
    colors = { 1.00, 0.60, 0.20 },
    footer = { 0.40, 1.00, 0.55 },
    addon  = { 0.45, 0.80, 1.00 },
}

local function IsAttuneHelperEmbedEnabled()
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.global = OmniInventoryDB.global or {}
    if OmniInventoryDB.global.attuneHelperEmbed == nil then
        OmniInventoryDB.global.attuneHelperEmbed = true
    end
    return OmniInventoryDB.global.attuneHelperEmbed == true
end

local function IsAttuneHelperMiniNoBorderEnabled()
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.global = OmniInventoryDB.global or {}
    if OmniInventoryDB.global.attuneHelperMiniNoBorder == nil then
        OmniInventoryDB.global.attuneHelperMiniNoBorder = false
    end
    return OmniInventoryDB.global.attuneHelperMiniNoBorder == true
end

local FOOTER_BUTTON_OPTIONS = {
    { key = "resetInstances", label = "Reset Instances" },
    { key = "transmog",     label = "Transmog"       },
    { key = "perks",        label = "Perks"          },
    { key = "lootFilter",   label = "Loot Filter"    },
    { key = "resourceBank", label = "Resource Bank"  },
    { key = "lootDb",       label = "Loot Database"  },
    { key = "attuneMgr",    label = "Attunable List" },
    { key = "leaderboard",  label = "Leaderboard"    },
}

local ADDON_BUTTON_OPTIONS = {
    { key = "scootsCraft", label = "ScootsCraft" },
    { key = "atlasLoot",   label = "AtlasLoot"   },
    { key = "theJournal",  label = "TheJournal"  },
}

local function GetFooterButtonsDB()
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.global = OmniInventoryDB.global or {}
    OmniInventoryDB.global.footerButtons = OmniInventoryDB.global.footerButtons or {}
    return OmniInventoryDB.global.footerButtons
end

local function IsFooterButtonEnabled(key)
    local db = GetFooterButtonsDB()
    if db[key] == nil then db[key] = true end
    return db[key] == true
end

local function GetAddonButtonsDB()
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.global = OmniInventoryDB.global or {}
    OmniInventoryDB.global.addonButtons = OmniInventoryDB.global.addonButtons or {}
    return OmniInventoryDB.global.addonButtons
end

local function IsAddonButtonEnabled(key)
    local db = GetAddonButtonsDB()
    if db[key] == nil then db[key] = true end
    return db[key] == true
end

-- =============================================================================
-- Creation
-- =============================================================================

function Settings:CreateOptionsFrame()
    if optionsFrame then return optionsFrame end

    optionsFrame = CreateFrame("Frame", "OmniOptionsFrame", UIParent)
    optionsFrame:SetSize(320, 520)
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:EnableMouse(true)
    optionsFrame:SetMovable(true)
    optionsFrame:SetClampedToScreen(true)
    optionsFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    optionsFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    optionsFrame:SetScript("OnEvent", function()
        if optionsFrame:IsShown() then
            self:UpdateValues()
        end
    end)

    -- Backdrop
    optionsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    -- Draggable header
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)

    -- Title
    local title = optionsFrame:CreateTexture(nil, "ARTWORK")
    title:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    title:SetSize(320, 64)
    title:SetPoint("TOP", 0, 12)

    local titleText = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", title, "TOP", 0, -14)
    titleText:SetText("OmniInventory Settings")

    local closeBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function()
        optionsFrame:Hide()
    end)

    -- ʕ •ᴥ•ʔ✿ Scrollable content viewport so we never outgrow the frame ✿ ʕ •ᴥ•ʔ
    local scrollFrame = CreateFrame("ScrollFrame", "OmniOptionsScroll", optionsFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -34, 16)

    -- Frame is 320 wide minus 16 (left inset) + 34 (right inset for scrollbar) = 270
    local SCROLL_CHILD_WIDTH = 270
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(SCROLL_CHILD_WIDTH, 1)
    scrollFrame:SetScrollChild(scrollChild)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local bar = _G[self:GetName() .. "ScrollBar"]
        if not bar then return end
        local step = 28
        bar:SetValue(bar:GetValue() - (delta * step))
    end)

    self.scrollFrame = scrollFrame
    self.content = scrollChild
    self:CreateControls(scrollChild)

    local requiredHeight = self._contentHeight or 700
    scrollChild:SetHeight(requiredHeight)

    optionsFrame:Hide()
    return optionsFrame
end

local function CreateSectionHeader(parent, text, y, color)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOP", 0, y)
    label:SetText(text)
    if color then
        label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    end
    return label
end

function Settings:CreateControls(parent)
    local yOffset = -20
    local SPACING = 40
    -- ʕ •ᴥ•ʔ✿ Vertical rhythm — SECTION_GAP lives above every category header, HEADER_GAP under it ✿ ʕ •ᴥ•ʔ
    local SECTION_GAP = 18
    local HEADER_GAP = 22
    self.colorSwatches = {}
    self._syncingScaleControls = false

    -- 1. Frame Scale Slider
    local scaleSlider = CreateFrame("Slider", "OmniScaleSlider", parent, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOP", 0, yOffset)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.1)
    -- Note: SetObeyStepOnDrag not available in WotLK 3.3.5a
    scaleSlider:SetWidth(200)

    _G[scaleSlider:GetName() .. "Low"]:SetText("50%")
    _G[scaleSlider:GetName() .. "High"]:SetText("200%")
    _G[scaleSlider:GetName() .. "Text"]:SetText("Frame Scale")
    local scaleValueText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleValueText:SetPoint("TOP", scaleSlider, "BOTTOM", 0, 2)
    scaleValueText:SetText("Current: 100%")

    scaleSlider:SetScript("OnValueChanged", function(self, value)
        if Settings._syncingScaleControls then return end
        -- Round to 1 decimal
        value = math.floor(value * 10 + 0.5) / 10
        if IsSettingEditLocked() then
            Settings:UpdateValues()
            print("|cFFFF4040OmniInventory|r: Scale settings can only be changed out of combat.")
            return
        end
        scaleValueText:SetText("Current: " .. FormatScalePercent(value))
        if Omni.Frame then
            Omni.Frame:SetScale(value)
        end
    end)
    self.scaleSlider = scaleSlider
    self.scaleValueText = scaleValueText

    yOffset = yOffset - SPACING

    -- 2. Item Scale Slider
    local itemScaleSlider = CreateFrame("Slider", "OmniItemScaleSlider", parent, "OptionsSliderTemplate")
    itemScaleSlider:SetPoint("TOP", 0, yOffset)
    itemScaleSlider:SetMinMaxValues(0.5, 2.0)
    itemScaleSlider:SetValueStep(0.1)
    itemScaleSlider:SetWidth(200)

    _G[itemScaleSlider:GetName() .. "Low"]:SetText("50%")
    _G[itemScaleSlider:GetName() .. "High"]:SetText("200%")
    _G[itemScaleSlider:GetName() .. "Text"]:SetText("Item Scale")
    local itemScaleValueText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    itemScaleValueText:SetPoint("TOP", itemScaleSlider, "BOTTOM", 0, 2)
    itemScaleValueText:SetText("Current: 100%")

    itemScaleSlider:SetScript("OnValueChanged", function(self, value)
        if Settings._syncingScaleControls then return end
        value = math.floor(value * 10 + 0.5) / 10
        if IsSettingEditLocked() then
            Settings:UpdateValues()
            print("|cFFFF4040OmniInventory|r: Scale settings can only be changed out of combat.")
            return
        end
        itemScaleValueText:SetText("Current: " .. FormatScalePercent(value))
        if Omni.Frame and Omni.Frame.SetItemScale then
            Omni.Frame:SetItemScale(value)
        end
    end)
    self.itemScaleSlider = itemScaleSlider
    self.itemScaleValueText = itemScaleValueText

    yOffset = yOffset - SPACING

    local itemGapSlider = CreateFrame("Slider", "OmniItemGapSlider", parent, "OptionsSliderTemplate")
    itemGapSlider:SetPoint("TOP", 0, yOffset)
    itemGapSlider:SetMinMaxValues(0, 20)
    itemGapSlider:SetValueStep(1)
    itemGapSlider:SetWidth(200)

    _G[itemGapSlider:GetName() .. "Low"]:SetText("0px")
    _G[itemGapSlider:GetName() .. "High"]:SetText("20px")
    _G[itemGapSlider:GetName() .. "Text"]:SetText("Item Gap")
    local itemGapValueText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    itemGapValueText:SetPoint("TOP", itemGapSlider, "BOTTOM", 0, 2)
    itemGapValueText:SetText("Current: 4 px")

    itemGapSlider:SetScript("OnValueChanged", function(self, value)
        if Settings._syncingScaleControls then return end
        value = math.floor(value + 0.5)
        if IsSettingEditLocked() then
            Settings:UpdateValues()
            print("|cFFFF4040OmniInventory|r: Scale settings can only be changed out of combat.")
            return
        end
        itemGapValueText:SetText("Current: " .. FormatGapPixels(value))
        if Omni.Frame and Omni.Frame.SetItemGap then
            Omni.Frame:SetItemGap(value)
        end
    end)
    self.itemGapSlider = itemGapSlider
    self.itemGapValueText = itemGapValueText

    yOffset = yOffset - SPACING - 20

    -- 3. View Mode (Grid, Flow, List)
    CreateSectionHeader(parent, "View Mode", yOffset, SECTION_COLORS.view)
    yOffset = yOffset - 20

    local viewBtn = CreateFrame("Button", "OmniViewToggle", parent, "UIPanelButtonTemplate")
    viewBtn:SetSize(140, 24)
    viewBtn:SetPoint("TOP", 0, yOffset)
    viewBtn:SetText("Cycle View")
    viewBtn:SetScript("OnClick", function()
        if Omni.Frame then Omni.Frame:CycleView() end
    end)
    self.viewBtn = viewBtn

    yOffset = yOffset - SPACING

    -- 4. Sort Mode
    CreateSectionHeader(parent, "Sort Mode (Default)", yOffset, SECTION_COLORS.sort)
    yOffset = yOffset - 20

    local sortBtn = CreateFrame("Button", "OmniSortToggle", parent, "UIPanelButtonTemplate")
    sortBtn:SetSize(140, 24)
    sortBtn:SetPoint("TOP", 0, yOffset)
    sortBtn:SetText("Cycle Sort")
    sortBtn:SetScript("OnClick", function()
        if Omni.Frame then Omni.Frame:CycleSort() end
    end)
    self.sortBtn = sortBtn

    yOffset = yOffset - SPACING - 20

    -- ʕ ● ᴥ ●ʔ Category Editor intentionally hidden — custom-rule engine is disabled pending rewrite

    yOffset = yOffset - SECTION_GAP
    CreateSectionHeader(parent, "Misc Options", yOffset, SECTION_COLORS.misc)
    yOffset = yOffset - HEADER_GAP

    local highlightCb = CreateFrame("CheckButton", "OmniHighlightNewItems", parent, "UICheckButtonTemplate")
    highlightCb:SetSize(24, 24)
    highlightCb:SetPoint("TOPLEFT", 14, yOffset)
    local highlightLabel = highlightCb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    highlightLabel:SetPoint("LEFT", highlightCb, "RIGHT", 2, 1)
    highlightLabel:SetText("New items")
    highlightCb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Highlight new items", 1, 0.82, 0)
        GameTooltip:AddLine("Visually emphasize items that count as new in your bags.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    highlightCb:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    highlightCb:SetScript("OnClick", function(self)
        if Omni.Data then
            Omni.Data:Set("highlightNewItems", self:GetChecked() and true or false)
            RefreshAllInventory()
        end
    end)
    self.highlightNewItemsCb = highlightCb

    local footerMoneyCb = CreateFrame("CheckButton", "OmniFooterMoneyEmphasis", parent, "UICheckButtonTemplate")
    footerMoneyCb:SetSize(24, 24)
    footerMoneyCb:SetPoint("TOPLEFT", 160, yOffset)
    local footerMoneyLabel = footerMoneyCb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    footerMoneyLabel:SetPoint("LEFT", footerMoneyCb, "RIGHT", 2, 1)
    footerMoneyLabel:SetText("Bold footer")
    footerMoneyCb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Bold footer", 1, 0.82, 0)
        GameTooltip:AddLine("Larger outlined gold and bag count. Slot text shifts from light blue to red as bags fill.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    footerMoneyCb:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    footerMoneyCb:SetScript("OnClick", function(self)
        if Omni.Data then
            Omni.Data:Set("footerMoneyEmphasis", self:GetChecked() and true or false)
        end
        if Omni.Frame and Omni.Frame.RefreshFooterMoneyStyle then
            Omni.Frame:RefreshFooterMoneyStyle()
        end
        RefreshAllInventory()
    end)
    self.footerMoneyEmphasisCb = footerMoneyCb

    yOffset = yOffset - 22

    local tooltipSideBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    tooltipSideBtn:SetSize(200, 22)
    tooltipSideBtn:SetPoint("TOP", 0, yOffset)
    tooltipSideBtn:SetScript("OnClick", function(self)
        local nextSide = GetTooltipSide() == "right" and "left" or "right"
        SetTooltipSide(nextSide)
        self:SetText("Tooltip Side: " .. (nextSide == "right" and "Prefer Right" or "Prefer Left"))
    end)
    tooltipSideBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Tooltip Side Preference", 1, 0.82, 0)
        GameTooltip:AddLine("Choose whether item tooltips prefer opening to the right or left.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    tooltipSideBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.tooltipSideBtn = tooltipSideBtn

    yOffset = yOffset - 24

    yOffset = yOffset - SPACING - 4

    -- 6. Reset Button
    local resetBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    resetBtn:SetSize(160, 24)
    resetBtn:SetPoint("TOP", 0, yOffset)
    resetBtn:SetText("Reset Position & Scale")
    resetBtn:SetScript("OnClick", function()
        if Omni.Frame then
            Omni.Frame:ResetPosition()
            if self.scaleSlider then self.scaleSlider:SetValue(1.0) end
            if self.itemScaleSlider then self.itemScaleSlider:SetValue(1.0) end
            if self.itemGapSlider then self.itemGapSlider:SetValue(4) end
        end
    end)

    yOffset = yOffset - SPACING - SECTION_GAP

    CreateSectionHeader(parent, "Attune Overlay", yOffset, SECTION_COLORS.attune)
    yOffset = yOffset - HEADER_GAP

    local function CreateAttuneCheckbox(key, text, xOffset)
        local settings = GetAttuneSettings()
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", xOffset, yOffset)
        local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", cb, "RIGHT", 2, 1)
        label:SetText(text)
        cb.label = label
        cb.key = key
        cb:SetChecked(settings[key] == true)
        cb:SetScript("OnClick", function(self)
            settings[self.key] = self:GetChecked() and true or false
            RefreshAllInventory()
        end)
        return cb
    end

    self.attuneEnabled = CreateAttuneCheckbox("enabled", "Enable", 14)
    self.attuneProgressText = CreateAttuneCheckbox("showProgressText", "Show %", 160)
    yOffset = yOffset - 22
    self.attuneBounty = CreateAttuneCheckbox("showBountyIcons", "Bounty", 14)
    self.attuneRed = CreateAttuneCheckbox("showRedForNonAttunable", "Red Bars", 160)
    yOffset = yOffset - 22
    self.attuneResist = CreateAttuneCheckbox("showResistIcons", "Resist", 14)
    self.attuneFae = CreateAttuneCheckbox("faeMode", "Fae 100%", 160)
    yOffset = yOffset - 22
    self.attuneForgeOutline = CreateAttuneCheckbox("forgeOutline", "Forge Outline", 14)
    yOffset = yOffset - 22

    local attuneHelperEmbedCb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    attuneHelperEmbedCb:SetSize(24, 24)
    attuneHelperEmbedCb:SetPoint("TOPLEFT", 14, yOffset)
    local attuneHelperEmbedLabel = attuneHelperEmbedCb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    attuneHelperEmbedLabel:SetPoint("LEFT", attuneHelperEmbedCb, "RIGHT", 2, 1)
    attuneHelperEmbedLabel:SetText("Embed AH Mini Buttons")
    attuneHelperEmbedCb:SetChecked(IsAttuneHelperEmbedEnabled())
    attuneHelperEmbedCb:SetScript("OnClick", function(self)
        OmniInventoryDB = OmniInventoryDB or {}
        OmniInventoryDB.global = OmniInventoryDB.global or {}
        OmniInventoryDB.global.attuneHelperEmbed = self:GetChecked() and true or false
        if Omni.Frame and Omni.Frame.UpdateEmbeddedAttuneHelper then
            Omni.Frame:UpdateEmbeddedAttuneHelper()
        end
    end)
    self.attuneHelperEmbedCb = attuneHelperEmbedCb

    yOffset = yOffset - 22

    local attuneHelperMiniNoBorderCb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    attuneHelperMiniNoBorderCb:SetSize(24, 24)
    attuneHelperMiniNoBorderCb:SetPoint("TOPLEFT", 14, yOffset)
    local attuneHelperMiniNoBorderLabel = attuneHelperMiniNoBorderCb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    attuneHelperMiniNoBorderLabel:SetPoint("LEFT", attuneHelperMiniNoBorderCb, "RIGHT", 2, 1)
    attuneHelperMiniNoBorderLabel:SetText("Hide AH Mini Border")
    attuneHelperMiniNoBorderCb:SetChecked(IsAttuneHelperMiniNoBorderEnabled())
    attuneHelperMiniNoBorderCb:SetScript("OnClick", function(self)
        OmniInventoryDB = OmniInventoryDB or {}
        OmniInventoryDB.global = OmniInventoryDB.global or {}
        OmniInventoryDB.global.attuneHelperMiniNoBorder = self:GetChecked() and true or false
        if Omni.Frame and Omni.Frame.UpdateEmbeddedAttuneHelper then
            Omni.Frame:UpdateEmbeddedAttuneHelper()
        end
    end)
    self.attuneHelperMiniNoBorderCb = attuneHelperMiniNoBorderCb

    yOffset = yOffset - 22 - SECTION_GAP

    CreateSectionHeader(parent, "Footer Buttons", yOffset, SECTION_COLORS.footer)
    yOffset = yOffset - HEADER_GAP

    self.footerButtonCbs = self.footerButtonCbs or {}
    for i, def in ipairs(FOOTER_BUTTON_OPTIONS) do
        local column = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local xOffset = (column == 0) and 14 or 160
        local rowY = yOffset - (row * 22)

        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", xOffset, rowY)
        local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("LEFT", cb, "RIGHT", 2, 1)
        lbl:SetText(def.label)
        cb:SetChecked(IsFooterButtonEnabled(def.key))
        cb.__fbKey = def.key
        cb:SetScript("OnClick", function(self)
            local db = GetFooterButtonsDB()
            db[self.__fbKey] = self:GetChecked() and true or false
            if Omni.Frame and Omni.Frame.UpdateFooterCustomButtons then
                Omni.Frame:UpdateFooterCustomButtons()
            end
        end)
        self.footerButtonCbs[def.key] = cb
    end
    local rowCount = math.ceil(#FOOTER_BUTTON_OPTIONS / 2)
    yOffset = yOffset - (rowCount * 22)

    yOffset = yOffset - SECTION_GAP

    CreateSectionHeader(parent, "Addon Buttons", yOffset, SECTION_COLORS.addon)
    yOffset = yOffset - HEADER_GAP

    self.addonButtonCbs = self.addonButtonCbs or {}
    for i, def in ipairs(ADDON_BUTTON_OPTIONS) do
        local column = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local xOffset = (column == 0) and 14 or 160
        local rowY = yOffset - (row * 22)

        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", xOffset, rowY)
        local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("LEFT", cb, "RIGHT", 2, 1)
        lbl:SetText(def.label)
        cb:SetChecked(IsAddonButtonEnabled(def.key))
        cb.__abKey = def.key
        cb:SetScript("OnClick", function(self)
            local db = GetAddonButtonsDB()
            db[self.__abKey] = self:GetChecked() and true or false
            if Omni.Frame and Omni.Frame.UpdateFooterCustomButtons then
                Omni.Frame:UpdateFooterCustomButtons()
            end
        end)
        self.addonButtonCbs[def.key] = cb
    end
    local addonRowCount = math.ceil(#ADDON_BUTTON_OPTIONS / 2)
    yOffset = yOffset - (addonRowCount * 22)

    yOffset = yOffset - SECTION_GAP

    CreateSectionHeader(parent, "Colors", yOffset, SECTION_COLORS.colors)
    yOffset = yOffset - HEADER_GAP

    -- ʕ •ᴥ•ʔ✿ Single swatch factory — caller owns the color table so forge tiers & attune colors share code ✿ ʕ •ᴥ•ʔ
    local function CreateColorSwatch(color, title, xOffset, yPos)
        local swatch = CreateFrame("Button", nil, parent)
        swatch:SetSize(18, 18)
        swatch:SetPoint("TOPLEFT", xOffset, yPos)
        swatch.__color = color

        swatch.bg = swatch:CreateTexture(nil, "BACKGROUND")
        swatch.bg:SetAllPoints()
        swatch.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        swatch.bg:SetVertexColor(0, 0, 0, 1)

        swatch.tex = swatch:CreateTexture(nil, "ARTWORK")
        swatch.tex:SetPoint("TOPLEFT", 1, -1)
        swatch.tex:SetPoint("BOTTOMRIGHT", -1, 1)
        swatch.tex:SetTexture("Interface\\Buttons\\WHITE8X8")

        local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lbl:SetPoint("LEFT", swatch, "RIGHT", 4, 0)
        lbl:SetText(title)
        swatch.label = lbl

        swatch:SetScript("OnClick", function(self)
            RegisterColorPickerCloseRefresh()
            local c = self.__color
            local oldR, oldG, oldB, oldA = c.r, c.g, c.b, c.a or 1
            local function SyncFromPicker()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = OpacitySliderFrame:GetValue()
                c.r, c.g, c.b, c.a = r, g, b, a
                self.tex:SetVertexColor(r, g, b, a)
            end
            colorPickerCloseRefreshPending = true
            ColorPickerFrame.hasOpacity = true
            ColorPickerFrame.opacity = c.a or 1
            ColorPickerFrame.func = SyncFromPicker
            ColorPickerFrame.opacityFunc = SyncFromPicker
            ColorPickerFrame.cancelFunc = function()
                c.r, c.g, c.b, c.a = oldR, oldG, oldB, oldA
                self.tex:SetVertexColor(oldR, oldG, oldB, oldA)
            end
            ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
            OpacitySliderFrame:SetValue(c.a or 1)
            ColorPickerFrame:Show()
        end)

        swatch.tex:SetVertexColor(color.r, color.g, color.b, color.a or 1)
        table.insert(self.colorSwatches, swatch)
        return swatch
    end

    local attune = GetAttuneSettings()

    -- ʕ ◕ᴥ◕ ʔ Row 1: attune bar/text colors
    self.attuneRedColor  = CreateColorSwatch(attune.nonAttunableBarColor,  "Red",   14, yOffset)
    self.attuneTextColor = CreateColorSwatch(attune.textColor,             "Text",  110, yOffset)
    self.attuneFaeColor  = CreateColorSwatch(attune.faeCompleteBarColor,   "Fae",   200, yOffset)
    yOffset = yOffset - 26

    -- ＼ʕ •ᴥ•ʔ／ Row 2: forge tier colors (T/W/L letter + bar tint)
    self.attuneTitanColor = CreateColorSwatch(attune.forgeColors.TITANFORGED, "Titan", 14,  yOffset)
    self.attuneWarColor   = CreateColorSwatch(attune.forgeColors.WARFORGED,   "War",   110, yOffset)
    self.attuneLightColor = CreateColorSwatch(attune.forgeColors.LIGHTFORGED, "Light", 200, yOffset)
    yOffset = yOffset - 26

    -- ʕ •ᴥ•ʔ✿ yOffset grows negative as rows are added — flip and pad for the scroll child ✿ ʕ •ᴥ•ʔ
    self._contentHeight = math.abs(yOffset) + 40
end

function Settings:CreateLabel(parent, text, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOP", x, y)
    label:SetText(text)
    return label
end

-- =============================================================================
-- Actions
-- =============================================================================

function Settings:Toggle()
    if not optionsFrame then
        self:CreateOptionsFrame()
    end

    if optionsFrame:IsShown() then
        optionsFrame:Hide()
    else
        self:UpdateValues()
        optionsFrame:Show()
    end
end

function Settings:UpdateValues()
    if not optionsFrame then return end

    self._syncingScaleControls = true

    if self.highlightNewItemsCb and Omni.Data then
        self.highlightNewItemsCb:SetChecked(Omni.Data:Get("highlightNewItems") == true)
    end
    if self.footerMoneyEmphasisCb and Omni.Data then
        self.footerMoneyEmphasisCb:SetChecked(Omni.Data:Get("footerMoneyEmphasis") == true)
    end
    if self.tooltipSideBtn then
        local side = GetTooltipSide()
        self.tooltipSideBtn:SetText("Tooltip Side: " .. (side == "right" and "Prefer Right" or "Prefer Left"))
    end

    if Omni.Frame and self.scaleSlider then
        local scale = Omni.Frame:GetScale()
        self.scaleSlider:SetValue(scale)
        if self.scaleValueText then
            self.scaleValueText:SetText("Current: " .. FormatScalePercent(scale))
        end
    end
    if Omni.Frame and self.itemScaleSlider and Omni.Frame.GetItemScale then
        local itemScale = Omni.Frame:GetItemScale()
        self.itemScaleSlider:SetValue(itemScale)
        if self.itemScaleValueText then
            self.itemScaleValueText:SetText("Current: " .. FormatScalePercent(itemScale))
        end
    end
    if Omni.Frame and self.itemGapSlider and Omni.Frame.GetItemGap then
        local itemGap = Omni.Frame:GetItemGap()
        self.itemGapSlider:SetValue(itemGap)
        if self.itemGapValueText then
            self.itemGapValueText:SetText("Current: " .. FormatGapPixels(itemGap))
        end
    end
    local scaleControlsEnabled = not IsSettingEditLocked()
    local function SetSliderInteractive(slider, enabled)
        if not slider then return end
        slider:EnableMouse(enabled)
        slider:SetAlpha(enabled and 1 or 0.55)
    end
    SetSliderInteractive(self.scaleSlider, scaleControlsEnabled)
    SetSliderInteractive(self.itemScaleSlider, scaleControlsEnabled)
    SetSliderInteractive(self.itemGapSlider, scaleControlsEnabled)

    local attune = GetAttuneSettings()
    if self.attuneEnabled then self.attuneEnabled:SetChecked(attune.enabled == true) end
    if self.attuneProgressText then self.attuneProgressText:SetChecked(attune.showProgressText == true) end
    if self.attuneBounty then self.attuneBounty:SetChecked(attune.showBountyIcons == true) end
    if self.attuneResist then self.attuneResist:SetChecked(attune.showResistIcons ~= false) end
    if self.attuneRed then self.attuneRed:SetChecked(attune.showRedForNonAttunable ~= false) end
    if self.attuneFae then self.attuneFae:SetChecked(attune.faeMode == true) end
    if self.attuneForgeOutline then self.attuneForgeOutline:SetChecked(attune.forgeOutline ~= false) end
    if self.attuneHelperEmbedCb then self.attuneHelperEmbedCb:SetChecked(IsAttuneHelperEmbedEnabled()) end
    if self.attuneHelperMiniNoBorderCb then self.attuneHelperMiniNoBorderCb:SetChecked(IsAttuneHelperMiniNoBorderEnabled()) end
    if self.footerButtonCbs then
        for _, def in ipairs(FOOTER_BUTTON_OPTIONS) do
            local cb = self.footerButtonCbs[def.key]
            if cb then cb:SetChecked(IsFooterButtonEnabled(def.key)) end
        end
    end
    if self.addonButtonCbs then
        for _, def in ipairs(ADDON_BUTTON_OPTIONS) do
            local cb = self.addonButtonCbs[def.key]
            if cb then cb:SetChecked(IsAddonButtonEnabled(def.key)) end
        end
    end
    if self.colorSwatches then
        for _, swatch in ipairs(self.colorSwatches) do
            local c = swatch.__color
            if c and swatch.tex then
                swatch.tex:SetVertexColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
            end
        end
    end

    self._syncingScaleControls = false
end

function Settings:Init()
    -- Initialized
end

print("|cFF00FF00OmniInventory|r: Settings module loaded")
