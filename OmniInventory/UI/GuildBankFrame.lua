-- =============================================================================
-- OmniInventory Guild Bank Frame
-- =============================================================================
-- ʕ •ᴥ•ʔ✿ Complete override of Blizzard's guild bank UI. Opens on
-- GUILDBANKFRAME_OPENED, closes on GUILDBANKFRAME_CLOSED. Renders tabs
-- as a column of icon buttons on the left and a 7x14 slot grid on the
-- right. Supports rename on right-click, tab purchase if guild master,
-- money deposit/withdraw, search dim, and one-click smart deposit of
-- BoE / account-attunable gear sorted by weapon/armor/jewelry. ✿ ʕ •ᴥ•ʔ
-- =============================================================================

local addonName, Omni = ...

Omni.GuildBankFrame = {}
local GuildBankFrame = Omni.GuildBankFrame

-- =============================================================================
-- Constants
-- =============================================================================

local MAX_TABS = 6
local SLOTS_PER_TAB = 98
local SLOTS_PER_ROW = 14
local ROWS_PER_TAB = 7

local SLOT_SIZE = 37
local SLOT_SPACING = 4
-- ʕ •ᴥ•ʔ✿ Tab strip matches main-bag footer mini-button size ✿ ʕ •ᴥ•ʔ
local FOOTER_TAB_BTN = 28
local TAB_TAB_GAP = 4
local TAB_COLUMN_WIDTH = FOOTER_TAB_BTN + 8
local TAB_SUMMARY_HEIGHT = 14

local PADDING = 8
local HEADER_HEIGHT = 24
local FOOTER_HEIGHT = 48
local SEARCH_HEIGHT = 22
local FOOTER_ICON_BTN_SIZE = 24
local FOOTER_ICON_BTN_GAP = 4
local FOOTER_SMART_ICON = "Interface\\Icons\\INV_Misc_Coin_01"
local FOOTER_BUYTAB_ICON = "Interface\\Icons\\INV_Misc_Coin_02"

local FRAME_WIDTH = TAB_COLUMN_WIDTH + 6 + (SLOTS_PER_ROW * (SLOT_SIZE + SLOT_SPACING))
                    + PADDING * 2 + 8
local FRAME_HEIGHT = HEADER_HEIGHT + SEARCH_HEIGHT + FOOTER_HEIGHT
                    + (ROWS_PER_TAB * (SLOT_SIZE + SLOT_SPACING))
                    + PADDING * 3 + 24 + TAB_SUMMARY_HEIGHT

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

local JEWELRY_EQUIP_SLOTS = {
    ["INVTYPE_FINGER"] = true,
    ["INVTYPE_NECK"] = true,
    ["INVTYPE_TRINKET"] = true,
}

local SMART_DEPOSIT_KEYS = {
    weapons = true,
    jewelry = true,
    armor_cloth = true,
    armor_leather = true,
    armor_mail = true,
    armor_plate = true,
    armor_misc = true,
    armor = true,
}

-- =============================================================================
-- State
-- =============================================================================

local frame = nil
local tabButtons = {}
local slotButtons = {}
local flowItemButtons = {}
local categoryHeadersFlow = {}
local currentTab = 1
local searchText = ""
local VIEW_FLOW = "flow"
local VIEW_GRID = "grid"

-- =============================================================================
-- Saved Variables
-- =============================================================================

local tabMappingStringsCoerced = false

local function GetDB()
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.char = OmniInventoryDB.char or {}
    OmniInventoryDB.char.guildBank = OmniInventoryDB.char.guildBank or {}
    OmniInventoryDB.char.guildBank.tabMappings = OmniInventoryDB.char.guildBank.tabMappings or {}
    if not tabMappingStringsCoerced then
        tabMappingStringsCoerced = true
        for tab, val in pairs(OmniInventoryDB.char.guildBank.tabMappings) do
            if type(val) == "string" and val ~= "" then
                OmniInventoryDB.char.guildBank.tabMappings[tab] = { [val] = true }
            end
        end
    end
    if not OmniInventoryDB.char.guildBank.viewMode then
        OmniInventoryDB.char.guildBank.viewMode = VIEW_FLOW
    end
    return OmniInventoryDB.char.guildBank
end

local function GetViewMode()
    local m = GetDB().viewMode
    if m == VIEW_GRID then return VIEW_GRID end
    return VIEW_FLOW
end

local function SetViewMode(mode)
    GetDB().viewMode = (mode == VIEW_GRID) and VIEW_GRID or VIEW_FLOW
end

local function GetTabMappings()
    return GetDB().tabMappings
end

-- ʕ •ᴥ•ʔ✿ set table: [categoryKey] = true; multiple keys per tab ✿ ʕ •ᴥ•ʔ
local function GetTabSet(tab)
    local m = GetTabMappings()
    if not m then return nil end
    local s = m[tab]
    if not s then return nil end
    if type(s) == "string" and s ~= "" then
        return { [s] = true }
    end
    if type(s) == "table" then
        return s
    end
    return nil
end

function GuildBankFrame:TabSetDescribesCategory(set, category)
    if not set or not category then return false end
    if set[category] then
        return true
    end
    if set["armor"] and string.find(category, "^armor_") then
        return true
    end
    return false
end

function GuildBankFrame:ToggleTabCategoryMapping(tab, categoryKey)
    if not tab or not categoryKey then
        return
    end
    if not SMART_DEPOSIT_KEYS[categoryKey] then
        return
    end
    local mappings = GetTabMappings()
    local nextSet = {}
    local cur = GetTabSet(tab)
    if cur then
        for k, v in pairs(cur) do
            if v then
                nextSet[k] = true
            end
        end
    end
    if nextSet[categoryKey] then
        nextSet[categoryKey] = nil
    else
        nextSet[categoryKey] = true
    end
    if not next(nextSet) then
        mappings[tab] = nil
    else
        mappings[tab] = nextSet
    end
    GuildBankFrame:UpdateTabs()
end

function GuildBankFrame:ClearTabCategoryMappings(tab)
    GetTabMappings()[tab] = nil
    self:UpdateTabs()
end

local function GetTabForCategory(category)
    for tab = 1, MAX_TABS do
        if GuildBankFrame:TabSetDescribesCategory(GetTabSet(tab), category) then
            return tab
        end
    end
    return nil
end

local guildBankIconFilenameList = nil

local function BuildGuildBankIconFilenameList()
    local list = {}
    list[1] = "INV_MISC_QUESTIONMARK"
    if GetMacroItemIcons then
        GetMacroItemIcons(list)
    end
    if GetMacroIcons then
        GetMacroIcons(list)
    end
    return list
end

local function GetGuildBankIconFilenameList()
    if not guildBankIconFilenameList then
        guildBankIconFilenameList = BuildGuildBankIconFilenameList()
    end
    return guildBankIconFilenameList
end

local function GuildBankTabTextureToShortName(tex)
    if not tex or tex == "" then
        return "INV_MISC_QUESTIONMARK"
    end
    local u = strupper(tex)
    u = string.gsub(u, "INTERFACE/ICONS/", "")
    u = string.gsub(u, "INTERFACE\\ICONS\\", "")
    return u
end

local function GetGuildBankTabIconIndex(tabIndex)
    local _, tex = GetGuildBankTabInfo(tabIndex)
    local short = GuildBankTabTextureToShortName(tex)
    local list = GetGuildBankIconFilenameList()
    for i = 1, #list do
        if strupper(list[i]) == short then
            return i
        end
    end
    return 1
end

local setGuildBankTabInfoOriginal = nil

function GuildBankFrame:ResolveGuildBankIconFilenameToIndex(iconOrShort)
    if not iconOrShort or iconOrShort == "" then
        return 1
    end
    local want = GuildBankTabTextureToShortName(iconOrShort)
    if want == "" then
        want = "INV_MISC_QUESTIONMARK"
    end
    local list = GetGuildBankIconFilenameList()
    for i = 1, #list do
        if strupper(list[i]) == want then
            return i
        end
    end
    return 1
end

function GuildBankFrame:InstallSetGuildBankTabInfoShim()
    if setGuildBankTabInfoOriginal then
        return
    end
    local fn = _G.SetGuildBankTabInfo
    if type(fn) ~= "function" then
        return
    end
    setGuildBankTabInfoOriginal = fn
    _G.SetGuildBankTabInfo = function(tab, name, icon)
        local arg3 = icon
        if type(arg3) == "string" then
            arg3 = GuildBankFrame:ResolveGuildBankIconFilenameToIndex(arg3)
        end
        return setGuildBankTabInfoOriginal(tab, name, arg3)
    end
end

