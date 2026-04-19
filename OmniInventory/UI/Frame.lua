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
local DEFAULT_VIEW_MODE = "flow"
local BAG_ICON_SIZE = 18
local BAG_IDS = { 0, 1, 2, 3, 4 }

-- =============================================================================
-- Frame State
-- =============================================================================

local mainFrame = nil
local itemButtons = {}  -- Active item buttons
local categoryHeaders = {}  -- Active category header FontStrings
local listRows = {}  -- Track list row frames
local currentView = DEFAULT_VIEW_MODE
local currentMode = "bags"
local isMerchantOpen = false
local isSearchActive = false
local searchText = ""
local selectedBagID = nil
local forceEmptyFrame = nil
local forceEmptyJob = nil
local FORCE_EMPTY_STEP_INTERVAL = 0.12
local FORCE_EMPTY_MAX_LOCK_RETRIES = 20
local FORCE_EMPTY_MAX_MOVE_RETRIES = 6

-- ʕ •ᴥ•ʔ✿ Combat-safety state ✿ ʕ •ᴥ•ʔ
--
-- ContainerFrameItemButtonTemplate (the AdiBags / Bagnon template) does
-- NOT promote OmniInventoryFrame to "protected by association", so
-- mainFrame:Show() and mainFrame:Hide() work normally in combat -- no
-- alpha-toggle / EnableMouse trickery required, and the entire bag UI
-- can disappear cleanly when closed.
--
-- The protected-child operations that ARE still forbidden in combat
-- are the structural ones on the ItemButtons themselves: SetParent,
-- SetID, SetPoint, ClearAllPoints. UpdateLayout is therefore combat-
-- gated end-to-end and PLAYER_REGEN_ENABLED replays the render once
-- combat ends. While combat is active the buttons keep whatever
-- (bag, slot, position) they were assigned before combat started, so
-- the user still sees their last known inventory and the template's
-- secure OnClick (use / pickup / equip / swap) still routes correctly.
local hasRenderedOnce = false
local pendingCombatRender = false

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function SetButtonItem(btn, itemInfo)
    if not btn then return end

    if btn.SetItem then
        btn:SetItem(itemInfo)
        return
    end

    if Omni.ItemButton and Omni.ItemButton.SetItem then
        Omni.ItemButton:SetItem(btn, itemInfo)
    end
end

local function NormalizeViewMode(mode)
    if mode == "grid" or mode == "flow" or mode == "list" or mode == "bag" then
        return mode
    end
    return DEFAULT_VIEW_MODE
end

local function GetSavedViewMode()
    local settings = OmniInventoryDB and OmniInventoryDB.char and OmniInventoryDB.char.settings
    return NormalizeViewMode(settings and settings.viewMode)
end

local function IsValidBagID(bagID)
    return type(bagID) == "number" and bagID >= 0 and bagID <= 4
end

local function GetSavedBagFilter()
    local settings = OmniInventoryDB and OmniInventoryDB.char and OmniInventoryDB.char.settings
    local bagID = settings and settings.selectedBagID
    if IsValidBagID(bagID) then
        return bagID
    end
    return nil
end

local function GetBagDisplayName(bagID)
    if bagID == 0 then
        return "Backpack"
    end
    local name = GetBagName and GetBagName(bagID)
    if name and name ~= "" then
        return name
    end
    return "Bag " .. tostring(bagID)
end

local function GetBagIconTexture(bagID)
    if bagID == 0 then
        return "Interface\\Buttons\\Button-Backpack-Up"
    end
    local inventorySlot = ContainerIDToInventoryID and ContainerIDToInventoryID(bagID)
    local texture = inventorySlot and GetInventoryItemTexture("player", inventorySlot)
    return texture or "Interface\\Icons\\INV_Misc_Bag_10_Blue"
