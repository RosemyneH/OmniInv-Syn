local addonName, NS = ...

NS.Settings = {}

function NS.Settings:Init()
    -- Create Settings Frame
    self.frame = CreateFrame("Frame", "ZenBagsSettingsFrame", UIParent)
    self.frame:SetSize(400, 500)
    self.frame:SetPoint("CENTER")
    self.frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    self.frame:EnableMouse(true)
    self.frame:SetMovable(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", self.frame.StartMoving)
    self.frame:SetScript("OnDragStop", self.frame.StopMovingOrSizing)
    self.frame:Hide()

    -- Title
    self.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.title:SetPoint("TOP", 0, -15)
    self.title:SetText("ZenBags Settings")

    -- Close Button
    self.closeBtn = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    self.closeBtn:SetPoint("TOPRIGHT", -5, -5)

    -- Create Controls
    self:CreateControls()
end

function NS.Settings:CreateControls()
    local yOffset = -60
    
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
    local resetBtn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 25)
    resetBtn:SetPoint("BOTTOM", 0, 20)
    resetBtn:SetText("Reset Defaults")
    resetBtn:SetScript("OnClick", function()
        NS.Config:Reset()
        self:RefreshControls()
        NS.Frames:Update(true)
        print("|cFF00FF00ZenBags:|r Settings reset to defaults.")
    end)
end

function NS.Settings:CreateHeader(text, y)
    local header = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 20, y)
    header:SetText(text)
end

function NS.Settings:CreateSlider(key, label, minVal, maxVal, step, callback, y)
    local slider = CreateFrame("Slider", "ZenBagsSlider"..key, self.frame, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 30, y)
    slider:SetWidth(200)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    -- slider:SetObeyStepOnDrag(true) -- Not available in Classic
    
    _G[slider:GetName().."Low"]:SetText(minVal)
    _G[slider:GetName().."High"]:SetText(maxVal)
    _G[slider:GetName().."Text"]:SetText(label)
    
    -- Value Label
    local valueLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueLabel:SetPoint("TOP", slider, "BOTTOM", 0, 0)
    
    slider:SetScript("OnValueChanged", function(self, value)
        -- Round to avoid floating point weirdness
        value = math.floor(value / step + 0.5) * step
        valueLabel:SetText(string.format("%.1f", value))
        callback(value)
    end)
    
    -- Store for refresh
    self.controls = self.controls or {}
    self.controls[key] = { type = "slider", frame = slider }
end

function NS.Settings:CreateCheckbox(key, label, callback, y)
    local cb = CreateFrame("CheckButton", "ZenBagsCheck"..key, self.frame, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 25, y)
    _G[cb:GetName().."Text"]:SetText(label)
    
    cb:SetScript("OnClick", function(self)
        callback(self:GetChecked())
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
    self.controls["Scale"].frame:SetValue(config:Get("scale"))
    self.controls["Opacity"].frame:SetValue(config:Get("opacity"))
    self.controls["ItemSize"].frame:SetValue(config:Get("itemSize"))
    self.controls["Padding"].frame:SetValue(config:Get("padding"))
    
    -- Checkboxes
    self.controls["EnableSearch"].frame:SetChecked(config:Get("enableSearch"))
    self.controls["ShowTooltips"].frame:SetChecked(config:Get("showTooltips"))
    self.controls["SortOnUpdate"].frame:SetChecked(config:Get("sortOnUpdate"))
end

function NS.Settings:Toggle()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:RefreshControls()
        self.frame:Show()
    end
end