local function ApplyGuildBankTabRename(tabIndex, newName)
    if not tabIndex or not newName or newName == "" or not SetGuildBankTabInfo then
        return
    end
    local iconIndex = GetGuildBankTabIconIndex(tabIndex)
    local list = GetGuildBankIconFilenameList()
    local shortName = list[iconIndex] or "INV_MISC_QUESTIONMARK"
    if pcall(SetGuildBankTabInfo, tabIndex, newName, iconIndex) then
        return
    end
    pcall(SetGuildBankTabInfo, tabIndex, newName, shortName)
end

local function HasAnySmartDepositMapping()
    for _, v in pairs(GetTabMappings()) do
        if type(v) == "string" and SMART_DEPOSIT_KEYS[v] then
            return true
        end
        if type(v) == "table" and next(v) then
            for k, on in pairs(v) do
                if on and SMART_DEPOSIT_KEYS[k] then
                    return true
                end
            end
        end
    end
    return false
end

local function SavePosition()
    if not frame then return end
    local point, _, _, x, y = frame:GetPoint()
    local db = GetDB()
    db.position = {
        point = point or "CENTER",
        x = x or 0,
        y = y or 0,
        userMoved = frame.userMoved or false,
    }
end

local function LoadPosition()
    if not frame then return end
    local db = GetDB()
    local pos = db.position
    if pos and pos.userMoved then
        frame.userMoved = true
        frame:ClearAllPoints()
        frame:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER",
            pos.x or 0, pos.y or 0)
    end
end

-- =============================================================================
-- Item Categorization (Smart Deposit)
-- =============================================================================

local function ResolveItemLink(itemLink)
    if not itemLink then return nil end
    -- ʕ •ᴥ•ʔ✿ 3.3.5 order: type=6, subType=7, stack=8, equipLoc=9 ✿ ʕ •ᴥ•ʔ
    local _, _, quality, _, _, itemType, subType, _, equipSlot = GetItemInfo(itemLink)
    return itemType, equipSlot, quality, subType
end

local function GetBagBindType(bagID, slotID)
    local info = OmniC_Container and OmniC_Container.GetContainerItemInfo(bagID, slotID)
    if info then
        return info.bindType, info.isAttunable, info.itemID, info.hyperlink
    end
    return nil, nil, nil, nil
end

local function IsAccountAttunableForAlt(itemID)
    if not itemID then return false end
    if _G.CanAttuneItemHelper and CanAttuneItemHelper(itemID) >= 1 then
        return false
    end
    if _G.IsAttunableBySomeone then
        local check = IsAttunableBySomeone(itemID)
        return check ~= nil and check ~= 0 and check ~= false
    end
    return false
end

local function CategorizeItemForDeposit(bagID, slotID)
    local bindType, isAttunable, itemID, itemLink = GetBagBindType(bagID, slotID)
    if not itemLink then return nil end

    local isBoE = bindType == "BoE"
    local isAccountBoE = isBoE and isAttunable and IsAccountAttunableForAlt(itemID)

    if not (isBoE or isAccountBoE) then
        return nil
    end

    local itemType, equipSlot, _, subType = ResolveItemLink(itemLink)
    if not itemType then return nil end

    if equipSlot and JEWELRY_EQUIP_SLOTS[equipSlot] then
        return "jewelry"
    end
    if itemType == "Weapon" then
        return "weapons"
    end
    if itemType == "Armor" then
        if subType == "Cloth" then return "armor_cloth" end
        if subType == "Leather" then return "armor_leather" end
        if subType == "Mail" then return "armor_mail" end
        if subType == "Plate" then return "armor_plate" end
        return "armor_misc"
    end
    return nil
end

-- =============================================================================
-- Tab Button (left column) — footer mini-button chrome, no solid overlay
-- =============================================================================

local function CountGuildBankTabFilledSlots(tabIndex)
    local used = 0
    for s = 1, SLOTS_PER_TAB do
        local tex = select(1, GetGuildBankItemInfo(tabIndex, s))
        if tex and tex ~= "" then
            used = used + 1
        end
    end
    return used
end

local function ApplyTabButtonBorder(btn, r, g, b, a)
    if btn.SetBackdropBorderColor then
        btn:SetBackdropBorderColor(r, g, b, a or 1)
    end
end

local function CreateTabButton(parent, index)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(FOOTER_TAB_BTN, FOOTER_TAB_BTN)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn.tabIndex = index

    btn:SetBackdrop({
        edgeFile = "Interface\\Buttons\\UI-Quickslot-Depress",
        edgeSize = 2,
        insets = { left = -1, right = -1, top = -1, bottom = -1 },
    })
    ApplyTabButtonBorder(btn, 0.4, 0.4, 0.4, 0.6)

    local iconPath = "Interface\\Icons\\INV_Misc_QuestionMark"
    btn:SetNormalTexture(iconPath)
    local normal = btn:GetNormalTexture()
    if normal and normal.SetTexCoord then
        normal:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlightTex = hl
    hl:SetAllPoints()
    hl:SetTexture(iconPath)
    hl:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    hl:SetBlendMode("ADD")
    hl:SetVertexColor(0.25, 0.25, 0.25, 0.35)

    btn.number = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.number:SetPoint("TOPRIGHT", -1, -1)

    btn.mapTag = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.mapTag:SetPoint("TOPLEFT", 1, -1)

    btn:SetScript("OnMouseDown", function(self)
        local tex = self:GetNormalTexture()
        if tex then tex:SetVertexColor(0.75, 0.75, 0.75) end
    end)
    btn:SetScript("OnMouseUp", function(self)
        local tex = self:GetNormalTexture()
        if tex then tex:SetVertexColor(1, 1, 1) end
    end)

    btn:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            GuildBankFrame:ShowTabContextMenu(self.tabIndex)
        else
            GuildBankFrame:SelectTab(self.tabIndex)
        end
    end)

    btn:SetScript("OnEnter", function(self)
        if not self._gbTabSelected then
            ApplyTabButtonBorder(self, 0.9, 0.8, 0.2, 1)
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local name, _, isViewable, canDeposit, numWith, remainWith =
            GetGuildBankTabInfo(self.tabIndex)
        GameTooltip:AddLine((name and name ~= "") and name or ("Tab " .. self.tabIndex), 1, 1, 1)
        if isViewable == nil or isViewable == 0 then
            GameTooltip:AddLine("Not viewable", 1, 0.3, 0.3)
        else
            if canDeposit and canDeposit ~= 0 then
                GameTooltip:AddLine("Deposit: allowed", 0.3, 1, 0.3)
            else
                GameTooltip:AddLine("Deposit: denied", 1, 0.5, 0.5)
            end
            if numWith and numWith ~= -1 then
                GameTooltip:AddLine(string.format("Withdrawals today: %d/%d",
                    (numWith or 0) - (remainWith or 0), numWith or 0), 0.8, 0.8, 0.8)
            end
        end
        local set = GetTabSet(self.tabIndex)
        if set and next(set) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Smart deposit categories:", 0.7, 0.85, 0.9)
            local list = {}
            for k, on in pairs(set) do
                if on and SMART_DEPOSIT_KEYS[k] then
                    table.insert(list, k)
                end
            end
            table.sort(list)
            for _, k in ipairs(list) do
                GameTooltip:AddLine("  |cFF00FFAA" .. k .. "|r", 0.9, 0.95, 0.9)
            end
        end
        if isViewable and isViewable ~= 0 then
            local u = self._gbSlotsUsed or 0
            local t = self._gbSlotsTotal or SLOTS_PER_TAB
            local f = t - u
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(string.format("Slots: %d / %d used (%d free)", u, t, f),
                0.75, 0.78, 0.76)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click: view  |  Right-click: menu", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        if self._gbTabSelected then
            ApplyTabButtonBorder(self, 0.0, 1.0, 0.65, 1)
        else
            ApplyTabButtonBorder(self, 0.4, 0.4, 0.4, 0.6)
        end
    end)

    return btn
end

