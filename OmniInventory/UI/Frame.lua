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
local ITEM_SCALE_MIN = 0.5
local ITEM_SCALE_MAX = 2.0
local ITEM_GAP_MIN = 0
local ITEM_GAP_MAX = 20
local DEFAULT_VIEW_MODE = "flow"
local BAG_ICON_SIZE = 18
local BAG_IDS = { 0, 1, 2, 3, 4 }

-- =============================================================================
-- Frame State
-- =============================================================================

local mainFrame = nil
-- ʕ •ᴥ•ʔ✿ Persistent slot-button map: slotButtons[bagID][slotID] = button.
-- Each button is created, parented to its bag's ItemContainer, and SetID
-- once out-of-combat. It is never reparented or renumbered again. During
-- combat we only mutate insecure state (alpha, icon, count), which keeps
-- every physical bag slot interactable even for items that appear while
-- PLAYER_REGEN_ENABLED is still pending. ✿ ʕ •ᴥ•ʔ
local slotButtons = {}
local itemButtons = {}  -- Flat list of populated slot buttons (search / cooldown)
local categoryHeaders = {}  -- Active category header FontStrings
local listRows = {}  -- Track list row frames
local currentView = DEFAULT_VIEW_MODE
local currentMode = "bags"
local isSearchActive = false
local searchText = ""
local selectedBagID = nil
-- ʕ •ᴥ•ʔ✿ Remembers the view mode the user was on before clicking a
-- bag icon forced bag view. ToggleBagPreview uses it to restore the
-- prior view (flow/grid/list) when the bag is unselected. ✿ ʕ •ᴥ•ʔ
local preBagViewMode = nil
local forceEmptyFrame = nil
local forceEmptyJob = nil
local FORCE_EMPTY_EVENT_TIMEOUT = 0.35
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
local burstRefreshFrame = nil
local burstRefreshElapsed = 0
local burstRefreshPending = false
local BURST_FULL_REFRESH_DELAY = 0.20
local FORCED_FULL_REFRESH_COOLDOWN = 0.20
local lastForcedFullRefreshAt = 0
local optimisticFlowRefreshFrame = nil
local optimisticFlowRefreshWatches = {}
local lastOptimisticFlowRefreshAt = 0
local OPTIMISTIC_FLOW_REFRESH_TIMEOUT = 0.75
local OPTIMISTIC_FLOW_REFRESH_SUPPRESS_WINDOW = 0.25
local flowLayoutCache = nil
local vendorFlowLayoutFreeze = nil
local wasMerchantOpen = false
local renderScratch = {
    categories = {},
    categoryOrder = {},
    touched = {},
    usedCategoryKeys = {},
    usedTouchedBags = {},
    headerByCategory = {},
}

local function ClearArray(t)
    for i = #t, 1, -1 do
        t[i] = nil
    end
end

