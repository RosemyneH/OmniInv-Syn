-- =============================================================================
-- OmniInventory Main Frame
-- =============================================================================
-- Purpose: Primary window container with header, search, content area,
-- footer, and window management (move, resize, position persistence).
-- =============================================================================

local addonName, Omni = ...

Omni.Frame = {}
local Frame = Omni.Frame

-- =============================================================================
-- Constants
-- =============================================================================

local FRAME_MIN_WIDTH = 350
local FRAME_MIN_HEIGHT = 300
local FRAME_DEFAULT_WIDTH = 450
local FRAME_DEFAULT_HEIGHT = 400
local HEADER_HEIGHT = 24
local FOOTER_HEIGHT = 24
local SEARCH_HEIGHT = 24
local PADDING = 8
local ITEM_SIZE = 37
local ITEM_SPACING = 4

-- =============================================================================
-- Frame State
-- =============================================================================

local mainFrame = nil
local itemButtons = {}  -- Active item buttons
local categoryHeaders = {}  -- Active category header FontStrings
local listRows = {}  -- Track list row frames
local currentView = "grid"
local currentMode = "bags"
local isBankOpen = false
local isMerchantOpen = false
local isSearchActive = false
local searchText = ""

-- =============================================================================
-- Frame Creation
-- =============================================================================

function Frame:CreateMainFrame()
    if mainFrame then return mainFrame end

    -- Main window
    mainFrame = CreateFrame("Frame", "OmniInventoryFrame", UIParent)
    mainFrame:SetSize(FRAME_DEFAULT_WIDTH, FRAME_DEFAULT_HEIGHT)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:SetFrameLevel(100)
    mainFrame:EnableMouse(true)
    mainFrame:SetMovable(true)
    mainFrame:SetResizable(true)
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMinResize(FRAME_MIN_WIDTH, FRAME_MIN_HEIGHT)

    -- Backdrop
    mainFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    mainFrame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    mainFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Apply saved scale
    local scale = OmniInventoryDB and OmniInventoryDB.char and OmniInventoryDB.char.settings and OmniInventoryDB.char.settings.scale
    mainFrame:SetScale(scale or 1)

    -- Make tabbable
    tinsert(UISpecialFrames, "OmniInventoryFrame")

    -- Create components
    self:CreateHeader()
    self:CreateSearchBar()
    self:CreateContentArea()
    self:CreateFooter()
    self:CreateResizeHandle()

    -- Fade Animation
    local ag = mainFrame:CreateAnimationGroup()
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.0)
    fade:SetToAlpha(1.0)
    fade:SetDuration(0.2)
    fade:SetSmoothing("OUT")
    mainFrame.fadeAnim = ag

    -- Register for updates
    self:RegisterEvents()

    -- Start hidden
    mainFrame:Hide()

    mainFrame:SetScript("OnShow", function(self)
        self:SetAlpha(0)
        self.fadeAnim:Play()
        if Frame.UpdateFooterButton then Frame:UpdateFooterButton() end
    end)

    return mainFrame
end

-- =============================================================================
-- Header
-- =============================================================================

