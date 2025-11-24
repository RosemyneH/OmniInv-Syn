local addonName, NS = ...

NS.Frames = {}
local Frames = NS.Frames

local SECTION_PADDING = 20

-- Theme constants
local COLORS = {
    BG      = {0.10, 0.10, 0.10, 0.95},
    HEADER  = {0.15, 0.15, 0.15, 1.00},
    -- Flat Dark Background
    self.mainFrame.bg = self.mainFrame:CreateTexture(nil, "BACKGROUND")
    self.mainFrame.bg:SetAllPoints()
    self.mainFrame.bg:SetTexture(unpack(COLORS.BG))

    -- Pixel Border
    NS.FrameHelpers:CreateBorder(self.mainFrame)

    self.mainFrame:EnableMouse(true)
    self.mainFrame:SetMovable(true)
    self.mainFrame:SetResizable(true)
    self.mainFrame:SetMinResize(300, 300)

    -- Resize Handle
    local resizeButton = CreateFrame("Button", nil, self.mainFrame)
    resizeButton:SetSize(16, 16)
    resizeButton:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    resizeButton:SetScript("OnMouseDown", function(self, button)
        self:GetParent():StartSizing("BOTTOMRIGHT")
    end)
    resizeButton:SetScript("OnMouseUp", function(self, button)
        self:GetParent():StopMovingOrSizing()
        NS.Frames:Update(true)
    end)

    -- Throttled resize updates
    local resizeThrottle = nil
    self.mainFrame:SetScript("OnSizeChanged", function()
        if not resizeThrottle then
            resizeThrottle = true
            NS.Utils:After(0.1, function()
                resizeThrottle = nil
                NS.Frames:Update(true)
            end)
        end
    end)

    self.mainFrame:Hide()

    -- Close Button
    self.mainFrame.closeBtn = NS.Utils:CreateCloseButton(self.mainFrame)
    self.mainFrame.closeBtn:SetPoint("TOPRIGHT", -10, -10)
    self.mainFrame.closeBtn:SetFrameLevel(self.mainFrame:GetFrameLevel() + 10)
    self.mainFrame.closeBtn:SetScript("OnClick", function() self:Hide() end)

    -- Settings Button
    self.settingsBtn = NS.Utils:CreateFlatButton(self.mainFrame, "", 20, 20, function()
        if NS.Settings then
            NS.Settings:Toggle()
        else
            print("|cFFFF0000ZenBags Error:|r Settings module not loaded.")
        end
    end)
    self.settingsBtn:SetPoint("RIGHT", self.mainFrame.closeBtn, "LEFT", -5, 0)
    self.settingsBtn:SetFrameLevel(self.mainFrame:GetFrameLevel() + 10)

    -- Gear Icon
    local gearIcon = self.settingsBtn:CreateTexture(nil, "ARTWORK")
    gearIcon:SetTexture("Interface\\GossipFrame\\BinderGossipIcon")
    gearIcon:SetSize(14, 14)
    gearIcon:SetPoint("CENTER", 0, 0)
    gearIcon:SetVertexColor(0.9, 0.9, 0.9)
    self.settingsBtn.icon = gearIcon

    self.settingsBtn:SetScript("OnEnter", function(self)
        NS.Utils:CreateBackdrop(self)
        self:SetBackdropColor(unpack(NS.Utils.COLORS.HIGHLIGHT or {0.3, 0.3, 0.3, 1}))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Settings")
        GameTooltip:Show()
    end)
    self.settingsBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.15, 1)
        GameTooltip:Hide()
    end)

    -- Create Header Components using FrameHeader module
    local header = NS.FrameHeader:Create(self.mainFrame)

    -- Store references to header components
    self.charButton = header.charButton
    self.deleteBtn = header.deleteBtn
    self.spaceCounter = header.spaceCounter
    self.searchBox = header.searchBox
    self.moneyFrame = header.moneyFrame

    -- Shortcut references for money display
    self.goldText = header.moneyFrame.goldText
    self.silverText = header.moneyFrame.silverText
    self.copperText = header.moneyFrame.copperText

    -- Scroll Frame
    self.scrollFrame = CreateFrame("ScrollFrame", "ZenBagsScrollFrame", self.mainFrame, "UIPanelScrollFrameTemplate")
    self.scrollFrame:SetPoint("TOPLEFT", 15, -85)
    self.scrollFrame:SetPoint("BOTTOMRIGHT", -35, 40)

    -- Skin the scrollbar
    NS.Utils:SkinScrollFrame(self.scrollFrame)

    self.content = CreateFrame("Frame", nil, self.scrollFrame)
    self.content:SetSize(350, 1000)
    self.scrollFrame:SetScrollChild(self.content)

    -- Drop-anywhere button
    self.dropButton = NS.FrameHelpers:CreateDropButton(self.content)

    self.buttons = {}
    self.headers = {}
    self.lastSearch = ""

    self.currentView = "bags"

    -- Create Tabs using FrameHelpers module
    local tabs = NS.FrameHelpers:CreateTabs(self.mainFrame)
    self.inventoryTab = tabs.inventoryTab
    self.bankTab = tabs.bankTab
