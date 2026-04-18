-- =============================================================================
-- OmniInventory Bank Frame
-- =============================================================================
-- ʕ •ᴥ•ʔ✿ Standalone bank window that docks to the left of the main bag frame
-- whenever BANKFRAME_OPENED fires. Closes on BANKFRAME_CLOSED. ✿ ʕ •ᴥ•ʔ
-- =============================================================================

local addonName, Omni = ...

Omni.BankFrame = {}
local BankFrame = Omni.BankFrame

-- =============================================================================
-- Constants
-- =============================================================================

local FRAME_MIN_WIDTH = 350
local FRAME_MIN_HEIGHT = 300
local FRAME_DEFAULT_WIDTH = 450
local FRAME_DEFAULT_HEIGHT = 500
local HEADER_HEIGHT = 24
local FOOTER_HEIGHT = 24
local SEARCH_HEIGHT = 24
local PADDING = 8
local ITEM_SIZE = 37
local ITEM_SPACING = 4
local FRAME_GAP = 6

-- =============================================================================
-- State
-- =============================================================================

local bankFrame = nil
local itemButtons = {}
local categoryHeaders = {}
local searchText = ""
local isSearchActive = false

-- =============================================================================
-- Helpers
-- =============================================================================

local function SetButtonItem(btn, itemInfo)
    if not btn then return end
    if Omni.ItemButton and Omni.ItemButton.SetItem then
        Omni.ItemButton:SetItem(btn, itemInfo)
    end
end

local function SavePosition()
    if not bankFrame then return end
    local point, _, _, x, y = bankFrame:GetPoint()
    local width, height = bankFrame:GetSize()
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.char = OmniInventoryDB.char or {}
    OmniInventoryDB.char.bankPosition = {
        point = point,
        x = x,
        y = y,
        width = width,
        height = height,
        userMoved = bankFrame.userMoved,
    }
end

local function LoadPosition()
    if not bankFrame then return end
    local pos = OmniInventoryDB and OmniInventoryDB.char and OmniInventoryDB.char.bankPosition
    if not pos then return end

    if pos.width and pos.height then
        bankFrame:SetSize(pos.width, pos.height)
    end
    if pos.userMoved then
        bankFrame.userMoved = true
        bankFrame:ClearAllPoints()
        bankFrame:SetPoint(pos.point or "CENTER", UIParent,
            pos.point or "CENTER", pos.x or 0, pos.y or 0)
    end
end

-- ʕ •ᴥ•ʔ✿ Anchor to the left of the main bag frame if available ✿ ʕ •ᴥ•ʔ
local function AnchorToMainFrame()
    if not bankFrame then return end
    if bankFrame.userMoved then return end

    local main = _G.OmniInventoryFrame
    if main and main:IsShown() then
        bankFrame:ClearAllPoints()
        bankFrame:SetPoint("TOPRIGHT", main, "TOPLEFT", -FRAME_GAP, 0)
    else
        bankFrame:ClearAllPoints()
        bankFrame:SetPoint("CENTER", UIParent, "CENTER", -250, 0)
    end
end

-- =============================================================================
-- Frame Construction
-- =============================================================================

local function CreateHeader(parent)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", PADDING, -PADDING)
    header:SetPoint("TOPRIGHT", -PADDING, -PADDING)

    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()
    header.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    header.bg:SetVertexColor(0.15, 0.15, 0.15, 1)

    header.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.title:SetPoint("LEFT", 6, 0)
    header.title:SetText("|cFF00FFAA Omni|r Bank")

    header.closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    header.closeBtn:SetSize(20, 20)
    header.closeBtn:SetPoint("RIGHT", -2, 0)
    header.closeBtn:SetScript("OnClick", function()
        if CloseBankFrame then CloseBankFrame() end
        BankFrame:Hide()
    end)

    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        parent:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
        parent.userMoved = true
        SavePosition()
    end)

    parent.header = header
    return header
end

local function CreateSearchBar(parent)
    local searchBar = CreateFrame("Frame", nil, parent)
    searchBar:SetHeight(SEARCH_HEIGHT)
    searchBar:SetPoint("TOPLEFT", parent.header, "BOTTOMLEFT", 0, -4)
    searchBar:SetPoint("TOPRIGHT", parent.header, "BOTTOMRIGHT", 0, -4)

    searchBar.bg = searchBar:CreateTexture(nil, "BACKGROUND")
    searchBar.bg:SetAllPoints()
    searchBar.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    searchBar.bg:SetVertexColor(0.1, 0.1, 0.1, 1)

    searchBar.icon = searchBar:CreateTexture(nil, "ARTWORK")
    searchBar.icon:SetSize(14, 14)
    searchBar.icon:SetPoint("LEFT", 6, 0)
    searchBar.icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")

    searchBar.editBox = CreateFrame("EditBox", "OmniBankSearchBox", searchBar)
    searchBar.editBox:SetPoint("LEFT", searchBar.icon, "RIGHT", 4, 0)
    searchBar.editBox:SetPoint("RIGHT", -6, 0)
    searchBar.editBox:SetHeight(18)
    searchBar.editBox:SetAutoFocus(false)
    searchBar.editBox:SetFontObject(ChatFontNormal)
    searchBar.editBox:SetTextColor(1, 1, 1, 1)
    searchBar.editBox:SetTextInsets(2, 2, 0, 0)

    searchBar.editBox:SetScript("OnTextChanged", function(self)
        searchText = self:GetText() or ""
        BankFrame:ApplySearch(searchText)
    end)
    searchBar.editBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    parent.searchBar = searchBar
    parent.searchBox = searchBar.editBox
    return searchBar
