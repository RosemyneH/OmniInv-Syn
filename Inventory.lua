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

-- Event bucketing to reduce spam
Inventory.updatePending = false
Inventory.bucketDelay = 0.1  -- 100ms delay for coalescing events

-- Dirty flag system for incremental updates
Inventory.dirtySlots = {}
Inventory.previousState = {}  -- bagID:slotID -> {link, count, texture}
Inventory.forceFullUpdate = false

function Inventory:Init()
    -- Initialize SavedVariables structure
    ZenBagsDB = ZenBagsDB or {}
    ZenBagsDB.newItems = {} -- Always start fresh on login
    ZenBagsDB.previousItemCounts = ZenBagsDB.previousItemCounts or {}

    -- Load saved new items state (fresh start)
    self.newItems = ZenBagsDB.newItems

    -- Load saved previous item counts
    self.previousItemCounts = ZenBagsDB.previousItemCounts

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
            -- Clear all new item highlights on fresh login
            -- Each session starts clean
            wipe(Inventory.newItems)
            ZenBagsDB.newItems = Inventory.newItems
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Force a scan when entering world to ensure items are loaded
            -- This fixes the issue where alt characters show empty inventory
            Inventory:ScanBags()
            if NS.Frames then NS.Frames:Update(true) end
        elseif event == "BAG_UPDATE" or event == "PLAYERBANKSLOTS_CHANGED" then
            -- Event Bucketing: Coalesce rapid-fire BAG_UPDATE events
            -- This reduces updates from ~50/sec to ~10/sec during looting
            if not Inventory.updatePending then
                Inventory.updatePending = true

                -- Use OnUpdate for WotLK compatibility (C_Timer not available)
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
        elseif event == "PLAYER_MONEY" then
            -- Update money display
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
                -- Don't hide bank tab or switch view!
                -- Just update to show offline state
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
    -- Don't scan here - bags aren't loaded yet!
    -- Wait for first BAG_UPDATE event instead
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
            if NS.Inventory:IsNew(button.itemData.itemID) then
                button.NewItemTexture:Show()
            else
                button.NewItemTexture:Hide()
            end
        end
    end
end

function Inventory:ScanBags()
    wipe(self.items)

    local currentCounts = {}
    local function countItems(bagList)
        for _, bagID in ipairs(bagList) do
            local numSlots = GetContainerNumSlots(bagID)
            for slotID = 1, numSlots do
                local itemID = GetContainerItemID(bagID, slotID)
                if itemID then
                    local _, count = GetContainerItemInfo(bagID, slotID)
                    currentCounts[itemID] = (currentCounts[itemID] or 0) + (count or 1)
                end
            end
        end
    end

    countItems(BAGS)
    if NS.Data:IsBankOpen() then
        countItems(BANK)
    end

    -- 2. Detect New Items (Count Increase)
    if not self.firstScan then
        for itemID, count in pairs(currentCounts) do
            local prevCount = self.previousItemCounts[itemID] or 0
            if count > prevCount then
                -- Item count increased, mark as new
                print("ZenBags Debug: New Item Detected! ID:", itemID, "Count:", count, "Prev:", prevCount)
                self.newItems[itemID] = true
                ZenBagsDB.newItems = self.newItems
            end
        end
    end

    -- 3. Build Item List
    local function scanList(bagList, locationType)
        for _, bagID in ipairs(bagList) do
            local numSlots = GetContainerNumSlots(bagID)
            for slotID = 1, numSlots do
                local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bagID, slotID)
                local itemID = GetContainerItemID(bagID, slotID) -- Use this instead of unreliable 10th return value

                if link and itemID then
                    -- Capture iLevel for equipment
                    local _, _, _, iLevel, _, _, _, _, equipSlot = GetItemInfo(link)
                    local isEquipment = (equipSlot and equipSlot ~= "") and (iLevel and iLevel > 1)

                    -- Check if item is new (by Item ID)
                    local isNew = self.newItems[itemID]

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
                        category = NS.Categories:GetCategory(link, isNew)
                    })
                end
            end
        end
    end

    scanList(BAGS, "bags")

    if NS.Data:IsBankOpen() then
        scanList(BANK, "bank")
    end

    -- Update previous counts and save to database
    -- Only update if we found items, or if it's not the first scan
    -- This protects against premature empty scans overwriting valid DB data
    local hasItems = next(currentCounts) ~= nil

    if hasItems or not self.firstScan then
        self.previousItemCounts = currentCounts
        ZenBagsDB.previousItemCounts = self.previousItemCounts

        if self.firstScan then
            self.firstScan = false
        end
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

-- Note: newItems is initialized from SavedVariables in Init()
Inventory.firstScan = true

function Inventory:IsNew(itemID)
    return self.newItems[itemID]
end

function Inventory:ClearNew(itemID)
    if self.newItems[itemID] then
        self.newItems[itemID] = nil
        -- Persist to SavedVariables
        ZenBagsDB.newItems = self.newItems
        -- Force update to remove glow
        if NS.Frames then NS.Frames:Update(true) end
    end
end

function Inventory:ClearRecentItems()
    wipe(self.newItems)
    ZenBagsDB.newItems = self.newItems
    -- Force full update to re-categorize items
    self:ScanBags()
    if NS.Frames then NS.Frames:Update(true) end
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