end

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

    -- Create components
    self:CreateHeader()
    self:CreateSearchBar()
    self:CreateFilterBar()
    self:CreateContentArea()
    self:CreateFooter()
    self:CreateResizeHandle()

    -- ʕ •ᴥ•ʔ✿ Combat hint banner: shown when bag is opened during combat
    -- and the layout cannot be safely (re)built. ✿ ʕ •ᴥ•ʔ
    mainFrame.combatHint = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mainFrame.combatHint:SetPoint("TOP", mainFrame, "TOP", 0, -2)
    mainFrame.combatHint:SetTextColor(1, 0.82, 0, 1)
    mainFrame.combatHint:SetText("")
    mainFrame.combatHint:Hide()

    self:RegisterEvents()

    -- ʕ •ᴥ•ʔ✿ Make ESC close the bag, like every other inventory addon. ✿ ʕ •ᴥ•ʔ
    if UISpecialFrames then
        local already = false
        for _, n in ipairs(UISpecialFrames) do
            if n == "OmniInventoryFrame" then already = true break end
        end
        if not already then
            tinsert(UISpecialFrames, "OmniInventoryFrame")
        end
    end

    mainFrame:Hide()

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
    header.viewBtn.text:SetText("Flow")

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

    local optBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    optBtn:SetSize(56, 18)
    optBtn:SetPoint("RIGHT", header.sortBtn, "LEFT", -4, 0)
    optBtn:SetText("Settings")
    optBtn:SetScript("OnClick", function()
        if Omni.Settings then
            Omni.Settings:Toggle()
        else
            print("|cFF00FF00OmniInventory|r: Settings not loaded")
        end
    end)
    optBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Open Settings")
        GameTooltip:Show()
    end)
    optBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    header.optBtn = optBtn

    -- Bag quick-select icons
    header.bagButtons = {}
    header.bagBar = CreateFrame("Frame", nil, header)
    header.bagBar:SetSize((BAG_ICON_SIZE + 2) * #BAG_IDS, BAG_ICON_SIZE)
    header.bagBar:SetPoint("RIGHT", header.optBtn, "LEFT", -6, 0)

    for index, bagID in ipairs(BAG_IDS) do
        local bagBtn = CreateFrame("Button", nil, header.bagBar)
        bagBtn:SetSize(BAG_ICON_SIZE, BAG_ICON_SIZE)
        bagBtn:SetPoint("LEFT", (index - 1) * (BAG_ICON_SIZE + 2), 0)
        bagBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        bagBtn.bagID = bagID

        bagBtn.icon = bagBtn:CreateTexture(nil, "ARTWORK")
        bagBtn.icon:SetAllPoints()
        bagBtn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        bagBtn.borderTop = bagBtn:CreateTexture(nil, "OVERLAY")
        bagBtn.borderTop:SetTexture("Interface\\Buttons\\WHITE8X8")
        bagBtn.borderTop:SetPoint("TOPLEFT", -1, 1)
        bagBtn.borderTop:SetPoint("TOPRIGHT", 1, 1)
        bagBtn.borderTop:SetHeight(1)

        bagBtn.borderBottom = bagBtn:CreateTexture(nil, "OVERLAY")
        bagBtn.borderBottom:SetTexture("Interface\\Buttons\\WHITE8X8")
        bagBtn.borderBottom:SetPoint("BOTTOMLEFT", -1, -1)
        bagBtn.borderBottom:SetPoint("BOTTOMRIGHT", 1, -1)
        bagBtn.borderBottom:SetHeight(1)

        bagBtn.borderLeft = bagBtn:CreateTexture(nil, "OVERLAY")
        bagBtn.borderLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
        bagBtn.borderLeft:SetPoint("TOPLEFT", -1, 1)
        bagBtn.borderLeft:SetPoint("BOTTOMLEFT", -1, -1)
        bagBtn.borderLeft:SetWidth(1)

        bagBtn.borderRight = bagBtn:CreateTexture(nil, "OVERLAY")
        bagBtn.borderRight:SetTexture("Interface\\Buttons\\WHITE8X8")
        bagBtn.borderRight:SetPoint("TOPRIGHT", 1, 1)
        bagBtn.borderRight:SetPoint("BOTTOMRIGHT", 1, -1)
        bagBtn.borderRight:SetWidth(1)

        bagBtn:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "LeftButton" then
                Frame:ToggleBagPreview(self.bagID)
            elseif mouseButton == "RightButton" then
                Frame:ForceEmptyBag(self.bagID)
            end
        end)

        bagBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(GetBagDisplayName(self.bagID), 1, 1, 1)
            GameTooltip:AddLine("Left-click: Preview this bag", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Right-click: Force-empty bag", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        bagBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        header.bagButtons[bagID] = bagBtn
    end

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

function Frame:UpdateBagIconTextures()
    if not mainFrame or not mainFrame.header or not mainFrame.header.bagButtons then return end

    for _, bagID in ipairs(BAG_IDS) do
        local bagBtn = mainFrame.header.bagButtons[bagID]
        if bagBtn and bagBtn.icon then
            bagBtn.icon:SetTexture(GetBagIconTexture(bagID))
        end
    end
end

function Frame:UpdateBagIconVisuals()
    if not mainFrame or not mainFrame.header or not mainFrame.header.bagButtons then return end

    if mainFrame.header.bagBar then
        mainFrame.header.bagBar:Show()
    end

    for _, bagID in ipairs(BAG_IDS) do
        local bagBtn = mainFrame.header.bagButtons[bagID]
        if bagBtn then
            local r, g, b = 0.4, 0.4, 0.4
            if selectedBagID == bagID then
                r, g, b = 0.2, 0.8, 0.2
            end
            if bagBtn.borderTop then bagBtn.borderTop:SetVertexColor(r, g, b, 1) end
            if bagBtn.borderBottom then bagBtn.borderBottom:SetVertexColor(r, g, b, 1) end
            if bagBtn.borderLeft then bagBtn.borderLeft:SetVertexColor(r, g, b, 1) end
            if bagBtn.borderRight then bagBtn.borderRight:SetVertexColor(r, g, b, 1) end
            bagBtn:SetAlpha(1)
        end
    end
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
-- Quick Filter Bar
-- =============================================================================

local FILTER_HEIGHT = 22
local activeFilter = nil  -- Current active filter

local QUICK_FILTERS = {
    { name = "All", filter = nil },
    { name = "New", filter = "NEW_ITEMS", isSpecial = true },
    { name = "Quest", filter = "Quest" },
    { name = "Gear", filter = "Equipment" },
    { name = "Cons", filter = "Consumable" },
    { name = "Junk", filter = "Junk" },
}

function Frame:CreateFilterBar()
    local filterBar = CreateFrame("Frame", nil, mainFrame)
    filterBar:SetHeight(FILTER_HEIGHT)
    filterBar:SetPoint("TOPLEFT", mainFrame.searchBar, "BOTTOMLEFT", 0, -2)
    filterBar:SetPoint("TOPRIGHT", mainFrame.searchBar, "BOTTOMRIGHT", 0, -2)

    -- Background
    filterBar.bg = filterBar:CreateTexture(nil, "BACKGROUND")
    filterBar.bg:SetAllPoints()
    filterBar.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    filterBar.bg:SetVertexColor(0.08, 0.08, 0.08, 1)

    -- Create filter buttons
    filterBar.buttons = {}
    local buttonWidth = 45
    local buttonSpacing = 2
    local startX = 4

    for i, filterInfo in ipairs(QUICK_FILTERS) do
        local btn = CreateFrame("Button", nil, filterBar)
        btn:SetSize(buttonWidth, 18)
        btn:SetPoint("LEFT", startX + (i-1) * (buttonWidth + buttonSpacing), 0)

        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
        btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(filterInfo.name)

        btn.filterName = filterInfo.filter

        btn:SetScript("OnClick", function(self)
            Frame:SetQuickFilter(self.filterName)
        end)

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.25, 0.25, 0.25, 1)
        end)

        btn:SetScript("OnLeave", function(self)
            if activeFilter == self.filterName then
                self:SetBackdropColor(0.2, 0.4, 0.2, 1)
            else
                self:SetBackdropColor(0.15, 0.15, 0.15, 1)
            end
        end)

        filterBar.buttons[i] = btn
    end

    mainFrame.filterBar = filterBar
