local addonName, NS = ...

NS.Inventory = {}
local Inventory = NS.Inventory

-- Bag IDs for WotLK
local BAGS = {0, 1, 2, 3, 4}
local KEYRING = -2
local BANK = {-1, 5, 6, 7, 8, 9, 10, 11}

-- Storage for scanned items
Inventory.items = {}
Inventory.itemCounts = {} -- itemID -> count
Inventory.previousItemCounts = {}

-- Session-based "Recent Items" tracking
Inventory.sessionCache = {} -- itemID -> count (snapshot at login/reload)
Inventory.recentItems = {}  -- itemID -> timestamp (when it became recent)
Inventory.RECENT_TIMEOUT = 900 -- 15 minutes
Inventory.startupTime = 0
Inventory.STARTUP_GRACE_PERIOD = 10 -- Seconds to ignore "new" items after login/load

Inventory.updatePending = false
Inventory.bucketDelay = 0.1

-- Dirty flag system
Inventory.dirtySlots = {}


function Inventory:Init()
    -- Initialize SavedVariables structure
    ZenBagsDB = ZenBagsDB or {}

    -- Database Versioning
    local DB_VERSION = 5  -- NEW: Slot-based tracking
    if not ZenBagsDB.version or ZenBagsDB.version < DB_VERSION then
        print("ZenBags: Upgrading database to version " .. DB_VERSION .. ". Resetting data.")
        wipe(ZenBagsDB)
        ZenBagsDB.version = DB_VERSION
    end

    -- Initialize Session Cache
    self:InitSessionCache()


    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("BAG_UPDATE")
    self.frame:RegisterEvent("PLAYER_MONEY")
    self.frame:RegisterEvent("BANKFRAME_OPENED")
    self.frame:RegisterEvent("BANKFRAME_CLOSED")
    self.frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.frame:RegisterEvent("MERCHANT_SHOW")
    self.frame:RegisterEvent("MERCHANT_CLOSED")

    self.frame:SetScript("OnEvent", function(self, event, arg1)
        if event == "PLAYER_LOGIN" then
            -- Reset session cache on login
            Inventory:InitSessionCache()

        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Start grace period
            Inventory.startupTime = GetTime()

            -- Ensure we have a baseline snapshot
            if not Inventory.sessionCacheInitialized then
                 Inventory:InitSessionCache()
                 Inventory.sessionCacheInitialized = true
            end
            Inventory:ScanBags()
            if NS.Frames then NS.Frames:Update(true) end

            -- Delayed rescan to handle late-loading bags
            -- Bags 1-4 often report 0 slots initially on login, then load after ~1 second
            C_Timer.After(1.5, function()
                Inventory:ScanBags()
                if NS.Frames then NS.Frames:Update(true) end
            end)
        elseif event == "BAG_UPDATE" then
            -- Check for new items
            Inventory:CheckForNewItems(arg1)

        elseif event == "PLAYERBANKSLOTS_CHANGED" then
             -- Bank updates
             if NS.Data:IsBankOpen() then
                 Inventory:ScanBags()
                 if NS.Frames then NS.Frames:Update(true) end
             end
        elseif event == "PLAYER_MONEY" then
            if NS.Frames and NS.Frames.mainFrame and NS.Frames.mainFrame:IsShown() then
                NS.Frames:UpdateMoney()
            end
        elseif event == "BANKFRAME_OPENED" then
            NS.Data:SetBankOpen(true)
            Inventory:ScanBags()
            if NS.Frames then
                NS.Frames:ShowBankTab()
                NS.Frames:Update(true)
            end
        elseif event == "BANKFRAME_CLOSED" then
            NS.Data:SetBankOpen(false)
            if NS.Frames then
                NS.Frames:Update(true)
            end
        elseif event == "MERCHANT_SHOW" then
            NS.Data:SetMerchantOpen(true)
            if NS.Frames then NS.Frames:Update(true) end
        elseif event == "MERCHANT_CLOSED" then
            NS.Data:SetMerchantOpen(false)
            if NS.Frames then NS.Frames:Update(true) end
        end
    end)
end

