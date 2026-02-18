local addonName, NS = ...

NS.Data = {}
local Data = NS.Data

-- Bag ID Constants
Data.BAGS = {0, 1, 2, 3, 4}
Data.BANK = {-1, 5, 6, 7, 8, 9, 10, 11}
Data.KEYRING = -2

-- State
Data.cache = {} -- Cached item data per character
Data.isBankOpen = false
Data.isMerchantOpen = false
Data.selectedCharacter = nil -- nil = current character, otherwise character key

-- =============================================================================
-- Initialization
-- =============================================================================

function Data:Init()
    -- Load cached data from SavedVariables
    if ZenBagsDB and ZenBagsDB.cache then
        self.cache = ZenBagsDB.cache
    end

    -- Default to current character
    self.selectedCharacter = nil
end

-- =============================================================================
-- Core API: Item Info
-- =============================================================================

--- Get item information for a specific bag slot
-- @param bag number Bag ID
-- @param slot number Slot ID
-- @return link, count, texture, quality, isLocked, itemID
function Data:GetItemInfo(bag, slot)
    -- Determine if we should use cached data
    if self:IsCached(bag) then
        return self:GetCachedItemInfo(bag, slot)
    else
        return self:GetLiveItemInfo(bag, slot)
    end
end

--- Check if a bag is currently using cached data
-- @param bag number Bag ID
-- @return boolean
function Data:IsCached(bag)
    -- If viewing another character, EVERYTHING is cached
    if self:IsViewingOtherCharacter() then
        return true
    end

    -- Bank bags are cached when bank is closed
    if self:IsBankBag(bag) then
        return not self.isBankOpen
    end

    -- Inventory bags are always live for current character
    return false
end
-- @param slot number
-- @return link, count, texture, quality, isLocked, itemID
function Data:GetLiveItemInfo(bag, slot)
    local texture, count, locked, quality, readable, lootable, link, isFiltered, noValue, itemID = GetContainerItemInfo(bag, slot)
    return link, count, texture, quality, locked, itemID
end

--- Get cached item info from SavedVariables
-- @param bag number
-- @param slot number
-- @return link, count, texture, quality, isLocked, itemID
function Data:GetCachedItemInfo(bag, slot)
    local charKey = self:GetCharacterKey()
    local bagData = self.cache[charKey] and self.cache[charKey][bag]

    if not bagData then
        return nil, nil, nil, nil, nil, nil
    end

    local itemData = bagData[slot]
    if not itemData then
        return nil, nil, nil, nil, nil, nil
    end

    return itemData.link, itemData.count, itemData.texture, itemData.quality, false, itemData.itemID
end

-- =============================================================================
-- Core API: Bag Info
-- =============================================================================

--- Get the size of a bag
-- @param bag number Bag ID
-- @return number
function Data:GetBagSize(bag)
    if self:IsCached(bag) then
        local charKey = self:GetCharacterKey()
        local bagData = self.cache[charKey] and self.cache[charKey][bag]
        if bagData then
            return bagData.size or 0
        end
        return 0
    else
        return GetContainerNumSlots(bag) or 0
    end
end

--- Check if a bag is a bank bag
-- @param bag number
-- @return boolean
function Data:IsBankBag(bag)
    for _, bankBag in ipairs(self.BANK) do
        if bag == bankBag then
            return true
        end
    end
    return false
end

--- Check if a bag is an inventory bag
-- @param bag number
-- @return boolean
function Data:IsInventoryBag(bag)
    for _, invBag in ipairs(self.BAGS) do
        if bag == invBag then
            return true
        end
    end
    return false
end

-- =============================================================================
-- Caching System
-- =============================================================================

--- Update the cache with current live data
-- This should be called whenever bags are scanned
function Data:UpdateCache()
    local charKey = self:GetCharacterKey()

    -- Initialize cache structure
    if not ZenBagsDB then
        ZenBagsDB = {}
    end
    ZenBagsDB.cache = ZenBagsDB.cache or {}
    ZenBagsDB.cache[charKey] = ZenBagsDB.cache[charKey] or {}

    -- Scan all bags
    local bagList = {}
    for _, bag in ipairs(self.BAGS) do
        table.insert(bagList, bag)
    end

    if self.isBankOpen then
        for _, bag in ipairs(self.BANK) do
            table.insert(bagList, bag)
        end
    end

    -- Update money cache
    ZenBagsDB.cache[charKey].money = GetMoney()

    for _, bag in ipairs(bagList) do
        local numSlots = GetContainerNumSlots(bag)
        local freeSlots, bagFamily = GetContainerNumFreeSlots(bag)
        ZenBagsDB.cache[charKey][bag] = {
            size = numSlots,
            family = bagFamily
        }

        for slot = 1, numSlots do
            local texture, count, locked, quality, readable, lootable, link, isFiltered, noValue, itemID = GetContainerItemInfo(bag, slot)

            if link then
                ZenBagsDB.cache[charKey][bag][slot] = {
                    link = link,
                    count = count,
                    texture = texture,
                    quality = quality,
                    itemID = itemID
                }
            else
                ZenBagsDB.cache[charKey][bag][slot] = nil
            end
        end
    end

    -- Update in-memory cache reference
    self.cache = ZenBagsDB.cache