local function ClearMap(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function IsMerchantOpen()
    return Omni and Omni._merchantOpen == true
end

local function HasBagChangeEntries(changedBags)
    if type(changedBags) ~= "table" then
        return false
    end
    for bagID in pairs(changedBags) do
        if type(bagID) == "number" then
            return true
        end
    end
    return false
end

local function StopBurstFullRefresh()
    burstRefreshPending = false
    burstRefreshElapsed = 0
    if burstRefreshFrame then
        burstRefreshFrame:SetScript("OnUpdate", nil)
    end
end

local function TryForceFullRefresh(reason)
    local now = (GetTime and GetTime()) or 0
    if now > 0 and lastForcedFullRefreshAt > 0 and (now - lastForcedFullRefreshAt) < FORCED_FULL_REFRESH_COOLDOWN then
        return false
    end
    lastForcedFullRefreshAt = now
    if Omni.Frame and Omni.Frame.UpdateLayout then
        Omni.Frame:UpdateLayout(nil, { forceFull = true, reason = reason or "forced_full" })
        return true
    end
    return false
end

local function RequestBurstFullRefresh()
    burstRefreshPending = true
    burstRefreshElapsed = 0

    if not burstRefreshFrame then
        burstRefreshFrame = CreateFrame("Frame")
    end

    burstRefreshFrame:SetScript("OnUpdate", function(self, elapsed)
        burstRefreshElapsed = burstRefreshElapsed + (elapsed or 0)
        if burstRefreshElapsed < BURST_FULL_REFRESH_DELAY then
            return
        end

        self:SetScript("OnUpdate", nil)
        burstRefreshPending = false
        burstRefreshElapsed = 0
        TryForceFullRefresh("burst_full")
    end)
end

local function BuildFlowCompositionSignature(categories, categoryOrder, usableWidth, itemStep, filterName)
    local parts = {
        tostring(math.floor((usableWidth or 0) + 0.5)),
        tostring(math.floor(((itemStep or 0) * 100) + 0.5)),
        tostring(filterName or "none"),
    }
    for _, catName in ipairs(categoryOrder or {}) do
        local count = categories and categories[catName] and #categories[catName] or 0
        parts[#parts + 1] = tostring(catName) .. ":" .. tostring(count)
    end
    return table.concat(parts, "|")
end

local function ItemRenderKey(itemInfo)
    if not itemInfo or itemInfo.__empty then
        return "empty"
    end
    return table.concat({
        tostring(itemInfo.itemID or 0),
        tostring(itemInfo.stackCount or 1),
        tostring(itemInfo.category or "Miscellaneous"),
        tostring(itemInfo.isQuickFiltered == true),
    }, ":")
end

local function BuildBagSlotStateKey(info)
    if not info then
        return "EMPTY"
    end

    return table.concat({
        tostring(info.itemID or 0),
        tostring(info.hyperlink or ""),
        tostring(info.stackCount or 0),
        tostring(info.iconFileID or ""),
    }, "\031")
end

local function GetBagSlotStateKey(bagID, slotID)
    if not OmniC_Container or not bagID or not slotID or bagID < 0 or slotID < 1 then
        return nil
    end

    return BuildBagSlotStateKey(OmniC_Container.GetContainerItemInfo(bagID, slotID))
end

local function DoesFlowSlotChangeRequireRelayout(previousInfo, nextInfo)
    if not previousInfo and not nextInfo then
        return false
    end

    if not previousInfo or not nextInfo then
        return true
    end

    if previousInfo.category ~= nextInfo.category then
        return true
    end

    if previousInfo.itemID ~= nextInfo.itemID then
        return true
    end

    if previousInfo.hyperlink ~= nextInfo.hyperlink then
        return true
    end

    if previousInfo.quality ~= nextInfo.quality then
        return true
    end

    return false
end

local function HasOptimisticFlowRefreshWatches()
    return next(optimisticFlowRefreshWatches) ~= nil
end

local function StopOptimisticFlowRefreshWatcher()
    optimisticFlowRefreshWatches = {}
    if optimisticFlowRefreshFrame then
        optimisticFlowRefreshFrame:SetScript("OnUpdate", nil)
    end
end

local function StartOptimisticFlowRefreshWatcher()
    if not optimisticFlowRefreshFrame then
        optimisticFlowRefreshFrame = CreateFrame("Frame")
    end

    optimisticFlowRefreshFrame:SetScript("OnUpdate", function(self, elapsed)
        if not mainFrame or not mainFrame:IsShown() or currentView ~= "flow" or InCombat() then
            StopOptimisticFlowRefreshWatcher()
            return
        end

        local slotChanged = false

        for watchKey, watch in pairs(optimisticFlowRefreshWatches) do
            watch.elapsed = (watch.elapsed or 0) + (elapsed or 0)
            if watch.elapsed >= OPTIMISTIC_FLOW_REFRESH_TIMEOUT then
                optimisticFlowRefreshWatches[watchKey] = nil
            else
                local waitingOnCursor = watch.waitForCursorClear
                    and CursorHasItem
                    and CursorHasItem()
                if not waitingOnCursor then
                    local currentKey = GetBagSlotStateKey(watch.bagID, watch.slotID)
                    if currentKey and currentKey ~= watch.stateKey then
                        slotChanged = true
                        break
                    end
                end
            end
        end

        if slotChanged then
            lastOptimisticFlowRefreshAt = (GetTime and GetTime()) or 0
            StopBurstFullRefresh()
            StopOptimisticFlowRefreshWatcher()
            TryForceFullRefresh("optimistic_flow")
            return
        end

        if not HasOptimisticFlowRefreshWatches() then
            self:SetScript("OnUpdate", nil)
        end
    end)
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

local function ApplyItemButtonMetrics(btn, itemScale)
    if not btn then return end
    local scale = math.max(ITEM_SCALE_MIN, math.min(itemScale or 1, ITEM_SCALE_MAX))
    local size = ITEM_SIZE * scale
    pcall(function()
        btn:SetScale(1)
        btn:SetSize(size, size)
        if btn.glow then
            btn.glow:SetSize(size * 1.5, size * 1.5)
        end
    end)
end

local function NormalizeViewMode(mode)
    if mode == "grid" or mode == "flow" or mode == "list" or mode == "bag" then
        return mode
    end
    return DEFAULT_VIEW_MODE
end

local function IsAttuneHelperEmbedEnabled()
    local global = OmniInventoryDB and OmniInventoryDB.global
    if global and global.attuneHelperEmbed == nil then
        global.attuneHelperEmbed = true
    end
    return not global or global.attuneHelperEmbed ~= false
end

local function IsAttuneHelperMiniNoBorderEnabled()
    local global = OmniInventoryDB and OmniInventoryDB.global
    if global and global.attuneHelperMiniNoBorder == nil then
        global.attuneHelperMiniNoBorder = false
    end
    return global and global.attuneHelperMiniNoBorder == true
end

local function ApplyEmbeddedMiniBorderStyle(miniFrame)
    if not miniFrame then return end
    if not miniFrame.SetBackdropBorderColor then return end

    if IsAttuneHelperMiniNoBorderEnabled() then
        miniFrame:SetBackdropBorderColor(0, 0, 0, 0)
    else
        miniFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    end
end

-- ʕ •ᴥ•ʔ✿ Rebind drag-drop on embedded mini buttons so cursor items feed
-- AHSet / AHIgnore directly via AH.*, bypassing the hidden main frame. ✿ ʕ •ᴥ•ʔ
local function GetAttuneHelperAddon()
    local ah = _G.AH
    if type(ah) == "table" then
        return ah
    end
    -- Fallback: _G.AttuneHelper is clobbered to the main frame, so reject
    -- frame-like handles and only accept the real addon table.
    local legacy = _G.AttuneHelper
    if type(legacy) == "table" and type(legacy.AddCursorItemToAHSet) == "function" then
        return legacy
    end
    return nil
end

local function RebindEmbeddedDragHandlers()
    local AH = GetAttuneHelperAddon()

    local equipBtn = _G.AttuneHelperMiniEquipButton
    if equipBtn and not equipBtn.__OmniEmbedDragFixed then
        equipBtn.__OmniEmbedDragFixed = true
        equipBtn:SetScript("OnReceiveDrag", function()
            local addon = GetAttuneHelperAddon()
            if addon and addon.AddCursorItemToAHSet then
                addon.AddCursorItemToAHSet()
            elseif _G.EquipAllButton and _G.EquipAllButton:GetScript("OnReceiveDrag") then
                _G.EquipAllButton:GetScript("OnReceiveDrag")()
            end
        end)
    end

    local vendorBtn = _G.AttuneHelperMiniVendorButton
    if vendorBtn and not vendorBtn.__OmniEmbedDragFixed then
        vendorBtn.__OmniEmbedDragFixed = true
        vendorBtn:SetScript("OnReceiveDrag", function(self)
            local addon = GetAttuneHelperAddon()
            if addon and addon.AddCursorItemToIgnore then
                addon.AddCursorItemToIgnore()
            elseif _G.VendorAttunedButton and _G.VendorAttunedButton:GetScript("OnReceiveDrag") then
                _G.VendorAttunedButton:GetScript("OnReceiveDrag")(self)
            end
        end)
    end
end

local function RestoreEmbeddedAttuneHelper()
    if not mainFrame or not mainFrame.footer then return end

    local host = mainFrame.footer.attuneHelperHost
    if host then
        host:Hide()
    end

    local miniFrame = _G.AttuneHelperMiniFrame
    if not miniFrame then return end
    if miniFrame:GetParent() ~= UIParent then
        miniFrame:SetParent(UIParent)
    end
    miniFrame:ClearAllPoints()
    miniFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    miniFrame:Hide()
end

-- ʕ •ᴥ•ʔ✿ Keep AttuneHelper hidden on login until the bag is opened.
-- Hooks both AH frames so any OnShow during load is suppressed; the embed
-- path reclaims the mini frame when OmniInventory is displayed. ✿ ʕ •ᴥ•ʔ
local earlyHideWatcher
local earlyHideApplied = false

local function InstallAttuneHelperEarlyHooks()
    local main = _G.AttuneHelperFrame
    local mini = _G.AttuneHelperMiniFrame
    if not main and not mini then
        return false
    end

    if main and not main.__OmniEarlyHideHooked then
        main.__OmniEarlyHideHooked = true
        main:HookScript("OnShow", function(frame)
            if not IsAttuneHelperEmbedEnabled() then return end
            frame:Hide()
        end)
    end

    if mini and not mini.__OmniEarlyHideHooked then
        mini.__OmniEarlyHideHooked = true
        mini:HookScript("OnShow", function(frame)
            if not IsAttuneHelperEmbedEnabled() then return end
            if mainFrame and mainFrame:IsShown() then
                return
            end
            frame:Hide()
        end)
    end

    if IsAttuneHelperEmbedEnabled() then
        _G.AttuneHelperDB = _G.AttuneHelperDB or {}
        _G.AttuneHelperDB["Mini Mode"] = 1
        if _G.AttuneHelper_UpdateDisplayMode then
            pcall(_G.AttuneHelper_UpdateDisplayMode)
        end
        if main then main:Hide() end
        if mini and not (mainFrame and mainFrame:IsShown()) then
            mini:Hide()
        end
    end

    return true
end

-- ʕ •ᴥ•ʔ✿ AH creates its frames on PLAYER_LOGIN; if we fire first we poll
-- briefly via an OnUpdate ticker (3.3.5 has no C_Timer). ✿ ʕ •ᴥ•ʔ
function Frame:HideAttuneHelperUntilOpened()
    earlyHideApplied = earlyHideApplied or InstallAttuneHelperEarlyHooks()
    if earlyHideApplied then
        return
    end

    if not earlyHideWatcher then
        earlyHideWatcher = CreateFrame("Frame")
        earlyHideWatcher.__elapsed = 0
        earlyHideWatcher.__totalElapsed = 0
    end

    earlyHideWatcher:SetScript("OnUpdate", function(self, elapsed)
        self.__elapsed = (self.__elapsed or 0) + elapsed
        self.__totalElapsed = (self.__totalElapsed or 0) + elapsed
        if self.__elapsed < 0.1 then return end
        self.__elapsed = 0

        if InstallAttuneHelperEarlyHooks() then
            earlyHideApplied = true
            self:SetScript("OnUpdate", nil)
            return
        end

        if self.__totalElapsed > 5 then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

local function GetSavedViewMode()
    local settings = OmniInventoryDB and OmniInventoryDB.char and OmniInventoryDB.char.settings
    return NormalizeViewMode(settings and settings.viewMode)
end

local function GetSavedItemScale()
    local settings = OmniInventoryDB and OmniInventoryDB.char and OmniInventoryDB.char.settings
    local scale = settings and settings.itemScale
    if type(scale) ~= "number" then
        return 1
    end
    return math.max(ITEM_SCALE_MIN, math.min(scale, ITEM_SCALE_MAX))
end

local function GetSavedItemGap()
    local settings = OmniInventoryDB and OmniInventoryDB.char and OmniInventoryDB.char.settings
    local gap = settings and settings.itemGap
    if type(gap) ~= "number" then
        return ITEM_SPACING
    end
    return math.max(ITEM_GAP_MIN, math.min(gap, ITEM_GAP_MAX))
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
    self:RefreshFooterMoneyStyle()
    self:CreateResizeHandle()

    -- ʕ •ᴥ•ʔ✿ Combat hint: only surfaces on the rare "opened during combat
    -- with no prior render" path. Width-constrained + word-wrapped so the
    -- message can never punch out of the frame like the old banner did. ✿ ʕ •ᴥ•ʔ
    mainFrame.combatHint = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mainFrame.combatHint:ClearAllPoints()
    mainFrame.combatHint:SetPoint("BOTTOM", mainFrame, "BOTTOM", 0, FOOTER_HEIGHT + PADDING + 6)
    mainFrame.combatHint:SetWidth(220)
    mainFrame.combatHint:SetJustifyH("CENTER")
    mainFrame.combatHint:SetJustifyV("MIDDLE")
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
-- Header (power ribbon)
-- =============================================================================

local RIBBON_BTN_HEIGHT = 20
local RIBBON_ICON_BTN_SIZE = 20
local RIBBON_TEXT_BTN_WIDTH = 46
local RIBBON_GAP = 3
local RIBBON_SEP_GAP = 5
local KEYRING_BAG_ID = -2
local SETTINGS_ICON = "Interface\\Icons\\Trade_Engineering"
local KEYRING_ICON = "Interface\\Icons\\INV_Misc_Key_03"
local FIND_DUNGEON_ICON = "Interface\\Icons\\INV_Misc_Map_01"
local FIND_DUNGEON_BASE_COMMAND = ".finddungeon"
local FIND_DUNGEON_POPUP_WIDTH = 372
local FIND_DUNGEON_POPUP_HEIGHT = 308
local FIND_DUNGEON_POPUP_PAD = 10
local FIND_DUNGEON_POPUP_HEADER = 22
local FIND_DUNGEON_SECTION_WIDTH = 112
local FIND_DUNGEON_SECTION_GAP = 8
local FIND_DUNGEON_BUTTON_HEIGHT = 20
local FIND_DUNGEON_BUTTON_GAP = 4
local FIND_DUNGEON_SECTION_TITLE_GAP = 16
local FIND_DUNGEON_CUSTOM_ROW_HEIGHT = 22
local FIND_DUNGEON_CUSTOM_RUN_WIDTH = 60
local FIND_DUNGEON_STATUS_HEIGHT = 26
local FIND_DUNGEON_STATUS_DEFAULT = "Rare+ unattuned loot, minus the slash-command archaeology."
local FIND_DUNGEON_SUBTITLE_TEXT = "Pick a preset, or type your own filters below."
local FIND_DUNGEON_MYTHIC_COLOR = { 0.35, 0.65, 1.00 }

local FIND_DUNGEON_PRESETS = {
    {
        title = "Vanilla",
        titleColor = { 1.00, 0.82, 0.00 },
        buttons = {
            { label = "Dungeons", filters = "vanilla notraid" },
            { label = "Raids", filters = "vanilla raid" },
        },
    },
    {
        title = "TBC",
        titleColor = { 0.28, 0.85, 0.55 },
        buttons = {
            { label = "Normal", filters = "tbc notheroic notmythic notraid" },
            { label = "Heroic", filters = "tbc heroic" },
            { label = "Raids", filters = "tbc raid" },
            { label = "Mythic", filters = "tbc mythic", accentColor = FIND_DUNGEON_MYTHIC_COLOR },
        },
    },
    {
        title = "WotLK",
        titleColor = { 0.45, 0.78, 1.00 },
        buttons = {
            { label = "Normal", filters = "wotlk notheroic notraid notmythic" },
            { label = "Heroic", filters = "wotlk heroic notraid" },
            { label = "Raids", filters = "wotlk raid" },
            { label = "10M", filters = "wotlk raid not25-man" },
            { label = "25M", filters = "wotlk raid 25-man" },
            { label = "Mythic", filters = "wotlk mythic", accentColor = FIND_DUNGEON_MYTHIC_COLOR },
        },
    },
}

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

local function CreateRibbonTextButton(parent, label, tooltipTitle, tooltipSub, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(RIBBON_TEXT_BTN_WIDTH, RIBBON_BTN_HEIGHT)
    StyleRibbonButton(btn)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(label)

    btn._tooltipTitle = tooltipTitle
    btn._tooltipSub = tooltipSub
    btn:SetScript("OnClick", onClick)
    return btn
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

local function ApplyFindDungeonPopupButtonAccent(btn, hovered)
    if not btn or not btn._accentColor then
        return
    end

    local r = btn._accentColor[1] or 1
    local g = btn._accentColor[2] or 1
    local b = btn._accentColor[3] or 1

    if btn.text then
        btn.text:SetTextColor(r, g, b, 1)
    end

    if hovered then
        btn:SetBackdropColor(r * 0.18, g * 0.18, b * 0.18, 1)
        btn:SetBackdropBorderColor(r, g, b, 1)
    else
        btn:SetBackdropColor(0.12, 0.12, 0.12, 1)
        btn:SetBackdropBorderColor(r * 0.75, g * 0.75, b * 0.75, 0.9)
    end
end

local function CreateFindDungeonPopupButton(parent, width, label, tooltipTitle, tooltipSub, onClick, accentColor)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, FIND_DUNGEON_BUTTON_HEIGHT)
    StyleRibbonButton(btn)
    btn._accentColor = accentColor

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(label)

    btn._tooltipTitle = tooltipTitle
    btn._tooltipSub = tooltipSub
    btn:SetScript("OnClick", onClick)

    if accentColor then
        btn:HookScript("OnEnter", function(self)
            ApplyFindDungeonPopupButtonAccent(self, true)
        end)
        btn:HookScript("OnLeave", function(self)
            ApplyFindDungeonPopupButtonAccent(self, false)
        end)
        ApplyFindDungeonPopupButtonAccent(btn, false)
    end

    return btn
end

local function TrimText(text)
    return (string.gsub(text or "", "^%s*(.-)%s*$", "%1"))
end

local function NormalizeFindDungeonFilters(filters)
    local normalized = TrimText(filters)
    normalized = string.gsub(normalized, "^%.finddungeon%s*", "")
    normalized = string.gsub(normalized, "^finddungeon%s*", "")
    return TrimText(normalized)
end

local function BuildFindDungeonCommand(filters)
    local normalized = NormalizeFindDungeonFilters(filters)
    if normalized == "" then
        return FIND_DUNGEON_BASE_COMMAND
    end
    return FIND_DUNGEON_BASE_COMMAND .. " " .. normalized
end

local function PrepareChatCommand(command)
    if not ChatFrame_OpenChat then
        return false, nil
    end

    local chatFrame = DEFAULT_CHAT_FRAME or SELECTED_CHAT_FRAME or _G.ChatFrame1
    if not chatFrame then
        return false, nil
    end

    local ok = pcall(ChatFrame_OpenChat, command, chatFrame)
    if not ok then
        return false, nil
    end

    local editBox = chatFrame.editBox or _G.ChatFrameEditBox
    if editBox and editBox.SetText then
        editBox:SetText(command)
        if editBox.HighlightText then
            editBox:HighlightText(0, 0)
        end
    end

    return true, editBox
end

-- ʕノ•ᴥ•ʔノ Drag-drop landing zone for bag-slot icons in the ribbon ノʕ•ᴥ•ʔ
function Frame:EquipBagFromCursor(bagID)
    if not IsValidBagID(bagID) then return end
    if bagID == 0 then
        print("|cFF00FF00OmniInventory|r: Backpack slot cannot be swapped.")
        if ClearCursor then ClearCursor() end
        return
    end
    if InCombat() then
        print("|cFF00FF00OmniInventory|r: Cannot change bags during combat.")
        return
    end
    if not (CursorHasItem and CursorHasItem()) then return end

    local inventoryID = ContainerIDToInventoryID and ContainerIDToInventoryID(bagID)
    if not inventoryID then return end
    if PutItemInBag then
        PutItemInBag(inventoryID)
    end
end

function Frame:CreateHeader()
    local header = CreateFrame("Frame", nil, mainFrame)
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", PADDING, -PADDING)
    header:SetPoint("TOPRIGHT", -PADDING, -PADDING)

    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()
    header.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    header.bg:SetVertexColor(0.15, 0.15, 0.15, 1)

    header.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.title:SetPoint("LEFT", 6, 0)
    header.title:SetJustifyH("LEFT")
    header.title:SetText("|cFF00FF00Omni|r Inventory")

    header.closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    header.closeBtn:SetSize(20, 20)
    header.closeBtn:SetPoint("RIGHT", -2, 0)
    header.closeBtn:SetScript("OnClick", function() Frame:Hide() end)

    -- ʕ ● ᴥ ●ʔ Ribbon: rightmost wins, everything else chains leftward
    header.viewBtn = CreateRibbonTextButton(header, "Flow",
        "View Mode", "Click to cycle Grid / Flow / List / Bag",
        function() Frame:CycleView() end)
    header.viewBtn:SetPoint("RIGHT", header.closeBtn, "LEFT", -RIBBON_GAP, 0)

    header.sortBtn = CreateRibbonTextButton(header, "Sort",
        "Sort Mode", "Click to cycle the active sort",
        function() Frame:CycleSort() end)
    header.sortBtn:SetPoint("RIGHT", header.viewBtn, "LEFT", -RIBBON_GAP, 0)

    header.sortBtn:HookScript("OnEnter", function(self)
        local mode = Omni.Sorter and Omni.Sorter:GetDefaultMode() or "category"
        self._tooltipSub = "Current: " .. mode
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
    header.optBtn:SetPoint("RIGHT", header.sortBtn, "LEFT", -RIBBON_GAP, 0)

    header.keyBtn = CreateRibbonIconButton(header, KEYRING_ICON,
        "Keyring", "Open keyring popup",
        function() Frame:ToggleKeyring() end)
    header.keyBtn:SetPoint("RIGHT", header.optBtn, "LEFT", -RIBBON_GAP, 0)

    -- Separator line between ribbon actions and bag slot icons
    header.ribbonSep = header:CreateTexture(nil, "OVERLAY")
    header.ribbonSep:SetTexture("Interface\\Buttons\\WHITE8X8")
    header.ribbonSep:SetVertexColor(0.35, 0.35, 0.35, 1)
    header.ribbonSep:SetSize(1, 14)
    header.ribbonSep:SetPoint("RIGHT", header.keyBtn, "LEFT", -RIBBON_SEP_GAP, 0)

    header.bagButtons = {}
    header.bagBar = CreateFrame("Frame", nil, header)
    header.bagBar:SetSize((BAG_ICON_SIZE + 2) * #BAG_IDS, BAG_ICON_SIZE)
    header.bagBar:SetPoint("RIGHT", header.ribbonSep, "LEFT", -RIBBON_SEP_GAP, 0)

    header.findDungeonBtn = CreateRibbonIconButton(header, FIND_DUNGEON_ICON,
        "Dungeon Radar",
        "Sniff out attunable dungeons without typing dot commands like a cave scribe.",
        function() Frame:ToggleFindDungeonPopup() end)
    header.findDungeonBtn:SetPoint("RIGHT", header.bagBar, "LEFT", -RIBBON_GAP, 0)
    header.title:SetPoint("RIGHT", header.findDungeonBtn, "LEFT", -6, 0)

    for index, bagID in ipairs(BAG_IDS) do
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
                -- ᵔᴥᵔ Cursor holds a bag → swap; otherwise preview filter.
                if CursorHasItem and CursorHasItem() then
                    Frame:EquipBagFromCursor(self.bagID)
                    return
                end
                Frame:ToggleBagPreview(self.bagID)
            elseif mouseButton == "RightButton" then
                Frame:ForceEmptyBag(self.bagID)
            end
        end)

        bagBtn:SetScript("OnReceiveDrag", function(self)
            Frame:EquipBagFromCursor(self.bagID)
        end)

        bagBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(GetBagDisplayName(self.bagID), 1, 1, 1)
            GameTooltip:AddLine("Left-click: Preview this bag", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Right-click: Force-empty bag", 0.8, 0.8, 0.8)
            if self.bagID ~= 0 then
                GameTooltip:AddLine("Drag a bag here to equip it", 0.6, 0.9, 0.6)
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
-- Find Dungeon Popup
-- =============================================================================

function Frame:SetFindDungeonStatus(message, r, g, b)
    if not mainFrame or not mainFrame.findDungeonPopup or not mainFrame.findDungeonPopup.status then
        return
    end

    local status = mainFrame.findDungeonPopup.status
    status:SetText(message or FIND_DUNGEON_STATUS_DEFAULT)
    status:SetTextColor(r or 0.78, g or 0.78, b or 0.78, 1)
end

function Frame:ExecuteFindDungeonCommand(filters)
    if InCombat() then
        print("|cFF00FF00OmniInventory|r: Dungeon Radar is unavailable during combat.")
        self:SetFindDungeonStatus("Combat lockdown says the radar can wait a second.", 1.0, 0.25, 0.25)
        return false
    end

    local command = BuildFindDungeonCommand(filters)
    local prepared, editBox = PrepareChatCommand(command)
    if prepared and editBox and ChatEdit_SendText then
        local ok = pcall(ChatEdit_SendText, editBox, 0)
        if ok then
            if editBox.ClearFocus then
                editBox:ClearFocus()
            end
            self:SetFindDungeonStatus("Scanning: " .. command, 0.45, 0.95, 0.55)
            return true
        end
    end

    if prepared then
        self:SetFindDungeonStatus("Queued in chat: " .. command, 1.0, 0.82, 0.0)
        print("|cFF00FF00OmniInventory|r: Ready in chat - press Enter to run " .. command)
        return false
    end

    self:SetFindDungeonStatus("Could not open chat for " .. command, 1.0, 0.25, 0.25)
    print("|cFF00FF00OmniInventory|r: Unable to open chat for " .. command)
    return false
end

function Frame:RunFindDungeonPreset(filters)
    return self:ExecuteFindDungeonCommand(filters)
end

function Frame:RunCustomFindDungeonFilters()
    if not mainFrame or not mainFrame.findDungeonPopup or not mainFrame.findDungeonPopup.customBox then
        return false
    end

    local filters = mainFrame.findDungeonPopup.customBox:GetText() or ""
    return self:ExecuteFindDungeonCommand(filters)
end

function Frame:CreateFindDungeonPopup()
    if not mainFrame then return nil end
    if mainFrame.findDungeonPopup then return mainFrame.findDungeonPopup end

    local popup = CreateFrame("Frame", "OmniFindDungeonPopup", mainFrame)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
    popup:SetPoint("TOPRIGHT", mainFrame, "TOPLEFT", -6, 0)
    popup:SetSize(FIND_DUNGEON_POPUP_WIDTH, FIND_DUNGEON_POPUP_HEIGHT)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    popup:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    popup:SetBackdropBorderColor(0.45, 0.38, 0.15, 1)

    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    popup.title:SetPoint("TOPLEFT", FIND_DUNGEON_POPUP_PAD, -6)
    popup.title:SetText("|cFFFFCC00Dungeon Radar|r")

    popup.subtitle = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.subtitle:SetPoint("TOPLEFT", popup.title, "BOTTOMLEFT", 0, -4)
    popup.subtitle:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -FIND_DUNGEON_POPUP_PAD - 18, -4)
    popup.subtitle:SetWidth(FIND_DUNGEON_POPUP_WIDTH - (FIND_DUNGEON_POPUP_PAD * 2) - 18)
    popup.subtitle:SetJustifyH("LEFT")
    popup.subtitle:SetJustifyV("TOP")
    popup.subtitle:SetTextColor(0.78, 0.78, 0.78, 1)
    popup.subtitle:SetText(FIND_DUNGEON_SUBTITLE_TEXT)

    popup.closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    popup.closeBtn:SetSize(18, 18)
    popup.closeBtn:SetPoint("TOPRIGHT", -2, -2)
    popup.closeBtn:SetScript("OnClick", function() popup:Hide() end)

    popup.sections = {}
    for index, section in ipairs(FIND_DUNGEON_PRESETS) do
        local sectionFrame = CreateFrame("Frame", nil, popup)
        sectionFrame:SetSize(FIND_DUNGEON_SECTION_WIDTH, 150)
        sectionFrame:SetPoint(
            "TOPLEFT",
            popup,
            "TOPLEFT",
            FIND_DUNGEON_POPUP_PAD + (index - 1) * (FIND_DUNGEON_SECTION_WIDTH + FIND_DUNGEON_SECTION_GAP),
            -(FIND_DUNGEON_POPUP_HEADER + 26)
        )

        sectionFrame.title = sectionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sectionFrame.title:SetPoint("TOPLEFT", 0, 0)
        sectionFrame.title:SetText(section.title)
        sectionFrame.title:SetTextColor(
            section.titleColor[1],
            section.titleColor[2],
            section.titleColor[3],
            1
        )

        sectionFrame.buttons = {}
        local yOffset = -FIND_DUNGEON_SECTION_TITLE_GAP
        for _, def in ipairs(section.buttons) do
            local command = BuildFindDungeonCommand(def.filters)
            local btn = CreateFindDungeonPopupButton(
                sectionFrame,
                FIND_DUNGEON_SECTION_WIDTH,
                def.label,
                section.title .. " " .. def.label,
                command,
                function() Frame:RunFindDungeonPreset(def.filters) end,
                def.accentColor
            )
            btn:SetPoint("TOPLEFT", 0, yOffset)
            table.insert(sectionFrame.buttons, btn)
            yOffset = yOffset - (FIND_DUNGEON_BUTTON_HEIGHT + FIND_DUNGEON_BUTTON_GAP)
        end

        popup.sections[index] = sectionFrame
    end

    popup.divider = popup:CreateTexture(nil, "OVERLAY")
    popup.divider:SetTexture("Interface\\Buttons\\WHITE8X8")
    popup.divider:SetVertexColor(0.35, 0.35, 0.35, 1)
    popup.divider:SetHeight(1)
    popup.divider:SetPoint("LEFT", FIND_DUNGEON_POPUP_PAD, 0)
    popup.divider:SetPoint("RIGHT", -FIND_DUNGEON_POPUP_PAD, 0)
    popup.divider:SetPoint("TOP", popup, "TOP", 0, -212)

    popup.customLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    popup.customLabel:SetPoint("TOPLEFT", FIND_DUNGEON_POPUP_PAD, -224)
    popup.customLabel:SetText("Custom filters")

    popup.customHint = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.customHint:SetPoint("TOPRIGHT", -FIND_DUNGEON_POPUP_PAD, -224)
    popup.customHint:SetTextColor(0.65, 0.65, 0.65, 1)
    popup.customHint:SetText("Omni adds .finddungeon for you")

    popup.customRow = CreateFrame("Frame", nil, popup)
    popup.customRow:SetHeight(FIND_DUNGEON_CUSTOM_ROW_HEIGHT)
    popup.customRow:SetPoint("TOPLEFT", FIND_DUNGEON_POPUP_PAD, -242)
    popup.customRow:SetPoint("TOPRIGHT", -FIND_DUNGEON_POPUP_PAD, -242)

    popup.customInput = CreateFrame("Frame", nil, popup.customRow)
    popup.customInput:SetPoint("TOPLEFT", 0, 0)
    popup.customInput:SetPoint("BOTTOMRIGHT", -FIND_DUNGEON_CUSTOM_RUN_WIDTH - 6, 0)
    popup.customInput:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    popup.customInput:SetBackdropColor(0.10, 0.10, 0.10, 1)
    popup.customInput:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)

    popup.customPrefix = popup.customInput:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.customPrefix:SetPoint("LEFT", 6, 0)
    popup.customPrefix:SetText(".finddungeon")
    popup.customPrefix:SetTextColor(1.0, 0.82, 0.0, 1)

    popup.customBox = CreateFrame("EditBox", nil, popup.customInput)
    popup.customBox:SetAutoFocus(false)
    popup.customBox:SetFontObject(ChatFontNormal)
    popup.customBox:SetTextColor(1, 1, 1, 1)
    popup.customBox:SetHeight(16)
    popup.customBox:SetPoint("LEFT", popup.customPrefix, "RIGHT", 6, 0)
    popup.customBox:SetPoint("RIGHT", -6, 0)
    popup.customBox:SetTextInsets(0, 0, 0, 0)
    popup.customBox:SetScript("OnEnterPressed", function(self)
        Frame:RunCustomFindDungeonFilters()
        self:ClearFocus()
    end)
    popup.customBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    popup.customRunBtn = CreateFindDungeonPopupButton(
        popup.customRow,
        FIND_DUNGEON_CUSTOM_RUN_WIDTH,
        "Run",
        "Custom .finddungeon",
        "Run the filters typed on the left.",
        function() Frame:RunCustomFindDungeonFilters() end
    )
    popup.customRunBtn:SetPoint("TOPRIGHT", 0, 0)

    popup.status = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.status:SetHeight(FIND_DUNGEON_STATUS_HEIGHT)
    popup.status:SetPoint("TOPLEFT", FIND_DUNGEON_POPUP_PAD, -272)
    popup.status:SetPoint("TOPRIGHT", -FIND_DUNGEON_POPUP_PAD, -272)
    popup.status:SetJustifyH("LEFT")
    popup.status:SetJustifyV("TOP")
    popup.status:SetTextColor(0.78, 0.78, 0.78, 1)
    popup.status:SetText(FIND_DUNGEON_STATUS_DEFAULT)

    popup:Hide()
    mainFrame.findDungeonPopup = popup

    popup:SetScript("OnShow", function()
        Frame:SetFindDungeonStatus(FIND_DUNGEON_STATUS_DEFAULT, 0.78, 0.78, 0.78)
    end)

    tinsert(UISpecialFrames, "OmniFindDungeonPopup")

    return popup
end

function Frame:ToggleFindDungeonPopup()
    local popup = mainFrame and mainFrame.findDungeonPopup or self:CreateFindDungeonPopup()
    if not popup then return end

    if popup:IsShown() then
        popup:Hide()
    else
        popup:Show()
    end
end

-- =============================================================================
-- Keyring Popup (bagID -2)
-- =============================================================================

local KEYRING_COLS = 8
local KEYRING_CELL = 30
local KEYRING_CELL_GAP = 2
local KEYRING_PAD = 10
local KEYRING_HEADER = 22

local function UpdateKeyringButtonForge(btn)
    -- ʕ ● ᴥ ●ʔ Keyring items have no forge/attune data; simplify styling ʕ ● ᴥ ●ʔ
    if btn.forgeText then btn.forgeText:Hide() end
    if btn.attuneBarBG then btn.attuneBarBG:Hide() end
    if btn.attuneBarFill then btn.attuneBarFill:Hide() end
    if btn.attuneText then btn.attuneText:Hide() end
    if btn.bountyIcon then btn.bountyIcon:Hide() end
    if btn.accountIcon then btn.accountIcon:Hide() end
    if btn.resistIcon then btn.resistIcon:Hide() end
end

function Frame:CreateKeyringPopup()
    if not mainFrame then return nil end
    if mainFrame.keyringPopup then return mainFrame.keyringPopup end

    local popup = CreateFrame("Frame", "OmniKeyringPopup", mainFrame)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
    -- ʕ •ᴥ•ʔ✿ Anchor above the main frame so the popup is always on-screen
    -- even when the bag is docked near the bottom of the display. ✿ ʕ •ᴥ•ʔ
    popup:SetPoint("BOTTOMLEFT", mainFrame, "TOPLEFT", 0, 4)
    popup:SetSize(
        KEYRING_PAD * 2 + KEYRING_COLS * (KEYRING_CELL + KEYRING_CELL_GAP) - KEYRING_CELL_GAP,
        KEYRING_HEADER + KEYRING_PAD + KEYRING_CELL + KEYRING_CELL_GAP
    )
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    popup:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    popup:SetBackdropBorderColor(0.45, 0.38, 0.15, 1)

    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    popup.title:SetPoint("TOPLEFT", KEYRING_PAD, -6)
    popup.title:SetText("|cFFFFCC00Keyring|r")

    popup.empty = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    popup.empty:SetPoint("CENTER", 0, -4)
    popup.empty:SetText("Keyring is empty.")
    popup.empty:Hide()

    popup.closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    popup.closeBtn:SetSize(18, 18)
    popup.closeBtn:SetPoint("TOPRIGHT", -2, -2)
    popup.closeBtn:SetScript("OnClick", function() popup:Hide() end)

    -- ʕ •ᴥ•ʔ✿ Container carries SetID(-2) so the secure template resolves
    -- to the keyring bag when a key is clicked. An explicit size keeps the
    -- child item buttons inside a non-zero hit region. ✿ ʕ •ᴥ•ʔ
    popup.container = CreateFrame("Frame", nil, popup)
    popup.container:SetPoint("TOPLEFT", KEYRING_PAD, -(KEYRING_HEADER + 2))
    popup.container:SetPoint("BOTTOMRIGHT", -KEYRING_PAD, KEYRING_PAD)
    popup.container:SetID(KEYRING_BAG_ID)

    popup.buttons = {}
    popup:Hide()
    mainFrame.keyringPopup = popup

    popup:SetScript("OnShow", function() Frame:UpdateKeyring() end)

    tinsert(UISpecialFrames, "OmniKeyringPopup")

    if Omni.Events then
        Omni.Events:RegisterEvent("BAG_UPDATE_KEYRING", function()
            if popup:IsShown() then Frame:UpdateKeyring() end
        end)
    end

    return popup
end

function Frame:UpdateKeyring()
    if not mainFrame or not mainFrame.keyringPopup then return end
    local popup = mainFrame.keyringPopup
    if InCombat() then
        popup.empty:SetText("Keyring update deferred during combat.")
        popup.empty:Show()
        return
    end

    local slots = GetContainerNumSlots(KEYRING_BAG_ID) or 0

    if slots <= 0 then
        popup.empty:SetText("You have no keyring.")
        popup.empty:Show()
        for _, btn in ipairs(popup.buttons) do pcall(btn.Hide, btn) end
        popup:SetSize(240, KEYRING_HEADER + KEYRING_PAD * 2 + 40)
        return
    end

    popup.empty:Hide()

    for slotID = 1, slots do
        local btn = popup.buttons[slotID]
        if not btn then
            btn = Omni.ItemButton and Omni.ItemButton:Create(popup.container)
                or CreateFrame("Button", nil, popup.container, "ContainerFrameItemButtonTemplate")
            btn:SetSize(KEYRING_CELL, KEYRING_CELL)
            if btn.SetID then pcall(btn.SetID, btn, slotID) end
            popup.buttons[slotID] = btn
        end

        local col = (slotID - 1) % KEYRING_COLS
        local row = math.floor((slotID - 1) / KEYRING_COLS)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", popup.container, "TOPLEFT",
            col * (KEYRING_CELL + KEYRING_CELL_GAP),
            -row * (KEYRING_CELL + KEYRING_CELL_GAP))

        local info
        if OmniC_Container then
            info = OmniC_Container.GetContainerItemInfo(KEYRING_BAG_ID, slotID)
        end
        if info then
            if Omni.Categorizer then
                info.category = info.category or Omni.Categorizer:GetCategory(info)
            end
            SetButtonItem(btn, info)
        else
            SetButtonItem(btn, nil)
        end
        UpdateKeyringButtonForge(btn)
        pcall(btn.Show, btn)
    end

    -- Hide any stale buttons left over from a previous larger keyring
    for slotID = slots + 1, #popup.buttons do
        local btn = popup.buttons[slotID]
        if btn then pcall(btn.Hide, btn) end
    end

    local rows = math.ceil(slots / KEYRING_COLS)
    local width = KEYRING_PAD * 2 + KEYRING_COLS * (KEYRING_CELL + KEYRING_CELL_GAP) - KEYRING_CELL_GAP
    local height = KEYRING_HEADER + KEYRING_PAD + rows * (KEYRING_CELL + KEYRING_CELL_GAP)
    popup:SetSize(width, height)
end

function Frame:ToggleKeyring()
    if InCombat() then
        print("|cFF00FF00OmniInventory|r: Keyring unavailable during combat.")
        return
    end
    local popup = mainFrame and mainFrame.keyringPopup or self:CreateKeyringPopup()
    if not popup then return end
    if popup:IsShown() then
        popup:Hide()
    else
        popup:Show()
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
local FILTER_BUTTON_HEIGHT = 18
local FILTER_BUTTON_SPACING = 2
local FILTER_BUTTON_START_X = 4
local FILTER_TEXT_PADDING_MAX = 10
local FILTER_TEXT_PADDING_MIN = 3
local FILTER_BUTTON_MIN_WIDTH = 22
local FILTER_FONT_PATH = "Fonts\\FRIZQT__.TTF"
local FILTER_FONT_SIZES = { 10, 9, 8, 7 }
local FILTER_ROW_SPACING = 2
local FILTER_ROW_TOP_PAD = 2
local FILTER_ROW_BOTTOM_PAD = 2
local FILTER_NEUTRAL_COLOR = { 0.75, 0.75, 0.75 }
local activeFilter = nil  -- Current active filter

-- ʕ ◕ᴥ◕ ʔ✿ Static specials always rendered first. "All" clears the
-- filter, "New" matches the session-acquired flag, and everything
-- after them is generated dynamically from the categories currently
-- present in the inventory (see RebuildFilterTabs). ✿ ʕ ◕ᴥ◕ ʔ
local SPECIAL_FILTERS = {
    { name = "All", filter = nil, color = FILTER_NEUTRAL_COLOR },
}

local function ApplyFilterButtonVisual(btn, hovered)
    local c = btn.colorTuple or FILTER_NEUTRAL_COLOR
    local r, g, b = c[1], c[2], c[3]
    local isActive = (activeFilter == btn.filterName)
    local bgIntensity
    if isActive then
        bgIntensity = 0.45
    elseif hovered then
        bgIntensity = 0.28
    else
        bgIntensity = 0.14
    end
    btn:SetBackdropColor(r * bgIntensity, g * bgIntensity, b * bgIntensity, 1)
    local borderAlpha = isActive and 1.0 or (hovered and 0.75 or 0.45)
    btn:SetBackdropBorderColor(r, g, b, borderAlpha)
    if btn.text then
        btn.text:SetTextColor(r, g, b, 1)
    end
end

local function CreateFilterButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(FILTER_BUTTON_HEIGHT)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("CENTER")
    btn:SetScript("OnClick", function(self)
        Frame:SetQuickFilter(self.filterName)
    end)
    btn:SetScript("OnEnter", function(self) ApplyFilterButtonVisual(self, true) end)
    btn:SetScript("OnLeave", function(self) ApplyFilterButtonVisual(self, false) end)
    return btn
end

local function ResolveCategoryColor(name)
    if Omni.Categorizer and name then
        local r, g, b = Omni.Categorizer:GetCategoryColor(name)
        if r and g and b then
            return { r, g, b }
        end
    end
    return FILTER_NEUTRAL_COLOR
end

function Frame:CreateFilterBar()
    local filterBar = CreateFrame("Frame", nil, mainFrame)
    filterBar:SetHeight(FILTER_HEIGHT)
    filterBar:SetPoint("TOPLEFT", mainFrame.searchBar, "BOTTOMLEFT", 0, -2)
    filterBar:SetPoint("TOPRIGHT", mainFrame.searchBar, "BOTTOMRIGHT", 0, -2)

    filterBar.bg = filterBar:CreateTexture(nil, "BACKGROUND")
    filterBar.bg:SetAllPoints()
    filterBar.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    filterBar.bg:SetVertexColor(0.08, 0.08, 0.08, 1)

    -- ʕ •ᴥ•ʔ✿ Button pool: buttons are created lazily as the inventory
    -- grows into new categories, then reused across refreshes. Each
    -- refresh repositions, re-labels, and re-colors them based on the
    -- categories currently in the bag. ✿ ʕ •ᴥ•ʔ
    filterBar.buttons = {}

    mainFrame.filterBar = filterBar
end

function Frame:RebuildFilterTabs(presentCategories)
    local filterBar = mainFrame and mainFrame.filterBar
    if not filterBar then return end

    -- ʕ •ᴥ•ʔ✿ Assemble the ordered tab definition list: specials first,
    -- then every category that currently holds an item (sorted by the
    -- Categorizer's priority so tabs read left-to-right in the same
    -- order the sections render). ✿ ʕ •ᴥ•ʔ
    local defs = {}
    for _, spec in ipairs(SPECIAL_FILTERS) do
        local color = spec.color or ResolveCategoryColor(spec.categoryColorFor)
        table.insert(defs, {
            name = spec.name,
            filter = spec.filter,
            color = color,
            isSpecial = spec.isSpecial,
        })
    end

    local categoryNames = {}
    if presentCategories then
        for name in pairs(presentCategories) do
            table.insert(categoryNames, name)
        end
    end
    table.sort(categoryNames, function(a, b)
        local ia = Omni.Categorizer and Omni.Categorizer:GetCategoryInfo(a) or { priority = 99 }
        local ib = Omni.Categorizer and Omni.Categorizer:GetCategoryInfo(b) or { priority = 99 }
        if (ia.priority or 99) ~= (ib.priority or 99) then
            return (ia.priority or 99) < (ib.priority or 99)
        end
        return a < b
    end)

    for _, name in ipairs(categoryNames) do
        table.insert(defs, {
            name = name,
            filter = name,
            color = ResolveCategoryColor(name),
        })
    end

    -- ʕ •ᴥ•ʔ✿ Single-row shrink-to-fit. We first try every tab at the
    -- default font and max padding. If the labels overflow the bar,
    -- we progressively compress: reduce padding, then step the font
    -- size down (10→9→8→7). We keep the existing wrap path as a last-
    -- resort fallback so oddly-wide labels on a tiny frame still land
    -- somewhere visible. ✿ ʕ •ᴥ•ʔ
    local barWidth = filterBar:GetWidth()
    if not barWidth or barWidth <= 0 then
        barWidth = mainFrame:GetWidth() - 16
    end
    local rowMaxX = barWidth - FILTER_BUTTON_START_X
    local availableWidth = barWidth - FILTER_BUTTON_START_X * 2

    -- Pre-create buttons so we can measure
    for i, def in ipairs(defs) do
        local btn = filterBar.buttons[i]
        if not btn then
            btn = CreateFilterButton(filterBar)
            filterBar.buttons[i] = btn
        end
        btn.text:SetText(def.name)
    end

    local function measureForFontAndPadding(fontSize, padding)
        local widths = {}
        local total = 0
        for i, def in ipairs(defs) do
            local btn = filterBar.buttons[i]
            btn.text:SetFont(FILTER_FONT_PATH, fontSize)
            local w = math.max(btn.text:GetStringWidth() + padding * 2, FILTER_BUTTON_MIN_WIDTH)
            widths[i] = w
            total = total + w
        end
        total = total + FILTER_BUTTON_SPACING * math.max(#defs - 1, 0)
        return widths, total
    end

    -- Walk (fontSize, padding) combinations from most generous to
    -- tightest; stop at the first combo where everything fits.
    local chosenWidths = nil
    for _, fontSize in ipairs(FILTER_FONT_SIZES) do
        for padding = FILTER_TEXT_PADDING_MAX, FILTER_TEXT_PADDING_MIN, -1 do
            local widths, total = measureForFontAndPadding(fontSize, padding)
            if total <= availableWidth then
                chosenWidths = widths
                break
            end
        end
        if chosenWidths then break end
    end

    -- Fallback: use the tightest combo even if it still overflows, and
    -- allow the wrap logic below to push the leftovers onto row 2.
    if not chosenWidths then
        chosenWidths = measureForFontAndPadding(
            FILTER_FONT_SIZES[#FILTER_FONT_SIZES],
            FILTER_TEXT_PADDING_MIN
        )
    end

    local x = FILTER_BUTTON_START_X
    local row = 0
    for i, def in ipairs(defs) do
        local btn = filterBar.buttons[i]
        local finalWidth = chosenWidths[i]

        -- Wrap only if we couldn't shrink enough to fit on one row.
        if x > FILTER_BUTTON_START_X and (x + finalWidth) > rowMaxX then
            row = row + 1
            x = FILTER_BUTTON_START_X
        end

        local y = -(FILTER_ROW_TOP_PAD + row * (FILTER_BUTTON_HEIGHT + FILTER_ROW_SPACING))

        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", filterBar, "TOPLEFT", x, y)
        btn:SetSize(finalWidth, FILTER_BUTTON_HEIGHT)

        btn.filterName = def.filter
        btn.colorTuple = def.color
        btn:Show()
        ApplyFilterButtonVisual(btn, false)

        x = x + finalWidth + FILTER_BUTTON_SPACING
    end

    for i = #defs + 1, #filterBar.buttons do
        filterBar.buttons[i]:Hide()
    end

    local rowCount = (#defs > 0) and (row + 1) or 1
    local barHeight = FILTER_ROW_TOP_PAD
        + rowCount * FILTER_BUTTON_HEIGHT
        + math.max(rowCount - 1, 0) * FILTER_ROW_SPACING
        + FILTER_ROW_BOTTOM_PAD
    filterBar:SetHeight(math.max(barHeight, FILTER_HEIGHT))

    -- ʕ •ᴥ•ʔ✿ If the active filter's category vanished from the bag
    -- (e.g. vendored every Junk item), fall back to "All" so the user
    -- isn't stuck looking at an empty filtered view. Re-apply visuals
    -- afterward so the previously-active tab no longer reads active. ✿ ʕ •ᴥ•ʔ
    if activeFilter then
        local stillPresent = false
        for _, def in ipairs(defs) do
            if def.filter == activeFilter then
                stillPresent = true
                break
            end
        end
        if not stillPresent then
            activeFilter = nil
            for i = 1, #defs do
                ApplyFilterButtonVisual(filterBar.buttons[i], false)
            end
        end
    end
end

function Frame:SetQuickFilter(filterName)
    -- ʕ •ᴥ•ʔ✿ Toggle semantics: clicking the active tab a second time
    -- clears the filter so the bag "sorts back" to its normal LPT
    -- layout without needing a separate "All" click. ✿ ʕ •ᴥ•ʔ
    if activeFilter ~= nil and activeFilter == filterName then
        filterName = nil
    end
    activeFilter = filterName

    if mainFrame.filterBar and mainFrame.filterBar.buttons then
        for _, btn in ipairs(mainFrame.filterBar.buttons) do
            if btn:IsShown() then
                ApplyFilterButtonVisual(btn, false)
            end
        end
    end

    self:UpdateLayout(nil, { reason = "filter_change" })
end

function Frame:GetActiveFilter()
    return activeFilter
end

-- =============================================================================
-- Content Area (ScrollFrame)
-- =============================================================================

-- ʕ •ᴥ•ʔ✿ Trade Goods → Resource Bank deposit shortcut ✿ ʕ •ᴥ•ʔ
local function DepositToResourceBank()
    local btn = _G["RBankFrame-DepositAll"]
    if btn and type(btn.Click) == "function" then
        btn:Click()
        return
    end

    -- Frame not yet constructed by the server UI; summon it, click, then
    -- close on the same frame so it never renders.
    if type(_G.OpenResourceSummary) ~= "function" then
        print("|cFF00FF00OmniInventory|r: Resource Bank not available on this client.")
        return
    end

    _G.OpenResourceSummary()

    btn = _G["RBankFrame-DepositAll"]
    if btn and type(btn.Click) == "function" then
        btn:Click()
    else
        print("|cFF00FF00OmniInventory|r: RBankFrame-DepositAll button not found after opening.")
    end

    if type(_G.CloseResourceSummary) == "function" then
        _G.CloseResourceSummary()
    end
end

local function EnsureTradeGoodsDepositButton()
    if not mainFrame then return nil end
    if mainFrame.tradeGoodsDepositBtn then return mainFrame.tradeGoodsDepositBtn end

    local btn = CreateFrame("Button", nil, mainFrame.scrollChild or mainFrame)
    btn:SetSize(14, 14)
    btn:SetNormalTexture("Interface\\Icons\\Achievement_BG_returnXflags_def_WSG")
    local normal = btn:GetNormalTexture()
    if normal and normal.SetTexCoord then
        normal:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Icons\\Achievement_BG_returnXflags_def_WSG")
    hl:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    hl:SetBlendMode("ADD")
    hl:SetVertexColor(0.3, 0.3, 0.3, 0.5)

    btn:SetBackdrop({
        edgeFile = "Interface\\Buttons\\UI-Quickslot-Depress",
        edgeSize = 2,
        insets = { left = -1, right = -1, top = -1, bottom = -1 },
    })
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.9, 0.8, 0.2, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Deposit to Resource Bank", 1, 1, 1)
        GameTooltip:AddLine("Sends all eligible Trade Goods to your Resource Bank.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
        GameTooltip:Hide()
    end)
    btn:SetScript("OnMouseDown", function(self)
        local tex = self:GetNormalTexture()
        if tex then tex:SetVertexColor(0.75, 0.75, 0.75) end
    end)
    btn:SetScript("OnMouseUp", function(self)
        local tex = self:GetNormalTexture()
        if tex then tex:SetVertexColor(1, 1, 1) end
    end)
    btn:SetScript("OnClick", DepositToResourceBank)
    btn:Hide()

    mainFrame.tradeGoodsDepositBtn = btn
    return btn
end

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
-- Persistent Slot-Button Map
-- =============================================================================
--
-- ʕ •ᴥ•ʔ✿ Why this exists ✿ ʕ •ᴥ•ʔ
--
-- ContainerFrameItemButtonTemplate is a protected frame. Structural ops
-- (SetParent, SetPoint, ClearAllPoints, SetID, Show, Hide) are forbidden
-- during combat. The ONLY way to guarantee a new item arriving mid-combat
-- is still clickable is to pre-allocate a button for every physical bag
-- slot out-of-combat, then touch ONLY insecure state (SetAlpha, icon,
-- count) when combat fills or empties it.

local OVERFLOW_ROW_GAP = 4
local EMPTY_SLOT_ALPHA = 1

local function GetSlotButton(bagID, slotID)
    local byBag = slotButtons[bagID]
    if not byBag then return nil end
    return byBag[slotID]
end
Frame._GetSlotButton = GetSlotButton

local function CreateSlotButton(bagID, slotID)
    if InCombat() then return nil end

    local container = GetItemContainer(bagID)
    if not container then return nil end

    local btn
    if Omni.Pool then
        btn = Omni.Pool:Acquire("ItemButton")
    end
    if not btn and Omni.ItemButton then
        btn = Omni.ItemButton:Create(container)
    end
    if not btn then return nil end

    pcall(function()
        if btn:GetParent() ~= container then
            btn:SetParent(container)
        end
        if btn.SetID then btn:SetID(slotID) end
        ApplyItemButtonMetrics(btn, GetSavedItemScale())
        btn:ClearAllPoints()
        btn:SetAlpha(0)
        btn:Show()
    end)

    btn.bagID = bagID
    btn.slotID = slotID

    return btn
end

-- ʕ ◕ᴥ◕ ʔ Ensure every physical bag slot has a persistent button. Called
-- OOC from RenderFlowView. Grows on bag upgrades and releases surplus
-- buttons back to the pool when a bag is swapped for something smaller.
local function EnsureSlotButtons()
    if InCombat() then return end

    for _, bagID in ipairs(BAG_IDS) do
        slotButtons[bagID] = slotButtons[bagID] or {}
        local byBag = slotButtons[bagID]
        local numSlots = GetContainerNumSlots(bagID) or 0

        for slotID = 1, numSlots do
            if not byBag[slotID] then
                byBag[slotID] = CreateSlotButton(bagID, slotID)
            end
        end

        for slotID, btn in pairs(byBag) do
            if slotID > numSlots then
                if Omni.Pool then
                    Omni.Pool:Release("ItemButton", btn)
                else
                    pcall(btn.Hide, btn)
                end
                byBag[slotID] = nil
            end
        end
    end
end
Frame._EnsureSlotButtons = EnsureSlotButtons

local function IterateSlotButtons(callback)
    for _, bagID in ipairs(BAG_IDS) do
        local byBag = slotButtons[bagID]
        if byBag then
            for slotID, btn in pairs(byBag) do
                if btn then
                    callback(bagID, slotID, btn)
                end
            end
        end
    end
end
Frame._IterateSlotButtons = IterateSlotButtons

-- =============================================================================
-- Footer
-- =============================================================================

-- ʕ •ᴥ•ʔ✿ Footer custom launcher buttons ✿ ʕ •ᴥ•ʔ
local FOOTER_BTN_SIZE = 20
local FOOTER_BTN_GAP = 3
local FOOTER_SEP_GAP = 5

local FOOTER_CUSTOM_BUTTONS = {
    {
        key     = "resetInstances",
        icon    = "Interface\\Icons\\Achievement_Boss_Murmur",
        title   = "Reset Instances",
        sub     = "Teleports out of the current LFG dungeon (if any) and resets all instances.",
        onClick = function()
            if type(_G.LFGTeleport) == "function" and type(_G.IsInLFGDungeon) == "function" then
                LFGTeleport(IsInLFGDungeon())
            end
            if type(_G.ResetInstances) == "function" then
                _G.ResetInstances()
            end
        end,
    },
    { key = "transmog",     icon = "Interface\\Icons\\INV_Mask_01",             title = "Transmog",       sub = "Open the transmog window",     fn = "OpenTransmog"        },
    { key = "perks",        icon = "Interface\\Icons\\Spell_Arcane_MindMastery", title = "Perks",          sub = "Open the perk manager",         fn = "OpenPerkMgr"         },
    { key = "lootFilter",   icon = "Interface\\Icons\\INV_Misc_Coin_17",        title = "Loot Filter",    sub = "Open the loot filter",          fn = "OpenLootFilter"      },
    { key = "resourceBank", icon = "Interface\\Icons\\INV_Misc_PlatnumDisks",   title = "Resource Bank",  sub = "Open resource summary",         fn = "OpenResourceSummary" },
    { key = "lootDb",       icon = "Interface\\Icons\\INV_Misc_Coin_18",        title = "Loot Database",  sub = "Search the loot database",      fn = "OpenLootDb"          },
    { key = "attuneMgr",    icon = "Interface\\Icons\\Ability_Townwatch",       title = "Attunables",     sub = "Open the attunable item list",  fn = "OpenAttuneMgr"       },
    { key = "leaderboard",  icon = "Interface\\Icons\\INV_Misc_Trophy_Argent",  title = "Leaderboard",    sub = "Open the leaderboards",         fn = "OpenLeaderboards"    },
}

-- ʕ •ᴥ•ʔ✿ Third-party addon launcher ribbon (each entry owns its click).
-- isAvailable gates visibility so we never show a broken tile. ✿ ʕ •ᴥ•ʔ
local FOOTER_ADDON_BUTTONS = {
    {
        key         = "scootsCraft",
        icon        = "Interface\\AddOns\\ScootsCraft\\Textures\\MinimapButton",
        title       = "ScootsCraft",
        sub         = "Toggle the ScootsCraft window",
        trimIcon    = false,
        isAvailable = function()
            return type(_G.ScootsCraft) == "table"
                and type(_G.ScootsCraft.interface) == "table"
                and type(_G.ScootsCraft.interface.toggle) == "function"
        end,
        onClick = function()
            if type(_G.ScootsCraft) == "table"
                and type(_G.ScootsCraft.interface) == "table"
                and type(_G.ScootsCraft.interface.toggle) == "function" then
                _G.ScootsCraft.interface.toggle()
            else
                print("|cFF00FF00OmniInventory|r: ScootsCraft is not loaded.")
            end
        end,
    },
    {
        key         = "atlasLoot",
        icon        = "Interface\\AddOns\\AtlasLoot\\Images\\AtlasImages\\AtlasIcon",
        title       = "AtlasLoot",
        sub         = "Toggle the AtlasLoot browser",
        trimIcon    = false,
        isAvailable = function()
            if _G.AtlasLootDefaultFrame then return true end
            if type(_G.AtlasLoot) == "table" and type(_G.AtlasLoot.SlashCommand) == "function" then
                return true
            end
            return SlashCmdList ~= nil and type(SlashCmdList["ATLASLOOT"]) == "function"
        end,
        -- ʕ •ᴥ•ʔ✿ Toggle pattern: hide the live frame if up, otherwise fall back
        -- to the slash command so AtlasLoot lazy-loads its modules on first open. ✿ ʕ •ᴥ•ʔ
        onClick = function()
            local frame = _G.AtlasLootDefaultFrame
            if frame and frame:IsShown() then
                frame:Hide()
                return
            end
            if type(_G.AtlasLoot) == "table" and type(_G.AtlasLoot.SlashCommand) == "function" then
                pcall(_G.AtlasLoot.SlashCommand, _G.AtlasLoot, "")
                return
            end
            if SlashCmdList and type(SlashCmdList["ATLASLOOT"]) == "function" then
                SlashCmdList["ATLASLOOT"]("")
                return
            end
            print("|cFF00FF00OmniInventory|r: AtlasLoot is not installed.")
        end,
    },
    {
        key         = "theJournal",
        icon        = "Interface\\Icons\\INV_Misc_Book_06",
        title       = "TheJournal",
        sub         = "Click: Toggle Journal\nDrag item: /testboe (ping friends & guild)",
        isAvailable = function()
            return type(_G.ToggleJournal) == "function"
        end,
        onClick = function()
            if type(_G.ToggleJournal) == "function" then
                _G.ToggleJournal()
            else
                print("|cFF00FF00OmniInventory|r: TheJournal is not installed.")
            end
        end,
        -- ʕ ◕ᴥ◕ ʔ✿ Drop an item to hand its link off to AttuneHelper's /testboe,
        -- which pings friends & guild via QueryItemFromFriends. ✿ ʕ ◕ᴥ◕ ʔ
        onReceiveDrag = function()
            if type(_G.GetCursorInfo) ~= "function" then return end
            local ctype, _, link = _G.GetCursorInfo()
            if ctype ~= "item" or not link then return end
            if _G.ClearCursor then _G.ClearCursor() end
            if SlashCmdList and type(SlashCmdList["TESTBOE"]) == "function" then
                SlashCmdList["TESTBOE"](link)
            else
                print("|cFF00FF00OmniInventory|r: /testboe unavailable (AttuneHelper required).")
            end
        end,
    },
}

local function IsFooterCustomButtonEnabled(key)
    local global = OmniInventoryDB and OmniInventoryDB.global
    if not global then return true end
    global.footerButtons = global.footerButtons or {}
    if global.footerButtons[key] == nil then
        global.footerButtons[key] = true
    end
    return global.footerButtons[key] ~= false
end

local function IsFooterAddonButtonEnabled(key)
    local global = OmniInventoryDB and OmniInventoryDB.global
    if not global then return true end
    global.addonButtons = global.addonButtons or {}
    if global.addonButtons[key] == nil then
        global.addonButtons[key] = true
    end
    return global.addonButtons[key] ~= false
end

local function StyleFooterMiniButton(btn)
    btn:SetBackdrop({
        edgeFile = "Interface\\Buttons\\UI-Quickslot-Depress",
        edgeSize = 2,
        insets = { left = -1, right = -1, top = -1, bottom = -1 },
    })
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)

    btn:HookScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.9, 0.8, 0.2, 1)
        if self._tooltipTitle then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(self._tooltipTitle, 1, 1, 1)
            if self._tooltipSub then
                GameTooltip:AddLine(self._tooltipSub, 0.8, 0.8, 0.8)
            end
            GameTooltip:Show()
        end
    end)
    btn:HookScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
        GameTooltip:Hide()
    end)
end

local function CreateFooterMiniButton(parent, def)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(FOOTER_BTN_SIZE, FOOTER_BTN_SIZE)

    local trim = def.trimIcon ~= false
    btn:SetNormalTexture(def.icon)
    local normal = btn:GetNormalTexture()
    if normal and normal.SetTexCoord and trim then
        normal:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(def.icon)
    if trim then
        hl:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    hl:SetBlendMode("ADD")
    hl:SetVertexColor(0.25, 0.25, 0.25, 0.4)

    StyleFooterMiniButton(btn)

    btn._tooltipTitle = def.title
    btn._tooltipSub = def.sub
    btn:SetScript("OnMouseDown", function(self)
        local tex = self:GetNormalTexture()
        if tex then tex:SetVertexColor(0.75, 0.75, 0.75) end
    end)
    btn:SetScript("OnMouseUp", function(self)
        local tex = self:GetNormalTexture()
        if tex then tex:SetVertexColor(1, 1, 1) end
    end)

    if type(def.onClick) == "function" then
        btn:SetScript("OnClick", def.onClick)
    else
        btn.__openFn = def.fn
        btn.__closeFn = def.fn:gsub("^Open", "Close")
        btn.__isOpen = false
        btn:SetScript("OnClick", function(self)
            local openFn = _G[self.__openFn]
            local closeFn = _G[self.__closeFn]

            if self.__isOpen and type(closeFn) == "function" then
                closeFn()
                self.__isOpen = false
                return
            end

            if type(openFn) == "function" then
                openFn()
                self.__isOpen = true
            else
                print("|cFF00FF00OmniInventory|r: " .. self.__openFn .. "() is not available on this client.")
            end
        end)
    end

    if type(def.onReceiveDrag) == "function" then
        btn:RegisterForDrag("LeftButton")
        btn:SetScript("OnReceiveDrag", def.onReceiveDrag)
    end
    return btn
end

function Frame:CreateFooter()
    local footer = CreateFrame("Frame", nil, mainFrame)
    footer:SetHeight(FOOTER_HEIGHT)
    footer:SetPoint("BOTTOMLEFT", PADDING, PADDING)
    footer:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)

    footer.bg = footer:CreateTexture(nil, "BACKGROUND")
    footer.bg:SetAllPoints()
    footer.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    footer.bg:SetVertexColor(0.15, 0.15, 0.15, 1)

    footer.topBorder = footer:CreateTexture(nil, "BORDER")
    footer.topBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
    footer.topBorder:SetVertexColor(0.35, 0.35, 0.35, 1)
    footer.topBorder:SetHeight(1)
    footer.topBorder:SetPoint("TOPLEFT", 0, 0)
    footer.topBorder:SetPoint("TOPRIGHT", 0, 0)

    -- ʕ •ᴥ•ʔ✿ FontString has no EnableMouse in 3.3.5a — use a button as hit box for the ! ✿ ʕ •ᴥ•ʔ
    footer.bagFullAlert = CreateFrame("Button", nil, footer)
    footer.bagFullAlert:SetPoint("LEFT", 6, 0)
    footer.bagFullAlert:SetHeight(FOOTER_HEIGHT)
    footer.bagFullAlert:SetWidth(16)
    footer.bagFullAlert:EnableMouse(true)
    footer.bagFullAlert.label = footer.bagFullAlert:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    footer.bagFullAlert.label:SetPoint("CENTER", 0, 0)
    footer.bagFullAlert.label:SetText("!")
    footer.bagFullAlert.label:SetTextColor(1, 0.12, 0.12, 1)
    footer.bagFullAlert:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Bags full", 1, 0.12, 0.12)
        GameTooltip:AddLine("No free inventory slots.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    footer.bagFullAlert:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    footer.bagFullAlert:Hide()

    footer.slots = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footer.slots:SetPoint("LEFT", 6, 0)
    footer.slots:SetText("0/0")

    footer.slotsSep = footer:CreateTexture(nil, "OVERLAY")
    footer.slotsSep:SetTexture("Interface\\Buttons\\WHITE8X8")
    footer.slotsSep:SetVertexColor(0.35, 0.35, 0.35, 1)
    footer.slotsSep:SetSize(1, 14)
    footer.slotsSep:Hide()

    footer.attuneHelperHost = CreateFrame("Frame", nil, footer)
    footer.attuneHelperHost:SetPoint("LEFT", footer.slots, "RIGHT", 8, 0)
    footer.attuneHelperHost:SetSize(96, 24)
    footer.attuneHelperHost:Hide()

    footer.customSep = footer:CreateTexture(nil, "OVERLAY")
    footer.customSep:SetTexture("Interface\\Buttons\\WHITE8X8")
    footer.customSep:SetVertexColor(0.35, 0.35, 0.35, 1)
    footer.customSep:SetSize(1, 14)
    footer.customSep:Hide()

    footer.customButtons = {}
    for _, def in ipairs(FOOTER_CUSTOM_BUTTONS) do
        local btn = CreateFooterMiniButton(footer, def)
        btn:Hide()
        footer.customButtons[def.key] = btn
    end
    footer.customButtonOrder = FOOTER_CUSTOM_BUTTONS

    footer.addonSep = footer:CreateTexture(nil, "OVERLAY")
    footer.addonSep:SetTexture("Interface\\Buttons\\WHITE8X8")
    footer.addonSep:SetVertexColor(0.35, 0.35, 0.35, 1)
    footer.addonSep:SetSize(1, 14)
    footer.addonSep:Hide()

    footer.addonButtons = {}
    for _, def in ipairs(FOOTER_ADDON_BUTTONS) do
        local btn = CreateFooterMiniButton(footer, def)
        btn:Hide()
        btn.__def = def
        footer.addonButtons[def.key] = btn
    end
    footer.addonButtonOrder = FOOTER_ADDON_BUTTONS

    footer.money = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footer.money:SetPoint("RIGHT", -6, 0)
    footer.money:SetText("0g 0s 0c")

    -- ʕ •ᴥ•ʔ✿ Overflow flyout: when ribbon + money can't fit, extra buttons
    -- are re-parented here and revealed above the footer on demand ✿ ʕ •ᴥ•ʔ
    footer.overflowPopup = CreateFrame("Frame", nil, footer)
    footer.overflowPopup:SetFrameStrata("DIALOG")
    footer.overflowPopup:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    footer.overflowPopup:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    footer.overflowPopup:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    footer.overflowPopup:Hide()

    footer.overflowBtn = CreateFrame("Button", nil, footer)
    footer.overflowBtn:SetSize(FOOTER_BTN_SIZE, FOOTER_BTN_SIZE)
    footer.overflowBtn:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
    local overflowTex = footer.overflowBtn:GetNormalTexture()
    if overflowTex then
        overflowTex:SetVertexColor(0.18, 0.18, 0.18, 0.9)
    end
    footer.overflowBtn.label = footer.overflowBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    footer.overflowBtn.label:SetPoint("CENTER")
    footer.overflowBtn.label:SetText(">>")
    StyleFooterMiniButton(footer.overflowBtn)
    footer.overflowBtn._tooltipTitle = "More"
    footer.overflowBtn._tooltipSub   = "Launchers that didn't fit"
    footer.overflowBtn:SetScript("OnClick", function(self)
        local popup = footer.overflowPopup
        if not popup then return end
        if popup:IsShown() then popup:Hide() else popup:Show() end
    end)
    footer.overflowBtn:Hide()

    -- ʕ •ᴥ•ʔ✿ Live reflow when the window is resized; cheap enough per-frame ✿ ʕ •ᴥ•ʔ
    footer:SetScript("OnSizeChanged", function()
        if Frame.UpdateFooterCustomButtons then Frame:UpdateFooterCustomButtons() end
    end)

    mainFrame.footer = footer
end

-- ʕノ•ᴥ•ʔノ Lays out custom + addon launcher buttons between AH embed host and money.
-- Buttons that don't fit are re-parented into an overflow flyout, toggled by a » tile.
local SEP_SLOT_WIDTH     = 1 + FOOTER_SEP_GAP * 2
local MONEY_SAFETY_GAP   = 8
local OVERFLOW_SLOT_COST = FOOTER_BTN_SIZE + FOOTER_BTN_GAP

local function SyncBagFullAlertHitBox(footer)
    local b = footer.bagFullAlert
    if not b or not b.label then return end
    local lw = b.label:GetStringWidth() or 8
    b:SetWidth(math.max(14, lw + 6))
end

local function GetFooterSlotsBlockWidth(footer)
    local w = (footer.slots and footer.slots:GetStringWidth()) or 0
    if footer.bagFullAlert and footer.bagFullAlert:IsShown() then
        w = w + 1 + ((footer.bagFullAlert:GetWidth()) or 14)
    end
    return w
end

local function ComputeRibbonAvailableWidth(footer)
    local footerWidth = footer:GetWidth()
    if not footerWidth or footerWidth <= 0 then
        return math.huge
    end

    local slotsBlock = GetFooterSlotsBlockWidth(footer)
    local leftEdge
    if footer.attuneHelperHost and footer.attuneHelperHost:IsShown() then
        local hostW = footer.attuneHelperHost:GetWidth() or 0
        leftEdge = 6 + slotsBlock + 8 + hostW
    else
        leftEdge = 6 + slotsBlock
    end

    local moneyReserve = (footer.money:GetStringWidth() or 0) + 6 + MONEY_SAFETY_GAP
    return footerWidth - leftEdge - moneyReserve
end

local function CollectRibbonItems(footer)
    local items = {}

    local function appendGroup(orderList, buttonsMap, isEnabledFn, sep)
        local groupHasMember = false
        for _, def in ipairs(orderList) do
            local btn = buttonsMap[def.key]
            if btn then
                local enabled = isEnabledFn(def.key)
                local available = (type(def.isAvailable) ~= "function") or def.isAvailable()
                if enabled and available then
                    if not groupHasMember then
                        groupHasMember = true
                        table.insert(items, { kind = "sep", obj = sep })
                    end
                    table.insert(items, { kind = "btn", obj = btn, def = def })
                else
                    btn:ClearAllPoints()
                    btn:SetParent(footer)
                    btn:Hide()
                end
            end
        end
        if not groupHasMember then
            sep:ClearAllPoints()
            sep:Hide()
        end
    end

    appendGroup(footer.customButtonOrder, footer.customButtons, IsFooterCustomButtonEnabled, footer.customSep)
    appendGroup(footer.addonButtonOrder, footer.addonButtons, IsFooterAddonButtonEnabled, footer.addonSep)
    return items
end

function Frame:UpdateFooterCustomButtons()
    if not mainFrame or not mainFrame.footer then return end
    local footer = mainFrame.footer
    if not footer.customButtons or not footer.addonButtons then return end

    local inlineAnchor, inlineAnchorGap
    if footer.attuneHelperHost and footer.attuneHelperHost:IsShown() then
        inlineAnchor    = footer.attuneHelperHost
        inlineAnchorGap = FOOTER_SEP_GAP
    else
        inlineAnchor    = footer.slots
        inlineAnchorGap = FOOTER_SEP_GAP + 2
    end

    local items = CollectRibbonItems(footer)
    local totalNeededWidth = 0
    for _, item in ipairs(items) do
        if item.kind == "sep" then
            totalNeededWidth = totalNeededWidth + SEP_SLOT_WIDTH
        else
            totalNeededWidth = totalNeededWidth + FOOTER_BTN_SIZE + FOOTER_BTN_GAP
        end
    end

    local available     = ComputeRibbonAvailableWidth(footer)
    local mustOverflow  = totalNeededWidth > available
    local inlineBudget  = mustOverflow and (available - OVERFLOW_SLOT_COST) or available

    local inlinePrev        = nil
    local runningWidth      = 0
    local overflowButtons   = {}
    local lastInlineSep     = nil

    local function placeInline(obj, kind)
        obj:ClearAllPoints()
        obj:SetParent(footer)
        if kind == "sep" then
            if inlinePrev then
                obj:SetPoint("LEFT", inlinePrev, "RIGHT", FOOTER_SEP_GAP, 0)
            else
                obj:SetPoint("LEFT", inlineAnchor, "RIGHT", inlineAnchorGap, 0)
            end
            obj:Show()
            lastInlineSep = obj
            inlinePrev = obj
        else
            if inlinePrev then
                local gap = (inlinePrev == lastInlineSep) and FOOTER_SEP_GAP or FOOTER_BTN_GAP
                obj:SetPoint("LEFT", inlinePrev, "RIGHT", gap, 0)
            else
                obj:SetPoint("LEFT", inlineAnchor, "RIGHT", inlineAnchorGap, 0)
            end
            obj:Show()
            inlinePrev = obj
        end
    end

    for i, item in ipairs(items) do
        local cost = (item.kind == "sep") and SEP_SLOT_WIDTH or (FOOTER_BTN_SIZE + FOOTER_BTN_GAP)
        local nextItem = items[i + 1]

        local wouldOverflow = (runningWidth + cost) > inlineBudget
        -- A sep alone at the tail is meaningless; if the next button won't fit, overflow the sep too
        if item.kind == "sep" and nextItem and nextItem.kind == "btn" then
            local btnCost = FOOTER_BTN_SIZE + FOOTER_BTN_GAP
            if (runningWidth + cost + btnCost) > inlineBudget then
                wouldOverflow = true
            end
        end

        if not mustOverflow or not wouldOverflow then
            placeInline(item.obj, item.kind)
            runningWidth = runningWidth + cost
        else
            if item.kind == "sep" then
                item.obj:ClearAllPoints()
                item.obj:Hide()
            else
                table.insert(overflowButtons, item.obj)
            end
        end
    end

    if mustOverflow and #overflowButtons > 0 then
        local attachAnchor = inlinePrev or inlineAnchor
        local attachGap    = inlinePrev and FOOTER_BTN_GAP or inlineAnchorGap
        footer.overflowBtn:ClearAllPoints()
        footer.overflowBtn:SetPoint("LEFT", attachAnchor, "RIGHT", attachGap, 0)
        footer.overflowBtn:Show()

        local popup = footer.overflowPopup
        local popupPad = 4
        local popupWidth = popupPad * 2 + #overflowButtons * FOOTER_BTN_SIZE + (#overflowButtons - 1) * FOOTER_BTN_GAP
        local popupHeight = popupPad * 2 + FOOTER_BTN_SIZE
        popup:ClearAllPoints()
        popup:SetSize(popupWidth, popupHeight)
        popup:SetPoint("BOTTOMRIGHT", footer.overflowBtn, "TOPRIGHT", 2, 4)

        local prevPopupBtn
        for _, btn in ipairs(overflowButtons) do
            btn:ClearAllPoints()
            btn:SetParent(popup)
            if prevPopupBtn then
                btn:SetPoint("LEFT", prevPopupBtn, "RIGHT", FOOTER_BTN_GAP, 0)
            else
                btn:SetPoint("LEFT", popupPad, 0)
            end
            btn:Show()
            prevPopupBtn = btn
        end
    else
        footer.overflowBtn:ClearAllPoints()
        footer.overflowBtn:Hide()
        footer.overflowPopup:Hide()
    end
end

function Frame:UpdateEmbeddedAttuneHelper()
    if not mainFrame or not mainFrame.footer then return end
    local host = mainFrame.footer.attuneHelperHost
    if not host then return end

    if not IsAttuneHelperEmbedEnabled() or not mainFrame:IsShown() then
        RestoreEmbeddedAttuneHelper()
        if self.UpdateFooterCustomButtons then self:UpdateFooterCustomButtons() end
        return
    end

    local miniFrame = _G.AttuneHelperMiniFrame
    if not miniFrame then
        host:Hide()
        if self.UpdateFooterCustomButtons then self:UpdateFooterCustomButtons() end
        return
    end

    _G.AttuneHelperDB = _G.AttuneHelperDB or {}
    if _G.AttuneHelperDB["Mini Mode"] ~= 1 then
        _G.AttuneHelperDB["Mini Mode"] = 1
    end

    if _G.AttuneHelper_UpdateDisplayMode then
        _G.AttuneHelper_UpdateDisplayMode()
    elseif _G.AttuneHelperFrame then
        _G.AttuneHelperFrame:Hide()
    end

    if not miniFrame.__OmniEmbedHooked then
        miniFrame.__OmniEmbedHooked = true
        miniFrame:HookScript("OnShow", function(frame)
            if not mainFrame or not mainFrame.footer or not mainFrame.footer.attuneHelperHost then
                return
            end
            if not IsAttuneHelperEmbedEnabled() or not mainFrame:IsShown() then
                return
            end
            local embedHost = mainFrame.footer.attuneHelperHost
            if frame:GetParent() ~= embedHost then
                frame:SetParent(embedHost)
            end
            frame:ClearAllPoints()
            frame:SetPoint("LEFT", embedHost, "LEFT", 0, 0)
            ApplyEmbeddedMiniBorderStyle(frame)
            embedHost:SetSize(frame:GetWidth(), frame:GetHeight())
            embedHost:Show()
            RebindEmbeddedDragHandlers()
            if Frame.UpdateFooterCustomButtons then Frame:UpdateFooterCustomButtons() end
        end)
    end

    miniFrame:SetParent(host)
    miniFrame:ClearAllPoints()
    miniFrame:SetPoint("LEFT", host, "LEFT", 0, 0)
    ApplyEmbeddedMiniBorderStyle(miniFrame)
    miniFrame:SetFrameStrata(mainFrame:GetFrameStrata())
    miniFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 40)
    miniFrame:SetMovable(false)
    miniFrame:EnableMouse(false)
    miniFrame:Show()

    host:SetSize(miniFrame:GetWidth(), miniFrame:GetHeight())
    host:Show()

    RebindEmbeddedDragHandlers()
    if self.UpdateFooterCustomButtons then self:UpdateFooterCustomButtons() end
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
        if Frame.UpdateFooterCustomButtons then Frame:UpdateFooterCustomButtons() end
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

