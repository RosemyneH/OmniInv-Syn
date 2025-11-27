local addonName, NS = ...

NS.Settings = {}

function NS.Settings:Init()
    -- 1. Create Main Panel (About)
    self.panel = CreateFrame("Frame", "ZenBagsOptionsPanel", UIParent)
    self.panel.name = "ZenBags"

    -- Title
    local title = self.panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("ZenBags")

    -- About Info
    local version = self.panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    version:SetText("Version: v0.1")

    local author = self.panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    author:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -10)
    author:SetText("Created by: |cFF00FFFFZendevve|r")

    local desc = self.panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    desc:SetPoint("TOPLEFT", author, "BOTTOMLEFT", 0, -20)
    desc:SetWidth(380)
    desc:SetJustifyH("LEFT")
    desc:SetText("ZenBags is a modern, lightweight bag addon designed to keep your inventory clean and organized.\n\nExpand the menu on the left to access configuration settings.")

    -- Register Main Panel
    InterfaceOptions_AddCategory(self.panel)

    -- 2. Create General Settings Sub-panel
    self.generalPanel = CreateFrame("Frame", "ZenBagsGeneralOptions", self.panel)
    self.generalPanel.name = "General"
    self.generalPanel.parent = "ZenBags"

    local subTitle = self.generalPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    subTitle:SetPoint("TOPLEFT", 16, -16)
    subTitle:SetText("General Settings")

    -- Register Sub-panel
    InterfaceOptions_AddCategory(self.generalPanel)

    -- Create Controls on the Sub-panel
    self:CreateGeneralSettings()
end

function NS.Settings:CreateGeneralSettings()
    local yOffset = -50 -- Start below title

    -- === Appearance Section ===
    self:CreateHeader("Appearance", yOffset)
    yOffset = yOffset - 30

    -- UI Scale Slider
    self:CreateSlider("Scale", "UI Scale", 0.5, 1.5, 0.1, function(value)
        NS.Config:Set("scale", value)
        NS.Frames.mainFrame:SetScale(value)
    end, yOffset)
    yOffset = yOffset - 50

    -- Opacity Slider
    self:CreateSlider("Opacity", "Opacity", 0.3, 1.0, 0.1, function(value)
        NS.Config:Set("opacity", value)
        NS.Frames.mainFrame:SetAlpha(value)
    end, yOffset)
    yOffset = yOffset - 50

    -- Item Size Slider
    self:CreateSlider("ItemSize", "Item Size", 30, 45, 1, function(value)
        NS.Config:Set("itemSize", value)
        NS.Frames:Update(true)
    end, yOffset)
    yOffset = yOffset - 50

    -- Spacing Slider
    self:CreateSlider("Padding", "Item Spacing", 2, 10, 1, function(value)
        NS.Config:Set("padding", value)
        NS.Frames:Update(true)
    end, yOffset)
    yOffset = yOffset - 60 -- Extra space

    -- === Behavior Section ===
    self:CreateHeader("Behavior", yOffset)
    yOffset = yOffset - 30

    -- Enable Search Checkbox
    self:CreateCheckbox("EnableSearch", "Enable Search Bar", function(checked)
        NS.Config:Set("enableSearch", checked)
        if checked then
            NS.Frames.searchBox:Show()
        else
            NS.Frames.searchBox:Hide()
        end
    end, yOffset)
    yOffset = yOffset - 30

    -- Show Tooltips Checkbox
    self:CreateCheckbox("ShowTooltips", "Show Item Tooltips", function(checked)
        NS.Config:Set("showTooltips", checked)
    end, yOffset)
    yOffset = yOffset - 30

    -- Auto Sort Checkbox
    self:CreateCheckbox("SortOnUpdate", "Auto-Sort Items", function(checked)
        NS.Config:Set("sortOnUpdate", checked)
    end, yOffset)
    yOffset = yOffset - 50

    -- Reset Button
    local resetBtn = CreateFrame("Button", nil, self.generalPanel, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 25)
    resetBtn:SetText("Reset Defaults")
    resetBtn:SetScript("OnClick", function()
        NS.Config:Reset()
        self:RefreshControls()
        NS.Frames:Update(true)
        print("|cFF00FF00ZenBags:|r Settings reset to defaults.")
    end)
    resetBtn:SetPoint("TOPLEFT", 20, yOffset)

    -- Initial Refresh
    self:RefreshControls()

    -- Hook into the panel's OnShow to refresh controls
    self.generalPanel:SetScript("OnShow", function()
        self:RefreshControls()
    end)
end

function NS.Settings:CreateHeader(text, y)
    local header = self.generalPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 20, y)
    header:SetText(text)
    header:SetTextColor(1, 0.82, 0, 1) -- Standard gold header color

    -- Add separator line under header
    local line = self.generalPanel:CreateTexture(nil, "ARTWORK")
    line:SetTexture(0.4, 0.4, 0.4, 0.5)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 20, y - 18)
    line:SetPoint("RIGHT", -20, 0)
end

function NS.Settings:CreateSlider(key, label, minVal, maxVal, step, callback, y)
    -- Use standard slider template but parent to our panel
    local slider = CreateFrame("Slider", "ZenBagsOption_"..key, self.generalPanel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 30, y)
    slider:SetWidth(200)

    getglobal(slider:GetName() .. 'Low'):SetText(minVal)
    getglobal(slider:GetName() .. 'High'):SetText(maxVal)
    getglobal(slider:GetName() .. 'Text'):SetText(label)

    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)

    slider:SetScript("OnValueChanged", function(self, value)
        -- Round to step
        value = math.floor(value / step + 0.5) * step
        callback(value)
    end)

    -- Store for refresh
    self.controls = self.controls or {}
    self.controls[key] = { type = "slider", frame = slider }
end

function NS.Settings:CreateCheckbox(key, label, callback, y)
    local cb = CreateFrame("CheckButton", "ZenBagsOption_"..key, self.generalPanel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 25, y)
    getglobal(cb:GetName() .. 'Text'):SetText(label)

    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        callback(checked)
    end)

    -- Store for refresh
    self.controls = self.controls or {}
    self.controls[key] = { type = "checkbox", frame = cb }
end

function NS.Settings:RefreshControls()
    if not self.controls then return end

    -- Update UI with current config values
    local config = NS.Config

    -- Sliders
    if self.controls["Scale"] then self.controls["Scale"].frame:SetValue(config:Get("scale")) end
    if self.controls["Opacity"] then self.controls["Opacity"].frame:SetValue(config:Get("opacity")) end
    if self.controls["ItemSize"] then self.controls["ItemSize"].frame:SetValue(config:Get("itemSize")) end
    if self.controls["Padding"] then self.controls["Padding"].frame:SetValue(config:Get("padding")) end

    -- Checkboxes
    if self.controls["EnableSearch"] then self.controls["EnableSearch"].frame:SetChecked(config:Get("enableSearch")) end
    if self.controls["ShowTooltips"] then self.controls["ShowTooltips"].frame:SetChecked(config:Get("showTooltips")) end
    if self.controls["SortOnUpdate"] then self.controls["SortOnUpdate"].frame:SetChecked(config:Get("sortOnUpdate")) end
end

function NS.Settings:Open()
    -- Open the General sub-panel directly
    InterfaceOptionsFrame_OpenToCategory(self.generalPanel)
    -- Double call is sometimes needed in 3.3.5a to properly select the category if the frame wasn't shown
    InterfaceOptionsFrame_OpenToCategory(self.generalPanel)
end