end

-- Get or create dummy bag frame
function Frames:GetDummyBag(bagID)
    return NS.FrameHelpers:GetOrCreateDummyBag(self.mainFrame, bagID)
end

function Frames:SetActiveTab(tabIndex)
    NS.FrameHelpers:SetActiveTab(self.mainFrame, tabIndex)
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

function Frames:Toggle()
    if self.mainFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function Frames:Show()
    self.mainFrame:Show()

    -- Fail-safe: If we have no items, force a scan immediately
    if #NS.Inventory:GetItems() == 0 then
        NS.Inventory:ScanBags()
    end

    NS.Inventory:SetFullUpdate(true)
    self:Update(true)
end

function Frames:Hide()
    self.mainFrame:Hide()
end

function Frames:UpdateSpaceCounter()
    local totalSlots = 0
    local usedSlots = 0

    -- Determine which bags to count based on view
    local bagsToCount = {}
    if self.currentView == "bank" then
        bagsToCount = {-1, 5, 6, 7, 8, 9, 10, 11}
    else
        bagsToCount = {0, 1, 2, 3, 4}
    end

    -- Count slots
    for _, bagID in ipairs(bagsToCount) do
        local size = NS.Data:GetBagSize(bagID)
        local free, _ = NS.Data:GetFreeSlots(bagID)
        totalSlots = totalSlots + size
        usedSlots = usedSlots + (size - free)
    end

 local percentFull = totalSlots > 0 and (usedSlots / totalSlots) * 100 or 0

    -- Color coding based on fullness
    local color = "|cFF00FF00" -- Green
    if percentFull > 90 then
        color = "|cFFFF0000" -- Red
    elseif percentFull > 70 then
        color = "|cFFFFFF00" -- Yellow
    end

    self.spaceCounter:SetText(color .. usedSlots .. "/" .. totalSlots .. "|r")
end

function Frames:UpdateMoney()
    local money = NS.Data:GetMoney()
    NS.FrameHeader:UpdateMoneyDisplay(self.moneyFrame, money)
end

function Frames:ShowCharacterDropdown()
    local chars = NS.Data:GetAvailableCharacters()

    -- Build dropdown menu
    local menu = {}
    for _, charData in ipairs(chars) do
        local displayName = charData.name
        if charData.isCurrent then
            displayName = displayName .. " (Current)"
        end

        table.insert(menu, {
            text = displayName,
            notCheckable = true,
            func = function()
                -- Set selected character
                if charData.isCurrent then
                    NS.Data:SetSelectedCharacter(nil)
                else
                    NS.Data:SetSelectedCharacter(charData.key)
                end

                -- Update button text
                self.charButton.text:SetText(charData.name)

                -- Clear search box when switching characters
                self.searchBox:SetText("")

                -- Force full update
                self:Update(true)
            end
        })
    end

    -- Show dropdown at cursor
    EasyMenu(menu, CreateFrame("Frame", "ZenBagsCharDropdown", UIParent, "UIDropDownMenuTemplate"), "cursor", 0, 0, "MENU")

    -- Apply flat dark styling to the dropdown
    NS.Utils:After(0.01, function()
        local dropdown = _G["DropDownList1"]
        if dropdown then
            dropdown:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false, tileSize = 0, edgeSize = 1,
                insets = {left = 0, right = 0, top = 0, bottom = 0}
            })
            dropdown:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
            dropdown:SetBackdropBorderColor(0, 0, 0, 1)
        end
    end)
end

function Frames:Update(fullUpdate)
    if not self.mainFrame:IsShown() then return end

    -- Check for search text changes
    local searchText = self.searchBox:GetText() or ""
    local query = searchText:lower()

    -- Dirty flag system: Only do full update if needed
    if not fullUpdate then
        local dirtySlots = NS.Inventory:GetDirtySlots()
        local isFullUpdate = NS.Inventory:IsFullUpdate()
        local searchChanged = (query ~= self.lastSearch)

        if not next(dirtySlots) and not isFullUpdate and not searchChanged then
            return
        end
    end

    self.lastSearch = query

    -- Delegate rendering to FrameContent module
    NS.FrameContent:Render(self, self.content, query)

    -- Update space counter
    self:UpdateSpaceCounter()

    -- Update money display
    self:UpdateMoney()

    -- Clear dirty flags after successful update
    NS.Inventory:ClearDirtySlots()
    NS.Inventory:SetFullUpdate(false)
end
