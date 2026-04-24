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
local BAG_ICON_SIZE = 18
local RIBBON_GAP = 3
local RIBBON_SEP_GAP = 5
local RIBBON_ICON_BTN_SIZE = 20
local SETTINGS_ICON = "Interface\\Icons\\Trade_Engineering"
local BANK_BAG_IDS = { 5, 6, 7, 8, 9, 10, 11 }

-- =============================================================================
-- State
-- =============================================================================

local bankFrame = nil
local itemButtons = {}
local categoryHeaders = {}
local searchText = ""
local isSearchActive = false
local selectedBankBagID = nil
local bankForceEmptyFrame = nil
local bankForceEmptyJob = nil
local BANK_FORCE_EMPTY_EVENT_TIMEOUT = 0.35
local BANK_FORCE_EMPTY_MAX_LOCK = 20
local BANK_FORCE_EMPTY_MAX_MOVE = 6

-- =============================================================================
-- Helpers
-- =============================================================================

local function SetButtonItem(btn, itemInfo)
    if not btn then return end
    if Omni.ItemButton and Omni.ItemButton.SetItem then
        Omni.ItemButton:SetItem(btn, itemInfo)
    end
end

local function GetSharedItemScale()
    if Omni.Frame and Omni.Frame.GetItemScale then
        return Omni.Frame:GetItemScale()
    end
    return 1
end

local function GetSharedItemGap()
    if Omni.Frame and Omni.Frame.GetItemGap then
        return Omni.Frame:GetItemGap()
    end
    return ITEM_SPACING
end

local function ApplyBankItemMetrics(btn, itemSize)
    if not btn then return end
    pcall(function()
        btn:SetScale(1)
        btn:SetSize(itemSize, itemSize)
        if btn.glow then
            btn.glow:SetSize(itemSize * 1.5, itemSize * 1.5)
        end
    end)
end

local function IsValidBankBagID(bagID)
    if bagID == nil then return false end
    if bagID == -1 then return true end
    if type(bagID) == "number" and bagID >= 5 and bagID <= 11 then
        local idx = bagID - 4
        local numPurchased = (GetNumBankSlots and GetNumBankSlots()) or 0
        return idx <= numPurchased
    end
    return false
end

local function GetSavedBankBagFilter()
    local settings = OmniInventoryDB and OmniInventoryDB.char and OmniInventoryDB.char.settings
    local id = settings and settings.selectedBankBagID
    if id == nil then return nil end
    if IsValidBankBagID(id) then
        return id
    end
    return nil
end

local function GetBankBagIconTexture(bagID)
    local inv = ContainerIDToInventoryID and ContainerIDToInventoryID(bagID)
    local tex = inv and GetInventoryItemTexture("player", inv)
    return tex or "Interface\\Icons\\INV_Misc_Bag_10_Blue"
end

local function StyleRibbonButton(btn)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(0.12, 0.12, 0.12, 1)
    btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)

    btn:HookScript("OnEnter", function(self)
        self:SetBackdropColor(0.22, 0.22, 0.22, 1)
        self:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        if self._tooltipTitle then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(self._tooltipTitle, 1, 1, 1)
            if self._tooltipSub then
                GameTooltip:AddLine(self._tooltipSub, 0.8, 0.8, 0.8)
            end
            GameTooltip:Show()
        end
    end)
    btn:HookScript("OnLeave", function(self)
        self:SetBackdropColor(0.12, 0.12, 0.12, 1)
        self:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
        GameTooltip:Hide()
    end)
end

local function CreateRibbonIconButton(parent, iconTexture, tooltipTitle, tooltipSub, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(RIBBON_ICON_BTN_SIZE, RIBBON_ICON_BTN_SIZE)
    StyleRibbonButton(btn)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 2, -2)
    btn.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    btn.icon:SetTexture(iconTexture)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    btn._tooltipTitle = tooltipTitle
    btn._tooltipSub = tooltipSub
    btn:SetScript("OnClick", onClick)
    return btn
end

local function BankBagSlotIndex(bagID)
    return bagID - 4
