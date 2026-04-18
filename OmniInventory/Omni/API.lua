-- =============================================================================
-- OmniInventory API Abstraction Layer (The Shim)
-- =============================================================================
-- Purpose: Bridge legacy 3.3.5a APIs to modern Retail-style table returns.
-- This allows the entire codebase to use modern syntax while remaining
-- compatible with WotLK 3.3.5a client.
--
-- This module mimics the Retail `C_Container` namespace.
-- =============================================================================

local addonName, Omni = ...

Omni.API = {}
local API = Omni.API

-- =============================================================================
-- Client Detection
-- =============================================================================

local clientVersion = select(4, GetBuildInfo()) or 30300
API.isWotLK = clientVersion < 40000
API.isRetail = clientVersion >= 100000

-- =============================================================================
-- ʕ •ᴥ•ʔ✿ Native Extended Lua Detection ✿ ʕ •ᴥ•ʔ
-- =============================================================================
-- Synastria (3.3.5a) ships a C-side extension pack that exposes item helpers
-- which bypass the slow GameTooltip scraping path entirely. When present we
-- prefer those over the classic tooltip/GetItemInfo combo.

API.hasCustomSoulbound = type(_G.Custom_IsItemSoulbound)   == "function"
API.hasCustomEquipMgr  = type(_G.Custom_IsItemEquipMgr)    == "function"
API.hasCustomGuid      = type(_G.Custom_GetItemGuid)       == "function"
API.hasCustomLinkSlot  = type(_G.Custom_GetItemLinkBySlot) == "function"
API.hasCustomIdFromLnk = type(_G.Custom_GetIdFromLink)     == "function"
API.hasHighestAttune   = type(_G.GetHighestAttunePct)      == "function"

-- =============================================================================
-- ʕ ◕ᴥ◕ ʔ Server Bag / Slot Translation Table ʕ ◕ᴥ◕ ʔ
-- =============================================================================
-- The native Custom_ functions speak the server's raw slot space, not the
-- Lua containerID space. We translate containerID/slotID pairs into the
-- (native_bag_id, native_slot_id) tuple the C code expects.
--
--   Lua container  | Native bag  | Native slot layout
--   ---------------+-------------+----------------------------------------
--    0  Backpack   | 0xFF        | character slot 23..38  (INVENTORY item)
--    1..4 Bags     | 0x13..0x16  | 0-indexed slot within the bag
--   -1  Main Bank  | 0xFF        | character slot 39..66  (BANK item)
--    5..11 Bank bg | 0x43..0x49  | 0-indexed slot within the bank bag
--   -2  Keyring    | 0xFF        | character slot 86..117 (KEYRING item)

local INVENTORY_SLOT_BAG_0       = 0xFF  -- Character-direct storage
local INVENTORY_SLOT_ITEM_START  = 23    -- Backpack item slot 1 -> 23
local BANK_SLOT_ITEM_START       = 39    -- Main bank slot 1 -> 39
local KEYRING_SLOT_START         = 86    -- Keyring slot 1 -> 86

local SERVER_BAG_MAP = {
    [0]  = INVENTORY_SLOT_BAG_0,
    [1]  = 0x13,
    [2]  = 0x14,
    [3]  = 0x15,
    [4]  = 0x16,
    [-1] = INVENTORY_SLOT_BAG_0,
    [-2] = INVENTORY_SLOT_BAG_0,
    [5]  = 0x43,
    [6]  = 0x44,
    [7]  = 0x45,
    [8]  = 0x46,
    [9]  = 0x47,
    [10] = 0x48,
    [11] = 0x49,
}

--- Translate a Lua (bagID, slotID) pair to the server-side (bag, slot) tuple
--- used by the Custom_ family of functions.
---@param bagID number
---@param slotID number
---@return number|nil nativeBag
---@return number|nil nativeSlot
function API:GetNativeBagSlot(bagID, slotID)
    local nativeBag = SERVER_BAG_MAP[bagID]
    if not nativeBag or not slotID then
        return nil, nil
    end

    local nativeSlot
    if bagID == 0 then
        nativeSlot = INVENTORY_SLOT_ITEM_START + slotID - 1
    elseif bagID == -1 then
        nativeSlot = BANK_SLOT_ITEM_START + slotID - 1
    elseif bagID == -2 then
        nativeSlot = KEYRING_SLOT_START + slotID - 1
    else
        nativeSlot = slotID - 1
    end

    return nativeBag, nativeSlot
