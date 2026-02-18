local addonName, NS = ...

NS.Theme = {}
local Theme = NS.Theme

-----------------------------------------------------------
-- ZenBags Zen 2.0 Design System
-- Inspired by: ElvUI (clean/modular) + AdiBags (modern/minimal)
-- Color: Dark + Blue (WoW Classic)
-----------------------------------------------------------

-- =============================================================================
-- Color Palette
-- =============================================================================

Theme.Colors = {
    -- Base Dark (BagShui-inspired)
    Background = { 0.10, 0.10, 0.10, 0.99 },      -- Neutral dark
    Surface = { 0.15, 0.15, 0.15, 1.00 },          -- Slightly lighter (header/footer)
    SurfaceHover = { 0.20, 0.20, 0.20, 1.00 },     -- Hover state

    -- Borders (BagShui-style)
    Border = { 0.30, 0.30, 0.30, 1.00 },           -- Subtle grey
    BorderLight = { 0.45, 0.45, 0.45, 1.00 },      -- Focus/hover border

    -- Accent (Gold - WoW classic)
    Accent = { 0.80, 0.70, 0.20, 1.00 },           -- Warm gold
    AccentLight = { 0.90, 0.80, 0.30, 1.00 },      -- Hover gold
    AccentDark = { 0.60, 0.50, 0.15, 1.00 },       -- Pressed gold

    -- Text
    Text = { 0.90, 0.90, 0.90, 1.00 },             -- Primary text
    TextSecondary = { 0.60, 0.60, 0.60, 1.00 },    -- Muted text
    TextDisabled = { 0.40, 0.40, 0.40, 1.00 },     -- Disabled text

    -- Semantic
    Success = { 0.30, 0.85, 0.45, 1.00 },          -- Green
    Warning = { 1.00, 0.75, 0.25, 1.00 },          -- Gold
    Danger = { 0.95, 0.30, 0.35, 1.00 },           -- Red

    -- Item Quality (Blizzard Standard)
    Quality = {
        [0] = { 0.62, 0.62, 0.62 },     -- Poor (Grey)
        [1] = { 1.00, 1.00, 1.00 },     -- Common (White)
        [2] = { 0.12, 1.00, 0.00 },     -- Uncommon (Green)
        [3] = { 0.00, 0.44, 0.87 },     -- Rare (Blue)
        [4] = { 0.64, 0.21, 0.93 },     -- Epic (Purple)
        [5] = { 1.00, 0.50, 0.00 },     -- Legendary (Orange)
        [6] = { 0.90, 0.80, 0.50 },     -- Artifact (Gold)
        [7] = { 0.00, 0.80, 1.00 },     -- Heirloom (Light Blue)
    }
}

-- =============================================================================
-- Spacing (BagShui Values)
-- =============================================================================

Theme.Spacing = {
    windowPadding = 6,           -- BagShui: inventoryWindowPadding
    headerFooterYAdjust = 2,     -- BagShui: inventoryHeaderFooterYAdjustment
    toolbarSpacing = 8,          -- BagShui: toolbarSpacing
    bagBarSpacing = 7,           -- BagShui: bagBarSpacing
    itemSlotMargin = 2,          -- BagShui: itemSlotMarginFudge
    groupPadding = 2,            -- BagShui: groupPaddingFudge
}

-- =============================================================================
-- Sizing (BagShui Values)
-- =============================================================================

Theme.Sizes = {
    ItemSlot = 37,               -- Standard item slot size
    HeaderFooterHeight = 22,     -- BagShui: inventoryHeaderFooterHeight
    TitleBarHeight = 20,         -- BagShui: windowTitleBarHeight
    CloseButtonSize = 18,        -- BagShui: closeButtonSize
    IconButtonSize = 16,         -- Toolbar icon size
    BagBarScale = 0.75,          -- BagShui: bagBarScale
}

-- =============================================================================
-- Border Styles (BagShui Values)
-- =============================================================================

Theme.Borders = {
    -- Item slot border (tooltip style)
    itemSlot = {
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    },
    -- Frame/window border
    frame = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        tileSize = 0,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    },
    -- Inner glow for active/hovered items
    innerGlowTexture = "Interface\\Buttons\\UI-ActionButton-Border",
    innerGlowOpacity = 0.4,
    innerGlowAnchor = 14,
}

-- =============================================================================
-- Font Helpers
-- =============================================================================

Theme.Fonts = {
    Header = "GameFontNormalLarge",
    Normal = "GameFontNormal",
    Small = "GameFontNormalSmall",
    Highlight = "GameFontHighlight",
    HighlightSmall = "GameFontHighlightSmall",
}

-- =============================================================================
-- UI Creation Helpers
-- =============================================================================

--- Create a styled backdrop
function Theme:CreateBackdrop(frame, style)
    style = style or "surface"

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })

    if style == "surface" then
        frame:SetBackdropColor(unpack(self.Colors.Surface))
        frame:SetBackdropBorderColor(unpack(self.Colors.Border))
    elseif style == "background" then
        frame:SetBackdropColor(unpack(self.Colors.Background))
        frame:SetBackdropBorderColor(unpack(self.Colors.Border))
    elseif style == "input" then
        frame:SetBackdropColor(0.04, 0.04, 0.06, 1)
        frame:SetBackdropBorderColor(unpack(self.Colors.Border))
    elseif style == "accent" then
        frame:SetBackdropColor(unpack(self.Colors.AccentDark))
        frame:SetBackdropBorderColor(unpack(self.Colors.Accent))
    end
end