function Frame:CreateHeader()
    local header = CreateFrame("Frame", nil, mainFrame)
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", PADDING, -PADDING)
    header:SetPoint("TOPRIGHT", -PADDING, -PADDING)

    -- Background
    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()
    header.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    header.bg:SetVertexColor(0.15, 0.15, 0.15, 1)

    -- Title
    header.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.title:SetPoint("LEFT", 6, 0)
    header.title:SetText("|cFF00FF00Omni|r Inventory")

    -- Close button
    header.closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    header.closeBtn:SetSize(20, 20)
    header.closeBtn:SetPoint("RIGHT", -2, 0)
    header.closeBtn:SetScript("OnClick", function()
        Frame:Hide()
    end)

    -- View toggle button
    header.viewBtn = CreateFrame("Button", nil, header)
    header.viewBtn:SetSize(50, 18)
    header.viewBtn:SetPoint("RIGHT", header.closeBtn, "LEFT", -4, 0)
    header.viewBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    header.viewBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    header.viewBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    header.viewBtn.text = header.viewBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.viewBtn.text:SetPoint("CENTER")
    header.viewBtn.text:SetText("Grid")

    header.viewBtn:SetScript("OnClick", function()
        Frame:CycleView()
    end)

    header.viewBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.3, 0.3, 1)
    end)
    header.viewBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 1)
    end)

    -- Sort mode button
    header.sortBtn = CreateFrame("Button", nil, header)
    header.sortBtn:SetSize(50, 18)
    header.sortBtn:SetPoint("RIGHT", header.viewBtn, "LEFT", -4, 0)
    header.sortBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    header.sortBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    header.sortBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    header.sortBtn.text = header.sortBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.sortBtn.text:SetPoint("CENTER")
    header.sortBtn.text:SetText("Sort")

    header.sortBtn:SetScript("OnClick", function()
        Frame:CycleSort()
    end)

    header.sortBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.3, 0.3, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        local mode = Omni.Sorter and Omni.Sorter:GetDefaultMode() or "category"
        GameTooltip:SetText("Sort Mode: " .. mode)
        GameTooltip:Show()
    end)
    header.sortBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 1)
        GameTooltip:Hide()
    end)

    -- Options Button
    local optBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    optBtn:SetSize(24, 24)
    optBtn:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)
    optBtn:SetText("O")
    optBtn:SetScript("OnClick", function()
        if Omni.CategoryEditor then
            Omni.CategoryEditor:Toggle()
        else
            print("Category Editor not loaded")
        end
    end)
    optBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Open Category Editor")
        GameTooltip:Show()
    end)
    optBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    header.optBtn = optBtn

    -- Bags/Bank toggle tabs
    header.bagsTab = CreateFrame("Button", nil, header)
    header.bagsTab:SetSize(40, 18)
    header.bagsTab:SetPoint("LEFT", header.title, "RIGHT", 12, 0)
    header.bagsTab:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    header.bagsTab:SetBackdropColor(0.3, 0.5, 0.3, 1)
    header.bagsTab:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    header.bagsTab.text = header.bagsTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.bagsTab.text:SetPoint("CENTER")
    header.bagsTab.text:SetText("Bags")
    header.bagsTab:SetScript("OnClick", function()
        Frame:SetMode("bags")
    end)

    header.bankTab = CreateFrame("Button", nil, header)
    header.bankTab:SetSize(40, 18)
    header.bankTab:SetPoint("LEFT", header.bagsTab, "RIGHT", 2, 0)
    header.bankTab:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    header.bankTab:SetBackdropColor(0.2, 0.2, 0.2, 1)
    header.bankTab:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    header.bankTab.text = header.bankTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.bankTab.text:SetPoint("CENTER")
    header.bankTab.text:SetText("Bank")
    header.bankTab:SetScript("OnClick", function()
        Frame:SetMode("bank")
    end)

    -- Make header draggable
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        mainFrame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        mainFrame:StopMovingOrSizing()
        Frame:SavePosition()
    end)

    mainFrame.header = header
end

-- =============================================================================
-- Search Bar
-- =============================================================================

function Frame:CreateSearchBar()
    local searchBar = CreateFrame("Frame", nil, mainFrame)
    searchBar:SetHeight(SEARCH_HEIGHT)
    searchBar:SetPoint("TOPLEFT", mainFrame.header, "BOTTOMLEFT", 0, -4)
    searchBar:SetPoint("TOPRIGHT", mainFrame.header, "BOTTOMRIGHT", 0, -4)

    -- Background
    searchBar.bg = searchBar:CreateTexture(nil, "BACKGROUND")
    searchBar.bg:SetAllPoints()
    searchBar.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    searchBar.bg:SetVertexColor(0.1, 0.1, 0.1, 1)

    -- Search icon
    searchBar.icon = searchBar:CreateTexture(nil, "ARTWORK")
    searchBar.icon:SetSize(14, 14)
    searchBar.icon:SetPoint("LEFT", 6, 0)
    searchBar.icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")

    -- Search editbox (plain EditBox, no template to avoid white borders)
    searchBar.editBox = CreateFrame("EditBox", "OmniSearchBox", searchBar)
    searchBar.editBox:SetPoint("LEFT", searchBar.icon, "RIGHT", 4, 0)
    searchBar.editBox:SetPoint("RIGHT", -6, 0)
    searchBar.editBox:SetHeight(18)
    searchBar.editBox:SetAutoFocus(false)
    searchBar.editBox:SetFontObject(ChatFontNormal)
    searchBar.editBox:SetTextColor(1, 1, 1, 1)
    searchBar.editBox:SetTextInsets(2, 2, 0, 0)

    searchBar.editBox:SetScript("OnTextChanged", function(self)
        searchText = self:GetText() or ""
        Frame:ApplySearch(searchText)
    end)

    searchBar.editBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    mainFrame.searchBar = searchBar
    mainFrame.searchBox = searchBar.editBox