end

--- Get the character key for cache storage
-- @return string
function Data:GetCharacterKey()
    -- If a specific character is selected, use that
    if self.selectedCharacter then
        return self.selectedCharacter
    end
    -- Otherwise use current character
    return UnitName("player") .. " - " .. GetRealmName()
end

--- Get the current player's character key
-- @return string
function Data:GetCurrentCharacterKey()
    return UnitName("player") .. " - " .. GetRealmName()
end

-- =============================================================================
-- Bank State Management
-- =============================================================================

function Data:SetBankOpen(isOpen)
    self.isBankOpen = isOpen
    if isOpen then
        self:UpdateCache()
    end
end

function Data:IsBankOpen()
    return self.isBankOpen
end

function Data:SetMerchantOpen(isOpen)
    self.isMerchantOpen = isOpen
end

function Data:IsMerchantOpen()
    return self.isMerchantOpen
end

--- Get cached inventory items (bags 0-4) in Inventory-compatible format
-- @return table Array of item data
function Data:GetCachedInventoryItems()
    local charKey = self:GetCharacterKey()
    local items = {}

    if not self.cache[charKey] then
        return items
    end

    -- Iterate through inventory bags
    for _, bag in ipairs(self.BAGS) do
        local bagData = self.cache[charKey][bag]
        if bagData then
            for slot = 1, (bagData.size or 0) do
                local itemData = bagData[slot]
                if itemData then
                    -- Build item in same format as Inventory.lua
                    -- Cached items are never "new" (they're from offline characters)
                    table.insert(items, {
                        bagID = bag,
                        slotID = slot,
                        link = itemData.link,
                        texture = itemData.texture,
                        count = itemData.count,
                        quality = itemData.quality,
                        itemID = itemData.itemID,
                        location = "bags",
                        category = NS.Categories:GetCategory(itemData.link, false)
                    })
                end
            end
        end
    end

    return items
end

--- Get cached bank items in Inventory-compatible format
-- @return table Array of item data
function Data:GetCachedBankItems()
    local charKey = self:GetCharacterKey()
    local items = {}

    if not self.cache[charKey] then
        return items
    end

    -- Iterate through all bank bags
    for _, bag in ipairs(self.BANK) do
        local bagData = self.cache[charKey][bag]
        if bagData then
            for slot = 1, (bagData.size or 0) do
                local itemData = bagData[slot]
                if itemData then
                    -- Build item in same format as Inventory.lua
                    -- Cached items are never "new" (they're from offline characters)
                    table.insert(items, {
                        bagID = bag,
                        slotID = slot,
                        link = itemData.link,
                        texture = itemData.texture,
                        count = itemData.count,
                        quality = itemData.quality,
                        itemID = itemData.itemID,
                        location = "bank",
                        category = NS.Categories:GetCategory(itemData.link, false)
                    })
                end
            end
        end
    end

    return items
end

--- Check if there are cached bank items available
-- @return boolean
function Data:HasCachedBankItems()
    local charKey = self:GetCharacterKey()
    if not self.cache[charKey] then
        return false
    end

    -- Check if any bank bag has items
    for _, bag in ipairs(self.BANK) do
        local bagData = self.cache[charKey][bag]
        if bagData then
            for slot = 1, (bagData.size or 0) do
                if bagData[slot] then
                    return true
                end
            end
        end
    end

    return false
end

-- =============================================================================
-- Extended Data API (Money, Free Slots, Bag Types)
-- =============================================================================

--- Get player money (copper)
-- @return number
function Data:GetMoney()
    if self:IsViewingOtherCharacter() then
        local charKey = self:GetCharacterKey()
        return (self.cache[charKey] and self.cache[charKey].money) or 0
    end
    return GetMoney()
end

--- Get number of free slots in a bag
-- @param bag number
-- @return number freeSlots, number bagFamily
function Data:GetFreeSlots(bag)
    if self:IsCached(bag) then
        local charKey = self:GetCharacterKey()
        local bagData = self.cache[charKey] and self.cache[charKey][bag]
        if bagData then
            -- Calculate free slots from cached data
            local size = bagData.size or 0
            local used = 0
            for slot = 1, size do
                if bagData[slot] then used = used + 1 end
            end
            return size - used, bagData.family or 0
        end
        return 0, 0
    else
        return GetContainerNumFreeSlots(bag)
    end
end

--- Get bag family type
-- @param bag number
-- @return number
function Data:GetBagType(bag)
    local _, family = self:GetFreeSlots(bag)
    return family
end

--- Set the selected character to view
-- @param charKey string Character key ("Name - Realm") or nil for current character
function Data:SetSelectedCharacter(charKey)
    self.selectedCharacter = charKey
end

--- Get the currently selected character
-- @return string Character key or nil if viewing current character
function Data:GetSelectedCharacter()
    return self.selectedCharacter
end

--- Check if viewing another character (not the current logged-in character)
-- @return boolean
function Data:IsViewingOtherCharacter()
    return self.selectedCharacter ~= nil
end

--- Get list of available characters (all characters with cached data)
-- @return table Array of {name, realm, key, isCurrent, class, gold}
function Data:GetAvailableCharacters()
    local chars = {}
    local currentKey = self:GetCurrentCharacterKey()

    if ZenBagsDB and ZenBagsDB.cache then
        for charKey, cacheData in pairs(ZenBagsDB.cache) do
            -- Parse character key
            local name, realm = charKey:match("^(.+) %- (.+)$")
            if name and realm then
                -- Get class and gold from Alts module if available
                local charClass = nil
                local gold = 0

                if NS.Alts then
                    -- Try to find matching alt data (Alts uses "Name-Realm" format)
                    local altKey = name .. "-" .. realm
                    local altData = NS.Alts:GetCharacter(altKey)
                    if altData then
                        charClass = altData.class
                        gold = altData.gold or 0
                    end
                end

                table.insert(chars, {
                    name = name,
                    realm = realm,
                    key = charKey,
                    isCurrent = (charKey == currentKey),
                    class = charClass,
                    gold = gold
                })
            end
        end
    end

    -- Sort: current character first, then alphabetically
    table.sort(chars, function(a, b)
        if a.isCurrent then return true end
        if b.isCurrent then return false end
        return a.name < b.name
    end)

    return chars
end

--- Delete a character from the cache
-- @param charKey string Character key ("Name - Realm")
function Data:DeleteCharacter(charKey)
    if not charKey or not ZenBagsDB or not ZenBagsDB.cache then return end

    -- Remove from cache
    ZenBagsDB.cache[charKey] = nil
    self.cache[charKey] = nil

    -- If we were viewing this character, reset to current
    if self.selectedCharacter == charKey then
        self.selectedCharacter = nil
    end
end

-- =============================================================================
-- Tooltip Enhancement: Total Item Count
-- =============================================================================

--- Get total count of an item across all bags and bank
-- @param itemID number The item ID to count
-- @return bagCount number, bankCount number Total counts in bags and bank
function Data:GetTotalItemCount(itemID)
    if not itemID then return 0, 0 end

    local bagCount = 0
    local bankCount = 0
    local charKey = self:GetCharacterKey()

    -- Count in bags
    for _, bag in ipairs(self.BAGS) do
        if self:IsCached(bag) then
            -- Use cached data
            local bagData = self.cache[charKey] and self.cache[charKey][bag]
            if bagData then
                for slot = 1, (bagData.size or 0) do
                    local itemData = bagData[slot]
                    if itemData and itemData.itemID == itemID then
                        bagCount = bagCount + (itemData.count or 1)
                    end
                end
            end
        else
            -- Use live data
            local numSlots = GetContainerNumSlots(bag) or 0
            for slot = 1, numSlots do
                local slotItemID = GetContainerItemID(bag, slot)
                if slotItemID == itemID then
                    local _, count = GetContainerItemInfo(bag, slot)
                    bagCount = bagCount + (count or 1)
                end
            end
        end
    end

    -- Count in bank (always cached if bank is closed)
    for _, bag in ipairs(self.BANK) do
        if self:IsCached(bag) then
            -- Use cached data
            local bagData = self.cache[charKey] and self.cache[charKey][bag]
            if bagData then
                for slot = 1, (bagData.size or 0) do
                    local itemData = bagData[slot]
                    if itemData and itemData.itemID == itemID then
                        bankCount = bankCount + (itemData.count or 1)
                    end
                end
            end
        else
            -- Bank is open, use live data
            local numSlots = GetContainerNumSlots(bag) or 0
            for slot = 1, numSlots do
                local slotItemID = GetContainerItemID(bag, slot)
                if slotItemID == itemID then
                    local _, count = GetContainerItemInfo(bag, slot)
                    bankCount = bankCount + (count or 1)
                end
            end
        end
    end

    return bagCount, bankCount
end