end

-- =============================================================================
-- ᵔᴥᵔ Polyfill: Tooltip Scanner (used only when native APIs are absent) ᵔᴥᵔ
-- =============================================================================

local scanningTooltip = CreateFrame("GameTooltip", "OmniScanningTooltip", nil, "GameTooltipTemplate")
scanningTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local SOULBOUND_TEXT = ITEM_SOULBOUND or "Soulbound"
local BOE_TEXT = ITEM_BIND_ON_EQUIP or "Binds when equipped"
local BOP_TEXT = ITEM_BIND_ON_PICKUP or "Binds when picked up"
local BOA_TEXT = ITEM_BIND_TO_ACCOUNT or "Binds to account"

-- ʕ •ᴥ•ʔ✿ Two-state model: soulbound -> BoP, otherwise -> BoE ✿ ʕ •ᴥ•ʔ
local function ScanTooltipForBinding(bag, slot)
    scanningTooltip:ClearLines()
    scanningTooltip:SetBagItem(bag, slot)

    for i = 2, math.min(5, scanningTooltip:NumLines()) do
        local textFrame = _G["OmniScanningTooltipTextLeft" .. i]
        if textFrame then
            local line = textFrame:GetText()
            if line then
                if line == SOULBOUND_TEXT or line == BOP_TEXT or line == BOA_TEXT then
                    return true, "BoP"
                elseif line == BOE_TEXT then
                    return false, "BoE"
                end
            end
        end
    end

    return false, "BoE"
end

-- =============================================================================
-- ＼ʕ •ᴥ•ʔ／ Native Extended API Wrappers ＼ʕ •ᴥ•ʔ／
-- =============================================================================

--- Fast soulbound check backed by native C. Falls back to a tooltip scan on
--- clients that don't ship the extension pack.
---@param bagID number
---@param slotID number
---@return boolean isBound
function API:IsItemSoulbound(bagID, slotID)
    if API.hasCustomSoulbound then
        local nb, ns = API:GetNativeBagSlot(bagID, slotID)
        if nb and ns then
            return Custom_IsItemSoulbound(nb, ns) == 1
        end
    end
    local bound = ScanTooltipForBinding(bagID, slotID)
    return bound
end

--- Check whether the item in (bagID, slotID) is referenced by any equipment
--- manager set. Returns nil when the native API is unavailable so the caller
--- can fall back to the slow GetEquipmentSetItemIDs iteration.
---@param bagID number
---@param slotID number
---@return boolean|nil inSet
function API:IsItemInEquipmentSet(bagID, slotID)
    if not API.hasCustomEquipMgr then
        return nil
    end
    local nb, ns = API:GetNativeBagSlot(bagID, slotID)
    if not nb or not ns then
        return nil
    end
    return Custom_IsItemEquipMgr(nb, ns) == 1
end

--- Get a stable server-side GUID for an item instance.
---@param bagID number
---@param slotID number
---@return number|nil lowGuid
---@return number|nil highGuid
function API:GetItemGuid(bagID, slotID)
    if not API.hasCustomGuid then
        return nil
    end
    local nb, ns = API:GetNativeBagSlot(bagID, slotID)
    if not nb or not ns then
        return nil
    end
    return Custom_GetItemGuid(nb, ns)
end

--- Native-backed replacement for GetContainerItemLink. Falls back to the stock
--- API when the extension is absent.
---@param bagID number
---@param slotID number
---@return string|nil link
function API:GetItemLinkBySlot(bagID, slotID)
    if API.hasCustomLinkSlot then
        local nb, ns = API:GetNativeBagSlot(bagID, slotID)
        if nb and ns then
            local link = Custom_GetItemLinkBySlot(nb, ns)
            if link then
                return link
            end
        end
    end
    return GetContainerItemLink(bagID, slotID)