end

-- =============================================================================
-- Content Area (ScrollFrame)
-- =============================================================================

function Frame:CreateContentArea()
    local content = CreateFrame("ScrollFrame", "OmniContentScroll", mainFrame, "UIPanelScrollFrameTemplate")
    content:SetPoint("TOPLEFT", mainFrame.searchBar, "BOTTOMLEFT", 0, -4)
    content:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -PADDING - 20, PADDING + FOOTER_HEIGHT + 4)

    -- Scroll child
    local scrollChild = CreateFrame("Frame", "OmniContentChild", content)
    scrollChild:SetSize(content:GetWidth(), 1)  -- Height set dynamically
    content:SetScrollChild(scrollChild)

    -- Style scrollbar
    local scrollBar = _G["OmniContentScrollScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", 20, -16)
        scrollBar:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 20, 16)
    end

    mainFrame.content = content
    mainFrame.scrollChild = scrollChild
end

-- =============================================================================
-- Footer
-- =============================================================================

function Frame:CreateFooter()
    local footer = CreateFrame("Frame", nil, mainFrame)
    footer:SetHeight(FOOTER_HEIGHT)
    footer:SetPoint("BOTTOMLEFT", PADDING, PADDING)
    footer:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)

    -- Background
    footer.bg = footer:CreateTexture(nil, "BACKGROUND")
    footer.bg:SetAllPoints()
    footer.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    footer.bg:SetVertexColor(0.12, 0.12, 0.12, 1)

    -- Bag space counter
    footer.slots = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footer.slots:SetPoint("LEFT", 6, 0)
    footer.slots:SetText("0/0")

    -- Sell Junk Button
    footer.sellBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    footer.sellBtn:SetSize(80, 20)
    footer.sellBtn:SetPoint("CENTER")
    footer.sellBtn:SetText("Sell Junk")
    footer.sellBtn:Hide()  -- Hidden by default
    footer.sellBtn:SetScript("OnClick", function()
        Frame:SellJunk()
    end)

    -- Money display
    footer.money = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footer.money:SetPoint("RIGHT", -6, 0)
    footer.money:SetText("0g 0s 0c")

    mainFrame.footer = footer
end

-- =============================================================================
-- Resize Handle
-- =============================================================================

function Frame:CreateResizeHandle()
    local handle = CreateFrame("Button", nil, mainFrame)
    handle:SetSize(16, 16)
    handle:SetPoint("BOTTOMRIGHT", -2, 2)
    handle:EnableMouse(true)

    handle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    handle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    handle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    handle:SetScript("OnMouseDown", function()
        mainFrame:StartSizing("BOTTOMRIGHT")
    end)

    handle:SetScript("OnMouseUp", function()
        mainFrame:StopMovingOrSizing()
        Frame:SavePosition()
        Frame:UpdateLayout()
    end)

    mainFrame.resizeHandle = handle
end

-- =============================================================================
-- Event Registration
-- =============================================================================

function Frame:RegisterEvents()
    if not mainFrame then return end

    -- Connect to Event bucket system
    if Omni.Events then
        Omni.Events:RegisterBucketEvent("BAG_UPDATE", function(changedBags)
            if mainFrame:IsShown() and currentMode == "bags" then
                Frame:UpdateLayout(changedBags)
            end
        end)

        Omni.Events:RegisterEvent("PLAYER_MONEY", function()
            Frame:UpdateMoney()
        end)

        -- Bank events
        Omni.Events:RegisterEvent("BANKFRAME_OPENED", function()
            isBankOpen = true
            Frame:UpdateBankTabState()
            if mainFrame and mainFrame:IsShown() and currentMode == "bank" then
                Frame:UpdateLayout()
            end
        end)

        Omni.Events:RegisterEvent("BANKFRAME_CLOSED", function()
            isBankOpen = false
            Frame:UpdateBankTabState()
        end)

        Omni.Events:RegisterEvent("PLAYERBANKSLOTS_CHANGED", function()
            if mainFrame and mainFrame:IsShown() and currentMode == "bank" then
                Frame:UpdateLayout()
            end
        end)

        Omni.Events:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED", function()
            if mainFrame and mainFrame:IsShown() and currentMode == "bank" then
                Frame:UpdateLayout()
            end
        end)

        -- Merchant events
        Omni.Events:RegisterEvent("MERCHANT_SHOW", function()
            isMerchantOpen = true
            Frame:UpdateFooterButton()
        end)

        Omni.Events:RegisterEvent("MERCHANT_CLOSED", function()
            isMerchantOpen = false
            Frame:UpdateFooterButton()
        end)
    end
