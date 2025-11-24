local addonName, NS = ...

NS.Frames = {}
local Frames = NS.Frames

local SECTION_PADDING = 20

-- =============================================================================
-- ZENBAGS REFORGED THEME CONSTANTS
-- =============================================================================
local COLORS = {
    BG      = {0.10, 0.10, 0.10, 0.95}, -- Main Background (Dark Grey)
    HEADER  = {0.15, 0.15, 0.15, 1.00}, -- Header Background (Slightly lighter)
    BORDER  = {0.00, 0.00, 0.00, 1.00}, -- 1px Black Border
    ACCENT  = {0.20, 0.20, 0.20, 1.00}, -- Separator Lines
    TEXT    = {0.90, 0.90, 0.90, 1.00}, -- Main Text
}

-- Helper to create a 1px border around a frame
local function CreateBorder(f)
    if f.border then return end
    f.border = {}

    -- Top
    f.border.t = f:CreateTexture(nil, "BORDER")
    f.border.t:SetTexture(unpack(COLORS.BORDER))
    f.border.t:SetPoint("TOPLEFT", -1, 1)
    f.border.t:SetPoint("TOPRIGHT", 1, 1)
    f.border.t:SetHeight(1)

    -- Bottom
    f.border.b = f:CreateTexture(nil, "BORDER")
    f.border.b:SetTexture(unpack(COLORS.BORDER))
    f.border.b:SetPoint("BOTTOMLEFT", -1, -1)
    f.border.b:SetPoint("BOTTOMRIGHT", 1, -1)
    f.border.b:SetHeight(1)

    -- Left
    f.border.l = f:CreateTexture(nil, "BORDER")
    f.border.l:SetTexture(unpack(COLORS.BORDER))
    f.border.l:SetPoint("TOPLEFT", -1, 1)
    f.border.l:SetPoint("BOTTOMLEFT", -1, -1)
    f.border.l:SetWidth(1)

    -- Right
    f.border.r = f:CreateTexture(nil, "BORDER")
    f.border.r:SetTexture(unpack(COLORS.BORDER))
    f.border.r:SetPoint("TOPRIGHT", 1, 1)
    f.border.r:SetPoint("BOTTOMRIGHT", 1, -1)
    f.border.r:SetWidth(1)
end

