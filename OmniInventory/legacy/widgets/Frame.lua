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
            NS.Settings:Open()
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

    -- Vendor Trash Button (icon-only, appears when at merchant)
    self.trashBtn = NS.Utils:CreateFlatButton(self.mainFrame, "", 20, 20, function()
        local trashItems = NS.Inventory:GetTrashItems()
        if #trashItems == 0 then
            print("|cFFFF0000ZenBags:|r No trash items to sell.")
            return
        end

        -- Track items being sold
        local itemsToSell = {}
        for _, item in ipairs(trashItems) do
            -- Check if merchant will accept this item (has vendor price)
            local _, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(item.link)
            if vendorPrice and vendorPrice > 0 then
                table.insert(itemsToSell, item)
            end
        end

        if #itemsToSell == 0 then
            print("|cFFFF0000ZenBags:|r Merchant doesn't want any of these items.")
            return
        end

        -- Sell all acceptable trash items
        for _, item in ipairs(itemsToSell) do
            UseContainerItem(item.bagID, item.slotID)
        end

        -- Show success message with count of items that will be sold
        print("|cFF00FF00ZenBags:|r Sold " .. #itemsToSell .. " trash items.")
    end)
    self.trashBtn:SetPoint("RIGHT", self.settingsBtn, "LEFT", -5, 0)
    self.trashBtn:SetFrameLevel(self.mainFrame:GetFrameLevel() + 10)
    self.trashBtn:Hide() -- Hidden by default

    -- Add Coin Icon to the button
    local coinIcon = self.trashBtn:CreateTexture(nil, "ARTWORK")
    coinIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    coinIcon:SetSize(14, 14)
    coinIcon:SetPoint("CENTER", 0, 0)
    coinIcon:SetVertexColor(0.9, 0.9, 0.9)
    self.trashBtn.icon = coinIcon

    self.trashBtn:SetScript("OnEnter", function(self)
        NS.Utils:CreateBackdrop(self)
        self:SetBackdropColor(unpack(NS.Utils.COLORS.HIGHLIGHT or {0.3, 0.3, 0.3, 1}))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Sell All Trash")
        local trashValue = NS.Inventory:GetTrashValue()
        if trashValue > 0 then
            local gold = math.floor(trashValue / 10000)
            local silver = math.floor((trashValue % 10000) / 100)
            local copper = trashValue % 100
            GameTooltip:AddLine(string.format("Value: %dg %ds %dc", gold, silver, copper), 1, 1, 0.5)
        else
            GameTooltip:AddLine("No trash items", 0.5, 0.5, 0.5)
        end
        GameTooltip:Show()
    end)
    self.trashBtn:SetScript("OnLeave", function(self)
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

    -- Button background (Flat Dark Style)
    NS.Utils:CreateBackdrop(self.charButton)
    self.charButton:SetBackdropColor(0.15, 0.15, 0.15, 1)
    self.charButton:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Hover effect
    self.charButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.25, 0.25, 0.25, 1)
        self:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Switch Character")
        GameTooltip:AddLine("View bags from other characters on this realm", 1, 1, 1)
        GameTooltip:Show()
    end)
    self.charButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.15, 1)
        self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
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

    -- ==========================================================
    -- QUICK SEARCH (UX: Auto-focus on any keypress)
    -- ==========================================================
    self.mainFrame:EnableKeyboard(true)
    self.mainFrame:SetPropagateKeyboardInput(true)
    self.mainFrame:SetScript("OnKeyDown", function(self, key)
        local searchBox = NS.Frames.searchBox
        if not searchBox then return end

        -- If already focused in search, let it handle input
        if searchBox:HasFocus() then return end

        -- Escape clears search and removes focus
        if key == "ESCAPE" then
            searchBox:SetText("")
            searchBox:ClearFocus()
            return
        end

        -- Only capture alphanumeric keys for search
        if key:len() == 1 and key:match("[%a%d]") then
            searchBox:SetFocus()
            -- The key will be typed into the search box naturally
        end
    end)

    -- Clear search on Escape in search box
    self.searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

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

    -- ==========================================================
    -- SELL JUNK BUTTON (UX: One-Click Selling)
    -- ==========================================================
    self.sellJunkBtn = NS.Utils:CreateFlatButton(self.mainFrame, "Sell Junk", 70, 22, function()
        if not MerchantFrame or not MerchantFrame:IsShown() then
            print("|cFF3399FFZenBags|r: Open a vendor to sell junk!")
            return
        end

        -- Sell all grey (Poor quality) items
        local soldCount = 0
        local totalValue = 0

        for bag = 0, 4 do
            for slot = 1, GetContainerNumSlots(bag) do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local _, _, quality = GetItemInfo(link)
                    if quality == 0 then -- Poor (Grey) quality
                        local _, count = GetContainerItemInfo(bag, slot)
                        local vendorPrice = select(11, GetItemInfo(link)) or 0
                        totalValue = totalValue + (vendorPrice * (count or 1))
                        UseContainerItem(bag, slot)
                        soldCount = soldCount + 1
                    end
                end
            end
        end

        if soldCount > 0 then
            local gold = math.floor(totalValue / 10000)
            local silver = math.floor((totalValue % 10000) / 100)
            print("|cFF3399FFZenBags|r: Sold " .. soldCount .. " junk items for " .. gold .. "g " .. silver .. "s")
        else
            print("|cFF3399FFZenBags|r: No junk to sell!")
        end
    end)
    self.sellJunkBtn:SetPoint("BOTTOMRIGHT", self.mainFrame, "BOTTOMRIGHT", -15, 15)
    -- Hide by default, show when at vendor
    self.sellJunkBtn:Hide()

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

    -- Create view toggle button (after trashBtn exists)
    -- Note: CreateViewToggleButton is defined in ViewToggle.lua
    -- We delay creation to ensure trashBtn positioning works
    local initFrame = CreateFrame("Frame")
    initFrame:SetScript("OnUpdate", function(f)
        if Frames.trashBtn then
            Frames:CreateViewToggleButton()
            f:SetScript("OnUpdate", nil)
        end
    end)