local function UpdateTabButtonAppearance(btn, index)
    local _, icon, isViewable = GetGuildBankTabInfo(index)
    local viewOK = not (isViewable == 0 or isViewable == false or isViewable == nil)
    local used, total = 0, SLOTS_PER_TAB
    if viewOK then
        used = CountGuildBankTabFilledSlots(index)
    end
    btn._gbSlotsUsed = used
    btn._gbSlotsTotal = total
    btn._gbSlotsFree = total - used

    local texPath = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    btn:SetNormalTexture(texPath)
    local normal = btn:GetNormalTexture()
    if normal and normal.SetTexCoord then
        normal:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    if btn.highlightTex then
        btn.highlightTex:SetTexture(texPath)
        btn.highlightTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    btn.number:SetText(tostring(index))

    local sel = (index == currentTab)
    btn._gbTabSelected = sel
    if sel then
        ApplyTabButtonBorder(btn, 0.0, 1.0, 0.65, 1)
    else
        ApplyTabButtonBorder(btn, 0.4, 0.4, 0.4, 0.6)
    end

    local desat = not viewOK
    if normal and normal.SetDesaturated then
        if desat then
            normal:SetDesaturated(1)
        else
            normal:SetDesaturated(0)
        end
    end

    local set = GetTabSet(index)
    if set and next(set) then
        local function oneTag(k)
            return (k == "weapons" and "W")
                or (k == "jewelry" and "J")
                or (k == "armor_cloth" and "c")
                or (k == "armor_leather" and "L")
                or (k == "armor_mail" and "M")
                or (k == "armor_plate" and "P")
                or (k == "armor_misc" and "m")
                or (k == "armor" and "A")
                or "?"
        end
        local keys = {}
        for k, on in pairs(set) do
            if on and SMART_DEPOSIT_KEYS[k] then
                table.insert(keys, k)
            end
        end
        table.sort(keys)
        local str = ""
        for i = 1, #keys do
            if i > 4 then
                str = str .. "+"
                break
            end
            str = str .. oneTag(keys[i])
        end
        btn.mapTag:SetText(str ~= "" and str or "?")
        btn.mapTag:Show()
    else
        btn.mapTag:Hide()
    end
end

-- =============================================================================
-- Slot Button (grid + flow); gbTab / gbSlot override current tab for flow layout
-- =============================================================================

local GB_ATTUNE_BAR = 6
local GB_RESIST_FALLBACK = "Interface\\Icons\\Spell_Holy_MagicalSentry"

local function EnsureGuildSlotDecorationFrames(btn)
    if btn.attuneBarBG then return end

    btn.attuneBarBG = btn:CreateTexture(nil, "OVERLAY")
    btn.attuneBarBG:SetTexture("Interface\\Buttons\\WHITE8X8")
    btn.attuneBarBG:SetVertexColor(0, 0, 0, 1)
    btn.attuneBarBG:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 2)
    btn.attuneBarBG:SetWidth(GB_ATTUNE_BAR + 2)
    btn.attuneBarBG:SetHeight(0)
    btn.attuneBarBG:Hide()

    btn.attuneBarFill = btn:CreateTexture(nil, "OVERLAY")
    btn.attuneBarFill:SetTexture("Interface\\Buttons\\WHITE8X8")
    btn.attuneBarFill:SetPoint("BOTTOMLEFT", btn.attuneBarBG, "BOTTOMLEFT", 1, 1)
    btn.attuneBarFill:SetWidth(GB_ATTUNE_BAR)
    btn.attuneBarFill:SetHeight(0)
    btn.attuneBarFill:Hide()

    btn.attuneText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.attuneText:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
    btn.attuneText:Hide()

    btn.bountyIcon = btn:CreateTexture(nil, "OVERLAY")
    btn.bountyIcon:SetTexture("Interface/MoneyFrame/UI-GoldIcon")
    btn.bountyIcon:SetSize(16, 16)
    btn.bountyIcon:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -2)
    btn.bountyIcon:Hide()

    btn.accountIcon = btn:CreateTexture(nil, "OVERLAY")
    btn.accountIcon:SetTexture("Interface\\Buttons\\WHITE8X8")
    btn.accountIcon:SetVertexColor(0.3, 0.7, 1.0, 0.8)
    btn.accountIcon:SetSize(8, 8)
    btn.accountIcon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
    btn.accountIcon:Hide()

    btn.resistIcon = btn:CreateTexture(nil, "OVERLAY")
    btn.resistIcon:SetTexture(GB_RESIST_FALLBACK)
    btn.resistIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.resistIcon:SetSize(16, 16)
    btn.resistIcon:SetPoint("TOP", btn, "TOP", 0, -2)
    btn.resistIcon:Hide()

    btn.forgeText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.forgeText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    btn.forgeText:SetJustifyH("RIGHT")
    btn.forgeText:Hide()
end

-- ʕ •ᴥ•ʔ✿ RegisterForClicks("RightButtonUp") passes "RightButtonUp" — must match
-- ItemButton.lua (NormalizeMouseButton) or the RightButton branch never runs. ✿ ʕ •ᴥ•ʔ
local function NormalizeGuildBankMouseButton(mouseButton)
    if mouseButton == "LeftButtonUp" or mouseButton == "LeftButtonDown" or mouseButton == "LeftButton" then
        return "LeftButton"
    end
    if mouseButton == "RightButtonUp" or mouseButton == "RightButtonDown" or mouseButton == "RightButton" then
        return "RightButton"
    end
    return mouseButton
end

-- ʕ •ᴥ•ʔ✿ Guild item buttons: same order as Blizzard_GuildBankUI (GuildBankItemButtonTemplate
-- OnClick). Right = AutoStoreGuildBankItem (withdraw to bags / deposit from cursor). ✿ ʕ •ᴥ•ʔ
local function GuildBankSlot_ResolveTarget(self)
    local bankTab = (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or (self.gbTab or currentTab)
    local bankSlot
    if self.GetID and self:GetID() and self:GetID() > 0 then
        bankSlot = self:GetID()
    else
        bankSlot = self.gbSlot or self.slotIndex
    end
    return bankTab, bankSlot
end

local function GuildBankSlotOnClick(self, mouseButton)
    mouseButton = NormalizeGuildBankMouseButton(mouseButton) or mouseButton
    if not mouseButton then
        return
    end

    local bankTab, bankSlot = GuildBankSlot_ResolveTarget(self)
    local itemLink = GetGuildBankItemLink and GetGuildBankItemLink(bankTab, bankSlot) or nil
    if HandleModifiedItemClick and itemLink and HandleModifiedItemClick(itemLink) then
        return
    end

    if IsModifiedClick and IsModifiedClick("SPLITSTACK") then
        local _tex, count, locked = GetGuildBankItemInfo(bankTab, bankSlot)
        if count and count > 1 and not locked then
            self.SplitStack = function(btn, splitCount)
                if not SplitGuildBankItem then
                    return
                end
                local t = (GetCurrentGuildBankTab and GetCurrentGuildBankTab()) or bankTab
                local s = (btn.GetID and btn:GetID() and btn:GetID() > 0) and btn:GetID() or bankSlot
                SplitGuildBankItem(t, s, splitCount)
            end
            OpenStackSplitFrame(count, self, "BOTTOMLEFT", "TOPLEFT")
        end
        return
    end

    local cType, cMoney
    if GetCursorInfo then
        cType, cMoney = GetCursorInfo()
    end
    if cType == "money" and cMoney and DepositGuildBankMoney and ClearCursor then
        DepositGuildBankMoney(cMoney)
        ClearCursor()
        return
    end
    if cType == "guildbankmoney" and DropCursorMoney and ClearCursor then
        DropCursorMoney()
        ClearCursor()
        return
    end

    if mouseButton == "RightButton" and AutoStoreGuildBankItem then
        AutoStoreGuildBankItem(bankTab, bankSlot)
        if GuildBankFrame and GuildBankFrame.UpdateLayout then
            GuildBankFrame:UpdateLayout()
        end
        return
    end
    if mouseButton == "LeftButton" and PickupGuildBankItem then
        PickupGuildBankItem(bankTab, bankSlot)
    end
end

local function CreateSlotButton(parent, slotIndex)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(SLOT_SIZE, SLOT_SIZE)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn.slotIndex = slotIndex

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    btn.bg:SetVertexColor(0.1, 0.1, 0.1, 1)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 2, -2)
    btn.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    btn.count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    btn.count:SetPoint("BOTTOMRIGHT", -2, 2)

    btn.borderTop = btn:CreateTexture(nil, "OVERLAY")
    btn.borderTop:SetTexture("Interface\\Buttons\\WHITE8X8")
    btn.borderTop:SetHeight(1)
    btn.borderTop:SetPoint("TOPLEFT", 0, 0)
    btn.borderTop:SetPoint("TOPRIGHT", 0, 0)

    btn.borderBottom = btn:CreateTexture(nil, "OVERLAY")
    btn.borderBottom:SetTexture("Interface\\Buttons\\WHITE8X8")
    btn.borderBottom:SetHeight(1)
    btn.borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    btn.borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)

    btn.borderLeft = btn:CreateTexture(nil, "OVERLAY")
    btn.borderLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
    btn.borderLeft:SetWidth(1)
    btn.borderLeft:SetPoint("TOPLEFT", 0, 0)
    btn.borderLeft:SetPoint("BOTTOMLEFT", 0, 0)

    btn.borderRight = btn:CreateTexture(nil, "OVERLAY")
    btn.borderRight:SetTexture("Interface\\Buttons\\WHITE8X8")
    btn.borderRight:SetWidth(1)
    btn.borderRight:SetPoint("TOPRIGHT", 0, 0)
    btn.borderRight:SetPoint("BOTTOMRIGHT", 0, 0)

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetAllPoints()
    btn.highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
    btn.highlight:SetVertexColor(1, 1, 1, 0.18)

    btn.dimOverlay = btn:CreateTexture(nil, "OVERLAY", nil, 7)
    btn.dimOverlay:SetAllPoints(btn.icon)
    btn.dimOverlay:SetTexture("Interface\\Buttons\\WHITE8X8")
    btn.dimOverlay:SetVertexColor(0, 0, 0, 0.7)
    btn.dimOverlay:Hide()

    btn:SetScript("OnClick", GuildBankSlotOnClick)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local t = self.gbTab or currentTab
        local s = self.gbSlot or self.slotIndex
        GameTooltip:SetGuildBankItem(t, s)
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if ResetCursor then ResetCursor() end
    end)

    btn:SetScript("OnReceiveDrag", function(self)
        local t = self.gbTab or currentTab
        local s = self.gbSlot or self.slotIndex
        if PickupGuildBankItem then
            PickupGuildBankItem(t, s)
        end
    end)

    btn:SetScript("OnDragStart", function(self)
        local t = self.gbTab or currentTab
        local s = self.gbSlot or self.slotIndex
        if PickupGuildBankItem then
            PickupGuildBankItem(t, s)
        end
    end)

    btn:RegisterForDrag("LeftButton")
    return btn