end

-- =============================================================================
-- Position Persistence
-- =============================================================================

function Frame:SavePosition()
    if not mainFrame then return end

    local point, _, _, x, y = mainFrame:GetPoint()
    local width, height = mainFrame:GetSize()

    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.char = OmniInventoryDB.char or {}
    OmniInventoryDB.char.position = {
        point = point,
        x = x,
        y = y,
        width = width,
        height = height,
    }
end

function Frame:LoadPosition()
    if not mainFrame then return end

    local pos = OmniInventoryDB and OmniInventoryDB.char and OmniInventoryDB.char.position
    if pos then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
        if pos.width and pos.height then
            mainFrame:SetSize(pos.width, pos.height)
        end
    end
end

function Frame:SetScale(scale)
    if not mainFrame then return end
    scale = math.max(0.5, math.min(scale or 1, 2.0))
    mainFrame:SetScale(scale)

    -- Save to DB
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.char = OmniInventoryDB.char or {}
    OmniInventoryDB.char.settings = OmniInventoryDB.char.settings or {}
    OmniInventoryDB.char.settings.scale = scale
end

function Frame:ResetPosition()
    if not mainFrame then return end
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self:SavePosition()
    self:SetScale(1.0)
end

-- =============================================================================
-- View Modes
-- =============================================================================

function Frame:SetView(mode)
    currentView = mode or "grid"

    if mainFrame and mainFrame.header and mainFrame.header.viewBtn then
        local labels = { grid = "Grid", flow = "Flow", list = "List" }
        mainFrame.header.viewBtn.text:SetText(labels[currentView] or "Grid")
    end

    Frame:UpdateLayout()
end