end

local function CreateContentArea(parent)
    local content = CreateFrame("ScrollFrame", "OmniBankContentScroll", parent, "UIPanelScrollFrameTemplate")
    content:SetPoint("TOPLEFT", parent.searchBar, "BOTTOMLEFT", 0, -4)
    content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -PADDING - 20, PADDING + FOOTER_HEIGHT + 4)

    local scrollChild = CreateFrame("Frame", "OmniBankContentChild", content)
    scrollChild:SetSize(content:GetWidth(), 1)
    content:SetScrollChild(scrollChild)

    local scrollBar = _G["OmniBankContentScrollScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", 20, -16)
        scrollBar:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 20, 16)
    end

    parent.content = content
    parent.scrollChild = scrollChild
end

local function CreateFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetHeight(FOOTER_HEIGHT)
    footer:SetPoint("BOTTOMLEFT", PADDING, PADDING)
    footer:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)

    footer.bg = footer:CreateTexture(nil, "BACKGROUND")
    footer.bg:SetAllPoints()
    footer.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    footer.bg:SetVertexColor(0.12, 0.12, 0.12, 1)

    footer.slots = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footer.slots:SetPoint("LEFT", 6, 0)
    footer.slots:SetText("0/0")

    footer.note = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footer.note:SetPoint("RIGHT", -6, 0)
    footer.note:SetTextColor(0.6, 0.6, 0.6)
    footer.note:SetText("Bank")

    parent.footer = footer
end

local function CreateResizeHandle(parent)
    local handle = CreateFrame("Button", nil, parent)
    handle:SetSize(16, 16)
    handle:SetPoint("BOTTOMRIGHT", -2, 2)
    handle:EnableMouse(true)

    handle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    handle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    handle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    handle:SetScript("OnMouseDown", function()
        parent:StartSizing("BOTTOMRIGHT")
    end)
    handle:SetScript("OnMouseUp", function()
        parent:StopMovingOrSizing()
        SavePosition()
        BankFrame:UpdateLayout()
    end)

    parent.resizeHandle = handle
end

function BankFrame:CreateMainFrame()
    if bankFrame then return bankFrame end

    bankFrame = CreateFrame("Frame", "OmniInventoryBankFrame", UIParent)
    bankFrame:SetSize(FRAME_DEFAULT_WIDTH, FRAME_DEFAULT_HEIGHT)
    bankFrame:SetPoint("CENTER")
    bankFrame:SetFrameStrata("HIGH")
    bankFrame:SetFrameLevel(100)
    bankFrame:EnableMouse(true)
    bankFrame:SetMovable(true)
    bankFrame:SetResizable(true)
    bankFrame:SetClampedToScreen(true)
    bankFrame:SetMinResize(FRAME_MIN_WIDTH, FRAME_MIN_HEIGHT)

    bankFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    bankFrame:SetBackdropColor(0.05, 0.09, 0.08, 0.95)
    bankFrame:SetBackdropBorderColor(0.3, 0.55, 0.45, 1)

    local scale = OmniInventoryDB and OmniInventoryDB.char
        and OmniInventoryDB.char.settings and OmniInventoryDB.char.settings.scale
    bankFrame:SetScale(scale or 1)

    tinsert(UISpecialFrames, "OmniInventoryBankFrame")

    CreateHeader(bankFrame)
    CreateSearchBar(bankFrame)
    CreateContentArea(bankFrame)
    CreateFooter(bankFrame)
    CreateResizeHandle(bankFrame)

    bankFrame:Hide()

    bankFrame:SetScript("OnShow", function()
        AnchorToMainFrame()
        BankFrame:UpdateLayout()
    end)

    bankFrame:SetScript("OnHide", function()
        if CloseBankFrame then CloseBankFrame() end
    end)

    return bankFrame
end

-- =============================================================================
-- Rendering (flow view only)
-- =============================================================================