end

local function UpdateGuildBankSlotVisual(btn, tab, slot)
    local texture, count, locked = GetGuildBankItemInfo(tab, slot)
    local link = GetGuildBankItemLink(tab, slot)

    if texture and texture ~= "" then
        btn.icon:SetTexture(texture)
        btn.icon:Show()
    else
        btn.icon:SetTexture(nil)
    end

    if count and count > 1 then
        btn.count:SetText(tostring(count))
        btn.count:Show()
    else
        btn.count:SetText("")
        btn.count:Hide()
    end

    local quality = 1
    if link then
        local _, _, q = GetItemInfo(link)
        if q then quality = q end
    end
    local color = QUALITY_COLORS[quality] or QUALITY_COLORS[1]
    local r, g, b = color[1], color[2], color[3]
    if not texture or texture == "" then
        r, g, b = 0.3, 0.3, 0.3
    end
    btn.borderTop:SetVertexColor(r, g, b, 1)
    btn.borderBottom:SetVertexColor(r, g, b, 1)
    btn.borderLeft:SetVertexColor(r, g, b, 1)
    btn.borderRight:SetVertexColor(r, g, b, 1)

    if locked then
        btn.icon:SetDesaturated(true)
    else
        btn.icon:SetDesaturated(false)
    end

    if searchText ~= "" and link then
        local name = GetItemInfo(link)
        if name and string.find(string.lower(name), string.lower(searchText), 1, true) then
            btn.dimOverlay:Hide()
            btn.icon:SetAlpha(1)
        else
            btn.dimOverlay:Show()
            btn.icon:SetAlpha(0.5)
        end
    else
        btn.dimOverlay:Hide()
        btn.icon:SetAlpha(1)
    end

    EnsureGuildSlotDecorationFrames(btn)
    if not texture or texture == "" then
        if Omni.ItemButton and Omni.ItemButton.UpdateGuildBankSlotDecorations then
            Omni.ItemButton:UpdateGuildBankSlotDecorations(btn, {})
        end
        return
    end

    local itemID
    if link and Omni.API then
        itemID = Omni.API:GetIdFromLink(link)
    end
    if not itemID and link then
        itemID = tonumber(string.match(link, "item:(%d+)"))
    end

    local isBound, bindType = true, "BoP"
    if link and Omni.API and Omni.API.GetBindingFromHyperlink then
        isBound, bindType = Omni.API:GetBindingFromHyperlink(link)
    end

    local isAttunable = false
    if itemID and _G.IsAttunableBySomeone then
        local check = IsAttunableBySomeone(itemID)
        isAttunable = check ~= nil and check ~= 0 and check ~= false
    end

    local itemInfo = {
        hyperlink = link,
        itemID = itemID,
        bindType = bindType,
        isBound = isBound,
        isAttunable = isAttunable,
    }

    if Omni.ItemButton and Omni.ItemButton.UpdateGuildBankSlotDecorations then
        Omni.ItemButton:UpdateGuildBankSlotDecorations(btn, itemInfo)
    end
end

local function UpdateSlotButton(btn)
    btn.gbTab = currentTab
    btn.gbSlot = btn.slotIndex
    if btn.SetID and btn.gbSlot then
        btn:SetID(btn.gbSlot)
    end
    UpdateGuildBankSlotVisual(btn, currentTab, btn.slotIndex)
end

-- =============================================================================
-- Header / Search / Footer
-- =============================================================================

local function CreateHeader(parent)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", PADDING, -PADDING)
    header:SetPoint("TOPRIGHT", -PADDING, -PADDING)

    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()
    header.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    header.bg:SetVertexColor(0.14, 0.14, 0.14, 1)

    header.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.title:SetPoint("LEFT", 6, 0)
    header.title:SetText("|cFF00FFAAOmni|r Guild Bank")

    header.guildName = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header.guildName:SetPoint("LEFT", header.title, "RIGHT", 8, 0)
    header.guildName:SetTextColor(0.7, 0.7, 0.7)

    header.closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    header.closeBtn:SetSize(20, 20)
    header.closeBtn:SetPoint("RIGHT", -2, 0)

    header.viewModeBtn = CreateFrame("Button", nil, header)
    header.viewModeBtn:SetSize(72, 20)
    header.viewModeBtn:SetPoint("RIGHT", header.closeBtn, "LEFT", -4, 0)
    header.viewModeBtn:SetBackdrop({
        edgeFile = "Interface\\Buttons\\UI-Quickslot-Depress",
        edgeSize = 2,
        insets = { left = -1, right = -1, top = -1, bottom = -1 },
    })
    header.viewModeBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
    header.viewModeBtn.icon = header.viewModeBtn:CreateTexture(nil, "ARTWORK")
    header.viewModeBtn.icon:SetSize(14, 14)
    header.viewModeBtn.icon:SetPoint("LEFT", 4, 0)
    header.viewModeBtn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    header.viewModeBtn.text = header.viewModeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header.viewModeBtn.text:SetPoint("LEFT", header.viewModeBtn.icon, "RIGHT", 3, 0)
    header.viewModeBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.9, 0.8, 0.2, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("View: Flow / Grid", 1, 1, 1)
        GameTooltip:AddLine("Flow: categories like the main bag. Grid: 7×14 bank layout.", 0.75, 0.75, 0.75, true)
        GameTooltip:Show()
    end)
    header.viewModeBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
        GameTooltip:Hide()
    end)
    header.viewModeBtn:SetScript("OnClick", function()
        local nextMode = (GetViewMode() == VIEW_FLOW) and VIEW_GRID or VIEW_FLOW
        SetViewMode(nextMode)
        GuildBankFrame:SyncViewModeLabel()
        GuildBankFrame:UpdateLayout()
    end)

    header.closeBtn:SetScript("OnClick", function()
        if CloseGuildBankFrame then CloseGuildBankFrame() end
        GuildBankFrame:Hide()
    end)

    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() parent:StartMoving() end)
    header:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
        parent.userMoved = true
        SavePosition()
    end)

    parent.header = header
end

local function CreateSearchBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(SEARCH_HEIGHT)
    bar:SetPoint("TOPLEFT", parent.header, "BOTTOMLEFT", 0, -4)
    bar:SetPoint("TOPRIGHT", parent.header, "BOTTOMRIGHT", 0, -4)

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bar.bg:SetVertexColor(0.1, 0.1, 0.1, 1)

    bar.icon = bar:CreateTexture(nil, "ARTWORK")
    bar.icon:SetSize(14, 14)
    bar.icon:SetPoint("LEFT", 6, 0)
    bar.icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")

    bar.editBox = CreateFrame("EditBox", "OmniGuildBankSearchBox", bar)
    bar.editBox:SetPoint("LEFT", bar.icon, "RIGHT", 4, 0)
    bar.editBox:SetPoint("RIGHT", -6, 0)
    bar.editBox:SetHeight(18)
    bar.editBox:SetAutoFocus(false)
    bar.editBox:SetFontObject(ChatFontNormal)
    bar.editBox:SetTextColor(1, 1, 1, 1)
    bar.editBox:SetTextInsets(2, 2, 0, 0)

    bar.editBox:SetScript("OnTextChanged", function(self)
        searchText = self:GetText() or ""
        GuildBankFrame:RefreshItemArea()
    end)
    bar.editBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    parent.searchBar = bar
