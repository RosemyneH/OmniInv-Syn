local addonName, NS = ...

-----------------------------------------------------------
-- View Toggle System
-- Purpose: Switch between Category view and Grid view
-----------------------------------------------------------

--- Update view toggle button icon based on current layout mode
function NS.Frames:UpdateViewToggleIcon()
    if not self.viewToggleBtn then return end

    local mode = NS.Config:Get("layoutMode") or "category"

    -- Change icon based on mode
    if mode == "category" then
        -- Category mode - show grid icon to indicate "switch to grid"
        self.viewToggleBtn.icon:SetTexture("Interface\\Buttons\\UI-GuildButton-MOTD-Up")
        self.viewToggleBtn.tooltip = "Switch to Grid View"
    else
        -- Grid mode - show list icon to indicate "switch to categories"
        self.viewToggleBtn.icon:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
        self.viewToggleBtn.tooltip = "Switch to Category View"
    end
end

--- Toggle between layout modes
function NS.Frames:ToggleLayoutMode()
    local currentMode = NS.Config:Get("layoutMode") or "category"
    local newMode = currentMode == "category" and "grid" or "category"

    NS.Config:Set("layoutMode", newMode)
    self:UpdateViewToggleIcon()
    self:Update(true) -- Force full update

    local modeName = newMode == "category" and "Category" or "Grid"
    print(string.format("|cFF00FF00ZenBags:|r Switched to %s view", modeName))
end

--- Create the view toggle button (called from Frame.lua Init)
function NS.Frames:CreateViewToggleButton()
    if self.viewToggleBtn then return end

    -- Create button next to settings button
    self.viewToggleBtn = NS.Utils:CreateFlatButton(self.mainFrame, "", 20, 20, function()
        NS.Frames:ToggleLayoutMode()
    end)

    -- Position: left of trash button (or settings if trash hidden)
    self.viewToggleBtn:SetPoint("RIGHT", self.trashBtn, "LEFT", -5, 0)
    self.viewToggleBtn:SetFrameLevel(self.mainFrame:GetFrameLevel() + 10)

    -- Add icon
    local icon = self.viewToggleBtn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetVertexColor(0.9, 0.9, 0.9)
    self.viewToggleBtn.icon = icon

    -- Tooltip
    self.viewToggleBtn:SetScript("OnEnter", function(btn)
        NS.Utils:CreateBackdrop(btn)
        btn:SetBackdropColor(0.3, 0.3, 0.3, 1)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(btn.tooltip or "Toggle View")
        GameTooltip:Show()
    end)

    self.viewToggleBtn:SetScript("OnLeave", function(btn)
        btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
        GameTooltip:Hide()
    end)

    -- Set initial icon
    self:UpdateViewToggleIcon()
end

--- Get current layout mode
function NS.Frames:GetLayoutMode()
    return NS.Config:Get("layoutMode") or "category"
end

--- Check if in grid mode
function NS.Frames:IsGridMode()
    return self:GetLayoutMode() == "grid"
end