function Frame:CycleView()
    local modes = { "grid", "flow", "list" }
    local nextIdx = 1

    for i, mode in ipairs(modes) do
        if mode == currentView then
            nextIdx = (i % #modes) + 1
            break
        end
    end

    Frame:SetView(modes[nextIdx])
end

function Frame:CycleSort()
    if not Omni.Sorter then return end

    local modes = Omni.Sorter:GetModes()
    local currentMode = Omni.Sorter:GetDefaultMode()
    local nextIdx = 1

    for i, mode in ipairs(modes) do
        if mode == currentMode then
            nextIdx = (i % #modes) + 1
            break
        end
    end

    local newMode = modes[nextIdx]
    Omni.Sorter:SetDefaultMode(newMode)

    -- Update button tooltip on next hover
    if mainFrame and mainFrame.header and mainFrame.header.sortBtn then
        -- Capitalize first letter for display
        local displayMode = newMode:gsub("^%l", string.upper)
        mainFrame.header.sortBtn.text:SetText(displayMode)
    end

    -- Refresh layout with new sort
    Frame:UpdateLayout()
end

-- =============================================================================
-- Bags/Bank Mode
-- =============================================================================

function Frame:SetMode(mode)
    currentMode = mode or "bags"

    self:UpdateBankTabState()
    self:UpdateLayout()
end

function Frame:UpdateBankTabState()
    if not mainFrame or not mainFrame.header then return end

    local header = mainFrame.header
    if not header.bagsTab or not header.bankTab then return end

    if currentMode == "bags" then
        header.bagsTab:SetBackdropColor(0.3, 0.5, 0.3, 1)  -- Active (green tint)
        header.bankTab:SetBackdropColor(0.2, 0.2, 0.2, 1)  -- Inactive
    else
        header.bagsTab:SetBackdropColor(0.2, 0.2, 0.2, 1)  -- Inactive
        if isBankOpen then
            header.bankTab:SetBackdropColor(0.3, 0.5, 0.3, 1)  -- Active (green tint)
        else
            header.bankTab:SetBackdropColor(0.5, 0.3, 0.3, 1)  -- Unavailable (red tint)
        end
    end

    -- Show bank unavailable hint
    if currentMode == "bank" and not isBankOpen then
        header.bankTab.text:SetText("Bank*")
    else
        header.bankTab.text:SetText("Bank")
    end
end

-- =============================================================================
-- Layout Update
-- =============================================================================

function Frame:UpdateLayout(changedBags)
    if not mainFrame or not mainFrame:IsShown() then return end

    -- Get items based on current mode
    local items = {}
    if OmniC_Container then
        if currentMode == "bank" then
            if isBankOpen then
                items = OmniC_Container.GetAllBankItems()
            else
                -- Bank is closed - show empty with message
                items = {}
            end
        else
            items = OmniC_Container.GetAllBagItems()
        end
    end

    -- Categorize items and check for new items
    if Omni.Categorizer then
        for _, item in ipairs(items) do
            item.category = Omni.Categorizer:GetCategory(item)
            -- Check if this is a new item (acquired this session)
            if item.itemID then
                item.isNew = Omni.Categorizer:IsNewItem(item.itemID)
            end
        end
    end

    -- Sort items
    if Omni.Sorter then
        items = Omni.Sorter:Sort(items, Omni.Sorter:GetDefaultMode())
    end

    -- Render based on view mode
    if currentView == "grid" then
        self:RenderGridView(items)
    elseif currentView == "flow" then
        self:RenderFlowView(items)
    elseif currentView == "list" then
        self:RenderListView(items)
    else
        self:RenderGridView(items)  -- Fallback
    end

    -- Update footer
    self:UpdateSlotCount()
    self:UpdateMoney()

    -- Apply search if active
    if searchText and searchText ~= "" then
        self:ApplySearch(searchText)
    end
end

-- =============================================================================
-- Grid View Rendering
-- =============================================================================

function Frame:RenderGridView(items)
    if not mainFrame or not mainFrame.scrollChild then return end

    local scrollChild = mainFrame.scrollChild

    -- Release existing buttons back to pool
    if Omni.Pool then
        for _, btn in ipairs(itemButtons) do
            Omni.Pool:Release("ItemButton", btn)
        end
    end
    itemButtons = {}

    -- Hide list rows if any (from List view)
    for _, row in ipairs(listRows) do
        row:Hide()
    end

    -- Hide category headers if any (from Flow view)
    for _, header in ipairs(categoryHeaders) do
        header:Hide()
    end

    -- Calculate layout
    local contentWidth = mainFrame.content:GetWidth() - 20
    local columns = math.floor(contentWidth / (ITEM_SIZE + ITEM_SPACING))
    columns = math.max(columns, 1)

    local rows = math.ceil(#items / columns)
    local contentHeight = rows * (ITEM_SIZE + ITEM_SPACING) + ITEM_SPACING
    scrollChild:SetSize(contentWidth, contentHeight)

    -- Create/position buttons
    for i, itemInfo in ipairs(items) do
        local btn

        if Omni.Pool then
            btn = Omni.Pool:Acquire("ItemButton")
        else
            btn = Omni.ItemButton:Create(scrollChild)
        end

        if btn then
            btn:SetParent(scrollChild)

            local col = ((i - 1) % columns)
            local row = math.floor((i - 1) / columns)
            local x = ITEM_SPACING + col * (ITEM_SIZE + ITEM_SPACING)
            local y = -(ITEM_SPACING + row * (ITEM_SIZE + ITEM_SPACING))

            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", x, y)

            Omni.ItemButton:SetItem(btn, itemInfo)
            btn:Show()

            table.insert(itemButtons, btn)
        end
    end
end

-- =============================================================================
-- Flow View Rendering (Category Sections)
-- =============================================================================

function Frame:RenderFlowView(items)
    if not mainFrame or not mainFrame.scrollChild then return end

    local scrollChild = mainFrame.scrollChild

    -- Group by category
    local categories = {}
    local categoryOrder = {}

    for _, item in ipairs(items) do
        local cat = item.category or "Miscellaneous"
        if not categories[cat] then
            categories[cat] = {}
            table.insert(categoryOrder, cat)
        end
        table.insert(categories[cat], item)
    end

    -- Sort categories by priority
    if Omni.Categorizer then
        table.sort(categoryOrder, function(a, b)
            local infoA = Omni.Categorizer:GetCategoryInfo(a)
            local infoB = Omni.Categorizer:GetCategoryInfo(b)
            return (infoA.priority or 99) < (infoB.priority or 99)
        end)
    end

    -- Release existing buttons
    if Omni.Pool then
        for _, btn in ipairs(itemButtons) do
            Omni.Pool:Release("ItemButton", btn)
        end
    end
    itemButtons = {}

    -- Hide existing category headers (they'll be reused by index)
    for _, header in ipairs(categoryHeaders) do
        header:Hide()
    end

    -- Hide list rows if any (from List view)
    for _, row in ipairs(listRows) do
        row:Hide()
    end

    -- Layout
    local contentWidth = mainFrame.content:GetWidth() - 20
    local columns = math.floor(contentWidth / (ITEM_SIZE + ITEM_SPACING))
    columns = math.max(columns, 1)

    local yOffset = -ITEM_SPACING
    local HEADER_HEIGHT = 20
    local headerIndex = 0

    for _, catName in ipairs(categoryOrder) do
        local catItems = categories[catName]
        if catItems and #catItems > 0 then
            -- Get or create category header
            headerIndex = headerIndex + 1
            local header = categoryHeaders[headerIndex]
            if not header then
                header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                categoryHeaders[headerIndex] = header
            end

            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", ITEM_SPACING, yOffset)

            local r, g, b = 1, 1, 1
            if Omni.Categorizer then
                r, g, b = Omni.Categorizer:GetCategoryColor(catName)
            end
            header:SetTextColor(r, g, b)
            header:SetText(catName .. " (" .. #catItems .. ")")
            header:Show()

            yOffset = yOffset - HEADER_HEIGHT

            -- Items in this category
            for i, itemInfo in ipairs(catItems) do
                local btn
                if Omni.Pool then
                    btn = Omni.Pool:Acquire("ItemButton")
                else
                    btn = Omni.ItemButton:Create(scrollChild)
                end

                if btn then
                    btn:SetParent(scrollChild)

                    local col = ((i - 1) % columns)
                    local row = math.floor((i - 1) / columns)
                    local x = ITEM_SPACING + col * (ITEM_SIZE + ITEM_SPACING)
                    local y = yOffset - row * (ITEM_SIZE + ITEM_SPACING)

                    btn:ClearAllPoints()
                    btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", x, y)

                    Omni.ItemButton:SetItem(btn, itemInfo)
                    btn:Show()

                    table.insert(itemButtons, btn)
                end
            end

            local catRows = math.ceil(#catItems / columns)
            yOffset = yOffset - (catRows * (ITEM_SIZE + ITEM_SPACING)) - ITEM_SPACING
        end
    end

    scrollChild:SetHeight(math.abs(yOffset) + ITEM_SPACING)
end

-- =============================================================================
-- List View Rendering (Data Table)
-- =============================================================================


function Frame:RenderListView(items)
    if not mainFrame or not mainFrame.scrollChild then return end

    local scrollChild = mainFrame.scrollChild

    -- Release existing item buttons
    if Omni.Pool then
        for _, btn in ipairs(itemButtons) do
            Omni.Pool:Release("ItemButton", btn)
        end
    end
    itemButtons = {}

    -- Hide existing list rows
    for _, row in ipairs(listRows) do
        row:Hide()
    end

    -- Hide category headers if any
    for _, header in ipairs(categoryHeaders) do
        header:Hide()
    end

    -- Layout constants
    local ROW_HEIGHT = 22
    local ICON_SIZE = 18
    local contentWidth = mainFrame.content:GetWidth() - 20
    local yOffset = -4

    for i, itemInfo in ipairs(items) do
        -- Get or create row frame
        local row = listRows[i]
        if not row then
            row = CreateFrame("Button", nil, scrollChild)
            row:SetHeight(ROW_HEIGHT)

            -- Background (alternating)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")

            -- Icon
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(ICON_SIZE, ICON_SIZE)
            row.icon:SetPoint("LEFT", 4, 0)

            -- Name
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.name:SetWidth(180)
            row.name:SetJustifyH("LEFT")

            -- Type
            row.itemType = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.itemType:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
            row.itemType:SetWidth(80)
            row.itemType:SetJustifyH("LEFT")
            row.itemType:SetTextColor(0.7, 0.7, 0.7)

            -- Quantity
            row.qty = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.qty:SetPoint("RIGHT", -8, 0)
            row.qty:SetWidth(30)
            row.qty:SetJustifyH("RIGHT")

            -- Hover highlight
            row:SetScript("OnEnter", function(self)
                self.bg:SetVertexColor(0.3, 0.3, 0.3, 1)
                if self.itemInfo and self.itemInfo.bagID and self.itemInfo.slotID then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetBagItem(self.itemInfo.bagID, self.itemInfo.slotID)
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function(self)
                local alpha = (i % 2 == 0) and 0.15 or 0.1
                self.bg:SetVertexColor(0.1, 0.1, 0.1, 1)
                GameTooltip:Hide()
            end)

            -- Click handler
            row:SetScript("OnClick", function(self, mouseButton)
                if self.itemInfo and self.itemInfo.bagID and self.itemInfo.slotID then
                    if mouseButton == "LeftButton" then
                        UseContainerItem(self.itemInfo.bagID, self.itemInfo.slotID)
                    elseif mouseButton == "RightButton" then
                        UseContainerItem(self.itemInfo.bagID, self.itemInfo.slotID)
                    end
                end
            end)

            listRows[i] = row
        end

        -- Position row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, yOffset)

        -- Set background color (alternating rows)
        if i % 2 == 0 then
            row.bg:SetVertexColor(0.15, 0.15, 0.15, 1)
        else
            row.bg:SetVertexColor(0.1, 0.1, 0.1, 1)
        end

        -- Set icon
        row.icon:SetTexture(itemInfo.iconFileID or "Interface\\Icons\\INV_Misc_QuestionMark")

        -- Get item info for name and type
        local itemName, _, quality, _, _, itemType, itemSubType = nil, nil, itemInfo.quality, nil, nil, nil, nil
        if itemInfo.hyperlink then
            itemName, _, quality, _, _, itemType, itemSubType = GetItemInfo(itemInfo.hyperlink)
        end

        -- Set name with quality color
        local QUALITY_COLORS = {
            [0] = { 0.62, 0.62, 0.62 },
            [1] = { 1.00, 1.00, 1.00 },
            [2] = { 0.12, 1.00, 0.00 },
            [3] = { 0.00, 0.44, 0.87 },
            [4] = { 0.64, 0.21, 0.93 },
            [5] = { 1.00, 0.50, 0.00 },
            [6] = { 0.90, 0.80, 0.50 },
            [7] = { 0.00, 0.80, 1.00 },
        }
        local qColor = QUALITY_COLORS[quality or 1] or QUALITY_COLORS[1]
        row.name:SetText(itemName or itemInfo.hyperlink or "Unknown")
        row.name:SetTextColor(qColor[1], qColor[2], qColor[3])

        -- Set type
        row.itemType:SetText(itemSubType or itemType or "")

        -- Set quantity
        local count = itemInfo.stackCount or 1
        if count > 1 then
            row.qty:SetText(count)
        else
            row.qty:SetText("")
        end

        -- Store item info for click/tooltip
        row.itemInfo = itemInfo

        row:Show()
        yOffset = yOffset - ROW_HEIGHT
    end

    scrollChild:SetHeight(math.abs(yOffset) + 8)
end

-- =============================================================================
-- Search
-- =============================================================================

function Frame:ApplySearch(text)
    searchText = text or ""
    isSearchActive = (searchText ~= "")

    if not isSearchActive then
        -- Clear search - show all itemButtons
        for _, btn in ipairs(itemButtons) do
            if Omni.ItemButton then
                Omni.ItemButton:ClearSearch(btn)
            end
        end
        -- Show all list rows (they'll be rebuilt on next update anyway)
        for _, row in ipairs(listRows) do
            if row.itemInfo then
                row:SetAlpha(1)
                if row.icon then row.icon:SetDesaturated(false) end
            end
        end
        return
    end

    local lowerSearch = string.lower(searchText)

    -- Filter Grid/Flow view buttons
    for _, btn in ipairs(itemButtons) do
        local itemInfo = btn.itemInfo
        local isMatch = false

        if itemInfo and itemInfo.hyperlink then
            local name = GetItemInfo(itemInfo.hyperlink)
            if name and string.find(string.lower(name), lowerSearch, 1, true) then
                isMatch = true
            end
        end

        if Omni.ItemButton then
            Omni.ItemButton:SetSearchMatch(btn, isMatch)
        end
    end

    -- Filter List view rows
    for _, row in ipairs(listRows) do
        if row:IsShown() and row.itemInfo then
            local itemInfo = row.itemInfo
            local isMatch = false

            if itemInfo.hyperlink then
                local name = GetItemInfo(itemInfo.hyperlink)
                if name and string.find(string.lower(name), lowerSearch, 1, true) then
                    isMatch = true
                end
            end

            if isMatch then
                row:SetAlpha(1)
                if row.icon then row.icon:SetDesaturated(false) end
            else
                row:SetAlpha(0.3)
                if row.icon then row.icon:SetDesaturated(true) end
            end
        end
    end
end

-- =============================================================================
-- Footer Updates
-- =============================================================================

function Frame:UpdateSlotCount()
    if not mainFrame or not mainFrame.footer then return end

    local free, total = 0, 0

    if currentMode == "bank" then
        -- Main bank container (bagID = -1)
        local mainSlots = GetContainerNumSlots(-1) or 0
        local mainFree = GetContainerNumFreeSlots(-1) or 0
        total = total + mainSlots
        free = free + mainFree

        -- Bank bags (5-11)
        for bagID = 5, 11 do
            local numSlots = GetContainerNumSlots(bagID) or 0
            local numFree = GetContainerNumFreeSlots(bagID) or 0
            total = total + numSlots
            free = free + numFree
        end
    else
        -- Regular bags (0-4)
        for bagID = 0, 4 do
            local numSlots = GetContainerNumSlots(bagID) or 0
            local numFree = GetContainerNumFreeSlots(bagID) or 0
            total = total + numSlots
            free = free + numFree
        end
    end

    local used = total - free
    mainFrame.footer.slots:SetText(string.format("%d/%d", used, total))
end

function Frame:UpdateMoney()
    if not mainFrame or not mainFrame.footer then return end

    local money = GetMoney() or 0
    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100

    mainFrame.footer.money:SetText(string.format("%dg %ds %dc", gold, silver, copper))
end

function Frame:UpdateFooterButton()
    if not mainFrame or not mainFrame.footer or not mainFrame.footer.sellBtn then return end

    if isMerchantOpen then
        mainFrame.footer.sellBtn:Show()
    else
        mainFrame.footer.sellBtn:Hide()
    end
end

-- =============================================================================
-- Sell Junk Logic
-- =============================================================================

function Frame:SellJunk()
    if not isMerchantOpen then return end

    local totalValue = 0
    local sellCount = 0

    for bagID = 0, 4 do
        local numSlots = GetContainerNumSlots(bagID)
        for slotID = 1, numSlots do
            local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bagID, slotID)
            if link and (quality == 0) then -- 0 is Poor/Grey
                local _, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(link)
                if vendorPrice and vendorPrice > 0 then
                    UseContainerItem(bagID, slotID)
                    totalValue = totalValue + (vendorPrice * (count or 1))
                    sellCount = sellCount + 1
                end
            end
        end
    end

    if sellCount > 0 then
        local gold = math.floor(totalValue / 10000)
        local silver = math.floor((totalValue % 10000) / 100)
        local copper = totalValue % 100
        print(string.format("|cFF00FF00OmniInventory|r: Sold %d junk items for %dg %ds %dc", sellCount, gold, silver, copper))
    else
        print("|cFF00FF00OmniInventory|r: No junk to sell.")
    end
end

-- =============================================================================
-- Show/Hide/Toggle
-- =============================================================================

function Frame:Show()
    if not mainFrame then
        self:CreateMainFrame()
        self:LoadPosition()
    end

    mainFrame:Show()
    self:UpdateLayout()
end

function Frame:Hide()
    if mainFrame then
        mainFrame:Hide()
    end
end

function Frame:Toggle()
    if mainFrame and mainFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function Frame:IsShown()
    return mainFrame and mainFrame:IsShown()
end

-- =============================================================================
-- Initialization
-- =============================================================================

function Frame:Init()
    -- Frame is created on first show
end

print("|cFF00FF00OmniInventory|r: Frame loaded")