end

local function StyleFooterRibbonButton(btn)
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
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(self._tooltipTitle, 1, 1, 1)
            if self._tooltipSub then
                GameTooltip:AddLine(self._tooltipSub, 0.8, 0.8, 0.8, true)
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

local function CreateFooterIconButton(parent, iconTexture, tooltipTitle, tooltipSub, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(FOOTER_ICON_BTN_SIZE, FOOTER_ICON_BTN_SIZE)
    StyleFooterRibbonButton(btn)

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

local function CreateFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetHeight(FOOTER_HEIGHT)
    footer:SetPoint("BOTTOMLEFT", PADDING, PADDING)
    footer:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)

    footer.bg = footer:CreateTexture(nil, "BACKGROUND")
    footer.bg:SetAllPoints()
    footer.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    footer.bg:SetVertexColor(0.12, 0.12, 0.12, 1)

    footer.moneyBtn = CreateFrame("Button", nil, footer)
    footer.moneyBtn:SetSize(260, 24)
    footer.moneyBtn:SetPoint("TOPLEFT", 6, -4)
    footer.moneyBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    StyleFooterRibbonButton(footer.moneyBtn)
    footer.moneyBtn._tooltipTitle = "Guild Funds"
    footer.moneyBtn._tooltipSub = "Left-click: withdraw | Right-click: deposit"
    footer.moneyBtn:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            StaticPopup_Show("OMNI_GUILDBANK_DEPOSIT_MONEY")
        else
            StaticPopup_Show("OMNI_GUILDBANK_WITHDRAW_MONEY")
        end
    end)
    footer.moneyBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.22, 0.22, 0.22, 1)
        self:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:AddLine("Guild Funds", 1, 1, 1)
        GameTooltip:AddLine((self._moneyText and self._moneyText ~= "") and self._moneyText or "0", 1, 0.85, 0.25)
        if self._withdrawText and self._withdrawText ~= "" then
            GameTooltip:AddLine(self._withdrawText, 0.75, 0.75, 0.75)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click: Withdraw", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: Deposit", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    footer.moneyBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.12, 0.12, 0.12, 1)
        self:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
        GameTooltip:Hide()
    end)

    footer.moneyIcon = footer.moneyBtn:CreateTexture(nil, "ARTWORK")
    footer.moneyIcon:SetSize(16, 16)
    footer.moneyIcon:SetPoint("LEFT", 6, 0)
    footer.moneyIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue")

    footer.money = footer.moneyBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    footer.money:SetPoint("LEFT", footer.moneyIcon, "RIGHT", 5, 0)
    footer.money:SetJustifyH("LEFT")
    footer.money:SetText("0")

    footer.withdrawLimit = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footer.withdrawLimit:SetPoint("TOPLEFT", footer.moneyBtn, "BOTTOMLEFT", 2, -2)
    footer.withdrawLimit:SetTextColor(0.76, 0.76, 0.76)
    footer.withdrawLimit:SetText("Withdraw: 0")

    footer.smartDepositBtn = CreateFooterIconButton(
        footer,
        FOOTER_SMART_ICON,
        "Smart Deposit BoEs",
        "Moves BoE + account-attunable gear using tab mapping.",
        function()
        GuildBankFrame:RunSmartDeposit()
    end)
    footer.smartDepositBtn:SetPoint("RIGHT", footer, "RIGHT", -6, 0)

    footer.buyTabBtn = CreateFooterIconButton(
        footer,
        FOOTER_BUYTAB_ICON,
        "Buy Next Guild Tab",
        "Guild leaders can purchase the next tab.",
        function()
        StaticPopup_Show("OMNI_GUILDBANK_BUY_TAB")
    end)
    footer.buyTabBtn:SetPoint("RIGHT", footer.smartDepositBtn, "LEFT", -FOOTER_ICON_BTN_GAP, 0)
    footer.buyTabBtn:Hide()

    parent.footer = footer
end

-- =============================================================================
-- Flow view (categorized like main bag) + view toggle
-- =============================================================================

local function CollectGuildBankTabItems(tab)
    local items = {}
    for slot = 1, SLOTS_PER_TAB do
        local tex, count, locked = GetGuildBankItemInfo(tab, slot)
        if tex and tex ~= "" then
            local link = GetGuildBankItemLink(tab, slot)
            local itemID
            if link and Omni.API then
                itemID = Omni.API:GetIdFromLink(link)
            elseif link then
                itemID = tonumber(string.match(link, "item:(%d+)"))
            end
            local quality = 1
            if link then
                local _, _, q = GetItemInfo(link)
                if q then quality = q end
            end
            local isBound, bindType = true, "BoP"
            if link and Omni.API and Omni.API.GetBindingFromHyperlink then
                isBound, bindType = Omni.API:GetBindingFromHyperlink(link)
            end
            local isAttunable = false
            if itemID and _G.IsAttunableBySomeone then
                local check = IsAttunableBySomeone(itemID)
                isAttunable = check ~= nil and check ~= 0 and check ~= false
            end
            local item = {
                iconFileID = tex,
                stackCount = math.max(1, tonumber(count) or 1),
                isLocked = locked,
                quality = quality,
                hyperlink = link,
                itemID = itemID,
                bindType = bindType,
                isBound = isBound,
                isAttunable = isAttunable,
                guildBankTab = tab,
                guildBankSlot = slot,
            }
            if Omni.Categorizer then
                item.category = Omni.Categorizer:GetCategory(item)
            end
            table.insert(items, item)
        end
    end
    if Omni.Sorter then
        items = Omni.Sorter:Sort(items, Omni.Sorter:GetDefaultMode())
    end
    return items
end

function GuildBankFrame:SyncViewModeLabel()
    if not frame or not frame.header or not frame.header.viewModeBtn then return end
    local mode = GetViewMode()
    frame.header.viewModeBtn.text:SetText(mode == VIEW_GRID and "Grid" or "Flow")
    local ic = frame.header.viewModeBtn.icon
    if ic and ic.SetTexture then
        if mode == VIEW_GRID then
            ic:SetTexture("Interface\\Icons\\INV_Misc_Gear_08")
        else
            ic:SetTexture("Interface\\Icons\\INV_Scroll_05")
        end
        ic:Show()
    end
end

function GuildBankFrame:RenderFlowView(items)
    if not frame or not frame.flowChild or not frame.flowScroll then return end

    local scrollChild = frame.flowChild
    local usableWidth = (frame.flowScroll:GetWidth() or 1) - 8
    if usableWidth < 120 then
        usableWidth = math.max(120, (frame.rightPanel and frame.rightPanel:GetWidth() or 300) - 8)
    end
    scrollChild:SetWidth(usableWidth)

    for _, h in ipairs(categoryHeadersFlow) do
        h:Hide()
    end

    local ITEM_SIZE = SLOT_SIZE
    local ITEM_SPACING = SLOT_SPACING
    local hInset = 8
    local sectionHeaderHeight = 20
    local sectionSpacing = 8
    local dualCategoryLanes = true
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
    local flowBtnCount = 0

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

            headerIndex = headerIndex + 1
            local header = categoryHeadersFlow[headerIndex]
            if not header then
                header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                categoryHeadersFlow[headerIndex] = header
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
                flowBtnCount = flowBtnCount + 1
                local btn = flowItemButtons[flowBtnCount]
                if not btn then
                    btn = CreateSlotButton(scrollChild, flowBtnCount)
                    flowItemButtons[flowBtnCount] = btn
                end
                btn.gbTab = itemInfo.guildBankTab
                btn.gbSlot = itemInfo.guildBankSlot
                if btn.SetID and itemInfo.guildBankSlot then
                    btn:SetID(itemInfo.guildBankSlot)
                end
                UpdateGuildBankSlotVisual(btn, itemInfo.guildBankTab, itemInfo.guildBankSlot)

                local col = ((i - 1) % columns)
                local row = math.floor((i - 1) / columns)
                local x = laneX + col * (ITEM_SIZE + ITEM_SPACING)
                local y = laneY - row * (ITEM_SIZE + ITEM_SPACING)
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", x, y)
                btn:Show()
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

    for i = flowBtnCount + 1, #flowItemButtons do
        flowItemButtons[i]:Hide()
    end

    local bottomY = dualCategoryLanes and math.min(yLeft, yRight) or yOffset
    scrollChild:SetHeight(math.max(1, math.abs(bottomY) + ITEM_SPACING))