end

local function BankBagSlotsMax()
    return NUM_BANKBAGSLOTS or 7
end

local function HandleUnpurchasedBankBagClick(bagID)
    local slotIndex = BankBagSlotIndex(bagID)
    local numSlots, full = GetNumBankSlots()
    numSlots = numSlots or 0
    if slotIndex <= numSlots then
        return false
    end
    if full or numSlots >= BankBagSlotsMax() then
        return true
    end
    if slotIndex ~= numSlots + 1 then
        if UIErrorsFrame and UIErrorsFrame.AddMessage then
            UIErrorsFrame:AddMessage("Purchase bank bag slots in order.", 1, 0.1, 0.1, 1)
        end
        return true
    end
    local cost = GetBankSlotCost and GetBankSlotCost(numSlots)
    if not cost then
        return true
    end
    local bf = _G.BankFrame
    if bf then
        bf.nextSlotCost = cost
    end
    if PlaySound then
        PlaySound("igMainMenuOption")
    end
    StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
    return true
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
    header.title:SetText("|cFF00FF00Omni|r Bank")

    header.closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    header.closeBtn:SetSize(20, 20)
    header.closeBtn:SetPoint("RIGHT", -2, 0)
    header.closeBtn:SetScript("OnClick", function()
        if CloseBankFrame then CloseBankFrame() end
        BankFrame:Hide()
    end)

    header.optBtn = CreateRibbonIconButton(header, SETTINGS_ICON,
        "Settings", "Open the OmniInventory settings panel",
        function()
            if Omni.Settings then
                Omni.Settings:Toggle()
            else
                print("|cFF00FF00OmniInventory|r: Settings not loaded")
            end
        end)
    header.optBtn:SetPoint("RIGHT", header.closeBtn, "LEFT", -RIBBON_GAP, 0)

    header.ribbonSep = header:CreateTexture(nil, "OVERLAY")
    header.ribbonSep:SetTexture("Interface\\Buttons\\WHITE8X8")
    header.ribbonSep:SetVertexColor(0.35, 0.35, 0.35, 1)
    header.ribbonSep:SetSize(1, 14)
    header.ribbonSep:SetPoint("RIGHT", header.optBtn, "LEFT", -RIBBON_SEP_GAP, 0)

    header.bagBar = CreateFrame("Frame", nil, header)
    header.bagBar:SetSize((BAG_ICON_SIZE + 2) * #BANK_BAG_IDS, BAG_ICON_SIZE)
    header.bagBar:SetPoint("RIGHT", header.ribbonSep, "LEFT", -RIBBON_SEP_GAP, 0)

    header.bagButtons = {}
    for index, bagID in ipairs(BANK_BAG_IDS) do
        local bagBtn = CreateFrame("Button", nil, header.bagBar)
        bagBtn:SetSize(BAG_ICON_SIZE, BAG_ICON_SIZE)
        bagBtn:SetPoint("LEFT", (index - 1) * (BAG_ICON_SIZE + 2), 0)
        bagBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        bagBtn:RegisterForDrag("LeftButton")
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
                if CursorHasItem and CursorHasItem() then
                    BankFrame:EquipBankBagFromCursor(self.bagID)
                    return
                end
                if HandleUnpurchasedBankBagClick(self.bagID) then
                    return
                end
                BankFrame:ToggleBankBagPreview(self.bagID)
            elseif mouseButton == "RightButton" then
                BankFrame:ForceEmptyBankBag(self.bagID)
            end
        end)
        bagBtn:SetScript("OnReceiveDrag", function(self)
            BankFrame:EquipBankBagFromCursor(self.bagID)
        end)
        bagBtn:SetScript("OnEnter", function(self)
            local slotIndex = BankBagSlotIndex(self.bagID)
            local numPurchased, bankBagsFull = GetNumBankSlots()
            numPurchased = numPurchased or 0
            local nextToBuy = (not bankBagsFull) and numPurchased < BankBagSlotsMax()
                and (slotIndex == numPurchased + 1)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            if slotIndex > numPurchased then
                GameTooltip:AddLine(BANK_BAG_PURCHASE or "Purchase this bank slot", 1, 0.2, 0.2)
                if nextToBuy then
                    GameTooltip:AddLine("Left-click: Purchase this slot (gold confirmation)", 0.8, 0.8, 0.8)
                elseif not bankBagsFull then
                    GameTooltip:AddLine("Buy earlier bank bag slots first.", 0.75, 0.75, 0.75)
                end
            else
                local name = GetBagName and GetBagName(self.bagID) or ("Bank bag " .. tostring(slotIndex))
                local slots = GetContainerNumSlots(self.bagID) or 0
                if slots > 0 and name and name ~= "" then
                    GameTooltip:AddLine(name, 1, 1, 1)
                else
                    GameTooltip:AddLine("Empty bank bag slot " .. tostring(slotIndex), 1, 1, 1)
                end
                GameTooltip:AddLine("Left-click: Show only this bank section", 0.8, 0.8, 0.8)
                GameTooltip:AddLine("Left-click (again): Show all bank slots", 0.8, 0.8, 0.8)
                GameTooltip:AddLine("Drag a bag here to equip in this slot", 0.6, 0.9, 0.6)
                GameTooltip:AddLine("Right-click: Move items to other bank space", 0.8, 0.8, 0.8)
            end
            GameTooltip:Show()
        end)
        bagBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        header.bagButtons[bagID] = bagBtn
    end

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

    -- ʕ •ᴥ•ʔ✿ Per-bag ItemContainer frames for the bank, mirroring the
    -- main bag's setup. ContainerFrameItemButton_OnClick reads bag from
    -- self:GetParent():GetID(), so each button must live under a parent
    -- whose SetID matches its bag (-1 main bank, 5..11 bank bags). ✿ ʕ •ᴥ•ʔ
    parent.itemContainers = {}
    local function MakeItemContainer(bagID)
        local f = CreateFrame("Frame", nil, scrollChild)
        f:SetSize(1, 1)
        f:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
        f:SetID(bagID)
        f:Show()
        parent.itemContainers[bagID] = f
        return f
    end
    MakeItemContainer(-1)
    for bagID = 5, 11 do
        MakeItemContainer(bagID)
    end
    parent._makeItemContainer = MakeItemContainer

    parent.content = content
    parent.scrollChild = scrollChild