function Frame:GetScale()
    if mainFrame and mainFrame.GetScale then
        return mainFrame:GetScale()
    end
    local settings = OmniInventoryDB and OmniInventoryDB.char and OmniInventoryDB.char.settings
    return settings and settings.scale or 1
end

function Frame:GetItemScale()
    return GetSavedItemScale()
end

function Frame:SetItemScale(scale)
    if InCombat() then return false end
    scale = math.max(ITEM_SCALE_MIN, math.min(scale or 1, ITEM_SCALE_MAX))

    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.char = OmniInventoryDB.char or {}
    OmniInventoryDB.char.settings = OmniInventoryDB.char.settings or {}
    OmniInventoryDB.char.settings.itemScale = scale

    IterateSlotButtons(function(_, _, btn)
        ApplyItemButtonMetrics(btn, scale)
    end)

    self:UpdateLayout()
    return true
end

function Frame:GetItemGap()
    return GetSavedItemGap()
end

function Frame:SetItemGap(gap)
    if InCombat() then return false end
    gap = math.max(ITEM_GAP_MIN, math.min(gap or ITEM_SPACING, ITEM_GAP_MAX))

    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.char = OmniInventoryDB.char or {}
    OmniInventoryDB.char.settings = OmniInventoryDB.char.settings or {}
    OmniInventoryDB.char.settings.itemGap = gap

    self:UpdateLayout()
    return true
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

    -- ʕ •ᴥ•ʔ✿ Any explicit view change away from "bag" invalidates the
    -- remembered pre-bag view -- otherwise a later bag toggle could
    -- restore to a view the user has since moved past. ✿ ʕ •ᴥ•ʔ
    if currentView ~= "bag" then
        preBagViewMode = nil
    end

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
-- Combat-safe in-place content refresh
-- =============================================================================