end

function GuildBankFrame:RefreshItemArea()
    if not frame then return end
    if GetViewMode() == VIEW_GRID then
        if frame.gridContainer then frame.gridContainer:Show() end
        if frame.flowScroll then frame.flowScroll:Hide() end
        self:UpdateSlots()
    else
        if frame.gridContainer then frame.gridContainer:Hide() end
        if frame.flowScroll then frame.flowScroll:Show() end
        local items = CollectGuildBankTabItems(currentTab)
        self:RenderFlowView(items)
    end
end

-- =============================================================================
-- Main Frame
-- =============================================================================

function GuildBankFrame:CreateMainFrame()
    if frame then return frame end

    frame = CreateFrame("Frame", "OmniInventoryGuildBankFrame", UIParent)
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(120)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.05, 0.09, 0.08, 0.95)
    frame:SetBackdropBorderColor(0.3, 0.55, 0.45, 1)

    local scale = OmniInventoryDB and OmniInventoryDB.char
        and OmniInventoryDB.char.settings and OmniInventoryDB.char.settings.scale
    frame:SetScale(scale or 1)

    tinsert(UISpecialFrames, "OmniInventoryGuildBankFrame")

    CreateHeader(frame)
    CreateSearchBar(frame)
    CreateFooter(frame)

    frame.tabColumn = CreateFrame("Frame", nil, frame)
    frame.tabColumn:SetPoint("TOPLEFT", frame.searchBar, "BOTTOMLEFT", 0, -PADDING)
    frame.tabColumn:SetPoint("BOTTOMLEFT", frame.footer, "TOPLEFT", 0, PADDING)
    frame.tabColumn:SetWidth(TAB_COLUMN_WIDTH)

    frame.rightPanel = CreateFrame("Frame", nil, frame)
    frame.rightPanel:SetPoint("TOPLEFT", frame.tabColumn, "TOPRIGHT", 6, 0)
    frame.rightPanel:SetPoint("BOTTOMRIGHT", frame.footer, "TOPRIGHT", 0, PADDING)

    frame.rightPanelBottom = CreateFrame("Frame", nil, frame.rightPanel)
    frame.rightPanelBottom:SetHeight(TAB_SUMMARY_HEIGHT)
    frame.rightPanelBottom:SetPoint("BOTTOMLEFT", frame.rightPanel, "BOTTOMLEFT", 0, 0)
    frame.rightPanelBottom:SetPoint("BOTTOMRIGHT", frame.rightPanel, "BOTTOMRIGHT", 0, 0)
    frame.rightPanelBottom.bg = frame.rightPanelBottom:CreateTexture(nil, "BACKGROUND")
    frame.rightPanelBottom.bg:SetAllPoints()
    frame.rightPanelBottom.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.rightPanelBottom.bg:SetVertexColor(0.06, 0.08, 0.07, 0.92)

    frame.tabSlotSummary = frame.rightPanelBottom:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.tabSlotSummary:SetPoint("BOTTOMLEFT", 6, 2)
    frame.tabSlotSummary:SetPoint("BOTTOMRIGHT", frame.rightPanelBottom, "BOTTOMRIGHT", -6, 2)
    frame.tabSlotSummary:SetJustifyH("LEFT")
    frame.tabSlotSummary:SetTextColor(0.78, 0.84, 0.8, 1)

    frame.gridContainer = CreateFrame("Frame", nil, frame.rightPanel)
    frame.gridContainer:SetPoint("TOPLEFT", frame.rightPanel, "TOPLEFT", 0, 0)
    frame.gridContainer:SetPoint("BOTTOMRIGHT", frame.rightPanelBottom, "TOPRIGHT", 0, 0)

    frame.flowScroll = CreateFrame("ScrollFrame", "OmniGuildBankFlowScroll", frame.rightPanel, "UIPanelScrollFrameTemplate")
    frame.flowScroll:SetPoint("TOPLEFT", frame.rightPanel, "TOPLEFT", 0, 0)
    frame.flowScroll:SetPoint("BOTTOMRIGHT", frame.rightPanelBottom, "TOPRIGHT", 0, 0)
    local flowSb = _G["OmniGuildBankFlowScrollScrollBar"]
    if flowSb then
        flowSb:ClearAllPoints()
        flowSb:Hide()
        flowSb:SetScript("OnShow", function(sb)
            sb:Hide()
        end)
    end
    local flowSbBd = _G["OmniGuildBankFlowScrollScrollBarBackdrop"]
    if flowSbBd and flowSbBd.Hide then
        flowSbBd:Hide()
    end

    frame.flowChild = CreateFrame("Frame", "OmniGuildBankFlowChild", frame.flowScroll)
    frame.flowChild:SetSize(100, 1)
    frame.flowScroll:SetScrollChild(frame.flowChild)
    frame.flowScroll:Hide()

    local tabStride = FOOTER_TAB_BTN + TAB_TAB_GAP
    for i = 1, MAX_TABS do
        local btn = CreateTabButton(frame.tabColumn, i)
        btn:SetPoint("TOP", frame.tabColumn, "TOP", 0, -((i - 1) * tabStride))
        tabButtons[i] = btn
    end

    for i = 1, SLOTS_PER_TAB do
        local col = (i - 1) % SLOTS_PER_ROW
        local row = math.floor((i - 1) / SLOTS_PER_ROW)
        local btn = CreateSlotButton(frame.gridContainer, i)
        btn:SetPoint("TOPLEFT", frame.gridContainer, "TOPLEFT",
            col * (SLOT_SIZE + SLOT_SPACING),
            -(row * (SLOT_SIZE + SLOT_SPACING)))
        slotButtons[i] = btn
    end

    frame.infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.infoText:SetPoint("TOPLEFT", frame.rightPanel, "BOTTOMLEFT", 2, -4)
    frame.infoText:SetPoint("TOPRIGHT", frame.rightPanel, "BOTTOMRIGHT", -2, -4)
    frame.infoText:SetJustifyH("LEFT")
    frame.infoText:SetTextColor(0.8, 0.8, 0.6)
    frame.infoText:SetHeight(12)

    frame:Hide()

    GuildBankFrame:SyncViewModeLabel()

    frame:SetScript("OnShow", function()
        GuildBankFrame:UpdateLayout()
    end)

    frame:SetScript("OnHide", function()
        if CloseGuildBankFrame then CloseGuildBankFrame() end
    end)

    return frame
end

-- =============================================================================
-- Update / Layout
-- =============================================================================

function GuildBankFrame:SelectTab(index)
    local numTabs = GetNumGuildBankTabs() or 0
    if index < 1 or index > numTabs then return end
    currentTab = index
    if SetCurrentGuildBankTab then SetCurrentGuildBankTab(index) end
    if QueryGuildBankTab then QueryGuildBankTab(index) end
    if QueryGuildBankText then QueryGuildBankText(index) end
    self:UpdateLayout()
end

function GuildBankFrame:UpdateTabs()
    local numTabs = GetNumGuildBankTabs() or 0
    for i = 1, MAX_TABS do
        local btn = tabButtons[i]
        if btn then
            if i <= numTabs then
                UpdateTabButtonAppearance(btn, i)
                btn:Show()
            else
                btn:Hide()
            end
        end
    end
end

function GuildBankFrame:UpdateSlots()
    for i = 1, SLOTS_PER_TAB do
        local btn = slotButtons[i]
        if btn then UpdateSlotButton(btn) end
    end
end

function GuildBankFrame:UpdateMoney()
    if not frame or not frame.footer then return end
    local money = GetGuildBankMoney and GetGuildBankMoney() or 0
    local withdraw = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
    local moneyText = GetCoinTextureString(money)
    frame.footer.money:SetText(moneyText)
    frame.footer.moneyBtn._moneyText = moneyText
    if withdraw == -1 then
        frame.footer.withdrawLimit:SetText("Withdraw: |cFFFFD700Unlimited|r")
        frame.footer.moneyBtn._withdrawText = "Withdraw: Unlimited"
    else
        local withdrawText = GetCoinTextureString(withdraw)
        frame.footer.withdrawLimit:SetText("Withdraw: " .. withdrawText)
        frame.footer.moneyBtn._withdrawText = "Withdraw: " .. withdrawText
    end
end

function GuildBankFrame:UpdateInfoText()
    if not frame or not frame.infoText then return end
    local text = (GetGuildBankText and GetGuildBankText(currentTab)) or ""
    if text == "" then
        frame.infoText:SetText("")
    else
        frame.infoText:SetText(text)
    end
end

