local addonName, NS = ...

NS.Inventory = {}
local Inventory = NS.Inventory

-- Bag IDs for WotLK
local BAGS = {0, 1, 2, 3, 4}
local KEYRING = -2
local BANK = {-1, 5, 6, 7, 8, 9, 10, 11}

-- Storage for scanned items
Inventory.items = {}

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
    ZenBagsDB.newItems = ZenBagsDB.newItems or {}

    -- Load saved new items state
    self.newItems = ZenBagsDB.newItems

    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("BAG_UPDATE")
    self.frame:RegisterEvent("PLAYER_MONEY")
    self.frame:RegisterEvent("BANKFRAME_OPENED")
    self.frame:RegisterEvent("BANKFRAME_CLOSED")
    self.frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")

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
        end
    end)
    -- Don't scan here - bags aren't loaded yet!
    -- Wait for first BAG_UPDATE event instead
end

function Inventory:ScanBags()
    wipe(self.items)
    local newState = {}

    -- Helper to scan a list of bags
    local function scanList(bagList, locationType)
        local addedItems = {}
        local removedItems = {}

        for _, bagID in ipairs(bagList) do
            local numSlots = GetContainerNumSlots(bagID)
            for slotID = 1, numSlots do
                local texture, count, locked, quality, readable, lootable, link, isFiltered, noValue, itemID = GetContainerItemInfo(bagID, slotID)

                local key = bagID .. ":" .. slotID

                -- Track current state
                if link then
                    -- Capture iLevel for equipment
                    local _, _, _, iLevel, _, _, _, _, equipSlot = GetItemInfo(link)
                    local isEquipment = (equipSlot and equipSlot ~= "") and (iLevel and iLevel > 1)

                    newState[key] = {
                        link = link,
                        count = count,
                        texture = texture,
                        itemID = itemID
                    }

                    table.insert(self.items, {
                        bagID = bagID,
                        slotID = slotID,
                        link = link,
                        texture = texture,
                        count = count,
                        quality = quality,
                        itemID = itemID,
                        iLevel = isEquipment and iLevel or nil, -- Store iLevel
                        location = locationType, -- "bags", "bank", "keyring"
                        category = NS.Categories:GetCategory(link)
                    })
                end

                -- Compare with previous state to detect changes
                local prev = self.previousState[key]
                local curr = newState[key]

                -- Mark dirty if changed
                if not prev and curr then
                    -- New item (potentially)
                    self:MarkDirty(bagID, slotID)
                    table.insert(addedItems, {bagID = bagID, slotID = slotID, itemID = itemID})
                elseif prev and not curr then
                    -- Item removed
                    self:MarkDirty(bagID, slotID)
                    table.insert(removedItems, {itemID = prev.itemID})
                elseif prev and curr then
                    -- Check if item changed (different link or count)
                    if prev.link ~= curr.link or prev.count ~= curr.count then
                        self:MarkDirty(bagID, slotID)
                    end
                end
            end
        end

        -- Process New Items (Filter out moves)
        if not self.firstScan then
            for _, added in ipairs(addedItems) do
                local isMove = false
                -- Check if this itemID was removed elsewhere
                for i, removed in ipairs(removedItems) do
                    if removed.itemID == added.itemID then
                        -- It's a move! Remove from removedItems so we don't match it again
                        table.remove(removedItems, i)
                        isMove = true
                        break
                    end
                end

                if not isMove then
                    self.newItems[added.bagID .. ":" .. added.slotID] = true
                    -- Persist to SavedVariables
                    ZenBagsDB.newItems = self.newItems
                end
            end
        end
    end

    scanList(BAGS, "bags")

    if NS.Data:IsBankOpen() then
        scanList(BANK, "bank")
    end

    -- Update previous state for next comparison
    -- IMPORTANT: Do this BEFORE clearing firstScan, so we have a baseline
    self.previousState = newState

    -- Clear first scan flag after establishing baseline state
    if self.firstScan then
        self.firstScan = false
    end

    -- Sort
    table.sort(self.items, function(a, b) return NS.Categories:CompareItems(a, b) end)

    -- Update the Data Layer cache
    NS.Data:UpdateCache()
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

function Inventory:IsNew(bagID, slotID)
    return self.newItems[bagID .. ":" .. slotID]
end

function Inventory:ClearNew(bagID, slotID)
    local key = bagID .. ":" .. slotID
    if self.newItems[key] then
        self.newItems[key] = nil
        -- Persist to SavedVariables
        ZenBagsDB.newItems = self.newItems
        -- Force update to remove glow
        if NS.Frames then NS.Frames:Update(true) end
    end
end

-- Helper to extract Item ID from link
local function GetItemID(link)
    if not link then return nil end
    local id = link:match("item:(%d+)")
    return tonumber(id)
end
