local addonName, NS = ...
local Frames = NS.Frames

-- =============================================================================
-- Tabs Logic
-- =============================================================================

function Frames:CreateTabs()
    self.mainFrame.numTabs = 2
    self.mainFrame.Tabs = {}

    -- Tab 1: Inventory (Custom Flat Style)
    self.inventoryTab = self:CreateTabButton("ZenBagsInventoryTab", "Inventory", "Interface\\Buttons\\Button-Backpack-Up")
    self.inventoryTab:SetPoint("BOTTOMLEFT", self.mainFrame, "BOTTOMLEFT", 20, -25)
    self.inventoryTab:SetScript("OnClick", function() self:SwitchView("bags") end)
    table.insert(self.mainFrame.Tabs, self.inventoryTab)

    -- Tab 2: Bank (Custom Flat Style)
    self.bankTab = self:CreateTabButton("ZenBagsBankTab", "Bank", "Interface\\Icons\\INV_Box_02")
    self.bankTab:SetPoint("LEFT", self.inventoryTab, "RIGHT", 2, 0)
    self.bankTab:SetScript("OnClick", function() self:SwitchView("bank") end)
    table.insert(self.mainFrame.Tabs, self.bankTab)

    -- Set inventory as active by default
    self:SetActiveTab(1)

    -- Show bank tab if we have cached data
    if NS.Data:HasCachedBankItems() then
        self.bankTab:Show()
    else
        self.bankTab:Hide()
    end
end

function Frames:CreateTabButton(name, text, iconPath)
    local tab = CreateFrame("Button", name, self.mainFrame)
    tab:SetSize(30, 25) -- Start collapsed (icon only width)

    -- Background
    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetAllPoints()
    tab.bg:SetTexture(0.12, 0.12, 0.12, 1)

    -- Icon
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetSize(16, 16)
    tab.icon:SetTexture(iconPath)
    tab.icon:SetPoint("CENTER") -- Centered when collapsed

    -- Text
    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.text:SetText(text)
    tab.text:Hide() -- Hidden by default

    -- Active indicator (bottom border)
    tab.activeBorder = tab:CreateTexture(nil, "OVERLAY")
    tab.activeBorder:SetHeight(2)
    tab.activeBorder:SetPoint("BOTTOMLEFT")
    tab.activeBorder:SetPoint("BOTTOMRIGHT")
    tab.activeBorder:SetTexture(0.4, 0.6, 1.0, 1)
    tab.activeBorder:Hide()

    -- Hover Scripts
    tab:SetScript("OnEnter", function(self)
        NS.Frames:UpdateTabState(self, true)
    end)
    tab:SetScript("OnLeave", function(self)
        NS.Frames:UpdateTabState(self, false)
    end)

    return tab
end

function Frames:UpdateTabState(tab, isHovered)
    local isActive = (tab.activeBorder:IsShown())

    if isHovered then
        -- Expanded State (Only on Hover)
        tab:SetWidth(100)
        tab.text:Show()
        tab.text:SetPoint("LEFT", tab.icon, "RIGHT", 5, 0)
        tab.icon:ClearAllPoints()
        tab.icon:SetPoint("LEFT", 10, 0)

        -- Highlight background on hover
        if not isActive then
             tab.bg:SetTexture(0.25, 0.25, 0.25, 1)
        end
    else
        -- Collapsed State (Active or Inactive)
        tab:SetWidth(30)
        tab.text:Hide()
        tab.icon:ClearAllPoints()
        tab.icon:SetPoint("CENTER")

        -- Reset background based on active state
        if isActive then
            tab.bg:SetTexture(0.18, 0.18, 0.18, 1)
        else
            tab.bg:SetTexture(0.12, 0.12, 0.12, 1)
        end
    end
end

function Frames:SetActiveTab(tabIndex)
    for i, tab in ipairs(self.mainFrame.Tabs) do
        if i == tabIndex then
            -- Active state
            tab.activeBorder:Show()
            self:UpdateTabState(tab, false) -- Update to active collapsed state
        else
            -- Inactive state
            tab.activeBorder:Hide()
            self:UpdateTabState(tab, false) -- Update to inactive collapsed state
        end
    end
end

function Frames:ShowBankTab()
    self.bankTab:Show()
end

function Frames:HideBankTab()
    self.bankTab:Hide()
end

function Frames:SwitchView(view)
    self.currentView = view

    if view == "bags" then
        self:SetActiveTab(1)
    else
        self:SetActiveTab(2)
    end

    NS.Inventory:SetFullUpdate(true)
    self:Update(true)
end