function GuildBankFrame:UpdateBuyButton()
    if not frame or not frame.footer then return end
    local btn = frame.footer.buyTabBtn
    if not btn then return end
    local numTabs = GetNumGuildBankTabs() or 0
    local isLeader = IsGuildLeader and IsGuildLeader() or false
    if isLeader and numTabs < MAX_TABS then
        btn._tooltipTitle = string.format("Buy Tab %d", numTabs + 1)
        btn:Show()
    else
        btn:Hide()
    end
end

function GuildBankFrame:UpdateGuildName()
    if not frame or not frame.header then return end
    local name = GetGuildInfo and GetGuildInfo("player") or nil
    frame.header.guildName:SetText(name and ("<" .. name .. ">") or "")
end

function GuildBankFrame:UpdateLayout()
    if not frame or not frame:IsShown() then return end
    self:SyncViewModeLabel()
    self:UpdateGuildName()
    self:UpdateTabs()
    self:UpdateCurrentTabSlotSummary()
    self:UpdateMoney()
    self:UpdateInfoText()
    self:UpdateBuyButton()
    self:RefreshItemArea()
end

function GuildBankFrame:UpdateCurrentTabSlotSummary()
    if not frame or not frame.tabSlotSummary then return end
    local numTabs = GetNumGuildBankTabs() or 0
    if currentTab < 1 or currentTab > numTabs then
        frame.tabSlotSummary:SetText("")
        return
    end
    local name, _, isViewable = GetGuildBankTabInfo(currentTab)
    local viewOK = not (isViewable == 0 or isViewable == false or isViewable == nil)
    local label = (name and name ~= "") and name or ("Tab " .. currentTab)
    if not viewOK then
        frame.tabSlotSummary:SetText(label .. "  (not viewable)")
        return
    end
    local used = CountGuildBankTabFilledSlots(currentTab)
    frame.tabSlotSummary:SetText(string.format("%s   %d / %d", label, used, SLOTS_PER_TAB))
end

function GuildBankFrame:OpenBlizzardTabEditPopup(tabIndex)
    if not tabIndex then return end
    if IsAddOnLoaded and not IsAddOnLoaded("Blizzard_GuildBankUI") then
        pcall(LoadAddOn, "Blizzard_GuildBankUI")
    end
    self:SelectTab(tabIndex)
    if SetCurrentGuildBankTab then
        SetCurrentGuildBankTab(tabIndex)
    end
    local popup = _G.GuildBankPopupFrame
    if not popup or not popup.Show then
        print("|cFFFF4040Omni Guild Bank:|r Blizzard tab editor (GuildBankPopupFrame) is not loaded.")
        return
    end
    popup:SetParent(UIParent)
    popup:SetFrameStrata("DIALOG")
    local host = self:GetFrame()
    if host and host.IsShown and host:IsShown() then
        popup:SetFrameLevel((host.GetFrameLevel and host:GetFrameLevel() or 120) + 25)
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", host, "TOPRIGHT", 14, -40)
    else
        popup:ClearAllPoints()
        popup:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    end
    popup:Show()
end

-- =============================================================================
-- Smart Deposit
-- =============================================================================

function GuildBankFrame:RunSmartDeposit()
    if not HasAnySmartDepositMapping() then
        print("|cFFFF4040Omni Guild Bank:|r No tab rules set. Right-click a tab and turn on at least one smart deposit type.")
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        print("|cFFFF4040Omni Guild Bank:|r Cannot deposit during combat.")
        return
    end

    local pending = {}
    for bagID = 0, 4 do
        local numSlots = GetContainerNumSlots(bagID) or 0
        for slotID = 1, numSlots do
            local link = GetContainerItemLink(bagID, slotID)
            if link then
                local category = CategorizeItemForDeposit(bagID, slotID)
                if category then
                    local targetTab = GetTabForCategory(category)
                    if targetTab then
                        table.insert(pending, {
                            bag = bagID, slot = slotID,
                            tab = targetTab,
                            category = category,
                        })
                    end
                end
            end
        end
    end

    if #pending == 0 then
        print("|cFF00FFAAOmni Guild Bank:|r No eligible BoE gear to deposit.")
        return
    end

    local index = 1
    local depositCount = 0
    local depositFrame = CreateFrame("Frame")
    depositFrame.elapsed = 0
    depositFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + (elapsed or 0)
        if self.elapsed < 0.12 then return end
        self.elapsed = 0

        if CursorHasItem and CursorHasItem() then return end
        if InCombatLockdown and InCombatLockdown() then
            self:SetScript("OnUpdate", nil)
            return
        end

        local entry = pending[index]
        if not entry then
            self:SetScript("OnUpdate", nil)
            print(string.format("|cFF00FFAAOmni Guild Bank:|r Smart deposit finished (%d items moved).", depositCount))
            return
        end
        index = index + 1

        if not GetContainerItemLink(entry.bag, entry.slot) then
            return
        end

        local emptySlot
        for slot = 1, SLOTS_PER_TAB do
            local tex = GetGuildBankItemInfo(entry.tab, slot)
            if not tex or tex == "" then
                emptySlot = slot
                break
            end
        end
        if not emptySlot then
            return
        end

        if PickupContainerItem then
            PickupContainerItem(entry.bag, entry.slot)
        end
        if CursorHasItem and CursorHasItem() then
            if PickupGuildBankItem then
                PickupGuildBankItem(entry.tab, emptySlot)
            end
            if CursorHasItem and CursorHasItem() and ClearCursor then
                ClearCursor()
            else
                depositCount = depositCount + 1
            end
        end
    end)
end

-- =============================================================================
-- Tab Context Menu (right-click)
-- =============================================================================

local contextMenu = nil

local function EnsureContextMenu()
    if contextMenu then return contextMenu end
    contextMenu = CreateFrame("Frame", "OmniGuildBankTabMenu", UIParent, "UIDropDownMenuTemplate")
    return contextMenu
end

function GuildBankFrame:ShowTabContextMenu(tabIndex)
    EnsureContextMenu()

    local isLeader = IsGuildLeader and IsGuildLeader() and true or false
    local canEditInfo = isLeader
    if CanEditGuildTabInfo then
        local ok, res = pcall(CanEditGuildTabInfo, tabIndex)
        if ok and res then
            canEditInfo = true
        end
    end

    local snap = GetTabSet(tabIndex) or {}

    local menu = {
        {
            text = "Tab " .. tabIndex,
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Rename (name only)...",
            notCheckable = true,
            disabled = not canEditInfo,
            func = function()
                local dialog = StaticPopup_Show("OMNI_GUILDBANK_RENAME_TAB", tabIndex)
                if dialog then dialog.tabIndex = tabIndex end
            end,
        },
        {
            text = "Edit Name & Icon (Blizzard)...",
            notCheckable = true,
            disabled = not canEditInfo,
            func = function()
                GuildBankFrame:OpenBlizzardTabEditPopup(tabIndex)
            end,
        },
        {
            text = "Edit Info Text...",
            notCheckable = true,
            disabled = not canEditInfo,
            func = function()
                local dialog = StaticPopup_Show("OMNI_GUILDBANK_EDIT_INFO", tabIndex)
                if dialog then dialog.tabIndex = tabIndex end
            end,
        },
        {
            text = "── Smart deposit (toggle each) ──",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "  Weapons (BoE gear)",
            checkable = true,
            keepShownOnClick = 1,
            checked = snap.weapons and true or false,
            func = function()
                GuildBankFrame:ToggleTabCategoryMapping(tabIndex, "weapons")
            end,
        },
        {
            text = "  Jewelry (rings, neck, trinkets)",
            checkable = true,
            keepShownOnClick = 1,
            checked = snap.jewelry and true or false,
            func = function()
                GuildBankFrame:ToggleTabCategoryMapping(tabIndex, "jewelry")
            end,
        },
        {
            text = "  All armor (any weight)",
            checkable = true,
            keepShownOnClick = 1,
            checked = snap.armor and true or false,
            func = function()
                GuildBankFrame:ToggleTabCategoryMapping(tabIndex, "armor")
            end,
        },
        {
            text = "  Armor: Cloth",
            checkable = true,
            keepShownOnClick = 1,
            checked = snap.armor_cloth and true or false,
            func = function()
                GuildBankFrame:ToggleTabCategoryMapping(tabIndex, "armor_cloth")
            end,
        },
        {
            text = "  Armor: Leather",
            checkable = true,
            keepShownOnClick = 1,
            checked = snap.armor_leather and true or false,
            func = function()
                GuildBankFrame:ToggleTabCategoryMapping(tabIndex, "armor_leather")
            end,
        },
        {
            text = "  Armor: Mail",
            checkable = true,
            keepShownOnClick = 1,
            checked = snap.armor_mail and true or false,
            func = function()
                GuildBankFrame:ToggleTabCategoryMapping(tabIndex, "armor_mail")
            end,
        },
        {
            text = "  Armor: Plate",
            checkable = true,
            keepShownOnClick = 1,
            checked = snap.armor_plate and true or false,
            func = function()
                GuildBankFrame:ToggleTabCategoryMapping(tabIndex, "armor_plate")
            end,
        },
        {
            text = "  Armor: Other / misc",
            checkable = true,
            keepShownOnClick = 1,
            checked = snap.armor_misc and true or false,
            func = function()
                GuildBankFrame:ToggleTabCategoryMapping(tabIndex, "armor_misc")
            end,
        },
        {
            text = "  Clear all rules on this tab",
            notCheckable = true,
            func = function()
                GuildBankFrame:ClearTabCategoryMappings(tabIndex)
            end,
        },
        {
            text = "Cancel",
            notCheckable = true,
            func = function() end,
        },
    }

    EasyMenu(menu, contextMenu, "cursor", 0, 0, "MENU")
