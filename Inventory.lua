local addonName, NS = ...

NS.Inventory = {}
local Inventory = NS.Inventory

-- Bag IDs for WotLK
local BAGS = {0, 1, 2, 3, 4}
local KEYRING = -2
local BANK = {-1, 5, 6, 7, 8, 9, 10, 11}

-- Storage for scanned items
Inventory.items = {}

function Inventory:Init()
    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("BAG_UPDATE")
    self.frame:SetScript("OnEvent", function(self, event, arg1)
        if event == "BAG_UPDATE" then
            -- For now, we just re-scan everything on any update. 
            -- Optimization: Only scan the updated bag (arg1).
            Inventory:ScanBags()
            if NS.Frames then NS.Frames:Update() end
        end
    end)
    self:ScanBags()
end

function Inventory:ScanBags()
    wipe(self.items)
    
    -- Helper to scan a list of bags
    local function scanList(bagList, locationType)
        for _, bagID in ipairs(bagList) do
            local numSlots = GetContainerNumSlots(bagID)
            for slotID = 1, numSlots do
                local texture, count, locked, quality, readable, lootable, link, isFiltered, noValue, itemID = GetContainerItemInfo(bagID, slotID)
                
                if link then
                    table.insert(self.items, {
                        bagID = bagID,
                        slotID = slotID,
                        link = link,
                        texture = texture,
                        count = count,
                        quality = quality,
                        itemID = itemID,
                        location = locationType, -- "bags", "bank", "keyring"
                        category = NS.Categories:GetCategory(link)
                    })
                end
            end
        end
    end

    scanList(BAGS, "bags")
    -- scanList({KEYRING}, "keyring") 
    -- scanList(BANK, "bank")
    
    -- Sort
    table.sort(self.items, function(a, b) return NS.Categories:CompareItems(a, b) end)

    -- Save to DB for offline viewing
    if ZenBagsDB then
        local charKey = UnitName("player") .. " - " .. GetRealmName()
        ZenBagsDB.characters = ZenBagsDB.characters or {}
        ZenBagsDB.characters[charKey] = self.items
    end
end

function Inventory:GetItems()
    return self.items
end