local function CollectBankItems()
    local items = {}
    if OmniC_Container and OmniC_Container.GetAllBankItems then
        items = OmniC_Container.GetAllBankItems() or {}
    end

    if Omni.Categorizer then
        for _, item in ipairs(items) do
            item.category = item.category or Omni.Categorizer:GetCategory(item)
            if item.itemID then
                item.isNew = Omni.Categorizer:IsNewItem(item.itemID)
            end
        end
    end

    if Omni.Sorter then
        items = Omni.Sorter:Sort(items, Omni.Sorter:GetDefaultMode())
    end

    return items
end

function BankFrame:RenderFlowView(items)
    if not bankFrame or not bankFrame.scrollChild then return end

    local scrollChild = bankFrame.scrollChild

    if Omni.Pool then
        for _, btn in ipairs(itemButtons) do
            Omni.Pool:Release("ItemButton", btn)
        end
    end
    itemButtons = {}

    for _, header in ipairs(categoryHeaders) do
        header:Hide()
    end

    local contentWidth = bankFrame.content:GetWidth() - 20
    local columns = math.max(math.floor(contentWidth / (ITEM_SIZE + ITEM_SPACING)), 1)

    local yOffset = -ITEM_SPACING
    local sectionHeaderHeight = 20
    local sectionSpacing = 8

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

    if Omni.Categorizer then
        table.sort(categoryOrder, function(a, b)
            local infoA = Omni.Categorizer:GetCategoryInfo(a)
            local infoB = Omni.Categorizer:GetCategoryInfo(b)
            return (infoA.priority or 99) < (infoB.priority or 99)
        end)
    end

    local headerIndex = 0
    for _, catName in ipairs(categoryOrder) do
        local catItems = categories[catName]
        if catItems and #catItems > 0 then
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

            yOffset = yOffset - sectionHeaderHeight

            for i, itemInfo in ipairs(catItems) do
                local btn
                if Omni.Pool then
                    btn = Omni.Pool:Acquire("ItemButton")
                elseif Omni.ItemButton then
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

                    local ok = pcall(function()
                        SetButtonItem(btn, itemInfo)
                        btn:Show()
                    end)
                    if not ok then
                        SetButtonItem(btn, nil)
                        if btn.icon then btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
                        btn:Show()
                    end

                    table.insert(itemButtons, btn)
                end
            end

            local catRows = math.ceil(#catItems / columns)
            yOffset = yOffset - (catRows * (ITEM_SIZE + ITEM_SPACING)) - sectionSpacing
        end
    end

    scrollChild:SetHeight(math.abs(yOffset) + ITEM_SPACING)
end

function BankFrame:UpdateLayout()
    if not bankFrame or not bankFrame:IsShown() then return end

    local items = CollectBankItems()
    self:RenderFlowView(items)
    self:UpdateSlotCount()

    if searchText and searchText ~= "" then
        self:ApplySearch(searchText)
    end
end

function BankFrame:UpdateSlotCount()
    if not bankFrame or not bankFrame.footer then return end

    local free, total = 0, 0
    local mainSlots = GetContainerNumSlots(-1) or 0
    local mainFree = GetContainerNumFreeSlots(-1) or 0
    total = total + mainSlots
    free = free + mainFree

    for bagID = 5, 11 do
        local slots = GetContainerNumSlots(bagID) or 0
        local freeSlots = GetContainerNumFreeSlots(bagID) or 0
        total = total + slots
        free = free + freeSlots
    end

    local used = total - free
    bankFrame.footer.slots:SetText(string.format("%d/%d", used, total))
end

function BankFrame:ApplySearch(text)
    searchText = text or ""
    isSearchActive = (searchText ~= "")

    if not isSearchActive then
        for _, btn in ipairs(itemButtons) do
            if Omni.ItemButton then
                Omni.ItemButton:ClearSearch(btn)
            end
        end
        return
    end

    local lowerSearch = string.lower(searchText)
    for _, btn in ipairs(itemButtons) do
        local info = btn.itemInfo
        local isMatch = false
        if info and info.hyperlink then
            local name = GetItemInfo(info.hyperlink)
            if name and string.find(string.lower(name), lowerSearch, 1, true) then
                isMatch = true
            end
        end
        if Omni.ItemButton then
            Omni.ItemButton:SetSearchMatch(btn, isMatch)
        end
    end
end

-- =============================================================================
-- Show / Hide / Toggle
-- =============================================================================

function BankFrame:Show()
    if not bankFrame then
        self:CreateMainFrame()
        LoadPosition()
    end
    AnchorToMainFrame()
    bankFrame:Show()
end

function BankFrame:Hide()
    if bankFrame then
        bankFrame:Hide()
    end
end

function BankFrame:Toggle()
    if bankFrame and bankFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function BankFrame:IsShown()
    return bankFrame and bankFrame:IsShown()
end

function BankFrame:GetFrame()
    return bankFrame
end

function BankFrame:Init()
    -- Frame is created lazily on first show
end

print("|cFF00FF00OmniInventory|r: BankFrame loaded")