end

--- Parse any WoW hyperlink (item, spell, achievement, etc.) into (id, typeID).
--- Falls back to cheap itemID string matching for item links only.
---@param link string
---@return number|nil id
---@return number|nil typeID  1 = item (when using the fallback path)
function API:GetIdFromLink(link)
    if not link then return nil end
    if API.hasCustomIdFromLnk then
        return Custom_GetIdFromLink(link)
    end
    local itemID = tonumber(string.match(link, "item:(%d+)"))
    if itemID then
        return itemID, 1
    end
    return nil
end

--- Highest known attunement % for an itemID. Aware of affix variants and forge
--- tiers. Pass -1 (or omit forge) for the highest across all forges; pass a
--- specific forge value (0..3) to pin to that tier.
---@param itemID number
---@param forge number|nil  -1 = any (default)
---@return number pct 0..100
function API:GetHighestAttunePct(itemID, forge)
    if not itemID then return 0 end
    if API.hasHighestAttune then
        local pct = GetHighestAttunePct(itemID, forge or -1)
        if type(pct) == "number" then
            return pct
        end
    end
    -- ʕノ•ᴥ•ʔノ Legacy fallback path ノʕ•ᴥ•ʔ
    if _G.GetItemAttuneProgress then
        local titanforged = (forge and forge > 0) and forge or nil
        local pct = GetItemAttuneProgress(itemID, nil, titanforged)
        if type(pct) == "number" then
            return pct
        end
    end
    return 0
end

-- =============================================================================
-- Namespace: OmniC_Container (C_Container Polyfill)
-- =============================================================================
-- Provides a modern, table-based API for item data.

OmniC_Container = {}

--- Get container item info in modern table format.
--- Replaces `GetContainerItemInfo` (returns 9 values) with a single table.
---@param bagID number
---@param slotID number
---@return table|nil info Item info structure or nil if slot is empty
function OmniC_Container.GetContainerItemInfo(bagID, slotID)
    local texture, itemCount, locked, quality, readable, lootable, itemLink = GetContainerItemInfo(bagID, slotID)

    if not texture then
        return nil
    end

    -- ʕ •ᴥ•ʔ✿ Prefer native link + id resolution when available ✿ ʕ •ᴥ•ʔ
    if API.hasCustomLinkSlot and not itemLink then
        itemLink = API:GetItemLinkBySlot(bagID, slotID)
    end

    local itemID
    if itemLink then
        itemID = API:GetIdFromLink(itemLink)
    end

    -- ʕ •ᴥ•ʔ✿ Bind state: soulbound -> BoP, otherwise -> BoE ✿ ʕ •ᴥ•ʔ
    local isBound, bindType
    if API.hasCustomSoulbound then
        isBound = API:IsItemSoulbound(bagID, slotID)
        bindType = isBound and "BoP" or "BoE"
    else
        isBound, bindType = ScanTooltipForBinding(bagID, slotID)
    end

    -- ʕ •ᴥ•ʔ✿ Attunability: true when anyone on the account can attune it ✿ ʕ •ᴥ•ʔ
    local isAttunable = false
    if itemID and _G.IsAttunableBySomeone then
        local check = IsAttunableBySomeone(itemID)
        isAttunable = check ~= nil and check ~= 0 and check ~= false
    end

    -- GetContainerItemInfo often returns -1/nil for quality in 3.3.5a
    if (not quality or quality < 0) and itemLink then
        local _, _, itemQuality = GetItemInfo(itemLink)
        quality = itemQuality
    end

    -- Return modern table structure (Matches Retail C_Container.GetContainerItemInfo)
    return {
        -- Core Identification
        iconFileID = texture,
        itemID = itemID,
        hyperlink = itemLink,

        -- Stack Info
        stackCount = itemCount or 1,

        -- State Flags
        isLocked = locked or false,
        isReadable = readable or false,
        hasLoot = lootable or false,
        isBound = isBound,
        bindType = bindType,         -- "BoP" when soulbound, "BoE" otherwise
        isAttunable = isAttunable,   -- IsAttunableBySomeone(itemID)

        -- Quality (default to 1/Common if still unknown to avoid Lua errors)
        quality = quality or 1,

        -- Location (Added convenience)
        bagID = bagID,
        slotID = slotID,
    }
