local addonName, NS = ...

NS.Utils = {}
local Utils = NS.Utils


function Utils:Init()
    -- Selling protection removed - was just a placeholder warning
end


-- =============================================================================
-- UI Skinning Helpers
-- =============================================================================

local COLORS = {
    BG      = {0.10, 0.10, 0.10, 1.00},
    BORDER  = {0.00, 0.00, 0.00, 1.00},
    ACCENT  = {0.20, 0.20, 0.20, 1.00},
    HIGHLIGHT = {0.30, 0.30, 0.30, 1.00},
    TEXT    = {0.90, 0.90, 0.90, 1.00},
    BLUE    = {0.20, 0.60, 1.00, 1.00},
    RED     = {0.80, 0.20, 0.20, 1.00},
}
Utils.COLORS = COLORS

function Utils:CreateBackdrop(f)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    f:SetBackdropColor(unpack(COLORS.BG))
    f:SetBackdropBorderColor(unpack(COLORS.BORDER))
end

function Utils:CreateFlatButton(parent, text, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)
    self:CreateBackdrop(btn)
    btn:SetBackdropColor(0.15, 0.15, 0.15, 1)

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    fs:SetText(text)
    btn.text = fs

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLORS.HIGHLIGHT))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.15, 1)
    end)

    if onClick then
        btn:SetScript("OnClick", onClick)
    end

    return btn
end

function Utils:CreateCloseButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(20, 20)
    self:CreateBackdrop(btn)
    btn:SetBackdropColor(0.15, 0.15, 0.15, 1)

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("CENTER", 0, 0)
    fs:SetText("X")

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLORS.RED))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.15, 1)
    end)

    return btn
end

function Utils:CreateFlatCheckbox(parent, label, onClick)
    local cb = CreateFrame("Button", nil, parent)
    cb:SetSize(18, 18)
    self:CreateBackdrop(cb)
    cb:SetBackdropColor(0.12, 0.12, 0.12, 1)

    -- Check texture
    local check = cb:CreateTexture(nil, "ARTWORK")
    check:SetPoint("TOPLEFT", 3, -3)
    check:SetPoint("BOTTOMRIGHT", -3, 3)
    check:SetTexture("Interface\\Buttons\\WHITE8X8")
    check:SetVertexColor(unpack(COLORS.BLUE))
    check:Hide()
    cb.check = check

    -- Label
    local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    fs:SetText(label)
    cb.text = fs

    cb.checked = false
    cb.SetChecked = function(self, checked)
        self.checked = checked
        if checked then self.check:Show() else self.check:Hide() end
    end
    cb.GetChecked = function(self) return self.checked end

    cb:SetScript("OnClick", function(self)
        local newVal = not self.checked
        self:SetChecked(newVal)
        if onClick then onClick(newVal) end
    end)

    return cb
end

function Utils:CreateFlatSlider(parent, label, minVal, maxVal, step, onValueChanged)
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation("HORIZONTAL")
    slider:SetHeight(10)
    slider:SetWidth(200)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    -- slider:SetObeyStepOnDrag(true) -- Not supported in 3.3.5a

    -- Track
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetTexture("Interface\\Buttons\\WHITE8X8")
    track:SetVertexColor(0.2, 0.2, 0.2, 1)
    track:SetHeight(4)
    track:SetPoint("LEFT", 0, 0)
    track:SetPoint("RIGHT", 0, 0)

    -- Thumb
    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
    thumb:SetVertexColor(unpack(COLORS.BLUE))
    thumb:SetSize(10, 16)
    slider:SetThumbTexture(thumb)

    -- Label
    local fs = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("BOTTOM", slider, "TOP", 0, 5)
    fs:SetText(label)

    -- Value Label
    local valFs = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valFs:SetPoint("TOP", slider, "BOTTOM", 0, -2)
    slider.valText = valFs

    slider:SetScript("OnValueChanged", function(self, value)
        -- Round
        value = math.floor(value / step + 0.5) * step
        self.valText:SetText(string.format("%.1f", value))
        if onValueChanged then onValueChanged(value) end
    end)

    return slider
end

function Utils:SkinScrollFrame(scrollFrame)
    local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
    if not scrollBar then return end

    -- Hide default textures
    local thumb = scrollBar:GetThumbTexture()
    if thumb then
        thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
        thumb:SetVertexColor(0.3, 0.3, 0.3, 1)
        thumb:SetWidth(8)
    end

    -- Hide arrows and border
    local children = {scrollBar:GetRegions()}
    for _, region in ipairs(children) do
        if region ~= thumb then
            region:Hide()
        end
    end

    -- Hide buttons if they exist as children
    local kids = {scrollBar:GetChildren()}
    for _, child in ipairs(kids) do
        child:Hide()
    end
end