end

function Frame:SetQuickFilter(filterName)
    activeFilter = filterName

    -- Update button visuals
    if mainFrame.filterBar and mainFrame.filterBar.buttons then
        for _, btn in ipairs(mainFrame.filterBar.buttons) do
            if btn.filterName == activeFilter then
                btn:SetBackdropColor(0.2, 0.4, 0.2, 1)
                btn:SetBackdropBorderColor(0.3, 0.6, 0.3, 1)
            else
                btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
                btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            end
        end
    end

    -- Apply filter (reuse search highlight logic)
    self:UpdateLayout()
end

function Frame:GetActiveFilter()
    return activeFilter
end

-- =============================================================================
-- Content Area (ScrollFrame)
-- =============================================================================

function Frame:CreateContentArea()
    local content = CreateFrame("ScrollFrame", "OmniContentScroll", mainFrame, "UIPanelScrollFrameTemplate")
    content:SetPoint("TOPLEFT", mainFrame.filterBar, "BOTTOMLEFT", 0, -4)
    content:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -PADDING, PADDING + FOOTER_HEIGHT + 4)

    -- Scroll child
    local scrollChild = CreateFrame("Frame", "OmniContentChild", content)
    scrollChild:SetSize(content:GetWidth(), 1)  -- Height set dynamically
    content:SetScrollChild(scrollChild)

    local scrollBar = _G["OmniContentScrollScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -16)
        scrollBar:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 16)
        scrollBar:SetAlpha(0)
        scrollBar:SetWidth(1)
        scrollBar:EnableMouse(false)
        local up = _G["OmniContentScrollScrollBarScrollUpButton"]
        local down = _G["OmniContentScrollScrollBarScrollDownButton"]
        if up then
            up:SetAlpha(0)
            up:EnableMouse(false)
        end
        if down then
            down:SetAlpha(0)
            down:EnableMouse(false)
        end
        local thumb = scrollBar:GetThumbTexture()
        if thumb then thumb:SetAlpha(0) end
    end

    -- ʕ •ᴥ•ʔ✿ Per-bag ItemContainer frames. ContainerFrameItemButton_OnClick
    -- reads the bag from self:GetParent():GetID(), so every item button
    -- must live under a parent whose SetID matches its bag. We create
    -- one zero-size insecure Frame per bag (and a -1 slot for stray
    -- buttons), pin them at scrollChild origin, and reparent buttons
    -- into them at acquire time. The bag IDs themselves are insecure so
    -- SetID here is allowed even in combat, but we only ever hand out
    -- the table OOC so it doesn't matter. ✿ ʕ •ᴥ•ʔ
    mainFrame.itemContainers = {}
    local function MakeItemContainer(bagID)
        local f = CreateFrame("Frame", nil, scrollChild)
        f:SetSize(1, 1)
        f:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
        f:SetID(bagID)
        f:Show()
        mainFrame.itemContainers[bagID] = f
        return f
    end
    for _, bagID in ipairs(BAG_IDS) do
        MakeItemContainer(bagID)
    end
    MakeItemContainer(-1)
    mainFrame._makeItemContainer = MakeItemContainer

    mainFrame.content = content
    mainFrame.scrollChild = scrollChild
end

