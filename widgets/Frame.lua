local addonName, NS = ...

NS.Frames = {}
local Frames = NS.Frames

local ITEM_SIZE = 37
local PADDING = 5
local SECTION_PADDING = 20
local COLS_PER_SECTION = 5 -- Items per row within a section

function Frames:Init()
    -- Main Frame
    self.mainFrame = CreateFrame("Frame", "ZenBagsFrame", UIParent)
    self.mainFrame:SetSize(400, 500) -- Initial size, will resize
    self.mainFrame:SetPoint("CENTER")
    self.mainFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    self.mainFrame:EnableMouse(true)
    self.mainFrame:SetMovable(true)
    self.mainFrame:RegisterForDrag("LeftButton")
    self.mainFrame:SetScript("OnDragStart", self.mainFrame.StartMoving)
    self.mainFrame:SetScript("OnDragStop", self.mainFrame.StopMovingOrSizing)
    self.mainFrame:Hide()

    -- Title
    self.mainFrame.title = self.mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.mainFrame.title:SetPoint("TOP", 0, -15)
    self.mainFrame.title:SetText("ZenBags")

    -- Close Button
    self.mainFrame.closeBtn = CreateFrame("Button", nil, self.mainFrame, "UIPanelCloseButton")
    self.mainFrame.closeBtn:SetPoint("TOPRIGHT", -5, -5)
    
    -- Space Counter
    self.spaceCounter = self.mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.spaceCounter:SetPoint("TOPLEFT", self.mainFrame.title, "TOPRIGHT", 10, 0)
    self.spaceCounter:SetText("0/0")

    -- Search Box
    self.searchBox = CreateFrame("EditBox", nil, self.mainFrame, "InputBoxTemplate")
    self.searchBox:SetSize(150, 20)
    self.searchBox:SetPoint("TOPRIGHT", -30, -35)
    self.searchBox:SetAutoFocus(false)
    self.searchBox:SetScript("OnTextChanged", function(self)
        NS.Frames:Update()
    end)

    -- Money Frame
    self.moneyFrame = CreateFrame("Frame", nil, self.mainFrame)
    self.moneyFrame:SetSize(250, 25)
    self.moneyFrame:SetPoint("BOTTOM", self.mainFrame, "BOTTOM", 0, 10)
    
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

    -- Scroll Frame (for scrolling through sections)
    self.scrollFrame = CreateFrame("ScrollFrame", "ZenBagsScrollFrame", self.mainFrame, "UIPanelScrollFrameTemplate")
    self.scrollFrame:SetPoint("TOPLEFT", 15, -65)
    self.scrollFrame:SetPoint("BOTTOMRIGHT", -35, 70)

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
    -- Inventory Tab
    self.inventoryTab = CreateFrame("Button", nil, self.mainFrame, "UIPanelButtonTemplate")
    self.inventoryTab:SetSize(80, 22)
    self.inventoryTab:SetPoint("BOTTOMLEFT", 15, 40)
    self.inventoryTab:SetText("Inventory")
    self.inventoryTab:SetScript("OnClick", function() self:SwitchView("bags") end)
    self.inventoryTab:Disable() -- Default selected
    
    -- Bank Tab
    self.bankTab = CreateFrame("Button", nil, self.mainFrame, "UIPanelButtonTemplate")
    self.bankTab:SetSize(80, 22)
    self.bankTab:SetPoint("LEFT", self.inventoryTab, "RIGHT", 5, 0)
    self.bankTab:SetText("Bank")
    self.bankTab:SetScript("OnClick", function() self:SwitchView("bank") end)
    self.bankTab:Hide() -- Hidden by default until bank opens
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
        self.inventoryTab:Disable()
        self.bankTab:Enable()
        self.mainFrame.title:SetText("ZenBags")
    else
        self.inventoryTab:Enable()
        self.bankTab:Disable()
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
    
    -- Filter by View and Search
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

    -- Render Sections
    local yOffset = 0
    local btnIdx = 1
    local hdrIdx = 1

    for _, cat in ipairs(sortedCats) do
        local catItems = groups[cat]
        
        -- Header - use pooled interactive button
        local headerPool = NS.Pools:GetPool("SectionHeader")
        local hdr = headerPool:Acquire()
        hdr:SetParent(self.content)
        hdr:SetPoint("TOPLEFT", 0, -yOffset)
        
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
            -- print("ZenBags: Header clicked!", cat) -- Debug print removed
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
        
        yOffset = yOffset + 20 -- Header height

        -- Items Grid - only render if not collapsed
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

            -- Grid Position (Relative to content frame, not the dummy bag)
            local row = math.floor((i - 1) / COLS_PER_SECTION)
            local col = (i - 1) % COLS_PER_SECTION
            
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", self.content, "TOPLEFT", col * (ITEM_SIZE + PADDING), -yOffset - (row * (ITEM_SIZE + PADDING)))
            
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
            
            -- Standard Template handles clicks now!
            -- We only need to ensure the button is shown
            btn:Show()
            
            btnIdx = btnIdx + 1
        end

        
        -- Calculate section height
        if not isCollapsed then
            local numRows = math.ceil(#catItems / COLS_PER_SECTION)
            local sectionHeight = numRows * (ITEM_SIZE + PADDING)
            yOffset = yOffset + sectionHeight + SECTION_PADDING
        else
            -- Collapsed: just add padding
            yOffset = yOffset + SECTION_PADDING
        end
        end  -- Close if not isCollapsed
    end
    
    self.content:SetHeight(yOffset)
    
    -- Update space counter
    self:UpdateSpaceCounter()
    
    -- Update money display
    self:UpdateMoney()
    
    -- Clear dirty flags after successful update
    NS.Inventory:ClearDirtySlots()
    NS.Inventory:SetFullUpdate(false)
end