function Frames:Init()
    -- Main Frame
    self.mainFrame = CreateFrame("Frame", "ZenBagsFrame", UIParent)
    self.mainFrame:SetSize(500, 500) -- Wider default size
    self.mainFrame:SetPoint("CENTER")

    -- Flat Dark Background
    self.mainFrame.bg = self.mainFrame:CreateTexture(nil, "BACKGROUND")
    self.mainFrame.bg:SetAllPoints()
    self.mainFrame.bg:SetTexture(unpack(COLORS.BG))

    -- Pixel Border
    CreateBorder(self.mainFrame)

    self.mainFrame:EnableMouse(true)
    self.mainFrame:SetMovable(true)
    self.mainFrame:SetResizable(true) -- Enable resizing
    self.mainFrame:SetMinResize(300, 300)

    -- Resize Handle
    local resizeButton = CreateFrame("Button", nil, self.mainFrame)
    resizeButton:SetSize(16, 16)
    resizeButton:SetPoint("BOTTOMRIGHT", -2, 2) -- Tighter fit
    resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    resizeButton:SetScript("OnMouseDown", function(self, button)
        self:GetParent():StartSizing("BOTTOMRIGHT")
    end)
    resizeButton:SetScript("OnMouseUp", function(self, button)
        self:GetParent():StopMovingOrSizing()
        NS.Frames:Update(true) -- Force update on resize end
    end)

    -- Throttled resize updates
    local resizeThrottle = nil
    local resizeTimer = CreateFrame("Frame")
    resizeTimer:Hide()
    resizeTimer:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= 0.1 then
            resizeThrottle = nil
            NS.Frames:Update(true)
            self:Hide()
            self.elapsed = 0
        end
    end)

    self.mainFrame:SetScript("OnSizeChanged", function()
        -- Throttle updates to prevent lag (max 10 updates/sec)
        if not resizeThrottle then
            resizeThrottle = true
            resizeTimer:Show()
        end
    end)

    self.mainFrame:Hide()

    -- Header Background (Flat & Darker)
    self.headerBg = self.mainFrame:CreateTexture(nil, "ARTWORK")
    self.headerBg:SetTexture(unpack(COLORS.HEADER))
    self.headerBg:SetPoint("TOPLEFT", 0, 0)
    self.headerBg:SetPoint("TOPRIGHT", 0, 0)
    self.headerBg:SetHeight(40)

    -- Make header draggable (create invisible button for dragging)
    self.headerDragArea = CreateFrame("Button", nil, self.mainFrame)
    self.headerDragArea:SetPoint("TOPLEFT", 0, 0)
    self.headerDragArea:SetPoint("TOPRIGHT", 0, 0)
    self.headerDragArea:SetHeight(40)
    self.headerDragArea:RegisterForDrag("LeftButton")
    self.headerDragArea:SetScript("OnDragStart", function() self.mainFrame:StartMoving() end)
    self.headerDragArea:SetScript("OnDragStop", function() self.mainFrame:StopMovingOrSizing() end)

    -- Header Separator Line (Thin & Sharp)
    self.headerSeparator = self.mainFrame:CreateTexture(nil, "OVERLAY")
    self.headerSeparator:SetTexture(unpack(COLORS.ACCENT))
    self.headerSeparator:SetPoint("TOPLEFT", 0, -40)
    self.headerSeparator:SetPoint("TOPRIGHT", 0, -40)
    self.headerSeparator:SetHeight(1)

    -- Close Button (raised frame level to be above drag area)
    self.mainFrame.closeBtn = NS.Utils:CreateCloseButton(self.mainFrame)
    self.mainFrame.closeBtn:SetPoint("TOPRIGHT", -10, -10) -- More padding from right edge
    self.mainFrame.closeBtn:SetFrameLevel(self.mainFrame:GetFrameLevel() + 10) -- Above drag area
    self.mainFrame.closeBtn:SetScript("OnClick", function() self:Hide() end)

    -- Settings Button (Gear Icon) - Now skinned to match Close Button
    self.settingsBtn = NS.Utils:CreateFlatButton(self.mainFrame, "", 20, 20, function()
        if NS.Settings then
            NS.Settings:Toggle()
        else
            print("|cFFFF0000ZenBags Error:|r Settings module not loaded.")
        end
    end)
    self.settingsBtn:SetPoint("RIGHT", self.mainFrame.closeBtn, "LEFT", -5, 0)
    self.settingsBtn:SetFrameLevel(self.mainFrame:GetFrameLevel() + 10)

    -- Add Gear Icon Texture to the button
    local gearIcon = self.settingsBtn:CreateTexture(nil, "ARTWORK")
    gearIcon:SetTexture("Interface\\GossipFrame\\BinderGossipIcon")
    gearIcon:SetSize(14, 14)
    gearIcon:SetPoint("CENTER", 0, 0)
    gearIcon:SetVertexColor(0.9, 0.9, 0.9)
    self.settingsBtn.icon = gearIcon

    self.settingsBtn:SetScript("OnEnter", function(self)
        NS.Utils:CreateBackdrop(self) -- Re-apply backdrop to ensure color reset
        self:SetBackdropColor(unpack(NS.Utils.COLORS.HIGHLIGHT or {0.3, 0.3, 0.3, 1}))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Settings")
        GameTooltip:Show()
    end)
    self.settingsBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.15, 1)
        GameTooltip:Hide()
    end)

    -- Character Dropdown Button (Top Left)
    self.charButton = CreateFrame("Button", "ZenBagsCharButton", self.mainFrame)
    self.charButton:SetSize(120, 20)
    self.charButton:SetPoint("TOPLEFT", 10, -10)
    self.charButton:SetFrameLevel(self.mainFrame:GetFrameLevel() + 10)

    -- Dropdown arrow texture
    local arrowTex = self.charButton:CreateTexture(nil, "ARTWORK")
    arrowTex:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    arrowTex:SetSize(16, 16)
    arrowTex:SetPoint("RIGHT", -2, 0)
    self.charButton.arrow = arrowTex

    -- Character name text
    local charText = self.charButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    charText:SetPoint("LEFT", 4, 0)
    charText:SetJustifyH("LEFT")
    charText:SetText(UnitName("player")) -- Start with current character
    self.charButton.text = charText

    -- Button background (subtle)
    local bg = self.charButton:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0.2, 0.2, 0.2, 0.3)
    bg:Hide()
    self.charButton.bg = bg

    -- Hover effect
    self.charButton:SetScript("OnEnter", function(self)
        self.bg:Show()
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Switch Character")
        GameTooltip:AddLine("View bags from other characters on this realm", 1, 1, 1)
        GameTooltip:Show()
    end)
    self.charButton:SetScript("OnLeave", function(self)
        self.bg:Hide()
        GameTooltip:Hide()
    end)

    -- Click to show dropdown
    self.charButton:SetScript("OnClick", function()
        NS.Frames:ShowCharacterDropdown()
    end)

    -- Space Counter
    self.spaceCounter = self.mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.spaceCounter:SetPoint("LEFT", self.charButton, "RIGHT", 10, 0)
    self.spaceCounter:SetText("0/0")

    -- Search Box (sticky, below header, NOT in scroll frame)
    self.searchBox = CreateFrame("EditBox", nil, self.mainFrame)
    self.searchBox:SetPoint("TOPLEFT", 20, -50) -- More padding from left and top
    self.searchBox:SetPoint("TOPRIGHT", -40, -50) -- More padding from right
    self.searchBox:SetHeight(24) -- Slightly taller
    self.searchBox:SetAutoFocus(false)
    self.searchBox:SetFont("Fonts\\FRIZQT__.TTF", 12)
    self.searchBox:SetTextColor(0.9, 0.9, 0.9, 1)

    -- Simple dark background with border
    NS.Utils:CreateBackdrop(self.searchBox)
    self.searchBox:SetBackdropColor(0.15, 0.15, 0.15, 1)
    self.searchBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 1) -- Visible grey border

    self.searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        local pool = NS.Pools:GetPool("ItemButton")
        if pool then
            for btn in pairs(pool.active) do
                btn:UpdateSearch(text)
            end
        end
    end)

    -- Search Icon (magnifying glass)
    local searchIcon = self.searchBox:CreateTexture(nil, "OVERLAY")
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    searchIcon:SetSize(14, 14)
    searchIcon:SetPoint("LEFT", self.searchBox, "LEFT", 5, 0) -- More padding
    searchIcon:SetVertexColor(0.6, 0.6, 0.6) -- Gray color

    -- Adjust text inset to make room for icon
    self.searchBox:SetTextInsets(25, 10, 0, 0)

    -- Money Frame
    self.moneyFrame = CreateFrame("Frame", nil, self.mainFrame)
    self.moneyFrame:SetSize(250, 25)
    self.moneyFrame:SetPoint("BOTTOMLEFT", self.mainFrame, "BOTTOMLEFT", 15, 18) -- Closer to bottom with good spacing

    -- Gold (leftmost)
    self.goldText = self.moneyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.goldText:SetPoint("LEFT", self.moneyFrame, "LEFT", 0, 0)
    self.goldText:SetText("0")

    self.goldIcon = self.moneyFrame:CreateTexture(nil, "ARTWORK")
    self.goldIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    self.goldIcon:SetSize(16, 16)
    self.goldIcon:SetPoint("LEFT", self.goldText, "RIGHT", 3, 0)

    -- Silver (middle)
    self.silverText = self.moneyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.silverText:SetPoint("LEFT", self.goldIcon, "RIGHT", 8, 0)
    self.silverText:SetText("0")

    self.silverIcon = self.moneyFrame:CreateTexture(nil, "ARTWORK")
    self.silverIcon:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")
    self.silverIcon:SetSize(16, 16)
    self.silverIcon:SetPoint("LEFT", self.silverText, "RIGHT", 3, 0)

    -- Copper (rightmost)
    self.copperText = self.moneyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.copperText:SetPoint("LEFT", self.silverIcon, "RIGHT", 8, 0)
    self.copperText:SetText("0")

    self.copperIcon = self.moneyFrame:CreateTexture(nil, "ARTWORK")
    self.copperIcon:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")
    self.copperIcon:SetSize(16, 16)
    self.copperIcon:SetPoint("LEFT", self.copperText, "RIGHT", 3, 0)

    -- Scroll Frame (starts below sticky search bar)
    self.scrollFrame = CreateFrame("ScrollFrame", "ZenBagsScrollFrame", self.mainFrame, "UIPanelScrollFrameTemplate")
    self.scrollFrame:SetPoint("TOPLEFT", 15, -85) -- More space for search bar
    self.scrollFrame:SetPoint("BOTTOMRIGHT", -35, 40) -- Balanced spacing - no overlap, minimal waste

    -- Skin the scrollbar
    NS.Utils:SkinScrollFrame(self.scrollFrame)

    self.content = CreateFrame("Frame", nil, self.scrollFrame)
    self.content:SetSize(350, 1000) --Height will be dynamic
    self.scrollFrame:SetScrollChild(self.content)

    -- Drop-anywhere background button (AdiBags pattern)
    -- This button sits behind all item buttons and catches drag-and-drop
    local dropButton = CreateFrame("Button", nil, self.content)
    dropButton:SetAllPoints(self.content)
    dropButton:EnableMouse(true)
    dropButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Timer for delayed sorting
    local sortTimer = CreateFrame("Frame")
    sortTimer:Hide()
    sortTimer:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= 0.1 then
            Frames:Update()
            self:Hide()
            self.elapsed = 0
        end
    end)

    dropButton:SetScript("OnReceiveDrag", function()
        if CursorHasItem() then
            -- Find first empty slot in bags 0-4
            for bagID = 0, 4 do
                local numSlots = GetContainerNumSlots(bagID)
                for slotID = 1, numSlots do
                    local itemInfo = GetContainerItemInfo(bagID, slotID)
                    if not itemInfo then
                        -- Empty slot found, place item here
                        PickupContainerItem(bagID, slotID)
                        -- Trigger immediate re-sort
                        sortTimer:Show()
                        return
                    end
                end
            end
        end
    end)

    dropButton:SetScript("OnClick", function()
        -- Also handle click when dragging
        if CursorHasItem() then
            for bagID = 0, 4 do
                local numSlots = GetContainerNumSlots(bagID)
                for slotID = 1, numSlots do
                    local itemInfo = GetContainerItemInfo(bagID, slotID)
                    if not itemInfo then
                        PickupContainerItem(bagID, slotID)
                        sortTimer:Show()
                        return
                    end
                end
            end
        end
    end)

    self.dropButton = dropButton

    self.buttons = {}
    self.headers = {}
    self.lastSearch = ""  -- Track search changes for dirty flag system

    self.currentView = "bags" -- "bags" or "bank"
    self:CreateTabs()