-- ʕ •ᴥ•ʔ✿ Lazy-fetch (or create OOC) the per-bag ItemContainer for `bagID`.
-- Hot path called from RenderFlowView for every item, so cheap. Returns
-- nil when called in combat for a bag we have not seen before -- callers
-- treat that as "no container, skip this button". ✿ ʕ •ᴥ•ʔ
local function GetItemContainer(bagID)
    if not mainFrame or not mainFrame.itemContainers then return nil end
    local container = mainFrame.itemContainers[bagID]
    if container then return container end
    if InCombat() then return nil end
    if mainFrame._makeItemContainer then
        return mainFrame._makeItemContainer(bagID)
    end
    return nil
end
Frame._GetItemContainer = GetItemContainer

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

    -- Connect to Event bucket system for bag updates only
    -- Note: Bank events and PLAYER_MONEY are handled by Omni.Events:Init()
    if Omni.Events then
        Omni.Events:RegisterBucketEvent("BAG_UPDATE", function(changedBags)
            -- ʕ •ᴥ•ʔ✿ UpdateLayout self-defers in combat; PLAYER_REGEN_ENABLED
            -- replays a full pass once lockdown clears. ✿ ʕ •ᴥ•ʔ
            Frame:UpdateLayout(changedBags)
        end)

        Omni.Events:RegisterEvent("BAG_UPDATE_COOLDOWN", function()
            if not mainFrame or not mainFrame:IsShown() then return end
            if InCombat() then return end
            if not Omni.ItemButton or not Omni.ItemButton.UpdateCooldown then return end
            for _, btn in ipairs(itemButtons) do
                Omni.ItemButton:UpdateCooldown(btn)
            end
        end)

        -- Merchant events (unique to Frame, not in Events.lua)
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
    currentView = NormalizeViewMode(mode)

    if mainFrame and mainFrame.header and mainFrame.header.viewBtn then
        local labels = { grid = "Grid", flow = "Flow", list = "List", bag = "Bag" }
        mainFrame.header.viewBtn.text:SetText(labels[currentView] or "Grid")
    end

    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.char = OmniInventoryDB.char or {}
    OmniInventoryDB.char.settings = OmniInventoryDB.char.settings or {}
    OmniInventoryDB.char.settings.viewMode = currentView

    self:UpdateBagIconVisuals()
    Frame:UpdateLayout()
end

function Frame:CycleView()
    local modes = { "grid", "flow", "list", "bag" }
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
-- View Mode (bags only; bank lives in Omni.BankFrame)
-- =============================================================================

function Frame:SetMode(mode)
    currentMode = "bags"
    self:UpdateBagIconVisuals()
    self:UpdateLayout()
end

-- ʕ •ᴥ•ʔ✿ Backwards-compat stubs: bank now lives in its own frame ✿ ʕ •ᴥ•ʔ
function Frame:SetBankOpen(_) end
function Frame:UpdateBankTabState() end

-- =============================================================================
-- Layout Update
-- =============================================================================

function Frame:UpdateLayout(changedBags)
    if not mainFrame then return end

    -- ʕ •ᴥ•ʔ✿ Combat policy ✿ ʕ •ᴥ•ʔ
    -- Touching SecureActionButtonTemplate children (SetParent, SetPoint,
    -- SetAttribute, Show, Hide) inside a secure-binding callstack during
    -- combat raises "Interface action failed because of an AddOn." and
    -- aborts the toggle action mid-stride. So we never re-render in
    -- combat. The frame itself is insecure and Show/Hide on it works
    -- fine -- the buttons rendered during the last out-of-combat pass
    -- stay positioned and shown across Hide/Show cycles, so opening the
    -- bag in combat shows the last good layout with working tooltips
    -- (same behavior as AdiBags on this client). Any updates missed
    -- during combat are replayed by PLAYER_REGEN_ENABLED.
    if InCombat() then
        pendingCombatRender = true
        if mainFrame:IsShown() and mainFrame.combatHint then
            mainFrame.combatHint:Show()
            if not hasRenderedOnce then
                mainFrame.combatHint:SetText(
                    "|cFFFFCC00Bag contents will appear when combat ends.|r")
            else
                mainFrame.combatHint:SetText(
                    "|cFFFFCC00Combat lockdown: showing last layout. Refresh after combat.|r")
            end
        end
        return
    end

    if mainFrame.combatHint then
        mainFrame.combatHint:Hide()
    end

    local items = {}
    if OmniC_Container then
        items = OmniC_Container.GetAllBagItems()
    end

    -- Categorize items and check for new items
    if Omni.Categorizer then
        for _, item in ipairs(items) do
            item.category = item.category or Omni.Categorizer:GetCategory(item)
            -- Check if this is a new item (acquired this session)
            if item.itemID then
                item.isNew = Omni.Categorizer:IsNewItem(item.itemID)
            end
        end
    end

    if IsValidBagID(selectedBagID) then
        local filtered = {}
        for _, item in ipairs(items) do
            if item.bagID == selectedBagID then
                table.insert(filtered, item)
            end
        end
        items = filtered
    end

    -- Apply quick filter (dim non-matching items)
    local quickFilter = self:GetActiveFilter()
    if quickFilter then
        for _, item in ipairs(items) do
            local matches = false

            -- Special filter: NEW_ITEMS - filter by isNew flag
            if quickFilter == "NEW_ITEMS" then
                matches = item.isNew == true
            else
                -- Normal filter: match by category
                if item.category and string.find(item.category, quickFilter) then
                    matches = true
                end
            end

            item.isQuickFiltered = not matches
        end
    else
        -- No filter active - clear all filter flags
        for _, item in ipairs(items) do
            item.isQuickFiltered = false
        end
    end

    -- Sort items
    if Omni.Sorter then
        items = Omni.Sorter:Sort(items, Omni.Sorter:GetDefaultMode())
    end

    -- Render based on view mode
    if currentView == "list" then
        self:RenderListView(items)
    else
        -- Combined Grid/Flow rendering
        self:RenderFlowView(items)
    end

    -- Update footer
    self:UpdateBagIconTextures()
    self:UpdateBagIconVisuals()
    self:UpdateSlotCount()
    self:UpdateMoney()

    -- Apply search if active
    if searchText and searchText ~= "" then
        self:ApplySearch(searchText)
    end

    hasRenderedOnce = true
    pendingCombatRender = false