-- ʕ ◕ᴥ◕ ʔ Combat-safe refresh. Walks the persistent slotButtons map (one
-- entry per physical bag slot, pre-parented and SetID'd OOC) and mirrors
-- the live container state onto each button using ONLY insecure calls
-- (SetAlpha + ItemButton:SetItem). Items that pop in during combat become
-- visible and clickable at whatever position the last OOC render parked
-- their slot button (their sorted home, or the overflow strip for slots
-- that were empty at last render). Items used during combat clear by
-- fading to alpha 0.
--
-- SetParent / SetPoint / SetID / Show / Hide are NEVER called here --
-- those are protected on ContainerFrameItemButtonTemplate children.
function Frame:RefreshCombatContent(changedBags)
    if not mainFrame or not OmniC_Container then return end

    -- ʕ •ᴥ•ʔ✿ List view parks all slot buttons at alpha 0 and drives its
    -- own insecure row widgets -- which are OOC-only anyway (list row
    -- clicks call PickupContainerItem directly and are blocked in combat).
    -- Flipping slot-button alpha here would punch ghost icons through the
    -- list layout, so we short-circuit and let PLAYER_REGEN_ENABLED do a
    -- clean full re-render once combat ends. ✿ ʕ •ᴥ•ʔ
    if currentView == "list" then
        self:UpdateSlotCount()
        self:UpdateMoney()
        return
    end

    local affected
    if type(changedBags) == "table" then
        local hasEntries = false
        for _ in pairs(changedBags) do hasEntries = true break end
        if hasEntries and not changedBags._trigger then
            affected = changedBags
        end
    end

    -- ʕ •ᴥ•ʔ✿ Rebuild the populated-button list so search / cooldown passes
    -- that run during combat see every visible item, including ones that
    -- arrived after the last OOC render. ✿ ʕ •ᴥ•ʔ
    local refreshed = {}
    local meta = {
        requiresFlowRelayout = false,
    }

    IterateSlotButtons(function(bagID, slotID, btn)
        local info
        if affected == nil or affected[bagID] then
            local previousInfo = btn.itemInfo
            info = OmniC_Container.GetContainerItemInfo(bagID, slotID)
            if info then
                if Omni.Categorizer then
                    info.category = info.category or Omni.Categorizer:GetCategory(info)
                end
                info.isQuickFiltered = btn.itemInfo and btn.itemInfo.isQuickFiltered or false
                if currentView == "flow"
                        and not meta.requiresFlowRelayout
                        and DoesFlowSlotChangeRequireRelayout(previousInfo, info) then
                    meta.requiresFlowRelayout = true
                end
                SetButtonItem(btn, info)
                pcall(btn.SetAlpha, btn, 1)
                table.insert(refreshed, btn)
            else
                if currentView == "flow"
                        and not meta.requiresFlowRelayout
                        and DoesFlowSlotChangeRequireRelayout(previousInfo, nil) then
                    meta.requiresFlowRelayout = true
                end
                SetButtonItem(btn, nil)
                pcall(btn.SetAlpha, btn, 0)
            end
        else
            if btn.itemInfo then
                table.insert(refreshed, btn)
            end
        end
    end)

    itemButtons = refreshed

    self:UpdateSlotCount()
    self:UpdateMoney()

    return meta
end

function Frame:SnapshotBagSlotState(bagID, slotID)
    return GetBagSlotStateKey(bagID, slotID)
end

function Frame:RequestOptimisticFlowRefresh(bagID, slotID, options)
    if not mainFrame or not mainFrame:IsShown() or InCombat() or currentView ~= "flow" then
        return false
    end
    if not bagID or not slotID or bagID < 0 or bagID > 4 or slotID < 1 then
        return false
    end

    local stateKey = options and options.stateKey or GetBagSlotStateKey(bagID, slotID)
    if not stateKey then
        return false
    end

    local watchKey = tostring(bagID) .. ":" .. tostring(slotID)
    optimisticFlowRefreshWatches[watchKey] = {
        bagID = bagID,
        slotID = slotID,
        stateKey = stateKey,
        elapsed = 0,
        waitForCursorClear = options and options.waitForCursorClear == true or false,
    }

    StartOptimisticFlowRefreshWatcher()
    return true
end

-- =============================================================================
-- Layout Update
-- =============================================================================

function Frame:UpdateLayout(changedBags, opts)
    if not mainFrame then return end
    local perfTotal = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("frame.UpdateLayout.total")
    local forceFull = opts and opts.forceFull == true
    local updateReason = (opts and opts.reason) or "layout"
    if not forceFull and mainFrame.IsShown and not mainFrame:IsShown() then
        if Omni._perfEnabled and Omni.Perf then
            Omni.Perf:End("frame.UpdateLayout.total", perfTotal, { skipped = "hidden", reason = updateReason })
        end
        return
    end

    -- ʕ •ᴥ•ʔ✿ Combat policy ✿ ʕ •ᴥ•ʔ
    -- Structural ops on ContainerFrameItemButton children (SetParent,
    -- SetID, SetPoint, ClearAllPoints) are protected during combat, so
    -- we cannot re-run the flow/grid layout. Content updates (icon,
    -- count, border color, tooltip-resolving bagID/slotID pair) ARE
    -- insecure, so we mirror AdiBags: refresh contents of existing
    -- slot buttons in place. Items sold during combat clear visually
    -- and items that change in a known slot update their tooltip
    -- instantly. Any fresh slots that had no button at the last OOC
    -- render are still deferred to PLAYER_REGEN_ENABLED.
    if InCombat() then
        pendingCombatRender = true
        if hasRenderedOnce then
            if mainFrame.combatHint then mainFrame.combatHint:Hide() end
            self:RefreshCombatContent(changedBags)
        elseif mainFrame:IsShown() and mainFrame.combatHint then
            mainFrame.combatHint:Show()
            mainFrame.combatHint:SetText("Bag contents will appear after combat.")
        end
        return
    end

    if burstRefreshPending and not (IsMerchantOpen() or HasBagChangeEntries(changedBags)) then
        StopBurstFullRefresh()
    end

    if not forceFull
            and hasRenderedOnce
            and HasBagChangeEntries(changedBags)
            and currentView ~= "list" then
        local refreshMeta = self:RefreshCombatContent(changedBags)
        local shouldForceFlowRelayout = currentView == "flow"
            and refreshMeta
            and refreshMeta.requiresFlowRelayout == true
        if shouldForceFlowRelayout then
            StopBurstFullRefresh()
            lastOptimisticFlowRefreshAt = (GetTime and GetTime()) or 0
            forceFull = true
        end

        if not forceFull then
            local now = (GetTime and GetTime()) or 0
            local suppressBurst = currentView == "flow"
                and lastOptimisticFlowRefreshAt > 0
                and now > 0
                and (now - lastOptimisticFlowRefreshAt) <= OPTIMISTIC_FLOW_REFRESH_SUPPRESS_WINDOW
            if not suppressBurst then
                RequestBurstFullRefresh()
            end
            return
        end
    end

    if mainFrame.combatHint then
        mainFrame.combatHint:Hide()
    end

    local items = {}
    local perfCollect = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("frame.UpdateLayout.collect")
    if OmniC_Container then
        items = OmniC_Container.GetAllBagItems()
    end
    if Omni._perfEnabled and Omni.Perf then
        Omni.Perf:End("frame.UpdateLayout.collect", perfCollect, { itemCount = #items, reason = updateReason })
    end

    -- Categorize items
    if Omni.Categorizer then
        local perfCategorize = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("frame.UpdateLayout.categorize")
        for _, item in ipairs(items) do
            item.category = item.category or Omni.Categorizer:GetCategory(item)
        end
        if Omni._perfEnabled and Omni.Perf then
            Omni.Perf:End("frame.UpdateLayout.categorize", perfCategorize, { reason = updateReason })
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

    -- ʕ •ᴥ•ʔ✿ Collect the set of categories actually present so the
    -- dynamic tab bar below only shows filters that would return
    -- something. Do this AFTER the bag filter so tabs reflect the
    -- currently-viewed scope. ✿ ʕ •ᴥ•ʔ
    local presentCategories = {}
    for _, item in ipairs(items) do
        if item.category then
            presentCategories[item.category] = true
        end
    end
    self:RebuildFilterTabs(presentCategories)

    -- ʕ •ᴥ•ʔ✿ Quick filter handling.
    --
    -- Out of combat, a category tab doesn't dim non-matches anymore --
    -- it re-orders the layout so the selected category pins to the
    -- top-left and everything else flows below it (handled in
    -- RenderFlowView via the `pinnedLaneTop` hint). Clicking the tab
    -- again toggles the filter off and the bag sorts back to normal.
    --
    -- In combat we can't restructure the layout safely, so we fall
    -- Exact equality matches stop "Attunable" from catching
    -- "Account Attunable" via substring. ✿ ʕ •ᴥ•ʔ
    -- ʕ •ᴥ•ʔ✿ When a filter tab is active, always dim the non-matching
    -- items so the selection pops. In flow mode OOC we ALSO re-order
    -- (the selected category gets pinned top-left by RenderFlowView's
    -- LPT block), so the user sees the filter both promoted and the
    -- rest grayed out in place. If the category later empties out,
    -- RebuildFilterTabs clears activeFilter and the dim goes with it. ✿ ʕ •ᴥ•ʔ
    local quickFilter = self:GetActiveFilter()
    if quickFilter then
        for _, item in ipairs(items) do
            local matches = item.category == quickFilter
            item.isQuickFiltered = not matches
        end
    else
        for _, item in ipairs(items) do
            item.isQuickFiltered = false
        end
    end

    -- Sort items
    if Omni.Sorter then
        local perfSort = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("frame.UpdateLayout.sort")
        items = Omni.Sorter:Sort(items, Omni.Sorter:GetDefaultMode())
        if Omni._perfEnabled and Omni.Perf then
            Omni.Perf:End("frame.UpdateLayout.sort", perfSort, { itemCount = #items, reason = updateReason })
        end
    end

    -- Render based on view mode
    if currentView == "list" then
        local perfRenderList = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("frame.UpdateLayout.renderList")
        self:RenderListView(items)
        if Omni._perfEnabled and Omni.Perf then
            Omni.Perf:End("frame.UpdateLayout.renderList", perfRenderList, { reason = updateReason })
        end
    else
        -- Combined Grid/Flow rendering
        local perfRenderFlow = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("frame.UpdateLayout.renderFlow")
        self:RenderFlowView(items)
        if Omni._perfEnabled and Omni.Perf then
            Omni.Perf:End("frame.UpdateLayout.renderFlow", perfRenderFlow, { reason = updateReason })
        end
    end

    -- Update footer
    self:UpdateBagIconTextures()
    self:UpdateBagIconVisuals()
    self:UpdateSlotCount()
    self:UpdateMoney()

    -- Apply search if active
    if searchText and searchText ~= "" then
        local perfSearch = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("frame.UpdateLayout.search")
        self:ApplySearch(searchText)
        if Omni._perfEnabled and Omni.Perf then
            Omni.Perf:End("frame.UpdateLayout.search", perfSearch, { reason = updateReason })
        end
    end

    hasRenderedOnce = true
    pendingCombatRender = false
    if Omni._perfEnabled and Omni.Perf then
        Omni.Perf:End("frame.UpdateLayout.total", perfTotal, {
            itemCount = #items,
            view = currentView or "unknown",
            quickFilter = self:GetActiveFilter() or "none",
            reason = updateReason,
        })
    end
end

-- =============================================================================
-- Flow/Grid View Rendering
-- =============================================================================

function Frame:RenderFlowView(items)
    if not mainFrame or not mainFrame.scrollChild then return end

    local scrollChild = mainFrame.scrollChild

    -- ʕ •ᴥ•ʔ✿ Make sure every physical bag slot has a persistent button
    -- before we begin. This is the foundation of combat safety: any item
    -- that lands in any slot already has a pre-parented, pre-SetID button
    -- ready to accept content updates from RefreshCombatContent without
    -- needing a protected structural call. ✿ ʕ •ᴥ•ʔ
    EnsureSlotButtons()

    ClearArray(itemButtons)

    local categories = renderScratch.categories
    local categoryOrder = renderScratch.categoryOrder
    local touched = renderScratch.touched
    local usedCategoryKeys = renderScratch.usedCategoryKeys
    local usedTouchedBags = renderScratch.usedTouchedBags
    local headerByCategory = renderScratch.headerByCategory
    local seenCategoryThisPass = {}
    local seenTouchedBagsThisPass = {}

    for i = 1, #usedCategoryKeys do
        local key = usedCategoryKeys[i]
        local bucket = categories[key]
        if bucket then
            ClearArray(bucket)
        end
    end
    ClearArray(usedCategoryKeys)
    for i = 1, #usedTouchedBags do
        local bagID = usedTouchedBags[i]
        local bagTouched = touched[bagID]
        if bagTouched then
            ClearMap(bagTouched)
        end
    end
    ClearArray(usedTouchedBags)
    ClearArray(categoryOrder)
    ClearMap(headerByCategory)

    local freezeHeadersForVendor = false
    -- Hide existing headers and list rows
    for _, header in ipairs(categoryHeaders) do header:Hide() end
    for _, row in ipairs(listRows) do row:Hide() end
    if mainFrame.tradeGoodsDepositBtn then mainFrame.tradeGoodsDepositBtn:Hide() end

    local hInset = 8
    local usableWidth = mainFrame.content:GetWidth() - hInset
    local itemGap = self:GetItemGap()
    local sectionHeaderHeight = (currentView == "grid") and 0 or 20 -- No headers in grid mode
    local sectionSpacing = (currentView == "grid") and itemGap or 8
    local dualCategoryLanes = (currentView ~= "grid")
    local laneGap = 10
    local itemScale = self:GetItemScale()
    local itemSize = ITEM_SIZE * itemScale
    local itemStep = itemSize + itemGap

    local function columnsForLaneWidth(laneW)
        local inner = laneW - itemGap
        local c = math.floor(inner / itemStep)
        return math.max(c, 1)
    end

    local yLeft = -itemGap
    local yRight = -itemGap
    local yOffset = -itemGap

    local itemBySlot = nil
    local bagSlotCounts = nil
    local bagItemCounts = nil

    if currentView == "grid" then
        -- ʕ •ᴥ•ʔ✿ Bagnon-like grid: keep physical slot order and render empty
        -- slots inline so players always see full bag capacity. ✿ ʕ •ᴥ•ʔ
        itemBySlot = {}
        categories["All"] = categories["All"] or {}
        seenCategoryThisPass["All"] = true
        usedCategoryKeys[#usedCategoryKeys + 1] = "All"
        categoryOrder[1] = "All"

        for _, itemInfo in ipairs(items) do
            if IsValidBagID(itemInfo.bagID) and itemInfo.slotID and itemInfo.slotID > 0 then
                itemBySlot[itemInfo.bagID] = itemBySlot[itemInfo.bagID] or {}
                itemBySlot[itemInfo.bagID][itemInfo.slotID] = itemInfo
            end
        end

        for _, bagID in ipairs(BAG_IDS) do
            local numSlots = GetContainerNumSlots(bagID) or 0
            for slotID = 1, numSlots do
                local info = itemBySlot[bagID] and itemBySlot[bagID][slotID] or nil
                table.insert(categories["All"], info or { bagID = bagID, slotID = slotID, __empty = true })
            end
        end
    elseif currentView == "bag" then
        itemBySlot = {}
        bagSlotCounts = {}
        bagItemCounts = {}
        local bagScope = {}

        if IsValidBagID(selectedBagID) then
            table.insert(bagScope, selectedBagID)
        else
            for _, bagID in ipairs(BAG_IDS) do
                table.insert(bagScope, bagID)
            end
        end

        for _, bagID in ipairs(bagScope) do
            categories[bagID] = categories[bagID] or {}
            seenCategoryThisPass[bagID] = true
            usedCategoryKeys[#usedCategoryKeys + 1] = bagID
            table.insert(categoryOrder, bagID)
            bagSlotCounts[bagID] = GetContainerNumSlots(bagID) or 0
            bagItemCounts[bagID] = 0
        end

        for _, item in ipairs(items) do
            if IsValidBagID(item.bagID) then
                itemBySlot[item.bagID] = itemBySlot[item.bagID] or {}
                itemBySlot[item.bagID][item.slotID] = item
                bagItemCounts[item.bagID] = (bagItemCounts[item.bagID] or 0) + 1
            end
        end

        for _, bagID in ipairs(bagScope) do
            local totalSlots = bagSlotCounts[bagID] or 0
            for slotID = 1, totalSlots do
                local info = itemBySlot[bagID] and itemBySlot[bagID][slotID] or nil
                table.insert(categories[bagID], info or { bagID = bagID, slotID = slotID, __empty = true })
            end
        end
    else
        -- FLOW MODE: Group by assigned category
        for _, item in ipairs(items) do
            local cat = item.category or "Miscellaneous"
            if not seenCategoryThisPass[cat] then
                categories[cat] = categories[cat] or {}
                seenCategoryThisPass[cat] = true
                usedCategoryKeys[#usedCategoryKeys + 1] = cat
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

        -- ʕ •ᴥ•ʔ✿ Keep BoE inside the dual-lane flow, but pin it to the
        -- tail of the priority order so it's the final section rendered.
        -- We still render the BoE header even when the player holds zero
        -- BoE equipment -- the overflow strip (where every pre-parked
        -- empty slot button lives) anchors to BoE's lane, so any item
        -- that lands in a previously empty slot during combat visually
        -- appears under "BoE" inside its half-width lane. ✿ ʕ •ᴥ•ʔ
        local reordered = {}
        for _, catName in ipairs(categoryOrder) do
            if catName ~= "BoE" then
                table.insert(reordered, catName)
            end
        end
        categories["BoE"] = categories["BoE"] or {}
        table.insert(reordered, "BoE")
        categoryOrder = reordered

        if IsMerchantOpen() then
            if not vendorFlowLayoutFreeze then
                local frozenOrder = {}
                local seedOrder = (flowLayoutCache and flowLayoutCache.order) or categoryOrder
                for _, catName in ipairs(seedOrder) do
                    frozenOrder[#frozenOrder + 1] = catName
                end
                vendorFlowLayoutFreeze = {
                    order = frozenOrder,
                    laneAssignment = flowLayoutCache and flowLayoutCache.laneAssignment or nil,
                }
            else
                local frozenSeen = {}
                local finalOrder = {}
                for _, catName in ipairs(vendorFlowLayoutFreeze.order or {}) do
                    finalOrder[#finalOrder + 1] = catName
                    frozenSeen[catName] = true
                    categories[catName] = categories[catName] or {}
                end
                for _, catName in ipairs(categoryOrder) do
                    if not frozenSeen[catName] then
                        finalOrder[#finalOrder + 1] = catName
                        frozenSeen[catName] = true
                    end
                end
                vendorFlowLayoutFreeze.order = finalOrder
                categoryOrder = finalOrder
            end
        else
            vendorFlowLayoutFreeze = nil
        end
    end

    local headerIndex = 0
    -- ʕ •ᴥ•ʔ✿ BoE tail anchor: captured when we render the BoE section
    -- so the overflow strip below can slot in under BoE's lane at
    -- BoE's own half-width. ✿ ʕ •ᴥ•ʔ
    local boeAnchor = nil
    local flowMode = (currentView ~= "grid" and currentView ~= "bag")
    local merchantOpen = IsMerchantOpen()
    if not flowMode then
        vendorFlowLayoutFreeze = nil
    end
    if flowMode and merchantOpen and not wasMerchantOpen and flowLayoutCache then
        local seededOrder = {}
        local cachedOrder = flowLayoutCache.order or categoryOrder
        for _, catName in ipairs(cachedOrder or {}) do
            seededOrder[#seededOrder + 1] = catName
        end
        vendorFlowLayoutFreeze = {
            order = seededOrder,
            laneAssignment = flowLayoutCache.laneAssignment or nil,
        }
    end
    local compositionSignature = nil
    local canReuseLaneAssignment = false

    if flowMode then
        compositionSignature = BuildFlowCompositionSignature(
            categories,
            categoryOrder,
            usableWidth,
            itemStep,
            activeFilter
        )
        freezeHeadersForVendor = merchantOpen
            and flowLayoutCache ~= nil
            and flowLayoutCache.signature == compositionSignature
        canReuseLaneAssignment = flowLayoutCache
            and flowLayoutCache.signature == compositionSignature
            and flowLayoutCache.laneAssignment ~= nil
    end

    -- ʕ ◕ᴥ◕ ʔ✿ LPT (Longest Processing Time first) lane partitioning for
    -- flow mode. We predict each section's height, sort categories by
    -- height descending, and greedily assign each to the currently
    -- shorter lane. That places the tallest sections at the top of each
    -- lane and folds smaller categories into whichever side still has
    -- room -- otherwise a single giant category (e.g. Attunable with 50
    -- items) sinks one lane entirely while everything else stacks on
    -- the other, wasting half the frame.
    --
    -- BoE is included in the LPT partition (so its own size balances
    -- correctly), then bubbled to the end of whichever lane it landed
    -- on so the overflow strip still anchors at the bottom of BoE's
    -- lane for combat-safe slot appearance. ✿ ʕ ◕ᴥ◕ ʔ
    local laneAssignment = nil
    local forceVendorFrozenLanes = flowMode
        and merchantOpen
        and vendorFlowLayoutFreeze ~= nil
        and vendorFlowLayoutFreeze.laneAssignment ~= nil
    if flowMode and dualCategoryLanes and #categoryOrder > 1 then
        if forceVendorFrozenLanes then
            laneAssignment = vendorFlowLayoutFreeze.laneAssignment
            canReuseLaneAssignment = true
        elseif canReuseLaneAssignment then
            laneAssignment = flowLayoutCache.laneAssignment
        end
        local laneColumns = columnsForLaneWidth((usableWidth - laneGap) * 0.5)
        local function sectionHeight(catName)
            local n = categories[catName] and #categories[catName] or 0
            if n <= 0 then
                return sectionHeaderHeight + sectionSpacing
            end
            local rows = math.ceil(n / laneColumns)
            return sectionHeaderHeight + rows * itemStep + sectionSpacing
        end
        local function categoryPriority(name)
            if Omni.Categorizer then
                local info = Omni.Categorizer:GetCategoryInfo(name)
                return info and info.priority or 99
            end
            return 99
        end

        -- ʕ ◕ᴥ◕ ʔ✿ Active quick filter? Pin that category to the top of
        -- the left lane and fold every other section around it using
        -- greedy shortest-lane assignment (no LPT rebalance, so the
        -- selected tab stays at top-left as the user requested). The
        -- caller already suppresses item dimming OOC, so this re-order
        -- is the entire "push the filter to top-left" behavior. ✿ ʕ ◕ᴥ◕ ʔ
        local pinnedCategory = nil
        if activeFilter and categories[activeFilter] then
            pinnedCategory = activeFilter
        end

        local leftLane, rightLane = {}, {}
        local leftH, rightH = 0, 0
        if not laneAssignment then
            laneAssignment = {}
        end

        if not canReuseLaneAssignment and pinnedCategory then
            table.insert(leftLane, pinnedCategory)
            laneAssignment[pinnedCategory] = "left"
            leftH = sectionHeight(pinnedCategory)

            local rest = {}
            for _, name in ipairs(categoryOrder) do
                if name ~= pinnedCategory then table.insert(rest, name) end
            end
            table.sort(rest, function(a, b)
                return categoryPriority(a) < categoryPriority(b)
            end)
            for _, name in ipairs(rest) do
                if rightH < leftH then
                    table.insert(rightLane, name)
                    rightH = rightH + sectionHeight(name)
                    laneAssignment[name] = "right"
                else
                    table.insert(leftLane, name)
                    leftH = leftH + sectionHeight(name)
                    laneAssignment[name] = "left"
                end
            end
        elseif not canReuseLaneAssignment then
            -- ʕ •ᴥ•ʔ✿ LPT: sort by predicted height descending, greedy
            -- into shorter lane for balance. Tallest sections land at
            -- the top of each lane. ✿ ʕ •ᴥ•ʔ
            local byHeight = {}
            for _, name in ipairs(categoryOrder) do table.insert(byHeight, name) end
            table.sort(byHeight, function(a, b)
                local ha, hb = sectionHeight(a), sectionHeight(b)
                if ha ~= hb then return ha > hb end
                return categoryPriority(a) < categoryPriority(b)
            end)
            for _, name in ipairs(byHeight) do
                if rightH < leftH then
                    table.insert(rightLane, name)
                    rightH = rightH + sectionHeight(name)
                    laneAssignment[name] = "right"
                else
                    table.insert(leftLane, name)
                    leftH = leftH + sectionHeight(name)
                    laneAssignment[name] = "left"
                end
            end
        end

        -- ʕ •ᴥ•ʔ✿ Render order: left lane top-to-bottom, then right lane
        -- top-to-bottom. Each section's lane is fixed by laneAssignment
        -- below so the render loop ignores live y-based greedy. ✿ ʕ •ᴥ•ʔ
        if canReuseLaneAssignment then
            local leftOrdered = {}
            local rightOrdered = {}
            for _, name in ipairs(categoryOrder) do
                if laneAssignment[name] == "right" then
                    table.insert(rightOrdered, name)
                else
                    table.insert(leftOrdered, name)
                end
            end
            local final = {}
            for _, n in ipairs(leftOrdered) do table.insert(final, n) end
            for _, n in ipairs(rightOrdered) do table.insert(final, n) end
            categoryOrder = final
        else
            local final = {}
            for _, n in ipairs(leftLane) do table.insert(final, n) end
            for _, n in ipairs(rightLane) do table.insert(final, n) end
            categoryOrder = final
        end
    end


    for _, catName in ipairs(categoryOrder) do
        local catItems = categories[catName]
        local isBoeAnchor = (flowMode and catName == "BoE")
        if catItems and (#catItems > 0 or isBoeAnchor) then
            local laneX, laneY, columns, laneW
            local useRight = false
            if dualCategoryLanes then
                laneW = (usableWidth - laneGap) * 0.5
                local edgePad = hInset * 0.5
                local leftX = edgePad + itemGap
                local rightX = edgePad + laneW + laneGap + itemGap
                -- ʕ •ᴥ•ʔ✿ Prefer the pre-computed LPT lane assignment
                -- (flow mode). If we don't have one (bag mode), fall
                -- back to a live greedy shortest-lane check: y values
                -- grow more negative as content stacks, so the larger
                -- (less negative) y has more room. Ties go left. ✿ ʕ •ᴥ•ʔ
                if laneAssignment and laneAssignment[catName] then
                    useRight = (laneAssignment[catName] == "right")
                else
                    useRight = (yRight > yLeft)
                end
                laneX = useRight and rightX or leftX
                laneY = useRight and yRight or yLeft
                columns = columnsForLaneWidth(laneW)
            else
                laneW = usableWidth
                laneX = itemGap
                laneY = yOffset
                columns = columnsForLaneWidth(usableWidth)
            end

            if currentView ~= "grid" then
                local header
                local reusedHeader = false
                local headerSlotIndex = nil
                if freezeHeadersForVendor and flowLayoutCache and flowLayoutCache.headerByCategory then
                    local cachedIdx = flowLayoutCache.headerByCategory[catName]
                    if cachedIdx then
                        header = categoryHeaders[cachedIdx]
                        if header then
                            reusedHeader = true
                            headerSlotIndex = cachedIdx
                            headerIndex = math.max(headerIndex, cachedIdx)
                        end
                    end
                end
                if not header then
                    headerIndex = headerIndex + 1
                    header = categoryHeaders[headerIndex]
                    if not header then
                        header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        categoryHeaders[headerIndex] = header
                    end
                    headerSlotIndex = headerIndex
                end

                headerByCategory[catName] = headerSlotIndex
                if not reusedHeader then
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
                        local usedSlots = bagItemCounts and bagItemCounts[catName] or #catItems
                        local totalSlots = bagSlotCounts and bagSlotCounts[catName] or #catItems
                        header:SetText(GetBagDisplayName(catName) .. " (" .. usedSlots .. "/" .. totalSlots .. ")")
                    else
                        header:SetText(catName .. " (" .. #catItems .. ")")
                    end
                end
                header:Show()

                if currentView ~= "bag" and catName == "Trade Goods" then
                    local depositBtn = EnsureTradeGoodsDepositButton()
                    if depositBtn then
                        depositBtn:SetParent(scrollChild)
                        depositBtn:SetFrameLevel(header:GetParent():GetFrameLevel() + 5)
                        depositBtn:ClearAllPoints()
                        depositBtn:SetPoint("LEFT", header, "RIGHT", 6, 0)
                        depositBtn:Show()
                    end
                end

                laneY = laneY - sectionHeaderHeight
            end

            for i, itemInfo in ipairs(catItems) do
                -- ʕ •ᴥ•ʔ✿ Look up the persistent slot button for this item's
                -- (bag, slot). It was created, parented to the bag's
                -- ItemContainer, and SetID'd by EnsureSlotButtons above, so
                -- we only need to reposition and SetItem here -- all of
                -- which is still OOC because UpdateLayout is combat-gated. ✿ ʕ •ᴥ•ʔ
                local bagID = itemInfo.bagID
                local slotID = itemInfo.slotID
                local btn = (bagID and slotID) and GetSlotButton(bagID, slotID) or nil

                if btn then
                    local col = ((i - 1) % columns)
                    local row = math.floor((i - 1) / columns)
                    local x = laneX + col * itemStep
                    local y = laneY - row * itemStep

                    local needsReposition = (btn._oiLayoutX ~= x) or (btn._oiLayoutY ~= y)
                    local needsMetrics = (btn._oiLayoutScale ~= itemScale)
                    pcall(function()
                        if needsReposition then
                            btn:ClearAllPoints()
                            btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", x, y)
                            btn._oiLayoutX = x
                            btn._oiLayoutY = y
                        end
                        if needsMetrics then
                            ApplyItemButtonMetrics(btn, itemScale)
                            btn._oiLayoutScale = itemScale
                        end
                        btn:SetAlpha(1)
                    end)

                    local slotItem = itemInfo
                    if itemInfo and itemInfo.__empty then
                        slotItem = nil
                    end

                    local nextRenderKey = ItemRenderKey(slotItem)
                    local success = true
                    if btn._oiRenderKey ~= nextRenderKey then
                        success = pcall(function()
                            SetButtonItem(btn, slotItem)
                            btn._oiRenderKey = nextRenderKey
                            btn:Show()
                        end)
                    else
                        pcall(btn.Show, btn)
                    end
                    if not success then
                        pcall(SetButtonItem, btn, nil)
                        if btn.icon then btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
                        pcall(btn.Show, btn)
                        btn._oiRenderKey = "error"
                    end

                    touched[bagID] = touched[bagID] or {}
                    if not seenTouchedBagsThisPass[bagID] then
                        seenTouchedBagsThisPass[bagID] = true
                        usedTouchedBags[#usedTouchedBags + 1] = bagID
                    end
                    touched[bagID][slotID] = true
                    if not slotItem then
                        pcall(btn.SetAlpha, btn, EMPTY_SLOT_ALPHA)
                    end
                    table.insert(itemButtons, btn)
                end
            end

            local catRows = math.ceil(#catItems / columns)
            local itemsBottomY = laneY - (catRows * itemStep)
            laneY = itemsBottomY - sectionSpacing

            if isBoeAnchor then
                -- ʕ •ᴥ•ʔ✿ Remember BoE's lane geometry. The overflow
                -- strip anchors to BoE's x/columns (same half-width
                -- column) but uses the lane's final bottom y (captured
                -- after the loop), so BoE can sit at the top of its
                -- lane per LPT without the overflow grid overlapping
                -- the sections rendered below it. ✿ ʕ •ᴥ•ʔ
                boeAnchor = {
                    x = laneX,
                    columns = columns,
                    laneW = laneW,
                    lane = useRight and "right" or "left",
                }
            end

            if dualCategoryLanes then
                if useRight then
                    yRight = laneY
                else
                    yLeft = laneY
                end
            else
                yOffset = laneY
            end
        end
    end

    local mainBottomY
    if dualCategoryLanes then
        mainBottomY = math.min(yLeft, yRight)
    else
        mainBottomY = yOffset
    end

    -- ʕ •ᴥ•ʔ✿ Overflow strip ✿ ʕ •ᴥ•ʔ
    --
    -- Every slot button that did NOT receive an item from the sorted pass
    -- gets parked in a grid at alpha 0 immediately below the BoE section
    -- (its own dual-lane column), so any item that lands in a previously
    -- empty slot during combat visually pops in "under BoE" without
    -- needing a protected SetPoint call. This guarantees:
    --
    --   1) Every bag slot has a real, on-screen position at all times --
    --      RefreshCombatContent can just SetAlpha(1) + SetItem and the
    --      user sees the new item immediately.
    --
    --   2) Items that are used / sold / moved during combat can fade out
    --      (alpha 0) in place without protected Hide() calls, and come
    --      back cleanly on the next OOC render.
    --
    -- If flow mode didn't render a BoE anchor (grid/bag view), we fall
    -- back to full-width overflow anchored at the deepest lane.
    local overflowX, overflowColumns, overflowTop
    if boeAnchor then
        overflowX = boeAnchor.x
        overflowColumns = boeAnchor.columns
        -- ʕ •ᴥ•ʔ✿ Park overflow at the bottom of BoE's entire lane (not
        -- directly below BoE's item rows) so sections rendered under
        -- BoE in the same lane aren't overlapped by the pre-parked
        -- grid when combat pops a new item into a previously empty
        -- slot. ✿ ʕ •ᴥ•ʔ
        local laneBottomY = (boeAnchor.lane == "right") and yRight or yLeft
        overflowTop = laneBottomY - OVERFLOW_ROW_GAP
    else
        overflowX = itemGap
        overflowColumns = columnsForLaneWidth(usableWidth)
        overflowTop = mainBottomY - OVERFLOW_ROW_GAP
    end

    local overflowIndex = 0
    IterateSlotButtons(function(bagID, slotID, btn)
        local isTouched = touched[bagID] and touched[bagID][slotID]
        if isTouched then return end

        local col = overflowIndex % overflowColumns
        local row = math.floor(overflowIndex / overflowColumns)
        local x = overflowX + col * itemStep
        local y = overflowTop - row * itemStep

        local needsReposition = (btn._oiLayoutX ~= x) or (btn._oiLayoutY ~= y)
        local needsMetrics = (btn._oiLayoutScale ~= itemScale)
        pcall(function()
            if needsReposition then
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", x, y)
                btn._oiLayoutX = x
                btn._oiLayoutY = y
            end
            if needsMetrics then
                ApplyItemButtonMetrics(btn, itemScale)
                btn._oiLayoutScale = itemScale
            end
            btn:SetAlpha(0)
        end)
        if btn._oiRenderKey ~= "empty" then
            pcall(SetButtonItem, btn, nil)
            btn._oiRenderKey = "empty"
        end
        pcall(btn.Show, btn)

        overflowIndex = overflowIndex + 1
    end)

    local overflowRows = math.ceil(overflowIndex / math.max(overflowColumns, 1))
    local overflowExtent = overflowRows > 0
        and (OVERFLOW_ROW_GAP + overflowRows * itemStep)
        or 0

    -- Scroll height has to accommodate the deepest point on the page,
    -- which is either the deepest lane (mainBottomY) or the bottom of
    -- the overflow strip anchored at the bottom of BoE's lane.
    local overflowAnchorY
    if boeAnchor then
        overflowAnchorY = (boeAnchor.lane == "right") and yRight or yLeft
    else
        overflowAnchorY = mainBottomY
    end
    local overflowBottom = overflowAnchorY - overflowExtent
    local deepestY = math.min(mainBottomY, overflowBottom)
    scrollChild:SetHeight(math.abs(deepestY) + itemGap)

    if flowMode then
        flowLayoutCache = {
            signature = compositionSignature,
            laneAssignment = laneAssignment,
            headerByCategory = headerByCategory,
            order = categoryOrder,
        }
        if merchantOpen and vendorFlowLayoutFreeze and laneAssignment then
            vendorFlowLayoutFreeze.laneAssignment = laneAssignment
        end
    else
        flowLayoutCache = nil
    end
    wasMerchantOpen = merchantOpen
end

-- =============================================================================
-- List View Rendering (Data Table)
-- =============================================================================


function Frame:RenderListView(items)
    if not mainFrame or not mainFrame.scrollChild then return end

    local scrollChild = mainFrame.scrollChild

    -- ʕ •ᴥ•ʔ✿ Park every persistent slot button at alpha 0 so flow buttons
    -- don't peek through the list layout. We never Release them back to
    -- the pool -- they stay allocated so we can flip straight back to
    -- flow/grid without re-parenting (which is protected during combat). ✿ ʕ •ᴥ•ʔ
    IterateSlotButtons(function(_, _, btn)
        pcall(btn.SetAlpha, btn, 0)
    end)
    itemButtons = {}

    for _, row in ipairs(listRows) do
        row:Hide()
    end

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
                    if IsMerchantOpen() and (not CursorHasItem or not CursorHasItem()) and ShowContainerSellCursor then
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
    local perfToken = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("frame.ApplySearch")
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
    local matchedButtons = 0

    -- Filter Grid/Flow view buttons
    for _, btn in ipairs(itemButtons) do
        local itemInfo = btn.itemInfo
        local isMatch = false

        if itemInfo and itemInfo.hyperlink then
            local name = itemInfo.__cachedName
            local lowerName = itemInfo.__cachedLowerName
            if not name then
                name = GetItemInfo(itemInfo.hyperlink)
                itemInfo.__cachedName = name
            end
            if name and not lowerName then
                lowerName = string.lower(name)
                itemInfo.__cachedLowerName = lowerName
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

    -- Filter List view rows
    local matchedRows = 0
    for _, row in ipairs(listRows) do
        if row:IsShown() and row.itemInfo then
            local itemInfo = row.itemInfo
            local isMatch = false

            if itemInfo.hyperlink then
                local name = itemInfo.__cachedName
                local lowerName = itemInfo.__cachedLowerName
                if not name then
                    name = GetItemInfo(itemInfo.hyperlink)
                    itemInfo.__cachedName = name
                end
                if name and not lowerName then
                    lowerName = string.lower(name)
                    itemInfo.__cachedLowerName = lowerName
                end
                if lowerName and string.find(lowerName, lowerSearch, 1, true) then
                    isMatch = true
                end
            end

            if isMatch then
                row:SetAlpha(1)
                if row.icon then row.icon:SetDesaturated(false) end
                matchedRows = matchedRows + 1
            else
                row:SetAlpha(0.3)
                if row.icon then row.icon:SetDesaturated(true) end
            end
        end
    end
    if Omni._perfEnabled and Omni.Perf then
        Omni.Perf:End("frame.ApplySearch", perfToken, {
            queryLen = string.len(searchText or ""),
            visibleButtons = #itemButtons,
            matchedButtons = matchedButtons,
            matchedRows = matchedRows,
        })
    end
end

-- =============================================================================
-- Footer Updates
-- =============================================================================

-- ʕ ◕ᴥ◕ ʔ Footer emphasis: money + slot count fonts; slot fill color is driven in UpdateSlotCount ✿ ʕ ◕ᴥ◕ ʔ
function Frame:RefreshFooterMoneyStyle()
    if not mainFrame or not mainFrame.footer then return end
    local footer = mainFrame.footer
    if not footer.money or not footer.slots then return end

    local emphasize = Omni.Data and Omni.Data:Get("footerMoneyEmphasis") == true
    local path, size = GameFontNormal:GetFont()
    size = (size or 12) + 2
    if emphasize then
        footer.money:SetFont(path, size, "OUTLINE")
        footer.slots:SetFont(path, size, "OUTLINE")
        if footer.bagFullAlert and footer.bagFullAlert.label then
            footer.bagFullAlert.label:SetFont(path, size + 2, "OUTLINE")
        end
    else
        footer.money:SetFontObject(GameFontNormalSmall)
        footer.slots:SetFontObject(GameFontNormalSmall)
        if footer.bagFullAlert and footer.bagFullAlert.label then
            local ap, as = GameFontNormal:GetFont()
            footer.bagFullAlert.label:SetFont(ap, (as or 12) + 2, "OUTLINE")
        end
    end
    SyncBagFullAlertHitBox(footer)
    if self.UpdateFooterCustomButtons then
        self:UpdateFooterCustomButtons()
    end
    self:UpdateSlotCount()
end

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
    local footer = mainFrame.footer
    local slots = footer.slots
    slots:SetText(string.format("%d/%d", used, total))

    local bagsFull = total > 0 and free == 0
    local alert = footer.bagFullAlert
    if alert then
        if bagsFull then
            alert:Show()
            SyncBagFullAlertHitBox(footer)
            slots:ClearAllPoints()
            slots:SetPoint("LEFT", alert, "RIGHT", 1, 0)
        else
            alert:Hide()
            slots:ClearAllPoints()
            slots:SetPoint("LEFT", footer, "LEFT", 6, 0)
        end
    end

    local emphasize = Omni.Data and Omni.Data:Get("footerMoneyEmphasis") == true
    if emphasize then
        local t = 0
        if total > 0 then
            t = used / total
        end
        local br, bg, bb = 0.55, 0.80, 1.00
        local rr, rg, rb = 1.00, 0.15, 0.15
        slots:SetTextColor(br + (rr - br) * t, bg + (rg - bg) * t, bb + (rb - bb) * t, 1)
    else
        slots:SetTextColor(1, 1, 1, 1)
    end

    if self.UpdateFooterCustomButtons then
        self:UpdateFooterCustomButtons()
    end
    if self.UpdateEmbeddedAttuneHelper then
        self:UpdateEmbeddedAttuneHelper()
    end
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

    self:UpdateLayout()
    self:UpdateEmbeddedAttuneHelper()
    if self.UpdateFooterCustomButtons then self:UpdateFooterCustomButtons() end
end

function Frame:Hide()
    if not mainFrame then return end

    pcall(mainFrame.Hide, mainFrame)
    RestoreEmbeddedAttuneHelper()
    flowLayoutCache = nil
    vendorFlowLayoutFreeze = nil
    wasMerchantOpen = false
    ClearMap(optimisticFlowRefreshWatches)
    ClearArray(itemButtons)

    for _, byBag in pairs(slotButtons) do
        for _, btn in pairs(byBag) do
            if btn then
                btn._oiLayoutX = nil
                btn._oiLayoutY = nil
                btn._oiLayoutScale = nil
                btn._oiRenderKey = nil
                btn._cachedSearchName = nil
                btn._cachedSearchNameLower = nil
            end
        end
    end

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

    local clickedActive = (selectedBagID == bagID)

    if clickedActive then
        -- Unselect: restore the prior view only if we remembered one.
        -- If the user chose bag view themselves (via the View button),
        -- leave them in bag view on unselect instead of forcing flow.
        self:SetBagFilter(nil)
        if currentView == "bag" and preBagViewMode then
            local restoreTo = preBagViewMode
            preBagViewMode = nil
            self:SetView(restoreTo)
        end
    else
        -- Select: capture the non-bag view once, then switch to bag view
        if currentView ~= "bag" then
            preBagViewMode = currentView
            self:SetView("bag")
        end
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
        forceEmptyFrame:SetScript("OnEvent", nil)
        forceEmptyFrame:UnregisterEvent("BAG_UPDATE")
        forceEmptyFrame:UnregisterEvent("ITEM_LOCK_CHANGED")
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
        forceEmptyJob.awaitingEvent = true
        forceEmptyJob.awaitElapsed = 0
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
        awaitingEvent = false,
        awaitElapsed = 0,
    }

    forceEmptyFrame = forceEmptyFrame or CreateFrame("Frame")
    forceEmptyFrame:RegisterEvent("BAG_UPDATE")
    forceEmptyFrame:RegisterEvent("ITEM_LOCK_CHANGED")
    forceEmptyFrame:SetScript("OnEvent", function(_, event, arg1)
        if not forceEmptyJob then
            return
        end
        if event == "BAG_UPDATE" and arg1 ~= nil then
            if arg1 ~= forceEmptyJob.sourceBagID then
                forceEmptyJob.awaitingEvent = false
            end
            return
        end
        if event == "ITEM_LOCK_CHANGED" then
            forceEmptyJob.awaitingEvent = false
        end
    end)
    forceEmptyFrame:SetScript("OnUpdate", function(_, elapsed)
        if not forceEmptyJob then
            return
        end
        if forceEmptyJob.awaitingEvent then
            forceEmptyJob.awaitElapsed = forceEmptyJob.awaitElapsed + (elapsed or 0)
            if forceEmptyJob.awaitElapsed < FORCE_EMPTY_EVENT_TIMEOUT then
                return
            end
            forceEmptyJob.awaitingEvent = false
        end
        RunForceEmptyStep()
    end)
end

-- =============================================================================
-- Initialization
-- =============================================================================

function Frame:SetMerchantOpen(isOpen)
    Omni._merchantOpen = (isOpen == true)
end

function Frame:Init()
    Omni._merchantOpen = false
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