end

--- Get total number of slots in a container.
---@param bagID number
---@return number numSlots
function OmniC_Container.GetContainerNumSlots(bagID)
    return GetContainerNumSlots(bagID) or 0
end

--- Get free slot count in a container.
---@param bagID number
---@return number freeSlots
---@return number bagType
function OmniC_Container.GetContainerFreeSlots(bagID)
    local numFreeSlots, bagType = GetContainerNumFreeSlots(bagID)
    return numFreeSlots or 0, bagType or 0
end

-- =============================================================================
-- Helper Functions (Extensions)
-- =============================================================================

--- Get all items in a specific bag container.
---@param bagID number
---@return table items Array of item info tables
function OmniC_Container.GetContainerItems(bagID)
    local items = {}
    local numSlots = OmniC_Container.GetContainerNumSlots(bagID)

    for slotID = 1, numSlots do
        local info = OmniC_Container.GetContainerItemInfo(bagID, slotID)
        if info then
            table.insert(items, info)
        end
    end

    return items
end

--- Get all items in player inventory (Bags 0-4).
---@return table items Array of item info tables
function OmniC_Container.GetAllBagItems()
    local items = {}

    for bagID = 0, 4 do
        local bagItems = OmniC_Container.GetContainerItems(bagID)
        for _, item in ipairs(bagItems) do
            table.insert(items, item)
        end
    end

    return items
end

--- Get all items in player bank (Main -1 + Bags 5-11).
---@return table items Array of item info tables
function OmniC_Container.GetAllBankItems()
    local items = {}

    -- Main bank (bagID = -1)
    local bankItems = OmniC_Container.GetContainerItems(-1)
    for _, item in ipairs(bankItems) do
        table.insert(items, item)
    end

    -- Bank bags (5-11)
    for bagID = 5, 11 do
        local bagItems = OmniC_Container.GetContainerItems(bagID)
        for _, item in ipairs(bagItems) do
            table.insert(items, item)
        end
    end

    return items
end

-- =============================================================================
-- Extended Item Info (GetItemInfo Wrapper)
-- =============================================================================

--- Get extended item info properly structured.
--- Wraps `GetItemInfo` to return a table instead of list of returns.
---@param itemLink string
---@return table|nil info Table with keys or nil not cached.
function API:GetExtendedItemInfo(itemLink)
    if not itemLink then return nil end

    local name, link, quality, iLevel, reqLevel, class, subclass,
          maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemLink)

    if not name then
        return nil -- Item info not in local cache yet
    end

    return {
        name = name,
        link = link,
        quality = quality or 0,
        itemLevel = iLevel or 0,
        requiredLevel = reqLevel or 0,
        itemType = class,
        itemSubType = subclass,
        maxStackSize = maxStack or 1,
        equipSlot = equipSlot,
        iconFileID = texture,
        vendorPrice = vendorPrice or 0,
    }
end

-- =============================================================================
-- Initialization
-- =============================================================================

do
    local nativeFlags = {}
    if API.hasCustomSoulbound  then table.insert(nativeFlags, "Soulbound") end
    if API.hasCustomEquipMgr   then table.insert(nativeFlags, "EquipMgr")  end
    if API.hasCustomGuid       then table.insert(nativeFlags, "GUID")      end
    if API.hasCustomLinkSlot   then table.insert(nativeFlags, "LinkSlot")  end
    if API.hasCustomIdFromLnk  then table.insert(nativeFlags, "IdFromLnk") end
    if API.hasHighestAttune    then table.insert(nativeFlags, "AttunePct") end

    local nativeStr = (#nativeFlags > 0) and (" | native: " .. table.concat(nativeFlags, "+")) or " | native: none"
    print("|cFF00FF00OmniInventory|r: API Shim loaded (" .. (API.isWotLK and "WotLK 3.3.5a" or "Retail") .. nativeStr .. ")")
end