function Inventory:InitSessionCache()
    wipe(self.sessionCache)
    wipe(self.recentItems)

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemID = GetContainerItemID(bag, slot)
                if itemID then
                    local _, count = GetContainerItemInfo(bag, slot)
                    self.sessionCache[itemID] = (self.sessionCache[itemID] or 0) + (count or 1)
                end
            end
        end
    end
end

function Inventory:CheckForNewItems(bagID)
    -- Snapshot current state of this bag
    local currentCounts = {}

    -- We need to scan ALL bags to get accurate totals, sadly,
    -- because an item moving from Bag 1 to Bag 2 looks like +1 in Bag 2 and -1 in Bag 1.
    -- If we only scan Bag 2, we think it's new.
    -- Optimization: We could defer this to the OnUpdate bucket, but let's try full scan first for correctness.

    local tempCounts = {}
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemID = GetContainerItemID(bag, slot)
                if itemID then
                    local _, count = GetContainerItemInfo(bag, slot)
                    tempCounts[itemID] = (tempCounts[itemID] or 0) + (count or 1)
                end
            end
        end
    end

    -- Guard: If session cache isn't initialized (e.g. during login load),
    -- just update the cache without marking anything as recent.
    if not self.sessionCacheInitialized then
        for itemID, count in pairs(tempCounts) do
            self.sessionCache[itemID] = count
        end
        return
    end

    -- Guard: Startup Grace Period
    -- During the first few seconds of gameplay, bag updates might be sporadic or partial.
    -- We suppress "New Item" detection here to prevent the entire inventory from glowing.
    if (GetTime() - self.startupTime) < self.STARTUP_GRACE_PERIOD then
         for itemID, count in pairs(tempCounts) do
            self.sessionCache[itemID] = count
        end
        return
    end

    -- Compare with session cache
    local now = time()
    for itemID, count in pairs(tempCounts) do
        local oldCount = self.sessionCache[itemID] or 0
        if count > oldCount then
            -- It's new!
            self.recentItems[itemID] = { time = now, viewed = false }
        end
        -- Update session cache to match current reality
        self.sessionCache[itemID] = count
    end

    -- Handle items that were removed (count < oldCount)
    -- We just update the cache, no need to mark as recent
    for itemID, count in pairs(self.sessionCache) do
        if not tempCounts[itemID] then
             self.sessionCache[itemID] = 0
        end
    end

    -- Trigger UI update
    if not self.updatePending then
        self.updatePending = true
        if not self.timerFrame then
            self.timerFrame = CreateFrame("Frame")
            self.timerFrame:Hide()
            self.timerFrame:SetScript("OnUpdate", function(f, elapsed)
                f.elapsed = (f.elapsed or 0) + elapsed
                if f.elapsed >= Inventory.bucketDelay then
                    f:Hide()
                    f.elapsed = 0
                    Inventory:ScanBags()
                    if NS.Frames then NS.Frames:Update() end
                    Inventory.updatePending = false
                end
            end)
        end
        self.timerFrame:Show()
    end
end


--- Fast path for updating item slot colors without full layout recalculation.
--- Use this for search highlighting, category color changes, etc.
--- Much faster than full Update() cycle.
function Inventory:UpdateItemSlotColors()
    if not NS.Frames or not NS.Frames.buttons then return end

    for _, button in ipairs(NS.Frames.buttons) do
        if button and button:IsVisible() and button.itemData then
            -- Update quality border color
            if button.itemData.quality and button.itemData.quality > 1 then
                local r, g, b = GetItemQualityColor(button.itemData.quality)
                button.IconBorder:SetVertexColor(r, g, b, 1)
                button.IconBorder:Show()
            else
                button.IconBorder:Hide()
            end

            -- Update new item glow
            if button.newGlow then
                if NS.Inventory:IsNew(button.itemData.itemID) then
                    button.newGlow:Show()
                    if button.newGlow.ag then button.newGlow.ag:Play() end
                else
                    button.newGlow:Hide()
                    if button.newGlow.ag then button.newGlow.ag:Stop() end
                end
            end
        end
    end
end