end

-- =============================================================================
-- Static Popups
-- =============================================================================

StaticPopupDialogs["OMNI_GUILDBANK_RENAME_TAB"] = {
    text = "Rename Guild Bank Tab %d:",
    button1 = ACCEPT or "Accept",
    button2 = CANCEL or "Cancel",
    hasEditBox = 1,
    maxLetters = 20,
    timeout = 0,
    whileDead = 0,
    hideOnEscape = 1,
    OnShow = function(self, data)
        local tab = self.tabIndex or 1
        local name = GetGuildBankTabInfo(tab)
        self.editBox:SetText(name or "")
        self.editBox:HighlightText()
    end,
    OnAccept = function(self)
        local tab = self.tabIndex or 1
        local newName = self.editBox:GetText()
        if newName and newName ~= "" then
            ApplyGuildBankTabRename(tab, newName)
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local tab = parent.tabIndex or 1
        local newName = self:GetText()
        if newName and newName ~= "" then
            ApplyGuildBankTabRename(tab, newName)
        end
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
}

StaticPopupDialogs["OMNI_GUILDBANK_EDIT_INFO"] = {
    text = "Guild Bank Tab %d info text:",
    button1 = ACCEPT or "Accept",
    button2 = CANCEL or "Cancel",
    hasEditBox = 1,
    maxLetters = 500,
    editBoxWidth = 260,
    timeout = 0,
    whileDead = 0,
    hideOnEscape = 1,
    OnShow = function(self)
        local tab = self.tabIndex or 1
        self.editBox:SetText(GetGuildBankText and GetGuildBankText(tab) or "")
        self.editBox:HighlightText()
    end,
    OnAccept = function(self)
        local tab = self.tabIndex or 1
        if SetGuildBankText then
            SetGuildBankText(tab, self.editBox:GetText() or "")
        end
    end,
}

local GUILD_BANK_MAX_COPPER = 18446744073709551615

local function ClampGuildBankMoneyCopper(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return nil
    end
    if value <= 0 then
        return nil
    end
    if value > GUILD_BANK_MAX_COPPER then
        return GUILD_BANK_MAX_COPPER
    end
    return value
end

local function ParseGuildBankMoneyInputToCopper(raw)
    if not raw then return nil end
    local s = string.lower(string.gsub(string.gsub(tostring(raw), "^%s+", ""), "%s+$", ""))
    s = string.gsub(s, ",", "")
    if s == "" then return nil end

    local num, suf = string.match(s, "^([%d%.]+)%s*([kmgsc])$")
    if num and suf then
        local v = tonumber(num)
        if not v or v <= 0 then return nil end
        if suf == "c" then return ClampGuildBankMoneyCopper(math.floor(v + 0.5)) end
        if suf == "s" then return ClampGuildBankMoneyCopper(math.floor(v * 100 + 0.5)) end
        if suf == "g" then return ClampGuildBankMoneyCopper(math.floor(v * 10000 + 0.5)) end
        if suf == "k" then return ClampGuildBankMoneyCopper(math.floor(v * 1000 * 10000 + 0.5)) end
        if suf == "m" then return ClampGuildBankMoneyCopper(math.floor(v * 1000000 * 10000 + 0.5)) end
    end

    local total = 0
    local found = false
    for n, u in string.gmatch(s, "([%d%.]+)%s*([gsc])") do
        local v = tonumber(n)
        if v and v > 0 then
            if u == "g" then
                total = total + math.floor(v * 10000 + 0.5)
                found = true
            elseif u == "s" then
                total = total + math.floor(v * 100 + 0.5)
                found = true
            elseif u == "c" then
                total = total + math.floor(v + 0.5)
                found = true
            end
        end
    end
    if found and total > 0 then
        return ClampGuildBankMoneyCopper(math.floor(total))
    end

    local c = tonumber(s)
    if c and c > 0 then
        return ClampGuildBankMoneyCopper(math.floor(c + 0.5))
    end
    return nil
end

StaticPopupDialogs["OMNI_GUILDBANK_DEPOSIT_MONEY"] = {
    text = "Deposit amount (copper, or e.g. 50g, 5k, 12g34s):",
    button1 = ACCEPT or "Accept",
    button2 = CANCEL or "Cancel",
    hasEditBox = 1,
    maxLetters = 32,
    timeout = 0,
    whileDead = 0,
    hideOnEscape = 1,
    OnAccept = function(self)
        local amt = ParseGuildBankMoneyInputToCopper(self.editBox:GetText())
        if amt and amt > 0 and DepositGuildBankMoney then
            DepositGuildBankMoney(amt)
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local amt = ParseGuildBankMoneyInputToCopper(self:GetText())
        if amt and amt > 0 and DepositGuildBankMoney then
            DepositGuildBankMoney(amt)
            parent:Hide()
        end
    end,
}

StaticPopupDialogs["OMNI_GUILDBANK_WITHDRAW_MONEY"] = {
    text = "Withdraw amount (copper, or e.g. 50g, 5k, 12g34s):",
    button1 = ACCEPT or "Accept",
    button2 = CANCEL or "Cancel",
    hasEditBox = 1,
    maxLetters = 32,
    timeout = 0,
    whileDead = 0,
    hideOnEscape = 1,
    OnAccept = function(self)
        local amt = ParseGuildBankMoneyInputToCopper(self.editBox:GetText())
        if amt and amt > 0 and WithdrawGuildBankMoney then
            WithdrawGuildBankMoney(amt)
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local amt = ParseGuildBankMoneyInputToCopper(self:GetText())
        if amt and amt > 0 and WithdrawGuildBankMoney then
            WithdrawGuildBankMoney(amt)
            parent:Hide()
        end
    end,
}

StaticPopupDialogs["OMNI_GUILDBANK_BUY_TAB"] = {
    text = "Purchase the next guild bank tab?",
    button1 = ACCEPT or "Accept",
    button2 = CANCEL or "Cancel",
    timeout = 0,
    whileDead = 0,
    hideOnEscape = 1,
    OnAccept = function()
        if BuyGuildBankTab then BuyGuildBankTab() end
    end,
}

-- =============================================================================
-- Show / Hide / Toggle
-- =============================================================================

function GuildBankFrame:SyncBlizzardGuildBankProxy()
    local gb = _G.GuildBankFrame
    if not gb then return end
    pcall(gb.Show, gb)
end

function GuildBankFrame:QueryAllTabs()
    local numTabs = GetNumGuildBankTabs() or 0
    if not QueryGuildBankTab or numTabs <= 0 then return end
    for tab = 1, numTabs do
        QueryGuildBankTab(tab)
        if QueryGuildBankText then QueryGuildBankText(tab) end
    end
end

function GuildBankFrame:Show()
    if not frame then
        self:CreateMainFrame()
        LoadPosition()
    end
    local numTabs = GetNumGuildBankTabs() or 0
    if numTabs > 0 and currentTab > numTabs then
        currentTab = 1
    end
    if SetCurrentGuildBankTab and numTabs > 0 then
        SetCurrentGuildBankTab(currentTab)
    end
    self:QueryAllTabs()
    pcall(frame.Show, frame)
    self:SyncBlizzardGuildBankProxy()
end

function GuildBankFrame:Hide()
    if frame then
        pcall(frame.Hide, frame)
    end
end

function GuildBankFrame:Toggle()
    if frame and frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function GuildBankFrame:IsShown()
    return frame and frame:IsShown()
end

function GuildBankFrame:GetFrame()
    return frame
end

function GuildBankFrame:GetCurrentTab()
    return currentTab
end

function GuildBankFrame:Init()
    self:InstallSetGuildBankTabInfoShim()
end

print("|cFF00FF00OmniInventory|r: GuildBankFrame loaded")
