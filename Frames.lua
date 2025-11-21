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
    self.scrollFrame:SetPoint("BOTTOMRIGHT", -35, 45)

    self.content = CreateFrame("Frame", nil, self.scrollFrame)
    self.content:SetSize(350, 1000) -- Height will be dynamic
    self.scrollFrame:SetScrollChild(self.content)

    self.buttons = {}
    self.headers = {}
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
    self:Update()
end

function Frames:Hide()
    self.mainFrame:Hide()
end

function Frames:UpdateSpaceCounter()
    local totalSlots = 0
    local usedSlots = 0
    
    -- Count slots in bags 0-4
    for bagID = 0, 4 do
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

function Frames:Update()
    if not self.mainFrame:IsShown() then return end

    local allItems = NS.Inventory:GetItems()
    local items = {}
    
    -- Filter
    local query = self.searchBox:GetText():lower()
    if query == "" then
        items = allItems
    else
        for _, item in ipairs(allItems) do
            local name = GetItemInfo(item.link)
            if name and name:lower():find(query, 1, true) then
                table.insert(items, item)
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

    -- Reset UI Elements
    for _, btn in pairs(self.buttons) do btn:Hide() end
    for _, hdr in pairs(self.headers) do hdr:Hide() end

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
        
        -- Header
        local hdr = self.headers[hdrIdx]
        if not hdr then
            hdr = self.content:CreateFontString(nil, "OVERLAY", "GameFontNormalLeft")
            self.headers[hdrIdx] = hdr
        end
        hdr:SetPoint("TOPLEFT", 0, -yOffset)
        hdr:SetText(cat .. " (" .. #catItems .. ")")
        hdr:Show()
        hdrIdx = hdrIdx + 1
        
        yOffset = yOffset + 20 -- Header height

        -- Items Grid
        for i, itemData in ipairs(catItems) do
            local btn = self.buttons[btnIdx]
            
            -- Get the dummy bag frame for this item's bag
            local dummyBag = self:GetDummyBag(itemData.bagID)
            
            if not btn then
                -- Parent the button to the dummy bag so GetParent():GetID() returns the bag ID
                btn = CreateFrame("Button", "ZenBagsItem"..btnIdx, dummyBag, "ContainerFrameItemButtonTemplate")
                btn:SetSize(ITEM_SIZE, ITEM_SIZE)

                -- Ensure IconBorder exists (ContainerFrameItemButtonTemplate uses $parentIconQuestTexture)
                if not btn.IconBorder then
                    btn.IconBorder = _G[btn:GetName() .. "IconQuestTexture"] or btn:CreateTexture(nil, "OVERLAY")
                end

                self.buttons[btnIdx] = btn
            else
                -- Re-parent existing button if needed
                if btn:GetParent() ~= dummyBag then
                    btn:SetParent(dummyBag)
                end
            end

            -- Grid Position (Relative to content frame, not the dummy bag)
            local row = math.floor((i - 1) / COLS_PER_SECTION)
            local col = (i - 1) % COLS_PER_SECTION
            
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", self.content, "TOPLEFT", col * (ITEM_SIZE + PADDING), -yOffset - (row * (ITEM_SIZE + PADDING)))
            
            -- Data
            btn:SetID(itemData.slotID)
            -- btn.bagID = itemData.bagID -- Not needed for template, but good for debug
            
            SetItemButtonTexture(btn, itemData.texture)
            SetItemButtonCount(btn, itemData.count)
            
            -- Quality/Quest Border
            local isQuestItem, questId, isActive = GetContainerItemQuestInfo(itemData.bagID, itemData.slotID)
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
                btn.IconBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                btn.IconBorder:SetVertexColor(r, g, b)
                btn.IconBorder:Show()
            else
                btn.IconBorder:Hide()
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
        local numRows = math.ceil(#catItems / COLS_PER_SECTION)
        local sectionHeight = numRows * (ITEM_SIZE + PADDING)
        yOffset = yOffset + sectionHeight + SECTION_PADDING
    end
    
    self.content:SetHeight(yOffset)
    
    -- Update space counter
    self:UpdateSpaceCounter()
    
    -- Update money display
    self:UpdateMoney()
end