end

function Frames:CreateTabs()
    self.mainFrame.numTabs = 2
    self.mainFrame.Tabs = {}

    -- Tab 1: Inventory (Custom Flat Style)
    self.inventoryTab = CreateFrame("Button", "ZenBagsInventoryTab", self.mainFrame)
    self.inventoryTab:SetSize(100, 25)
    self.inventoryTab:SetPoint("BOTTOMLEFT", self.mainFrame, "BOTTOMLEFT", 20, -25)

    -- Background
    self.inventoryTab.bg = self.inventoryTab:CreateTexture(nil, "BACKGROUND")
    self.inventoryTab.bg:SetAllPoints()
    self.inventoryTab.bg:SetTexture(0.12, 0.12, 0.12, 1)

    -- Text
    self.inventoryTab.text = self.inventoryTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.inventoryTab.text:SetPoint("CENTER")
    self.inventoryTab.text:SetText("Inventory")

    -- Active indicator (bottom border)
    self.inventoryTab.activeBorder = self.inventoryTab:CreateTexture(nil, "OVERLAY")
    self.inventoryTab.activeBorder:SetHeight(2)
    self.inventoryTab.activeBorder:SetPoint("BOTTOMLEFT")
    self.inventoryTab.activeBorder:SetPoint("BOTTOMRIGHT")
    self.inventoryTab.activeBorder:SetTexture(0.4, 0.6, 1.0, 1)

    self.inventoryTab:SetScript("OnClick", function() self:SwitchView("bags") end)
    table.insert(self.mainFrame.Tabs, self.inventoryTab)

    -- Tab 2: Bank (Custom Flat Style)
    self.bankTab = CreateFrame("Button", "ZenBagsBankTab", self.mainFrame)
    self.bankTab:SetSize(100, 25)
    self.bankTab:SetPoint("LEFT", self.inventoryTab, "RIGHT", 2, 0)

    -- Background
    self.bankTab.bg = self.bankTab:CreateTexture(nil, "BACKGROUND")
    self.bankTab.bg:SetAllPoints()
    self.bankTab.bg:SetTexture(0.12, 0.12, 0.12, 1)

    -- Text
    self.bankTab.text = self.bankTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.bankTab.text:SetPoint("CENTER")
    self.bankTab.text:SetText("Bank")

    -- Active indicator (bottom border)
    self.bankTab.activeBorder = self.bankTab:CreateTexture(nil, "OVERLAY")
    self.bankTab.activeBorder:SetHeight(2)
    self.bankTab.activeBorder:SetPoint("BOTTOMLEFT")
    self.bankTab.activeBorder:SetPoint("BOTTOMRIGHT")
    self.bankTab.activeBorder:SetTexture(0.4, 0.6, 1.0, 1)

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

