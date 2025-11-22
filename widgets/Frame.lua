local addonName, NS = ...

NS.Frames = {}
local Frames = NS.Frames

local ITEM_SIZE = 37
local PADDING = 5
local SECTION_PADDING = 20

function Frames:Init()
    -- Main Frame
    self.mainFrame = CreateFrame("Frame", "ZenBagsFrame", UIParent)
    self.mainFrame:SetSize(500, 500) -- Wider default size
    self.mainFrame:SetPoint("CENTER")
    self.mainFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    self.mainFrame:EnableMouse(true)
    self.mainFrame:SetMovable(true)
    self.mainFrame:SetResizable(true) -- Enable resizing
    self.mainFrame:SetMinResize(300, 300)
    
    -- Resize Handle
    local resizeButton = CreateFrame("Button", nil, self.mainFrame)
    resizeButton:SetSize(16, 16)
    resizeButton:SetPoint("BOTTOMRIGHT", -7, 7)
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
    self.mainFrame:SetScript("OnSizeChanged", function()
        -- Throttle updates to prevent lag (max 10 updates/sec)
        if not resizeThrottle then
            resizeThrottle = true
            C_Timer.After(0.1, function()
                resizeThrottle = nil
                NS.Frames:Update(true)
            end)
        end
    end)
    
    self.mainFrame:Hide()

    -- Header Background (inset from frame border) - Only covers title area
    self.headerBg = self.mainFrame:CreateTexture(nil, "BACKGROUND")
    self.headerBg:SetTexture(0, 0, 0, 0.5) -- Subtle black with transparency
    self.headerBg:SetPoint("TOPLEFT", 12, -12)
    self.headerBg:SetPoint("TOPRIGHT", -12, -12)
    self.headerBg:SetHeight(30) -- Only covers title and close button
    
    -- Make header draggable (create invisible button for dragging)
    self.headerDragArea = CreateFrame("Button", nil, self.mainFrame)
    self.headerDragArea:SetPoint("TOPLEFT", 12, -12)
    self.headerDragArea:SetPoint("TOPRIGHT", -12, -12)
    self.headerDragArea:SetHeight(25) -- Only cover title area, not search box
    self.headerDragArea:RegisterForDrag("LeftButton")
    self.headerDragArea:SetScript("OnDragStart", function() self.mainFrame:StartMoving() end)
    self.headerDragArea:SetScript("OnDragStop", function() self.mainFrame:StopMovingOrSizing() end)
    
    -- Header Separator Line
    self.headerSeparator = self.mainFrame:CreateTexture(nil, "OVERLAY")
    self.headerSeparator:SetTexture(0.3, 0.3, 0.3, 0.8) -- Gray line
    self.headerSeparator:SetPoint("TOPLEFT", 12, -42)
    self.headerSeparator:SetPoint("TOPRIGHT", -12, -42)
    self.headerSeparator:SetHeight(1)

    -- Title
    self.mainFrame.title = self.mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.mainFrame.title:SetPoint("TOP", 0, -20)
    self.mainFrame.title:SetText("ZenBags")

    -- Close Button (raised frame level to be above drag area)
    self.mainFrame.closeBtn = CreateFrame("Button", nil, self.mainFrame, "UIPanelCloseButton")
    self.mainFrame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    self.mainFrame.closeBtn:SetFrameLevel(self.mainFrame:GetFrameLevel() + 10) -- Above drag area
    
    -- Space Counter
    self.spaceCounter = self.mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.spaceCounter:SetPoint("TOPLEFT", self.mainFrame.title, "TOPRIGHT", 10, 0)
    self.spaceCounter:SetText("0/0")

    -- Search Box (sticky, below header, NOT in scroll frame)
    self.searchBox = CreateFrame("EditBox", nil, self.mainFrame, "InputBoxTemplate")
    self.searchBox:SetPoint("TOPLEFT", 20, -48)
    self.searchBox:SetPoint("TOPRIGHT", -38, -48)
    self.searchBox:SetHeight(20)
    self.searchBox:SetAutoFocus(false)
    self.searchBox:SetScript("OnTextChanged", function(self)
        NS.Frames:Update()
    end)
    
    -- Search Icon (magnifying glass)
    local searchIcon = self.searchBox:CreateTexture(nil, "OVERLAY")
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    searchIcon:SetSize(14, 14)
    searchIcon:SetPoint("LEFT", self.searchBox, "LEFT", 3, 0)
    searchIcon:SetVertexColor(0.6, 0.6, 0.6) -- Gray color
    
    -- Adjust text inset to make room for icon
    self.searchBox:SetTextInsets(20, 10, 0, 0)

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
    self.scrollFrame:SetPoint("TOPLEFT", 15, -78)
    self.scrollFrame:SetPoint("BOTTOMRIGHT", -35, 40) -- Balanced spacing - no overlap, minimal waste

    self.content = CreateFrame("Frame", nil, self.scrollFrame)
    self.content:SetSize(350, 1000) --Height will be dynamic
    self.scrollFrame:SetScrollChild(self.content)
    
    -- Drop-anywhere background button (AdiBags pattern)
    -- This button sits behind all item buttons and catches drag-and-drop
    local dropButton = CreateFrame("Button", nil, self.content)
    dropButton:SetAllPoints(self.content)
    dropButton:EnableMouse(true)
    dropButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
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
                        C_Timer.After(0.1, function()
                            Frames:Update()
                        end)
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
                        C_Timer.After(0.1, function()
                            Frames:Update()
                        end)
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

    -- Tab 1: Inventory
    self.inventoryTab = CreateFrame("Button", "$parentTab1", self.mainFrame, "CharacterFrameTabButtonTemplate")
    self.inventoryTab:SetID(1)
    self.inventoryTab:SetPoint("TOPLEFT", self.mainFrame, "BOTTOMLEFT", 20, 8) -- Increased overlap to fix gap
    self.inventoryTab:SetText("Inventory")
    self.inventoryTab:SetScript("OnClick", function() self:SwitchView("bags") end)
    table.insert(self.mainFrame.Tabs, self.inventoryTab)
    
    -- Tab 2: Bank
    self.bankTab = CreateFrame("Button", "$parentTab2", self.mainFrame, "CharacterFrameTabButtonTemplate")
    self.bankTab:SetID(2)
    self.bankTab:SetPoint("TOPLEFT", self.inventoryTab, "TOPRIGHT", -16, 0)
    self.bankTab:SetText("Bank")
    self.bankTab:SetScript("OnClick", function() self:SwitchView("bank") end)
    table.insert(self.mainFrame.Tabs, self.bankTab)
    
    PanelTemplates_SetNumTabs(self.mainFrame, 2)
    PanelTemplates_SetTab(self.mainFrame, 1)
    
    -- Show bank tab if we have cached data
    if NS.Inventory:HasCachedBankItems() then
        self.bankTab:Show()
    else
        self.bankTab:Hide()
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
        PanelTemplates_SetTab(self.mainFrame, 1)
        self.mainFrame.title:SetText("ZenBags")
    else
        PanelTemplates_SetTab(self.mainFrame, 2)
        if NS.Inventory.isBankOpen then
            self.mainFrame.title:SetText("ZenBags - Bank")
        else
            self.mainFrame.title:SetText("ZenBags - Bank (Offline)")
        end
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
        local numSlots = GetContainerNumSlots(bagID)
        totalSlots = totalSlots + numSlots
        
        for slotID = 1, numSlots do
            local itemLink = GetContainerItemLink(bagID, slotID)
            if itemLink then
                usedSlots = usedSlots + 1
            end
        end
    end
    
    local freeSlots = totalSlots - usedSlots
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
    local money = GetMoney()
    
    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100
    
    self.goldText:SetText(gold)
    self.silverText:SetText(silver)
    self.copperText:SetText(copper)
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

    local allItems = NS.Inventory:GetItems()
    local items = {}
    
    -- If viewing bank and bank is closed, load cached items
    local isOfflineBank = (self.currentView == "bank" and not NS.Inventory.isBankOpen)
    if isOfflineBank then
        local cachedItems = NS.Inventory:GetCachedBankItems()
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
        
        -- Update title to indicate offline
        self.mainFrame.title:SetText("ZenBags - Bank (Offline)")
    elseif self.currentView == "bank" then
        self.mainFrame.title:SetText("ZenBags - Bank")
    end
    
    -- Filter by View (keep all items, track matches for highlighting)
    for _, item in ipairs(allItems) do
        -- Filter by location (bags vs bank)
        if item.location == self.currentView then
            -- Check if item matches search (but don't filter out)\n            item.searchMatch = false  -- Default to no match
            if query == "" then
                item.searchMatch = true  -- Empty search = all match
            else
                local name = GetItemInfo(item.link)
                if name and name:lower():find(query, 1, true) then
                    item.searchMatch = true
                end
            end
            table.insert(items, item)
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
        -- Align header with the grid start (looks cleaner)
        hdr:SetPoint("TOPLEFT", sectionX + sectionXOffset, -sectionY)
        
        -- Check collapsed state
        local isCollapsed = NS.Config:IsSectionCollapsed(cat)
        
        -- Set icon texture
        if isCollapsed then
            hdr.icon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
        else
            hdr.icon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
        end
        
        hdr.text:SetText(cat .. " (" .. #catItems .. ")")
        
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
        
        local currentSectionHeight = 20 -- Header height

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
                
                SetItemButtonTexture(btn, itemData.texture)
                SetItemButtonCount(btn, itemData.count)
                
                -- Quality/Quest Border
                local isQuestItem, questId, isActive = GetContainerItemQuestInfo(itemData.bagID, itemData.slotID)
                
                -- Reset borders
                btn.IconBorder:Hide()
                if btn.QualityBorder then btn.QualityBorder:Hide() end
                
                if questId and not isActive then
                    btn.IconBorder:SetTexture(TEXTURE_ITEM_QUEST_BANG)
                    btn.IconBorder:SetVertexColor(1, 1, 1)
                    btn.IconBorder:Show()
                elseif questId or isQuestItem then
                    btn.IconBorder:SetTexture(TEXTURE_ITEM_QUEST_BORDER)
                    btn.IconBorder:SetVertexColor(1, 1, 1)
                    btn.IconBorder:Show()
                elseif itemData.quality and itemData.quality > 1 then
                    local r, g, b = GetItemQualityColor(itemData.quality)
                    if btn.QualityBorder then
                        btn.QualityBorder:SetVertexColor(r, g, b)
                        btn.QualityBorder:Show()
                    end
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

                -- Store item data reference
                btn.itemData = itemData
                
                -- Search Highlighting: Dim non-matching items (with safety check)
                if btn.icon then
                    if itemData.searchMatch then
                        -- Matching item - bright and normal
                        btn.icon:SetAlpha(1.0)
                        btn.icon:SetDesaturated(false)
                    else
                        -- Non-matching item - dimmed and desaturated
                        btn.icon:SetAlpha(0.35)
                        btn.icon:SetDesaturated(true)
                    end
                end
                
                -- Standard Template handles clicks now!
                -- We only need to ensure the button is shown
                btn:Show()
                
                btnIdx = btnIdx + 1
            end

            -- Calculate section height
            local numRows = math.ceil(#catItems / itemCols)
            local gridHeight = numRows * (ITEM_SIZE + PADDING)
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
