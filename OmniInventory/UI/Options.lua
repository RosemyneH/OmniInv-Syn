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
    if attune.faeMode == nil then attune.faeMode = false end
    if attune.enableAnimations == nil then attune.enableAnimations = true end
    if attune.enableTextAnimations == nil then attune.enableTextAnimations = true end
    if attune.animationSpeed == nil then attune.animationSpeed = 0.15 end

    attune.nonAttunableBarColor = attune.nonAttunableBarColor or { r = 1.0, g = 0.0, b = 0.0, a = 1.0 }
    attune.textColor = attune.textColor or { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
    attune.faeCompleteBarColor = attune.faeCompleteBarColor or { r = 0.95, g = 0.8, b = 0.2, a = 1.0 }

    return attune
end

-- =============================================================================
-- Creation
-- =============================================================================

function Settings:CreateOptionsFrame()
    if optionsFrame then return optionsFrame end

    optionsFrame = CreateFrame("Frame", "OmniOptionsFrame", UIParent)
    optionsFrame:SetSize(320, 560)
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:EnableMouse(true)
    optionsFrame:SetMovable(true)
    optionsFrame:SetClampedToScreen(true)

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

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    -- Content Container
    local content = CreateFrame("Frame", nil, optionsFrame)
    content:SetPoint("TOPLEFT", 16, -40)
    content:SetPoint("BOTTOMRIGHT", -16, 16)

    self.content = content
    self:CreateControls(content)

    optionsFrame:Hide()
    return optionsFrame
end

function Settings:CreateControls(parent)
    local yOffset = -20
    local SPACING = 40

    -- 1. Scale Slider
    local scaleSlider = CreateFrame("Slider", "OmniScaleSlider", parent, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOP", 0, yOffset)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.1)
    -- Note: SetObeyStepOnDrag not available in WotLK 3.3.5a
    scaleSlider:SetWidth(200)

    _G[scaleSlider:GetName() .. "Low"]:SetText("50%")
    _G[scaleSlider:GetName() .. "High"]:SetText("200%")
    _G[scaleSlider:GetName() .. "Text"]:SetText("Frame Scale")

    scaleSlider:SetScript("OnValueChanged", function(self, value)
        -- Round to 1 decimal
        value = math.floor(value * 10 + 0.5) / 10
        if Omni.Frame then
            Omni.Frame:SetScale(value)
        end
    end)
    self.scaleSlider = scaleSlider

    yOffset = yOffset - SPACING - 20

    -- 2. View Mode (Grid, Flow, List)
    self:CreateLabel(parent, "View Mode", 0, yOffset)
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

    -- 3. Sort Mode
    self:CreateLabel(parent, "Sort Mode (Default)", 0, yOffset)
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

    -- 4. Category Editor Button
    local catBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    catBtn:SetSize(160, 24)
    catBtn:SetPoint("TOP", 0, yOffset)
    catBtn:SetText("Open Category Editor")
    catBtn:SetScript("OnClick", function()
        if Omni.CategoryEditor then
            Omni.CategoryEditor:Toggle()
        else
            print("|cFF00FF00OmniInventory|r: Category Editor not loaded")
        end
    end)
    self.catBtn = catBtn

    yOffset = yOffset - SPACING - 10

    -- 5. Reset Button
    local resetBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    resetBtn:SetSize(160, 24)
    resetBtn:SetPoint("TOP", 0, yOffset)
    resetBtn:SetText("Reset Position & Scale")
    resetBtn:SetScript("OnClick", function()
        if Omni.Frame then
            Omni.Frame:ResetPosition()
            if self.scaleSlider then self.scaleSlider:SetValue(1.0) end
        end
    end)

    yOffset = yOffset - SPACING - 10

    local attuneLabel = self:CreateLabel(parent, "Attune Overlay", 0, yOffset)
    yOffset = yOffset - 18

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
            if Omni.Frame then Omni.Frame:UpdateLayout() end
        end)
        return cb
    end

    self.attuneEnabled = CreateAttuneCheckbox("enabled", "Enable", 14)
    self.attuneProgressText = CreateAttuneCheckbox("showProgressText", "Show %", 160)
    yOffset = yOffset - 22
    self.attuneBounty = CreateAttuneCheckbox("showBountyIcons", "Bounty", 14)
    self.attuneAccount = CreateAttuneCheckbox("showAccountIcons", "Account", 160)
    yOffset = yOffset - 22
    self.attuneResist = CreateAttuneCheckbox("showResistIcons", "Resist", 14)
    self.attuneRed = CreateAttuneCheckbox("showRedForNonAttunable", "Red Bars", 160)
    yOffset = yOffset - 22
    self.attuneFae = CreateAttuneCheckbox("faeMode", "Fae 100%", 14)
    self.attuneBarAnim = CreateAttuneCheckbox("enableAnimations", "Bar Anim", 160)
    yOffset = yOffset - 22
    self.attuneTextAnim = CreateAttuneCheckbox("enableTextAnimations", "Text Anim", 14)
    yOffset = yOffset - 34

    local attuneSpeed = CreateFrame("Slider", "OmniAttuneAnimSpeedSlider", parent, "OptionsSliderTemplate")
    attuneSpeed:SetPoint("TOP", parent, "TOP", 0, yOffset)
    attuneSpeed:SetMinMaxValues(0.05, 1.0)
    attuneSpeed:SetValueStep(0.05)
    attuneSpeed:SetWidth(180)
    local attune = GetAttuneSettings()
    attuneSpeed:SetValue(attune.animationSpeed)
    _G[attuneSpeed:GetName() .. "Low"]:SetText("0.05")
    _G[attuneSpeed:GetName() .. "High"]:SetText("1.0")
    _G[attuneSpeed:GetName() .. "Text"]:SetText("Anim Speed")
    attuneSpeed:SetScript("OnValueChanged", function(self, value)
        attune.animationSpeed = value
        if Omni.Frame then
            Omni.Frame:UpdateLayout()
        end
    end)
    self.attuneSpeed = attuneSpeed

    yOffset = yOffset - 56

    local function CreateColorSwatch(key, title, xOffset)
        local settings = GetAttuneSettings()
        local swatch = CreateFrame("Button", nil, parent)
        swatch:SetSize(18, 18)
        swatch:SetPoint("TOPLEFT", xOffset, yOffset)
        swatch.key = key

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
            local color = settings[self.key]
            local function ApplyColor()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = OpacitySliderFrame:GetValue()
                color.r, color.g, color.b, color.a = r, g, b, a
                self.tex:SetVertexColor(r, g, b, a)
                if Omni.Frame then Omni.Frame:UpdateLayout() end
            end
            ColorPickerFrame.hasOpacity = true
            ColorPickerFrame.opacity = color.a or 1
            ColorPickerFrame.func = ApplyColor
            ColorPickerFrame.opacityFunc = ApplyColor
            ColorPickerFrame:SetColorRGB(color.r, color.g, color.b)
            OpacitySliderFrame:SetValue(color.a or 1)
            ColorPickerFrame:Show()
        end)

        local color = settings[key]
        swatch.tex:SetVertexColor(color.r, color.g, color.b, color.a or 1)
        return swatch
    end

    self.attuneRedColor = CreateColorSwatch("nonAttunableBarColor", "Red", 14)
    self.attuneTextColor = CreateColorSwatch("textColor", "Text", 110)
    self.attuneFaeColor = CreateColorSwatch("faeCompleteBarColor", "Fae", 200)
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

    -- Sync slider with current scale
    if OmniInventoryDB and OmniInventoryDB.char and OmniInventoryDB.char.settings then
        local scale = OmniInventoryDB.char.settings.scale or 1
        self.scaleSlider:SetValue(scale)
    end

    local attune = GetAttuneSettings()
    if self.attuneEnabled then self.attuneEnabled:SetChecked(attune.enabled == true) end
    if self.attuneProgressText then self.attuneProgressText:SetChecked(attune.showProgressText == true) end
    if self.attuneBounty then self.attuneBounty:SetChecked(attune.showBountyIcons == true) end
    if self.attuneAccount then self.attuneAccount:SetChecked(attune.showAccountIcons == true) end
    if self.attuneResist then self.attuneResist:SetChecked(attune.showResistIcons ~= false) end
    if self.attuneRed then self.attuneRed:SetChecked(attune.showRedForNonAttunable ~= false) end
    if self.attuneFae then self.attuneFae:SetChecked(attune.faeMode == true) end
    if self.attuneTextAnim then self.attuneTextAnim:SetChecked(attune.enableTextAnimations ~= false) end
    if self.attuneBarAnim then self.attuneBarAnim:SetChecked(attune.enableAnimations ~= false) end
    if self.attuneSpeed then self.attuneSpeed:SetValue(attune.animationSpeed or 0.15) end
    if self.attuneRedColor then
        local c = attune.nonAttunableBarColor
        self.attuneRedColor.tex:SetVertexColor(c.r, c.g, c.b, c.a or 1)
    end
    if self.attuneTextColor then
        local c = attune.textColor
        self.attuneTextColor.tex:SetVertexColor(c.r, c.g, c.b, c.a or 1)
    end
    if self.attuneFaeColor then
        local c = attune.faeCompleteBarColor
        self.attuneFaeColor.tex:SetVertexColor(c.r, c.g, c.b, c.a or 1)
    end
end

function Settings:Init()
    -- Initialized
end

print("|cFF00FF00OmniInventory|r: Settings module loaded")