function Frames:SetActiveTab(tabIndex)
    for i, tab in ipairs(self.mainFrame.Tabs) do
        if i == tabIndex then
            -- Active state: lighter background + blue border
            tab.bg:SetTexture(0.18, 0.18, 0.18, 1)
            tab.activeBorder:Show()
        else
            -- Inactive state: darker background, no border
            tab.bg:SetTexture(0.12, 0.12, 0.12, 1)
            tab.activeBorder:Hide()
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

function Frames:Toggle()
    if self.mainFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function Frames:Show()
    self.mainFrame:Show()
    NS.Inventory:SetFullUpdate(true)  -- Force full update on show
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

    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100

    self.goldText:SetText(gold)
    self.silverText:SetText(silver)
    self.copperText:SetText(copper)
end

-- Show character selection dropdown
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
                    NS.Data:SetSelectedCharacter(nil) -- nil = current character
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

    -- Add Separator
    table.insert(menu, { text = "", notCheckable = true, disabled = true })

    -- Add Delete Character Submenu
    local deleteMenu = {}
    for _, charData in ipairs(chars) do
        if not charData.isCurrent then -- Can't delete current character
            table.insert(deleteMenu, {
                text = "Delete " .. charData.name,
                notCheckable = true,
                func = function()
                    NS.Data:DeleteCharacter(charData.key)
                    -- Refresh dropdown if open (tricky, so just close it)
                    CloseDropDownMenus()
                    -- Reset view if needed
                    if NS.Data:GetSelectedCharacter() == nil then
                        self.charButton.text:SetText(UnitName("player"))
                        self:Update(true)
                    end
                    print("|cFFFF0000ZenBags:|r Deleted character data for " .. charData.name)
                end
            })
        end
    end

    if #deleteMenu > 0 then
        table.insert(menu, {
            text = "|cFFFF0000Delete Character|r",
            notCheckable = true,
            hasArrow = true,
            menuList = deleteMenu
        })
    else
        table.insert(menu, {
            text = "|cFF808080Delete Character|r",
            notCheckable = true,
            disabled = true,
            tooltipTitle = "No Characters to Delete",
            tooltipText = "You can only delete other characters' data.",
            tooltipOnButton = true
        })
    end

    -- Show dropdown at cursor
    EasyMenu(menu, CreateFrame("Frame", "ZenBagsCharDropdown", UIParent, "UIDropDownMenuTemplate"), "cursor", 0, 0, "MENU")

    -- Apply flat dark styling to the dropdown
    -- Use OnUpdate for WotLK compatibility (C_Timer not available)
    local timer = CreateFrame("Frame")
    timer:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= 0.01 then
            local dropdown = _G["DropDownList1"]
            if dropdown then
                dropdown:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    tile = false,
                    edgeSize = 1,
                })
                dropdown:SetBackdropColor(0.12, 0.12, 0.12, 0.95)
                dropdown:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
            end
            self:SetScript("OnUpdate", nil) -- Stop timer
        end
    end)