end

-- Tabs Logic
-- Logic moved to widgets/Tabs.lua


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


-- Info Logic (Space & Money)
-- Logic moved to widgets/Info.lua


-- Show character selection dropdown
-- Logic moved to widgets/Dropdown.lua


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

    -- Show/hide trash button based on merchant state
    if NS.Data:IsMerchantOpen() then
        self.trashBtn:Show()
    else
        self.trashBtn:Hide()
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
            -- Don't filter by search - we'll dim non-matches instead
            table.insert(items, item)
        end
    end

    -- ==========================================
    -- GRID MODE: Flat layout without headers
    -- ==========================================
    local layoutMode = NS.Config:Get("layoutMode") or "category"

    if layoutMode == "grid" then
        -- Sort items (by quality, then name)
        if NS.Sorter and NS.Sorter.Sort then
            NS.Sorter:Sort(items, "quality")
        else
            table.sort(items, function(a, b)
                local qA = a.quality or 0
                local qB = b.quality or 0
                if qA ~= qB then return qA > qB end
                local nA = a.name or ""
                local nB = b.name or ""
                return nA < nB
            end)
        end

        -- Object Pooling: Release old buttons
        local pool = NS.Pools:GetPool("ItemButton")
        if pool then
            for i = #self.buttons, 1, -1 do
                local btn = self.buttons[i]
                if btn then pool:Release(btn) end
            end
        end
        wipe(self.buttons)

        -- Release headers (not used in grid mode)
        local headerPool = NS.Pools:GetPool("SectionHeader")
        if headerPool then
            for i = #self.headers, 1, -1 do
                local hdr = self.headers[i]
                if hdr then headerPool:Release(hdr) end
            end
        end
        wipe(self.headers)

        -- Grid layout calculation
        local ITEM_SIZE = NS.Config:Get("itemSize")
        local PADDING = NS.Config:Get("padding")
        local width = self.mainFrame:GetWidth()
        local availableWidth = width - 60

        local itemCols = math.floor((availableWidth - PADDING) / (ITEM_SIZE + PADDING))
        if itemCols < 1 then itemCols = 1 end

        -- Center the grid
        local gridWidth = itemCols * ITEM_SIZE + (itemCols - 1) * PADDING
        local xOffset = (availableWidth - gridWidth) / 2
        if xOffset < 0 then xOffset = 0 end

        -- Render all items in flat grid
        local btnIdx = 1
        for i, itemData in ipairs(items) do
            local row = math.floor((i - 1) / itemCols)
            local col = (i - 1) % itemCols

            local xPos = xOffset + col * (ITEM_SIZE + PADDING)
            local yPos = row * (ITEM_SIZE + PADDING)

            local btn = pool:Acquire()
            table.insert(self.buttons, btn)
            btn:SetParent(self.content)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", xPos, -yPos)
            btn:SetSize(ITEM_SIZE, ITEM_SIZE)
            btn:SetFrameLevel(self.content:GetFrameLevel() + 2)

            -- Set item data
            btn.bagID = itemData.bagID
            btn.slotID = itemData.slotID
            btn.itemData = itemData

            -- Update visuals
            SetItemButtonTexture(btn, itemData.texture)
            SetItemButtonCount(btn, itemData.count)

            -- Quality border
            local quality = itemData.quality or 0
            if btn.UpdateQuality then
                btn:UpdateQuality(quality)
            end

            -- Junk icon
            if not btn.junkIcon then
                btn.junkIcon = btn:CreateTexture(nil, "OVERLAY")
                btn.junkIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
                btn.junkIcon:SetPoint("TOPLEFT", 2, -2)
                btn.junkIcon:SetSize(12, 12)
            end
            if quality == 0 then btn.junkIcon:Show() else btn.junkIcon:Hide() end

            -- Item level
            if btn.ilvl and itemData.iLevel then
                btn.ilvl:SetText(itemData.iLevel)
            elseif btn.ilvl then
                btn.ilvl:SetText("")
            end

            -- New item glow
            local glowEnabled = NS.Config:Get("newItemGlowEnabled")
            local glowIgnoreJunk = NS.Config:Get("newItemGlowIgnoreJunk")
            local shouldGlow = glowEnabled and NS.Inventory:IsNew(itemData.itemID) and not (glowIgnoreJunk and quality == 0)

            if shouldGlow and not btn.newGlow then
                btn.newGlow = btn:CreateTexture(nil, "OVERLAY")
                btn.newGlow:SetTexture("Interface\\Cooldown\\star4")
                btn.newGlow:SetPoint("CENTER")
                btn.newGlow:SetBlendMode("ADD")
                local ag = btn.newGlow:CreateAnimationGroup()
                local spin = ag:CreateAnimation("Rotation")
                spin:SetDegrees(360)
                spin:SetDuration(10)
                ag:SetLooping("REPEAT")
                ag:Play()
                btn.newGlow.ag = ag
            end

            if shouldGlow then
                local glowColor = NS.Config:Get("newItemGlowColor")
                local glowScale = NS.Config:Get("newItemGlowScale")
                btn.newGlow:SetSize(ITEM_SIZE * glowScale, ITEM_SIZE * glowScale)
                btn.newGlow:SetVertexColor(glowColor.r, glowColor.g, glowColor.b, 0.8)
                btn.newGlow:Show()
            elseif btn.newGlow then
                btn.newGlow:Hide()
            end

            btn:Show()

            -- Apply search filter
            if self.searchBox then
                local searchText = self.searchBox:GetText()
                if searchText and searchText ~= "" and btn.UpdateSearch then
                    btn:UpdateSearch(searchText)
                end
            end

            -- Tooltip handlers
            btn:SetScript("OnEnter", function(self)
                if self.itemData and self.itemData.itemID then
                    NS.Inventory:MarkItemViewed(self.itemData.itemID)
                end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self.itemData.link then
                    GameTooltip:SetHyperlink(self.itemData.link)
                end
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            btnIdx = btnIdx + 1
        end

        -- Set content height
        local numRows = math.ceil(#items / itemCols)
        local contentHeight = numRows * (ITEM_SIZE + PADDING)
        self.content:SetHeight(contentHeight)

        -- Update counters
        self:UpdateSpaceCounter()
        self:UpdateMoney()
        NS.Inventory:ClearDirtySlots()
        NS.Inventory:SetFullUpdate(false)

        return -- Exit early, skip category rendering
    end

    -- ==========================================
    -- CATEGORY MODE: Original grouped layout
    -- ==========================================

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

        -- Right-click to clear recent items
        if cat == "Recent Items" then
            hdr:SetScript("OnMouseUp", function(self, button)
                if button == "RightButton" then
                    NS.Inventory:ClearRecentItems()
                elseif button == "LeftButton" then
                    NS.Config:ToggleSectionCollapsed(cat)
                    NS.Frames:Update(true)
                end
            end)
            -- Add tooltip hint
            hdr:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(cat)
                GameTooltip:AddLine("Left-Click to Collapse/Expand", 1, 1, 1)
                GameTooltip:AddLine("Right-Click to Clear Recent Items", 1, 0.2, 0.2)
                GameTooltip:Show()
                self.text:SetTextColor(1, 1, 0)  -- Yellow
            end)
            hdr:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
                self.text:SetTextColor(1, 1, 1)  -- White
            end)
        else
            hdr:SetScript("OnMouseUp", function(self, button)
                if button == "LeftButton" then
                    NS.Config:ToggleSectionCollapsed(cat)
                    NS.Frames:Update(true)
                end
            end)
            hdr:SetScript("OnEnter", function(self)
                self.text:SetTextColor(1, 1, 0)  -- Yellow
            end)
            hdr:SetScript("OnLeave", function(self)
                self.text:SetTextColor(1, 1, 1)  -- White
            end)
        end

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

                -- New Item Highlight (configurable)
                local glowEnabled = NS.Config:Get("newItemGlowEnabled")
                local glowIgnoreJunk = NS.Config:Get("newItemGlowIgnoreJunk")
                local isJunk = itemData.quality == 0
                local shouldGlow = glowEnabled and NS.Inventory:IsNew(itemData.itemID) and not (glowIgnoreJunk and isJunk)

                if shouldGlow then
                    local glowColor = NS.Config:Get("newItemGlowColor")
                    local glowScale = NS.Config:Get("newItemGlowScale")

                    if not btn.newGlow then
                        btn.newGlow = btn:CreateTexture(nil, "OVERLAY")
                        btn.newGlow:SetTexture("Interface\\Cooldown\\star4")
                        btn.newGlow:SetPoint("CENTER")
                        btn.newGlow:SetBlendMode("ADD")

                        -- Animation
                        local ag = btn.newGlow:CreateAnimationGroup()
                        local spin = ag:CreateAnimation("Rotation")
                        spin:SetDegrees(360)
                        spin:SetDuration(10)
                        ag:SetLooping("REPEAT")
                        ag:Play()
                        btn.newGlow.ag = ag
                    end
                    -- Apply current settings
                    btn.newGlow:SetSize(ITEM_SIZE * glowScale, ITEM_SIZE * glowScale)
                    btn.newGlow:SetVertexColor(glowColor.r, glowColor.g, glowColor.b, 0.8)
                    btn.newGlow:Show()
                    btn.newGlow.ag:Play()
                else
                    if btn.newGlow then
                        btn.newGlow:Hide()
                        btn.newGlow.ag:Stop()
                    end
                end

                -- Gear Upgrade Indicator
                if NS.GearUpgrade and itemData.iLevel then
                    local status, diff = NS.GearUpgrade:GetStatus(itemData.link, itemData.iLevel)

                    -- Create upgrade arrow if it doesn't exist
                    if not btn.upgradeArrow then
                        btn.upgradeArrow = btn:CreateTexture(nil, "OVERLAY")
                        btn.upgradeArrow:SetTexture("Interface\\Buttons\\UI-MicroStream-Green")
                        btn.upgradeArrow:SetSize(12, 12)
                        btn.upgradeArrow:SetPoint("TOPRIGHT", -1, -1)
                    end

                    if status == "upgrade" then
                        -- Green arrow for upgrades
                        btn.upgradeArrow:SetTexture("Interface\\Buttons\\UI-MicroStream-Green")
                        btn.upgradeArrow:Show()
                        -- Make item glow slightly green
                        if btn.icon then
                            btn.icon:SetVertexColor(0.8, 1.0, 0.8)
                        end
                    elseif status == "downgrade" then
                        -- Hide arrow, dim item
                        btn.upgradeArrow:Hide()
                        if btn.icon then
                            btn.icon:SetVertexColor(0.5, 0.5, 0.5)
                        end
                    else
                        -- Sidegrade or not equipment
                        btn.upgradeArrow:Hide()
                        if btn.icon then
                            btn.icon:SetVertexColor(1, 1, 1)
                        end
                    end
                else
                    -- Not equipment or no GearUpgrade
                    if btn.upgradeArrow then btn.upgradeArrow:Hide() end
                    if btn.icon then btn.icon:SetVertexColor(1, 1, 1) end
                end

                -- Store item data reference
                btn.itemData = itemData

                -- Standard Template handles clicks now!
                -- We only need to ensure the button is shown
                btn:Show()

                -- Apply current search filter (fixes search not working after /reload until bag opened)
                if self.searchBox then
                    local searchText = self.searchBox:GetText()
                    if searchText and searchText ~= "" then
                        btn:UpdateSearch(searchText)
                    end
                end

                -- Clear New Status on Hover
                btn:SetScript("OnEnter", function(self)
                    if self.itemData and self.itemData.itemID then
                        NS.Inventory:MarkItemViewed(self.itemData.itemID)
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

                    -- Add total item count if enabled
                    if NS.Config:Get("showTotalItemCount") and self.itemData and self.itemData.itemID then
                        local bagCount, bankCount = NS.Data:GetTotalItemCount(self.itemData.itemID)
                        local totalCount = bagCount + bankCount

                        -- Only show if there's more than just this stack
                        if totalCount > (self.itemData.count or 1) then
                            local countText = ""
                            if bankCount > 0 then
                                countText = string.format("|cFFFFFFFFTotal:|r %d  |cFF888888(Bags: %d, Bank: %d)|r", totalCount, bagCount, bankCount)
                            else
                                countText = string.format("|cFFFFFFFFTotal:|r %d", totalCount)
                            end
                            GameTooltip:AddLine(countText)
                            GameTooltip:Show()
                        end

                        -- Cross-Alt Total (from Alts module)
                        -- Only show if item exists on OTHER characters
                        if NS.Alts then
                            local altTotal, breakdown = NS.Alts:GetTotalItemCount(self.itemData.itemID)
                            local currentName = UnitName("player")

                            -- Filter out current character from breakdown
                            local otherAlts = {}
                            for _, char in ipairs(breakdown) do
                                if char.name ~= currentName then
                                    table.insert(otherAlts, char.name .. ": " .. char.count)
                                end
                            end

                            -- Only show if other alts have the item
                            if #otherAlts > 0 then
                                GameTooltip:AddLine(" ")
                                GameTooltip:AddLine("|cFF00FF00Other Characters:|r", 1, 1, 1)
                                for _, altText in ipairs(otherAlts) do
                                    GameTooltip:AddLine("  " .. altText, 0.7, 0.7, 0.7)
                                end
                                GameTooltip:Show()
                            end
                        end
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