end

-- =============================================================================
-- Flow/Grid View Rendering
-- =============================================================================

function Frame:RenderFlowView(items)
    if not mainFrame or not mainFrame.scrollChild then return end

    local scrollChild = mainFrame.scrollChild

    -- Release existing buttons
    if Omni.Pool then
        for _, btn in ipairs(itemButtons) do
            Omni.Pool:Release("ItemButton", btn)
        end
    end
    itemButtons = {}

    -- Hide existing headers and list rows
    for _, header in ipairs(categoryHeaders) do header:Hide() end
    for _, row in ipairs(listRows) do row:Hide() end

    local hInset = 8
    local usableWidth = mainFrame.content:GetWidth() - hInset
    local sectionHeaderHeight = (currentView == "grid") and 0 or 20 -- No headers in grid mode
    local sectionSpacing = (currentView == "grid") and ITEM_SPACING or 8
    local dualCategoryLanes = (currentView ~= "grid")
    local laneGap = 10

    local function columnsForLaneWidth(laneW)
        local inner = laneW - ITEM_SPACING
        local c = math.floor(inner / (ITEM_SIZE + ITEM_SPACING))
        return math.max(c, 1)
    end

    local yLeft = -ITEM_SPACING
    local yRight = -ITEM_SPACING
    local yOffset = -ITEM_SPACING
    local renderedSectionCount = 0

    -- Group items
    local categories = {}
    local categoryOrder = {}

    if currentView == "grid" then
        -- GRID MODE: Everything in one bucket, sorted by user's preference (already sorted)
        categories["All"] = items
        categoryOrder = { "All" }
    elseif currentView == "bag" then
        for _, bagID in ipairs(BAG_IDS) do
            categories[bagID] = {}
            table.insert(categoryOrder, bagID)
        end

        for _, item in ipairs(items) do
            if IsValidBagID(item.bagID) then
                table.insert(categories[item.bagID], item)
            end
        end
    else
        -- FLOW MODE: Group by assigned category
        for _, item in ipairs(items) do
            local cat = item.category or "Miscellaneous"
            if not categories[cat] then
                categories[cat] = {}
                table.insert(categoryOrder, cat)
            end
            table.insert(categories[cat], item)
        end

        -- Sort categories
        if Omni.Categorizer then
            table.sort(categoryOrder, function(a, b)
                local infoA = Omni.Categorizer:GetCategoryInfo(a)
                local infoB = Omni.Categorizer:GetCategoryInfo(b)
                return (infoA.priority or 99) < (infoB.priority or 99)
            end)
        end
    end

    local headerIndex = 0

    for _, catName in ipairs(categoryOrder) do
        local catItems = categories[catName]
        if catItems and #catItems > 0 then
            renderedSectionCount = renderedSectionCount + 1

            local laneX, laneY, columns
            if dualCategoryLanes then
                local laneW = (usableWidth - laneGap) * 0.5
                local edgePad = hInset * 0.5
                local leftX = edgePad + ITEM_SPACING
                local rightX = edgePad + laneW + laneGap + ITEM_SPACING
                local useRight = (renderedSectionCount % 2 == 0)
                laneX = useRight and rightX or leftX
                laneY = useRight and yRight or yLeft
                columns = columnsForLaneWidth(laneW)
            else
                laneX = ITEM_SPACING
                laneY = yOffset
                columns = columnsForLaneWidth(usableWidth)
            end

            if currentView ~= "grid" then
                headerIndex = headerIndex + 1
                local header = categoryHeaders[headerIndex]
                if not header then
                    header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    categoryHeaders[headerIndex] = header
                end

                header:ClearAllPoints()
                header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", laneX, laneY)

                local r, g, b = 1, 1, 1
                if currentView == "bag" then
                    r, g, b = 0.9, 0.8, 0.4
                elseif Omni.Categorizer then
                    r, g, b = Omni.Categorizer:GetCategoryColor(catName)
                end
                header:SetTextColor(r, g, b)
                if currentView == "bag" then
                    header:SetText(GetBagDisplayName(catName) .. " (" .. #catItems .. ")")
                else
                    header:SetText(catName .. " (" .. #catItems .. ")")
                end
                header:Show()

                laneY = laneY - sectionHeaderHeight
            end

            for i, itemInfo in ipairs(catItems) do
                local btn
                if Omni.Pool then
                    btn = Omni.Pool:Acquire("ItemButton")
                else
                    btn = Omni.ItemButton:Create(scrollChild)
                end

                if btn then
                    local col = ((i - 1) % columns)
                    local row = math.floor((i - 1) / columns)
                    local x = laneX + col * (ITEM_SIZE + ITEM_SPACING)
                    local y = laneY - row * (ITEM_SIZE + ITEM_SPACING)

                    -- ʕ •ᴥ•ʔ✿ Parent under the ItemContainer that matches this
                    -- item's bag so ContainerFrameItemButton_OnClick resolves
                    -- the right bag. SetParent / SetPoint / SetID on the
                    -- ContainerFrameItemButton are protected; we only get
                    -- here OOC because UpdateLayout is combat-gated. ✿ ʕ •ᴥ•ʔ
                    local container = GetItemContainer(itemInfo.bagID or -1) or scrollChild
                    pcall(function()
                        if btn:GetParent() ~= container then
                            btn:SetParent(container)
                        end
                        btn:ClearAllPoints()
                        btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", x, y)
                    end)

                    local success = pcall(function()
                        SetButtonItem(btn, itemInfo)
                        btn:Show()
                    end)
                    if not success then
                        pcall(SetButtonItem, btn, nil)
                        if btn.icon then btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
                        pcall(btn.Show, btn)
                    end

                    table.insert(itemButtons, btn)
                end
            end

            local catRows = math.ceil(#catItems / columns)
            laneY = laneY - (catRows * (ITEM_SIZE + ITEM_SPACING)) - sectionSpacing

            if dualCategoryLanes then
                if (renderedSectionCount % 2 == 0) then
                    yRight = laneY
                else
                    yLeft = laneY
                end
            else
                yOffset = laneY
            end
        end
    end

    local bottomY
    if dualCategoryLanes then
        bottomY = math.min(yLeft, yRight)
    else
        bottomY = yOffset
    end
    scrollChild:SetHeight(math.abs(bottomY) + ITEM_SPACING)
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

    -- ʕ •ᴥ•ʔ✿ Rows are now plain Buttons (see CreateFrame above) so there
    -- is nothing secure to configure. Kept as a no-op to keep the call
    -- sites below trivially correct. ✿ ʕ •ᴥ•ʔ
    local function ConfigureSecureRowUse(row)
        if row then row.secureUseConfigured = false end
    end

    -- Layout constants
    local ROW_HEIGHT = 22
    local ICON_SIZE = 18
    local contentWidth = mainFrame.content:GetWidth() - 8
    local yOffset = -4

    for i, itemInfo in ipairs(items) do
        -- Get or create row frame
        local row = listRows[i]
        if not row then
            -- ʕ •ᴥ•ʔ✿ Plain Button (no secure template) so list rows do NOT
            -- promote OmniInventoryFrame to "protected by association".
            -- List view's row clicks are insecure-only by design (they
            -- call PickupContainerItem directly which is forbidden in
            -- combat anyway); secure use/swap during combat is handled
            -- by the flow/grid item buttons via ContainerFrameItemButton
            -- Template. ✿ ʕ •ᴥ•ʔ
            row = CreateFrame("Button", nil, scrollChild)
            row:SetHeight(ROW_HEIGHT)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

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
                    if MerchantFrame and MerchantFrame:IsShown() and (not CursorHasItem or not CursorHasItem()) and ShowContainerSellCursor then
                        ShowContainerSellCursor(self.itemInfo.bagID, self.itemInfo.slotID)
                    elseif CursorUpdate then
                        CursorUpdate(self)
                    end
                end
            end)
            row:SetScript("OnLeave", function(self)
                local alpha = (i % 2 == 0) and 0.15 or 0.1
                self.bg:SetVertexColor(0.1, 0.1, 0.1, 1)
                GameTooltip:Hide()
                if ResetCursor then
                    ResetCursor()
                end
            end)
            row:SetScript("PreClick", function(self, mouseButton)
                if Omni.ItemButton and Omni.ItemButton.OnPreClick then
                    Omni.ItemButton:OnPreClick(self, mouseButton)
                end
            end)
            row:HookScript("OnClick", function(self, mouseButton)
                local mb = mouseButton
                if mb == "RightButtonUp" or mb == "RightButtonDown" then
                    mb = "RightButton"
                elseif mb == "LeftButtonUp" or mb == "LeftButtonDown" then
                    mb = "LeftButton"
                end
                if mb == "RightButton" and self.itemInfo then
                    local bagID, slotID = self.itemInfo.bagID, self.itemInfo.slotID
                    if bagID and slotID and bagID >= 0 and slotID >= 1 then
                        if Omni.ItemButton and Omni.ItemButton.HandleBagSlotRightClickInventory then
                            Omni.ItemButton:HandleBagSlotRightClickInventory(bagID, slotID, self.secureUseConfigured)
                        end
                    end
                    return
                end
                if mb ~= "LeftButton" or not self.itemInfo then
                    return
                end
                local bagID, slotID = self.itemInfo.bagID, self.itemInfo.slotID
                if not bagID or not slotID or bagID < 0 or slotID < 1 then
                    return
                end
                if InCombatLockdown and InCombatLockdown() then
                    return
                end
                PickupContainerItem(bagID, slotID)
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

        -- Error boundary
        local success, err = pcall(function()
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
        end)

        if not success then
             row.name:SetText("Error loading item")
             row.name:SetTextColor(1, 0, 0)
             row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        -- Store item info for click/tooltip
        row.itemInfo = itemInfo
        row:SetScript("PreClick", nil)
        ConfigureSecureRowUse(row, itemInfo.bagID, itemInfo.slotID)

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
    for bagID = 0, 4 do
        local numSlots = GetContainerNumSlots(bagID) or 0
        local numFree = GetContainerNumFreeSlots(bagID) or 0
        total = total + numSlots
        free = free + numFree
    end

    local used = total - free
    mainFrame.footer.slots:SetText(string.format("%d/%d", used, total))
end

function Frame:UpdateMoney()
    if not mainFrame or not mainFrame.footer then return end

    local money = GetMoney() or 0
    if Omni.Utils and Omni.Utils.FormatMoney then
        mainFrame.footer.money:SetText(Omni.Utils:FormatMoney(money))
        return
    end

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
        currentView = GetSavedViewMode()
        selectedBagID = GetSavedBagFilter()
        self:CreateMainFrame()
        self:SetView(currentView)
        self:LoadPosition()
    end

    -- ʕ •ᴥ•ʔ✿ ContainerFrameItemButtonTemplate keeps mainFrame insecure, so
    -- a plain Show() works in combat just like AdiBags. UpdateLayout is
    -- still combat-gated; the buttons keep their last OOC (bag, slot,
    -- position) and remain clickable through Blizzard's secure path. ✿ ʕ •ᴥ•ʔ
    pcall(mainFrame.Show, mainFrame)

    if Frame.UpdateFooterButton then Frame:UpdateFooterButton() end
    self:UpdateLayout()
end

function Frame:Hide()
    if not mainFrame then return end

    pcall(mainFrame.Hide, mainFrame)

    if not InCombat()
            and OmniInventoryDB and OmniInventoryDB.global
            and OmniInventoryDB.global.autoSortOnClose then
        Frame:PhysicalSortBags()
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
    return mainFrame and mainFrame:IsShown() and true or false
end

-- =============================================================================
-- Auto-Sort Physical Bags
-- =============================================================================

function Frame:PhysicalSortBags()
    -- Use Blizzard's native SortBags function (WoTLK 3.3.5a compatible)
    if SortBags then
        SortBags()
    end
end

function Frame:SetBagFilter(bagID)
    if bagID ~= nil and not IsValidBagID(bagID) then return end

    selectedBagID = bagID

    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.char = OmniInventoryDB.char or {}
    OmniInventoryDB.char.settings = OmniInventoryDB.char.settings or {}
    OmniInventoryDB.char.settings.selectedBagID = selectedBagID

    self:UpdateBagIconVisuals()
    self:UpdateLayout()
end

function Frame:ToggleBagPreview(bagID)
    if not IsValidBagID(bagID) then return end

    if currentView ~= "bag" then
        self:SetView("bag")
    end

    if selectedBagID == bagID then
        self:SetBagFilter(nil)
    else
        self:SetBagFilter(bagID)
    end
end

local function CanBagAcceptItem(bagID, itemFamily)
    local _, bagFamily = GetContainerNumFreeSlots(bagID)
    bagFamily = bagFamily or 0

    if bagFamily == 0 then
        return true
    end
    if not itemFamily or itemFamily == 0 then
        return false
    end
    if bit and bit.band then
        return bit.band(itemFamily, bagFamily) > 0
    end
    return true
end

local function FindFirstOpenSlotExcludingBag(excludedBagID, itemFamily)
    for _, bagID in ipairs(BAG_IDS) do
        if bagID ~= excludedBagID and CanBagAcceptItem(bagID, itemFamily) then
            local slots = GetContainerNumSlots(bagID) or 0
            for slotID = 1, slots do
                local texture = GetContainerItemInfo(bagID, slotID)
                if not texture then
                    return bagID, slotID
                end
            end
        end
    end
    return nil, nil
end

local function StopForceEmptyJob()
    if forceEmptyFrame then
        forceEmptyFrame:SetScript("OnUpdate", nil)
    end
    forceEmptyJob = nil
end

local function FinishForceEmptyJob()
    if not forceEmptyJob then
        return
    end

    print(string.format("|cFF00FF00OmniInventory|r: Force-empty bag %d moved %d, blocked %d.",
        forceEmptyJob.sourceBagID, forceEmptyJob.movedCount, forceEmptyJob.blockedCount))

    StopForceEmptyJob()
    if Frame and Frame.UpdateLayout then
        Frame:UpdateLayout()
    end
end

local function RunForceEmptyStep()
    if not forceEmptyJob then
        return
    end

    if #forceEmptyJob.slots == 0 then
        FinishForceEmptyJob()
        return
    end

    local sourceBagID = forceEmptyJob.sourceBagID
    local slotEntry = table.remove(forceEmptyJob.slots, 1)
    local slotID = slotEntry.slotID
    local attempts = slotEntry.attempts or 0

    local texture, _, isLocked = GetContainerItemInfo(sourceBagID, slotID)
    if not texture then
        return
    end
    if isLocked then
        attempts = attempts + 1
        if attempts >= FORCE_EMPTY_MAX_LOCK_RETRIES then
            forceEmptyJob.blockedCount = forceEmptyJob.blockedCount + 1
        else
            slotEntry.attempts = attempts
            table.insert(forceEmptyJob.slots, slotEntry)
        end
        return
    end

    local itemLink = GetContainerItemLink(sourceBagID, slotID)
    local itemFamily = (itemLink and GetItemFamily(itemLink)) or 0
    local targetBagID, targetSlotID = FindFirstOpenSlotExcludingBag(sourceBagID, itemFamily)
    if not targetBagID or not targetSlotID then
        forceEmptyJob.blockedCount = forceEmptyJob.blockedCount + 1
        return
    end

    PickupContainerItem(sourceBagID, slotID)
    if CursorHasItem and CursorHasItem() then
        PickupContainerItem(targetBagID, targetSlotID)
    end

    if CursorHasItem and CursorHasItem() then
        ClearCursor()
        attempts = attempts + 1
        if attempts >= FORCE_EMPTY_MAX_MOVE_RETRIES then
            forceEmptyJob.blockedCount = forceEmptyJob.blockedCount + 1
        else
            slotEntry.attempts = attempts
            table.insert(forceEmptyJob.slots, slotEntry)
        end
    else
        forceEmptyJob.movedCount = forceEmptyJob.movedCount + 1
    end
end

function Frame:ForceEmptyBag(sourceBagID)
    if not IsValidBagID(sourceBagID) then return end

    if CursorHasItem and CursorHasItem() then
        print("|cFF00FF00OmniInventory|r: Clear cursor item before force-empty.")
        return
    end

    local sourceSlots = GetContainerNumSlots(sourceBagID) or 0
    if sourceSlots <= 0 then
        print("|cFF00FF00OmniInventory|r: That bag has no slots.")
        return
    end

    local slots = {}
    for slotID = 1, sourceSlots do
        local texture = GetContainerItemInfo(sourceBagID, slotID)
        if texture then
            table.insert(slots, { slotID = slotID, attempts = 0 })
        end
    end

    if #slots == 0 then
        print("|cFF00FF00OmniInventory|r: Bag is already empty.")
        return
    end

    if forceEmptyJob then
        StopForceEmptyJob()
    end

    forceEmptyJob = {
        sourceBagID = sourceBagID,
        slots = slots,
        movedCount = 0,
        blockedCount = 0,
        elapsed = 0,
    }

    forceEmptyFrame = forceEmptyFrame or CreateFrame("Frame")
    forceEmptyFrame:SetScript("OnUpdate", function(_, elapsed)
        if not forceEmptyJob then
            return
        end
        forceEmptyJob.elapsed = forceEmptyJob.elapsed + (elapsed or 0)
        if forceEmptyJob.elapsed < FORCE_EMPTY_STEP_INTERVAL then
            return
        end
        forceEmptyJob.elapsed = 0
        RunForceEmptyStep()
    end)
end

-- =============================================================================
-- Initialization
-- =============================================================================

function Frame:Init()
    currentView = GetSavedViewMode()
    selectedBagID = GetSavedBagFilter()

    self:CreateMainFrame()
    self:LoadPosition()

    if Omni.Pool and Omni.Pool.Prewarm then
        Omni.Pool:Prewarm("ItemButton", 160)
    end

    -- ʕ •ᴥ•ʔ✿ Park every prewarmed button on the limbo parent OOC so the
    -- first OOC render can freely SetParent them onto the right bag's
    -- ItemContainer. SetParent on a ContainerFrameItemButton is still
    -- protected, so all of this MUST happen out of combat. ✿ ʕ •ᴥ•ʔ
    if not InCombat() then
        local pool = Omni.Pool and Omni.Pool:Get("ItemButton")
        local available = pool and pool.available
        if available then
            for _, btn in ipairs(available) do
                pcall(btn.ClearAllPoints, btn)
                pcall(btn.Hide, btn)
            end
        end
    end

    -- ʕ •ᴥ•ʔ✿ Eagerly populate the layout while hidden so a first open
    -- mid-combat already has every item button parented to its bag's
    -- ItemContainer, positioned, and click-routable through the
    -- template's secure OnClick. ✿ ʕ •ᴥ•ʔ
    pcall(function() Frame:SetView(currentView) end)
end

print("|cFF00FF00OmniInventory|r: Frame loaded")