end

-- Dummy Bag Getter
function Frames:GetDummyBag(bagID)
    if not self.dummyBags then self.dummyBags = {} end
    if not self.dummyBags[bagID] then
        -- Create invisible frame to serve as parent with correct ID
        local f = CreateFrame("Frame", nil, self.content)
        f:SetID(bagID)
        self.dummyBags[bagID] = f
    end
    return self.dummyBags[bagID]
end

function Frames:Update(fullUpdate)
    if not self.mainFrame:IsShown() then return end

    -- Check if search changed
    local query = self.searchBox:GetText():lower()
    local searchChanged = (self.lastSearch ~= query)
    self.lastSearch = query

    -- Check if inventory changed
    local dirtySlots = NS.Inventory:GetDirtySlots()
    local hasDirtySlots = next(dirtySlots) ~= nil

    -- Skip update if nothing changed
    if not fullUpdate and not searchChanged and not hasDirtySlots and not NS.Inventory:NeedsFullUpdate() then
        return
    end

    local allItems = {}

    -- If viewing another character, load EVERYTHING from cache
    if NS.Data:IsViewingOtherCharacter() then
        local bagItems = NS.Data:GetCachedInventoryItems()
        local bankItems = NS.Data:GetCachedBankItems()

        for _, item in ipairs(bagItems) do table.insert(allItems, item) end
        for _, item in ipairs(bankItems) do table.insert(allItems, item) end

    else
        -- Viewing current character: Load live items + cached offline bank
        allItems = NS.Inventory:GetItems()

        -- If viewing bank and bank is closed, load cached items
        local isOfflineBank = (self.currentView == "bank" and not NS.Data:IsBankOpen())
        if isOfflineBank then
            local cachedItems = NS.Data:GetCachedBankItems()
            -- Merge cached items into allItems for processing
            -- Note: We create a new list to avoid modifying the live inventory
            local combinedItems = {}
            -- Only include non-bank items from live inventory (if any, though usually we filter)
            for _, item in ipairs(allItems) do
                if item.location ~= "bank" then
                    table.insert(combinedItems, item)
                end
            end
            -- Add cached bank items
            for _, item in ipairs(cachedItems) do
                table.insert(combinedItems, item)
            end
            allItems = combinedItems

            -- Title removed in header redesign
        end
    end

    local items = {}
    for _, item in ipairs(allItems) do
        -- Filter by location (bags vs bank)
        if item.location == self.currentView then
            -- Filter by search query
            if query == "" then
                table.insert(items, item)
            else
                local name = GetItemInfo(item.link)
                if name and name:lower():find(query, 1, true) then
                    table.insert(items, item)
                end
            end
        end
    end

    -- Group by Category
    local groups = {}
    for _, item in ipairs(items) do
        local cat = item.category or "Miscellaneous"
        if not groups[cat] then groups[cat] = {} end
        table.insert(groups[cat], item)
    end

    -- Sort Groups by Priority
    local sortedCats = {}
    for cat in pairs(groups) do table.insert(sortedCats, cat) end
    table.sort(sortedCats, function(a, b)
        local collapsedA = NS.Config:IsSectionCollapsed(a)
        local collapsedB = NS.Config:IsSectionCollapsed(b)

        if collapsedA ~= collapsedB then
            return not collapsedA
        end

        local prioA = NS.Categories.Priority[a] or 99
        local prioB = NS.Categories.Priority[b] or 99
        return prioA < prioB
    end)

    -- Object Pooling: Release old buttons back to pool
    local pool = NS.Pools:GetPool("ItemButton")
    if pool then
        for i = #self.buttons, 1, -1 do
            local btn = self.buttons[i]
            if btn then
                pool:Release(btn)
            end
        end
    end
    wipe(self.buttons)

    -- Release headers back to pool
    local headerPool = NS.Pools:GetPool("SectionHeader")
    if headerPool then
        for i = #self.headers, 1, -1 do
            local hdr = self.headers[i]
            if hdr then
                headerPool:Release(hdr)
            end
        end
    end
    wipe(self.headers)

    -- Dynamic column calculation (Masonry Layout)
    -- Get settings from Config
    local ITEM_SIZE = NS.Config:Get("itemSize")
    local PADDING = NS.Config:Get("padding")

    local width = self.mainFrame:GetWidth()
    local availableWidth = width - 60 -- Padding (left+right+scrollbar)

    -- Determine number of section columns
    local MIN_SECTION_WIDTH = 300
    local numSectionCols = math.floor(availableWidth / MIN_SECTION_WIDTH)
    if numSectionCols < 1 then numSectionCols = 1 end

    local sectionWidth = availableWidth / numSectionCols

    -- Calculate item columns per section
    local itemCols = math.floor((sectionWidth - PADDING) / (ITEM_SIZE + PADDING))
    if itemCols < 1 then itemCols = 1 end

    -- Calculate centering offset within each section
    local sectionGridWidth = itemCols * ITEM_SIZE + (itemCols - 1) * PADDING
    local sectionXOffset = (sectionWidth - sectionGridWidth) / 2
    if sectionXOffset < 0 then sectionXOffset = 0 end

    -- Masonry State
    local colHeights = {}
    for i = 1, numSectionCols do colHeights[i] = 0 end

    -- Render Sections
    local btnIdx = 1

    for _, cat in ipairs(sortedCats) do
        local catItems = groups[cat]

        -- Find shortest column
        local minHeight = colHeights[1]
        local minCol = 1
        for i = 2, numSectionCols do
            if colHeights[i] < minHeight then
                minHeight = colHeights[i]
                minCol = i
            end
        end

        -- Calculate Section Position
        local sectionX = (minCol - 1) * sectionWidth
        local sectionY = minHeight
        -- Header - use pooled interactive button
        local headerPool = NS.Pools:GetPool("SectionHeader")
        local hdr = headerPool:Acquire()
        hdr:SetParent(self.content)
        -- Set header width to match section's grid width to prevent separator line overlap
        hdr:SetWidth(sectionGridWidth)
        -- Align header with the grid start (looks cleaner)
        hdr:SetPoint("TOPLEFT", sectionX + sectionXOffset, -sectionY)

        -- Check collapsed state
        local isCollapsed = NS.Config:IsSectionCollapsed(cat)

        -- Set icon texture
        if isCollapsed then
            -- hdr.icon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
            hdr.text:SetText("[+] " .. cat .. " (" .. #catItems .. ")")
        else
            -- hdr.icon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
            hdr.text:SetText("[-] " .. cat .. " (" .. #catItems .. ")")
        end

        -- Hide the icon texture as we are using text
        hdr.icon:SetTexture(nil)

        -- hdr.text:SetText(cat .. " (" .. #catItems .. ")")

        -- Ensure header is clickable and on top
        hdr:SetFrameLevel(self.content:GetFrameLevel() + 10)
        hdr:RegisterForClicks("AnyUp")

        -- Click handler to toggle
        hdr:SetScript("OnClick", function(self, button)
            NS.Config:ToggleSectionCollapsed(cat)
            NS.Frames:Update(true)  -- Force full redraw
        end)

        -- Hover effects
        hdr:SetScript("OnEnter", function(self)
            self.text:SetTextColor(1, 1, 0)  -- Yellow
        end)
        hdr:SetScript("OnLeave", function(self)
            self.text:SetTextColor(1, 1, 1)  -- White
        end)

        hdr:Show()
        table.insert(self.headers, hdr)

        local currentSectionHeight = 30 -- Header height

        -- Items Grid
        if not isCollapsed then
            for i, itemData in ipairs(catItems) do
                local btn = self.buttons[btnIdx]

                -- Get the dummy bag frame for this item's bag
                local dummyBag = self:GetDummyBag(itemData.bagID)

                -- Object Pooling: Acquire button from pool
                local pool = NS.Pools:GetPool("ItemButton")
                btn = pool:Acquire()

                -- Parent the button to the dummy bag so GetParent():GetID() returns the bag ID
                btn:SetParent(dummyBag)
                btn:SetSize(ITEM_SIZE, ITEM_SIZE)

                self.buttons[btnIdx] = btn
                -- Re-parent if bag changed
                if btn:GetParent() ~= dummyBag then
                    btn:SetParent(dummyBag)
                end

                -- Grid Position within Section
                local row = math.floor((i - 1) / itemCols)
                local col = (i - 1) % itemCols

                local itemX = sectionX + sectionXOffset + col * (ITEM_SIZE + PADDING)
                local itemY = sectionY + currentSectionHeight + row * (ITEM_SIZE + PADDING)

                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", self.content, "TOPLEFT", itemX, -itemY)

                -- Data
                btn:SetID(itemData.slotID)

                -- Handle Offline vs Live Tooltips
                -- Use Data Layer to determine if this bag is cached
                local isCached = NS.Data:IsCached(itemData.bagID)

                if isCached then
                    btn.dummyOverlay:Show()
                    btn.dummyOverlay.itemLink = itemData.link
                else
                    btn.dummyOverlay:Hide()
                end

                -- Store data for search highlighting
                btn.itemLink = itemData.link

                SetItemButtonTexture(btn, itemData.texture)
                SetItemButtonCount(btn, itemData.count)

                -- Quality/Quest Border
                local isQuestItem, questId, isActive = GetContainerItemQuestInfo(itemData.bagID, itemData.slotID)

                -- Determine quality for border
                local quality = itemData.quality
                if questId or isQuestItem then
                    quality = 4 -- Epic color for quest items (or use custom logic)
                end

                -- Update using new method
                if btn.UpdateQuality then
                    btn:UpdateQuality(quality)
                end

                -- Cooldown
                if btn.cooldown then
                    ContainerFrame_UpdateCooldown(itemData.bagID, btn)
                else
                    if not btn.Cooldown then
                        btn.Cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
                        btn.Cooldown:SetAllPoints()
                    end
                    ContainerFrame_UpdateCooldown(itemData.bagID, btn)
                end

                -- Junk Overlay
                if not btn.junkIcon then
                    btn.junkIcon = btn:CreateTexture(nil, "OVERLAY")
                    btn.junkIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
                    btn.junkIcon:SetPoint("TOPLEFT", 2, -2)
                    btn.junkIcon:SetSize(12, 12)
                end
                if itemData.quality == 0 then btn.junkIcon:Show() else btn.junkIcon:Hide() end

                -- Item Level Display
                if btn.ilvl then
                    if itemData.iLevel then
                        btn.ilvl:SetText(itemData.iLevel)
                        -- Color based on quality? For now, stick to the default yellow defined in Pools
                    else
                        btn.ilvl:SetText("")
                    end
                end

                -- New Item Highlight
                if NS.Inventory:IsNew(itemData.bagID, itemData.slotID) then
                    if not btn.newGlow then
                        btn.newGlow = btn:CreateTexture(nil, "OVERLAY")
                        btn.newGlow:SetTexture("Interface\\Cooldown\\star4")
                        btn.newGlow:SetPoint("CENTER")
                        btn.newGlow:SetSize(ITEM_SIZE * 1.8, ITEM_SIZE * 1.8)
                        btn.newGlow:SetBlendMode("ADD")
                        btn.newGlow:SetVertexColor(1, 1, 0, 0.8) -- Yellow glow

                        -- Animation
                        local ag = btn.newGlow:CreateAnimationGroup()
                        local spin = ag:CreateAnimation("Rotation")
                        spin:SetDegrees(360)
                        spin:SetDuration(10)
                        ag:SetLooping("REPEAT")
                        ag:Play()
                        btn.newGlow.ag = ag
                    end
                    btn.newGlow:Show()
                    btn.newGlow.ag:Play()
                else
                    if btn.newGlow then
                        btn.newGlow:Hide()
                        btn.newGlow.ag:Stop()
                    end
                end

                -- Store item data reference
                btn.itemData = itemData

                -- Standard Template handles clicks now!
                -- We only need to ensure the button is shown
                btn:Show()

                -- Clear New Status on Hover
                btn:SetScript("OnEnter", function(self)
                    if self.itemData then
                        NS.Inventory:ClearNew(self.itemData.bagID, self.itemData.slotID)
                    end

                    -- Standard Tooltip
                    if self.itemData.location == "bank" then
                        -- Bank tooltip logic
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        if self.itemData.link then
                            GameTooltip:SetHyperlink(self.itemData.link)
                        end
                        GameTooltip:Show()
                    else
                        -- Standard bag tooltip
                        ContainerFrameItemButton_OnEnter(self)
                    end
                end)

                btn:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                end)

                btnIdx = btnIdx + 1
            end

            -- Calculate section height
            local numRows = math.ceil(#catItems / itemCols)
            local gridHeight = numRows * ITEM_SIZE + (numRows - 1) * PADDING
            currentSectionHeight = currentSectionHeight + gridHeight
        end

        -- Update column height
        colHeights[minCol] = colHeights[minCol] + currentSectionHeight + SECTION_PADDING
    end

    -- Set content height to max column height
    local maxColHeight = 0
    for _, h in ipairs(colHeights) do
        if h > maxColHeight then maxColHeight = h end
    end
    self.content:SetHeight(maxColHeight)

    -- Update space counter
    self:UpdateSpaceCounter()

    -- Update money display
    self:UpdateMoney()

    -- Clear dirty flags after successful update
    NS.Inventory:ClearDirtySlots()
    NS.Inventory:SetFullUpdate(false)
end
