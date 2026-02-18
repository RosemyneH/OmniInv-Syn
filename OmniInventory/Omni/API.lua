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
-- Polyfill: Tooltip Scanner (WotLK 3.3.5a)
-- =============================================================================
-- Legacy API does not return binding status (Soulbound/BoE/BoP) directly.
-- We must scan the tooltip text to determine this.

local scanningTooltip = CreateFrame("GameTooltip", "OmniScanningTooltip", nil, "GameTooltipTemplate")
scanningTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local SOULBOUND_TEXT = ITEM_SOULBOUND or "Soulbound"
local BOE_TEXT = ITEM_BIND_ON_EQUIP or "Binds when equipped"
local BOP_TEXT = ITEM_BIND_ON_PICKUP or "Binds when picked up"
local BOA_TEXT = ITEM_BIND_TO_ACCOUNT or "Binds to account"

--- Scan tooltip for binding status (Polyfill for WotLK)
---@param bag number
---@param slot number
---@return boolean isBound
---@return string|nil bindType "Soulbound", "BoE", "BoP", "BoA"
local function ScanTooltipForBinding(bag, slot)
    scanningTooltip:ClearLines()
    scanningTooltip:SetBagItem(bag, slot)

    -- Scan only the first few lines where binding text usually appears
    for i = 2, math.min(5, scanningTooltip:NumLines()) do
        local textFrame = _G["OmniScanningTooltipTextLeft" .. i]
        if textFrame then
            local line = textFrame:GetText()
            if line then
                if line == SOULBOUND_TEXT then
                    return true, "Soulbound"
                elseif line == BOE_TEXT then
                    return false, "BoE"
                elseif line == BOP_TEXT then
                    return false, "BoP"
                elseif line == BOA_TEXT then
                    return true, "BoA"
                end
            end
        end
    end

    return false, nil
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
    -- Native 3.3.5a call
    local texture, itemCount, locked, quality, readable, lootable, itemLink = GetContainerItemInfo(bagID, slotID)

    if not texture then
        return nil
    end

    -- Parse itemID from link (e.g., "item:1234:...")
    local itemID = nil
    if itemLink then
        itemID = tonumber(string.match(itemLink, "item:(%d+)"))
    end

    -- Polyfill: Get binding status (WotLK needs tooltip scan)
    local isBound, bindType = ScanTooltipForBinding(bagID, slotID)

    -- Polyfill: Fix missing quality info in 3.3.5a
    -- GetContainerItemInfo often returns -1/nil for quality; fetch from GetItemInfo
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
        bindType = bindType,

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

print("|cFF00FF00OmniInventory|r: API Shim loaded (" .. (API.isWotLK and "WotLK 3.3.5a" or "Retail") .. ")")