--- Create a flat button with hover effects
function Theme:CreateButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width or 80, height or self.Sizes.ButtonHeight)
    self:CreateBackdrop(btn, "surface")

    -- Text
    local fs = btn:CreateFontString(nil, "OVERLAY", self.Fonts.Small)
    fs:SetPoint("CENTER")
    fs:SetText(text or "")
    fs:SetTextColor(unpack(self.Colors.Text))
    btn.text = fs

    -- Hover effects
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(Theme.Colors.SurfaceHover))
        self:SetBackdropBorderColor(unpack(Theme.Colors.BorderLight))
    end)
    btn:SetScript("OnLeave", function(self)
        Theme:CreateBackdrop(self, "surface")
    end)
    btn:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(unpack(Theme.Colors.AccentDark))
    end)
    btn:SetScript("OnMouseUp", function(self)
        self:SetBackdropColor(unpack(Theme.Colors.SurfaceHover))
    end)

    return btn
end

--- Create an icon button (small, square)
function Theme:CreateIconButton(parent, texture, size)
    size = size or self.Sizes.IconSize + 8
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)
    self:CreateBackdrop(btn, "surface")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(self.Sizes.IconSize, self.Sizes.IconSize)
    icon:SetPoint("CENTER")
    icon:SetTexture(texture)
    icon:SetVertexColor(unpack(self.Colors.TextSecondary))
    btn.icon = icon

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(Theme.Colors.SurfaceHover))
        self.icon:SetVertexColor(unpack(Theme.Colors.Text))
    end)
    btn:SetScript("OnLeave", function(self)
        Theme:CreateBackdrop(self, "surface")
        self.icon:SetVertexColor(unpack(Theme.Colors.TextSecondary))
    end)

    return btn
end

--- Create a search box
function Theme:CreateSearchBox(parent, width)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width or 200, self.Sizes.SearchHeight)
    self:CreateBackdrop(frame, "input")

    -- Search icon
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(12, 12)
    icon:SetPoint("LEFT", 8, 0)
    icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    icon:SetVertexColor(unpack(self.Colors.TextSecondary))

    -- EditBox
    local eb = CreateFrame("EditBox", nil, frame)
    eb:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    eb:SetPoint("RIGHT", -8, 0)
    eb:SetHeight(self.Sizes.SearchHeight)
    eb:SetFontObject(self.Fonts.Small)
    eb:SetTextColor(unpack(self.Colors.Text))
    eb:SetAutoFocus(false)
    frame.editBox = eb

    -- Placeholder
    local ph = eb:CreateFontString(nil, "OVERLAY", self.Fonts.Small)
    ph:SetPoint("LEFT", 0, 0)
    ph:SetText("Search...")
    ph:SetTextColor(unpack(self.Colors.TextDisabled))
    eb.placeholder = ph

    eb:SetScript("OnTextChanged", function(self)
        if self:GetText() == "" then
            self.placeholder:Show()
        else
            self.placeholder:Hide()
        end
    end)

    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    return frame
end

--- Create a section header
function Theme:CreateSectionHeader(parent, text, width)
    local frame = CreateFrame("Button", nil, parent)
    frame:SetSize(width or 200, self.Sizes.HeaderHeight)

    -- Background (subtle)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(unpack(self.Colors.Surface))
    frame.bg = bg

    -- Chevron
    local chevron = frame:CreateFontString(nil, "OVERLAY", self.Fonts.Small)
    chevron:SetPoint("LEFT", self.Spacing.sm, 0)
    chevron:SetText("▼")
    chevron:SetTextColor(unpack(self.Colors.TextSecondary))
    frame.chevron = chevron

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", self.Fonts.Normal)
    title:SetPoint("LEFT", chevron, "RIGHT", self.Spacing.sm, 0)
    title:SetText(text or "Section")
    title:SetTextColor(unpack(self.Colors.Text))
    frame.title = title

    -- Count badge
    local count = frame:CreateFontString(nil, "OVERLAY", self.Fonts.HighlightSmall)
    count:SetPoint("LEFT", title, "RIGHT", self.Spacing.sm, 0)
    count:SetText("")
    count:SetTextColor(unpack(self.Colors.TextSecondary))
    frame.count = count

    -- Hover effect
    frame:SetScript("OnEnter", function(self)
        self.bg:SetVertexColor(unpack(Theme.Colors.SurfaceHover))
    end)
    frame:SetScript("OnLeave", function(self)
        self.bg:SetVertexColor(unpack(Theme.Colors.Surface))
    end)

    -- Collapse state
    frame.collapsed = false
    frame.SetCollapsed = function(self, collapsed)
        self.collapsed = collapsed
        self.chevron:SetText(collapsed and "▶" or "▼")
    end

    return frame
end

--- Get quality color
function Theme:GetQualityColor(quality)
    return self.Colors.Quality[quality] or self.Colors.Quality[1]
end

--- Apply item slot styling
function Theme:StyleItemSlot(btn)
    -- Remove default border styling
    if btn.IconBorder then
        btn.IconBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
        btn.IconBorder:SetDrawLayer("BORDER")
    end

    -- Add hover glow
    if not btn.hoverGlow then
        local glow = btn:CreateTexture(nil, "OVERLAY")
        glow:SetPoint("TOPLEFT", -2, 2)
        glow:SetPoint("BOTTOMRIGHT", 2, -2)
        glow:SetTexture("Interface\\Buttons\\WHITE8X8")
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(1, 1, 1, 0.15)
        glow:Hide()
        btn.hoverGlow = glow
    end

    btn:HookScript("OnEnter", function(self)
        if self.hoverGlow then self.hoverGlow:Show() end
    end)
    btn:HookScript("OnLeave", function(self)
        if self.hoverGlow then self.hoverGlow:Hide() end
    end)
end

-- Debug log
print("|cFF3399FFZenBags Theme|r loaded.")