function Inventory:ScanBags()
    wipe(self.items)

    -- Auto-expire old new slots (5 minutes)
    -- Auto-expire recent items
    local currentTime = time()
    for itemID, data in pairs(self.recentItems) do
        if currentTime - data.time > self.RECENT_TIMEOUT then
            self.recentItems[itemID] = nil
        end
    end

    -- Scan all bags
    local function scanList(bagList, locationType)
        for _, bagID in ipairs(bagList) do
            local numSlots = GetContainerNumSlots(bagID)
            if numSlots then
                for slotID = 1, numSlots do
                    local texture, count, _, quality, _, _, link = GetContainerItemInfo(bagID, slotID)
                    local itemID = GetContainerItemID(bagID, slotID)

                    if link and itemID then
                        local _, _, _, iLevel, _, _, _, _, equipSlot = GetItemInfo(link)
                        local isEquipment = (equipSlot and equipSlot ~= "") and (iLevel and iLevel > 1)

                        -- Check if item is recent
                        local isRecent = self:IsRecent(itemID)


                        table.insert(self.items, {
                            bagID = bagID,
                            slotID = slotID,
                            link = link,
                            texture = texture,
                            count = count,
                            quality = quality,
                            itemID = itemID,
                            iLevel = isEquipment and iLevel or nil,
                            location = locationType,
                            category = NS.Categories:GetCategory(link, isRecent)
                        })
                    end
                end
            end
        end
    end

    scanList(BAGS, "bags")

    if NS.Data:IsBankOpen() then
        scanList(BANK, "bank")
    end

    -- Sort
    table.sort(self.items, function(a, b) return NS.Categories:CompareItems(a, b) end)

    -- Update the Data Layer cache
    NS.Data:UpdateCache()

    -- Mark dirty (simplified for now, full update usually needed after scan)
    self:SetFullUpdate(true)
end

function Inventory:GetItems()
    return self.items
end

function Inventory:MarkDirty(bagID, slotID)
    local key = bagID .. ":" .. (slotID or "all")
    self.dirtySlots[key] = true
end

function Inventory:GetDirtySlots()
    return self.dirtySlots
end

function Inventory:ClearDirtySlots()
    wipe(self.dirtySlots)
end

function Inventory:NeedsFullUpdate()
    return self.forceFullUpdate
end

function Inventory:SetFullUpdate(value)
    self.forceFullUpdate = value
end

-- =============================================================================
-- New Item Tracking
-- =============================================================================

function Inventory:IsRecent(itemID)
    if not itemID then return false end
    return self.recentItems[itemID] ~= nil
end

function Inventory:IsNew(itemID)
    if not itemID then return false end
    local data = self.recentItems[itemID]
    return data and not data.viewed
end

function Inventory:MarkItemViewed(itemID)
    if self.recentItems[itemID] then
        self.recentItems[itemID].viewed = true
        -- Update glow only (fast path)
        self:UpdateItemSlotColors()
    end
end

function Inventory:ClearRecentItems()
    wipe(self.recentItems)
    -- Force full update to re-categorize items
    self:ScanBags()
    if NS.Frames then NS.Frames:Update(true) end
end

function Inventory:ClearRecentItem(itemID)
    if self.recentItems[itemID] then
        self.recentItems[itemID] = nil
        -- Force full update to re-categorize items (it will move out of Recent category)
        self:ScanBags()
        if NS.Frames then NS.Frames:Update(true) end
    end
end



function Inventory:GetTrashItems()
    local trashItems = {}
    for _, item in ipairs(self.items) do
        if item.location == "bags" then
            -- Get item info for quality and category checks
            local _, _, quality, _, _, itemClass, itemSubClass = GetItemInfo(item.link)
            local itemID = select(1, GetItemInfo(item.link))

            -- Exclude Hearthstone (6948) - it's grey but should never be sold
            if itemID == 6948 then
                -- Skip Hearthstone
            -- Check if item is trash:
            -- 1. Grey/Poor quality (quality == 0)
            -- 2. OR marked as Junk category/class by Blizzard (even if common quality)
            elseif quality == 0 or itemClass == "Junk" or itemSubClass == "Junk" then
                table.insert(trashItems, item)
            end
        end
    end
    return trashItems
end

function Inventory:GetTrashValue()
    local totalValue = 0
    for _, item in ipairs(self:GetTrashItems()) do
        local _, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(item.link)
        if vendorPrice and vendorPrice > 0 then
            totalValue = totalValue + (vendorPrice * item.count)
        end
    end
    return totalValue
end