end

local function GetBankItemContainer(bagID)
    if not bankFrame or not bankFrame.itemContainers then return nil end
    local container = bankFrame.itemContainers[bagID]
    if container then return container end
    if InCombatLockdown and InCombatLockdown() then return nil end
    if bankFrame._makeItemContainer then
        return bankFrame._makeItemContainer(bagID)
    end
    return nil
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

    selectedBankBagID = GetSavedBankBagFilter()
    BankFrame:UpdateBankBagButtonVisuals()
    BankFrame:UpdateBankBagButtonIcons()

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
    local perfCollect = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("bank.CollectBankItems.total")
    local items = {}
    if OmniC_Container and OmniC_Container.GetAllBankItems then
        items = OmniC_Container.GetAllBankItems() or {}
    end

    if Omni.Categorizer then
        local perfCategorize = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("bank.CollectBankItems.categorize")
        for _, item in ipairs(items) do
            item.category = item.category or Omni.Categorizer:GetCategory(item)
        end
        if Omni._perfEnabled and Omni.Perf then
            Omni.Perf:End("bank.CollectBankItems.categorize", perfCategorize)
        end
    end

    if Omni.Sorter then
        local perfSort = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("bank.CollectBankItems.sort")
        items = Omni.Sorter:Sort(items, Omni.Sorter:GetDefaultMode())
        if Omni._perfEnabled and Omni.Perf then
            Omni.Perf:End("bank.CollectBankItems.sort", perfSort, { itemCount = #items })
        end
    end

    if IsValidBankBagID(selectedBankBagID) then
        local filtered = {}
        for _, item in ipairs(items) do
            if item.bagID == selectedBankBagID then
                table.insert(filtered, item)
            end
        end
        items = filtered
    end

    if Omni._perfEnabled and Omni.Perf then
        Omni.Perf:End("bank.CollectBankItems.total", perfCollect, { itemCount = #items })
    end
    return items
end

function BankFrame:SetBankBagFilter(bagID)
    if bagID ~= nil and not IsValidBankBagID(bagID) then
        return
    end
    selectedBankBagID = bagID
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.char = OmniInventoryDB.char or {}
    OmniInventoryDB.char.settings = OmniInventoryDB.char.settings or {}
    OmniInventoryDB.char.settings.selectedBankBagID = selectedBankBagID
    self:UpdateBankBagButtonVisuals()
    self:UpdateLayout()
end

function BankFrame:ToggleBankBagPreview(bagID)
    if not IsValidBankBagID(bagID) then return end
    if selectedBankBagID == bagID then
        self:SetBankBagFilter(nil)
    else
        self:SetBankBagFilter(bagID)
    end
end

function BankFrame:UpdateBankBagButtonIcons()
    if not bankFrame or not bankFrame.header or not bankFrame.header.bagButtons then
        return
    end
    local numPurchased = (GetNumBankSlots and GetNumBankSlots()) or 0
    for _, bagID in ipairs(BANK_BAG_IDS) do
        local btn = bankFrame.header.bagButtons[bagID]
        if btn and btn.icon then
            btn.icon:SetTexture(GetBankBagIconTexture(bagID))
            local slotIndex = BankBagSlotIndex(bagID)
            local slots = GetContainerNumSlots(bagID) or 0
            local purchased = slotIndex <= numPurchased
            if btn.icon.SetVertexColor then
                if not purchased then
                    btn.icon:SetVertexColor(1, 0.15, 0.15)
                else
                    btn.icon:SetVertexColor(1, 1, 1)
                end
            end
            if btn.icon.SetDesaturated then
                local emptySocket = purchased and slots <= 0
                if not purchased or emptySocket then
                    btn.icon:SetDesaturated(1)
                else
                    btn.icon:SetDesaturated(0)
                end
            end
        end
    end
end

function BankFrame:UpdateBankBagButtonVisuals()
    if not bankFrame or not bankFrame.header or not bankFrame.header.bagButtons then
        return
    end
    for _, bagID in ipairs(BANK_BAG_IDS) do
        local btn = bankFrame.header.bagButtons[bagID]
        if btn then
            local r, g, b = 0.4, 0.4, 0.4
            if selectedBankBagID == bagID then
                r, g, b = 0.2, 0.8, 0.2
            end
            if btn.borderTop then btn.borderTop:SetVertexColor(r, g, b, 1) end
            if btn.borderBottom then btn.borderBottom:SetVertexColor(r, g, b, 1) end
            if btn.borderLeft then btn.borderLeft:SetVertexColor(r, g, b, 1) end
            if btn.borderRight then btn.borderRight:SetVertexColor(r, g, b, 1) end
        end
    end
end

function BankFrame:EquipBankBagFromCursor(bagID)
    if bagID == -1 then
        if ClearCursor then ClearCursor() end
        return
    end
    if not IsValidBankBagID(bagID) then
        if ClearCursor then ClearCursor() end
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        print("|cFF00FF00OmniInventory|r: Cannot change bank bags during combat.")
        return
    end
    if not (CursorHasItem and CursorHasItem()) then
        return
    end
    local inv = ContainerIDToInventoryID and ContainerIDToInventoryID(bagID)
    if not inv or not PutItemInBag then
        return
    end
    PutItemInBag(inv)
end

local function CanBankSlotAcceptItem(bagID, itemFamily)
    local numFree, bagType = GetContainerNumFreeSlots(bagID)
    if not numFree or numFree <= 0 then
        return false
    end
    bagType = bagType or 0
    if bagType == 0 then
        return true
    end
    if not itemFamily or itemFamily == 0 then
        return false
    end
    if bit and bit.band then
        return bit.band(itemFamily, bagType) > 0
    end
    return true
end

local function FindFirstOpenBankSlotExcluding(excludedBagID, itemFamily)
    for _, bid in ipairs(BANK_BAG_IDS) do
        if bid ~= excludedBagID and CanBankSlotAcceptItem(bid, itemFamily) then
            local slots = GetContainerNumSlots(bid) or 0
            for slotID = 1, slots do
                local texture = GetContainerItemInfo(bid, slotID)
                if not texture then
                    return bid, slotID
                end
            end
        end
    end
    return nil, nil
end

local function StopBankForceEmptyJob()
    if bankForceEmptyFrame then
        bankForceEmptyFrame:SetScript("OnUpdate", nil)
        bankForceEmptyFrame:SetScript("OnEvent", nil)
        bankForceEmptyFrame:UnregisterEvent("BAG_UPDATE")
        bankForceEmptyFrame:UnregisterEvent("ITEM_LOCK_CHANGED")
        bankForceEmptyFrame:UnregisterEvent("PLAYERBANKSLOTS_CHANGED")
    end
    bankForceEmptyJob = nil
end

local function FinishBankForceEmptyJob()
    if not bankForceEmptyJob then
        return
    end
    print(string.format(
        "|cFF00FF00OmniInventory|r: Bank clear bag %s moved %d, blocked %d.",
        tostring(bankForceEmptyJob.sourceBagID),
        bankForceEmptyJob.movedCount,
        bankForceEmptyJob.blockedCount
    ))
    StopBankForceEmptyJob()
    if BankFrame and BankFrame.UpdateLayout then
        BankFrame:UpdateLayout()
    end
end

local function RunBankForceEmptyStep()
    if not bankForceEmptyJob then
        return
    end
    if #bankForceEmptyJob.slots == 0 then
        FinishBankForceEmptyJob()
        return
    end
    local source = bankForceEmptyJob.sourceBagID
    local entry = table.remove(bankForceEmptyJob.slots, 1)
    local slotID = entry.slotID
    local attempts = entry.attempts or 0

    local texture, _, isLocked = GetContainerItemInfo(source, slotID)
    if not texture then
        return
    end
    if isLocked then
        attempts = attempts + 1
        if attempts >= BANK_FORCE_EMPTY_MAX_LOCK then
            bankForceEmptyJob.blockedCount = bankForceEmptyJob.blockedCount + 1
        else
            entry.attempts = attempts
            table.insert(bankForceEmptyJob.slots, entry)
        end
        return
    end
    local itemLink = GetContainerItemLink(source, slotID)
    local fam = (itemLink and GetItemFamily(itemLink)) or 0
    local tBag, tSlot = FindFirstOpenBankSlotExcluding(source, fam)
    if not tBag or not tSlot then
        bankForceEmptyJob.blockedCount = bankForceEmptyJob.blockedCount + 1
        return
    end
    if PickupContainerItem then
        PickupContainerItem(source, slotID)
    end
    if CursorHasItem and CursorHasItem() and PickupContainerItem then
        PickupContainerItem(tBag, tSlot)
    end
    if CursorHasItem and CursorHasItem() and ClearCursor then
        ClearCursor()
        attempts = attempts + 1
        if attempts >= BANK_FORCE_EMPTY_MAX_MOVE then
            bankForceEmptyJob.blockedCount = bankForceEmptyJob.blockedCount + 1
        else
            entry.attempts = attempts
            table.insert(bankForceEmptyJob.slots, entry)
        end
    else
        bankForceEmptyJob.movedCount = bankForceEmptyJob.movedCount + 1
        bankForceEmptyJob.awaitingEvent = true
        bankForceEmptyJob.awaitElapsed = 0
    end
end

function BankFrame:ForceEmptyBankBag(sourceBagID)
    if not IsValidBankBagID(sourceBagID) then return end
    if CursorHasItem and CursorHasItem() then
        print("|cFF00FF00OmniInventory|r: Clear cursor before force-empty.")
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        print("|cFF00FF00OmniInventory|r: Bank force-empty is unavailable during combat.")
        return
    end
    local sourceSlots = GetContainerNumSlots(sourceBagID) or 0
    if sourceSlots <= 0 then
        print("|cFF00FF00OmniInventory|r: That bank space has no slots.")
        return
    end
    local slots = {}
    for s = 1, sourceSlots do
        local tex = GetContainerItemInfo(sourceBagID, s)
        if tex then
            table.insert(slots, { slotID = s, attempts = 0 })
        end
    end
    if #slots == 0 then
        print("|cFF00FF00OmniInventory|r: Already empty.")
        return
    end
    if bankForceEmptyJob then
        StopBankForceEmptyJob()
    end
    bankForceEmptyJob = {
        sourceBagID = sourceBagID,
        slots = slots,
        movedCount = 0,
        blockedCount = 0,
        awaitingEvent = false,
        awaitElapsed = 0,
    }
    bankForceEmptyFrame = bankForceEmptyFrame or CreateFrame("Frame")
    bankForceEmptyFrame:RegisterEvent("BAG_UPDATE")
    bankForceEmptyFrame:RegisterEvent("ITEM_LOCK_CHANGED")
    bankForceEmptyFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    bankForceEmptyFrame:SetScript("OnEvent", function(_, event, arg1)
        if not bankForceEmptyJob then
            return
        end
        if event == "BAG_UPDATE" and arg1 ~= nil then
            if arg1 ~= bankForceEmptyJob.sourceBagID then
                bankForceEmptyJob.awaitingEvent = false
            end
            return
        end
        bankForceEmptyJob.awaitingEvent = false
    end)
    bankForceEmptyFrame:SetScript("OnUpdate", function(self, elapsed)
        if not bankForceEmptyJob then
            return
        end
        if bankForceEmptyJob.awaitingEvent then
            bankForceEmptyJob.awaitElapsed = bankForceEmptyJob.awaitElapsed + (elapsed or 0)
            if bankForceEmptyJob.awaitElapsed < BANK_FORCE_EMPTY_EVENT_TIMEOUT then
                return
            end
            bankForceEmptyJob.awaitingEvent = false
        end
        if CursorHasItem and CursorHasItem() then
            return
        end
        if InCombatLockdown and InCombatLockdown() then
            StopBankForceEmptyJob()
            return
        end
        RunBankForceEmptyStep()
    end)
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

    local hInset = 8
    local usableWidth = bankFrame.content:GetWidth() - 20
    local itemScale = GetSharedItemScale()
    local itemGap = GetSharedItemGap()
    local itemSize = ITEM_SIZE * itemScale
    local itemStep = itemSize + itemGap
    local sectionHeaderHeight = 20
    local sectionSpacing = 8
    local dualCategoryLanes = true
    local laneGap = 10

    local function columnsForLaneWidth(laneW)
        local inner = laneW - itemGap
        local c = math.floor(inner / itemStep)
        return math.max(c, 1)
    end

    local yLeft = -itemGap
    local yRight = -itemGap
    local yOffset = -itemGap
    local renderedSectionCount = 0

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
            renderedSectionCount = renderedSectionCount + 1

            local laneX, laneY, columns
            if dualCategoryLanes then
                local laneW = (usableWidth - laneGap) * 0.5
                local edgePad = hInset * 0.5
                local leftX = edgePad + itemGap
                local rightX = edgePad + laneW + laneGap + itemGap
                local useRight = (renderedSectionCount % 2 == 0)
                laneX = useRight and rightX or leftX
                laneY = useRight and yRight or yLeft
                columns = columnsForLaneWidth(laneW)
            else
                laneX = itemGap
                laneY = yOffset
                columns = columnsForLaneWidth(usableWidth)
            end

            headerIndex = headerIndex + 1
            local header = categoryHeaders[headerIndex]
            if not header then
                header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                categoryHeaders[headerIndex] = header
            end

            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", laneX, laneY)

            local r, g, b = 1, 1, 1
            if Omni.Categorizer then
                r, g, b = Omni.Categorizer:GetCategoryColor(catName)
            end
            header:SetTextColor(r, g, b)
            header:SetText(catName .. " (" .. #catItems .. ")")
            header:Show()

            laneY = laneY - sectionHeaderHeight

            for i, itemInfo in ipairs(catItems) do
                local btn
                if Omni.Pool then
                    btn = Omni.Pool:Acquire("ItemButton")
                elseif Omni.ItemButton then
                    btn = Omni.ItemButton:Create(scrollChild)
                end

                if btn then
                    local col = ((i - 1) % columns)
                    local row = math.floor((i - 1) / columns)
                    local x = laneX + col * itemStep
                    local y = laneY - row * itemStep

                    local container = GetBankItemContainer(itemInfo.bagID or -1) or scrollChild
                    pcall(function()
                        if btn:GetParent() ~= container then
                            btn:SetParent(container)
                        end
                        ApplyBankItemMetrics(btn, itemSize)
                        btn:ClearAllPoints()
                        btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", x, y)
                    end)

                    local ok = pcall(function()
                        SetButtonItem(btn, itemInfo)
                        btn:Show()
                    end)
                    if not ok then
                        pcall(SetButtonItem, btn, nil)
                        if btn.icon then btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
                        pcall(btn.Show, btn)
                    end

                    table.insert(itemButtons, btn)
                end
            end

            local catRows = math.ceil(#catItems / columns)
            laneY = laneY - (catRows * itemStep) - sectionSpacing

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

    local bottomY = dualCategoryLanes and math.min(yLeft, yRight) or yOffset
    scrollChild:SetHeight(math.abs(bottomY) + itemGap)
end

function BankFrame:UpdateLayout()
    local perfTotal = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("bank.UpdateLayout.total")
    if not bankFrame or not bankFrame:IsShown() then return end

    -- ʕ •ᴥ•ʔ✿ Defer secure-button churn to PLAYER_REGEN_ENABLED ✿ ʕ •ᴥ•ʔ
    if InCombatLockdown and InCombatLockdown() then
        return
    end

    self:UpdateBankBagButtonIcons()
    self:UpdateBankBagButtonVisuals()

    local items = CollectBankItems()
    local perfRender = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("bank.UpdateLayout.renderFlow")
    self:RenderFlowView(items)
    if Omni._perfEnabled and Omni.Perf then
        Omni.Perf:End("bank.UpdateLayout.renderFlow", perfRender, { itemCount = #items })
    end
    self:UpdateSlotCount()

    if searchText and searchText ~= "" then
        local perfSearch = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("bank.UpdateLayout.search")
        self:ApplySearch(searchText)
        if Omni._perfEnabled and Omni.Perf then
            Omni.Perf:End("bank.UpdateLayout.search", perfSearch)
        end
    end
    if Omni._perfEnabled and Omni.Perf then
        Omni.Perf:End("bank.UpdateLayout.total", perfTotal, { itemCount = #items })
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
    local perfToken = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("bank.ApplySearch")
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
    local matchedButtons = 0
    for _, btn in ipairs(itemButtons) do
        local info = btn.itemInfo
        local isMatch = false
        if info and info.hyperlink then
            local name = info.__cachedName
            local lowerName = info.__cachedLowerName
            if not name then
                name = GetItemInfo(info.hyperlink)
                info.__cachedName = name
            end
            if name and not lowerName then
                lowerName = string.lower(name)
                info.__cachedLowerName = lowerName
            end
            if lowerName and string.find(lowerName, lowerSearch, 1, true) then
                isMatch = true
            end
        end
        if Omni.ItemButton then
            Omni.ItemButton:SetSearchMatch(btn, isMatch)
        end
        if isMatch then
            matchedButtons = matchedButtons + 1
        end
    end
    if Omni._perfEnabled and Omni.Perf then
        Omni.Perf:End("bank.ApplySearch", perfToken, {
            queryLen = string.len(searchText or ""),
            visibleButtons = #itemButtons,
            matchedButtons = matchedButtons,
        })
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
    pcall(bankFrame.Show, bankFrame)
end

function BankFrame:Hide()
    if bankFrame then
        pcall(bankFrame.Hide, bankFrame)
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
