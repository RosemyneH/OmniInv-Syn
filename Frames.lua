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

    -- Search Box
    self.searchBox = CreateFrame("EditBox", nil, self.mainFrame, "InputBoxTemplate")
    self.searchBox:SetSize(150, 20)
    self.searchBox:SetPoint("TOPRIGHT", -30, -35)
    self.searchBox:SetAutoFocus(false)
    self.searchBox:SetScript("OnTextChanged", function(self)
        NS.Frames:Update()
    end)

    -- Scroll Frame (for scrolling through sections)
    self.scrollFrame = CreateFrame("ScrollFrame", "ZenBagsScrollFrame", self.mainFrame, "UIPanelScrollFrameTemplate")
    self.scrollFrame:SetPoint("TOPLEFT", 15, -65)
    self.scrollFrame:SetPoint("BOTTOMRIGHT", -35, 15)

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
            if not btn then
                btn = CreateFrame("Button", "ZenBagsItem"..btnIdx, self.content, "ItemButtonTemplate")
                btn:SetSize(ITEM_SIZE, ITEM_SIZE)
                self.buttons[btnIdx] = btn
            end

            -- Grid Position
            local row = math.floor((i - 1) / COLS_PER_SECTION)
            local col = (i - 1) % COLS_PER_SECTION
            
            btn:SetPoint("TOPLEFT", col * (ITEM_SIZE + PADDING), -yOffset - (row * (ITEM_SIZE + PADDING)))
            
            -- Data
            SetItemButtonTexture(btn, itemData.texture)
            SetItemButtonCount(btn, itemData.count)
            -- Quality Border
            if itemData.quality and itemData.quality > 1 then
                local r, g, b = GetItemQualityColor(itemData.quality)
                if btn.IconBorder then
                    btn.IconBorder:SetVertexColor(r, g, b)
                    btn.IconBorder:Show()
                end
            else
                if btn.IconBorder then
                    btn.IconBorder:Hide()
                end
            end
            
            -- Junk Overlay
            if not btn.junkIcon then
                btn.junkIcon = btn:CreateTexture(nil, "OVERLAY")
                btn.junkIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
                btn.junkIcon:SetPoint("TOPLEFT", 2, -2)
                btn.junkIcon:SetSize(12, 12)
            end
            if itemData.quality == 0 then btn.junkIcon:Show() else btn.junkIcon:Hide() end

            -- Tooltip
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetBagItem(itemData.bagID, itemData.slotID)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            btn:Show()
            
            btnIdx = btnIdx + 1
        end
        
        -- Calculate section height
        local numRows = math.ceil(#catItems / COLS_PER_SECTION)
        local sectionHeight = numRows * (ITEM_SIZE + PADDING)
        yOffset = yOffset + sectionHeight + SECTION_PADDING
    end
    
    self.content:SetHeight(yOffset)
end
