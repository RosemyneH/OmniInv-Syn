local addonName, NS = ...

NS.GearUpgrade = {}
local GearUpgrade = NS.GearUpgrade

-----------------------------------------------------------
-- Gear Upgrade Detection
-- Purpose: Highlight items that are upgrades to equipped gear
-----------------------------------------------------------

-- Cache equipped items
GearUpgrade.equipped = {}

-- Slot ID to inventory slot mapping
local SLOT_MAP = {
    INVTYPE_HEAD = 1,
    INVTYPE_NECK = 2,
    INVTYPE_SHOULDER = 3,
    INVTYPE_BODY = 4,
    INVTYPE_CHEST = 5,
    INVTYPE_ROBE = 5,
    INVTYPE_WAIST = 6,
    INVTYPE_LEGS = 7,
    INVTYPE_FEET = 8,
    INVTYPE_WRIST = 9,
    INVTYPE_HAND = 10,
    INVTYPE_FINGER = {11, 12},
    INVTYPE_TRINKET = {13, 14},
    INVTYPE_CLOAK = 15,
    INVTYPE_WEAPON = 16,
    INVTYPE_SHIELD = 17,
    INVTYPE_2HWEAPON = 16,
    INVTYPE_WEAPONMAINHAND = 16,
    INVTYPE_WEAPONOFFHAND = 17,
    INVTYPE_HOLDABLE = 17,
    INVTYPE_RANGED = 18,
    INVTYPE_THROWN = 18,
    INVTYPE_RANGEDRIGHT = 18,
    INVTYPE_RELIC = 18,
}

--- Initialize and scan equipped gear
function GearUpgrade:Init()
    self:ScanEquipped()

    -- Update on gear changes
    local f = CreateFrame("Frame")
    f:RegisterEvent("UNIT_INVENTORY_CHANGED")
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    f:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
        GearUpgrade:ScanEquipped()
    end)
end

--- Scan all equipped items
function GearUpgrade:ScanEquipped()
    wipe(self.equipped)

    for slot = 1, 18 do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local _, _, _, iLevel, _, _, _, _, equipLoc = GetItemInfo(link)
            self.equipped[slot] = {
                link = link,
                iLevel = iLevel or 0,
                equipLoc = equipLoc
            }
        end
    end
end

--- Get equipped item level for a slot
function GearUpgrade:GetEquippedLevel(equipLoc)
    if not equipLoc or equipLoc == "" then return nil end

    local slotID = SLOT_MAP[equipLoc]
    if not slotID then return nil end

    -- Handle slots with two options (rings, trinkets)
    if type(slotID) == "table" then
        local minLevel = math.huge
        for _, id in ipairs(slotID) do
            local eq = self.equipped[id]
            if eq and eq.iLevel then
                minLevel = math.min(minLevel, eq.iLevel)
            else
                return 0 -- Empty slot = any item is upgrade
            end
        end
        return minLevel < math.huge and minLevel or nil
    else
        local eq = self.equipped[slotID]
        if eq then
            return eq.iLevel or 0
        end
        return 0 -- Empty slot
    end
end

--- Check if item is an upgrade
-- @param itemLink string Item link
-- @param itemLevel number Item's level
-- @return number|nil Upgrade level difference (positive = upgrade, negative = downgrade, 0 = same, nil = not equipment)
function GearUpgrade:GetUpgradeLevel(itemLink, itemLevel)
    if not itemLink or not itemLevel then return nil end

    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemLink)
    if not equipLoc or equipLoc == "" then return nil end

    local equippedLevel = self:GetEquippedLevel(equipLoc)
    if not equippedLevel then return nil end

    return itemLevel - equippedLevel
end

--- Check if item is wearable by current class
function GearUpgrade:IsWearable(itemLink)
    if not itemLink then return false end

    local _, _, _, _, _, itemType, itemSubType, _, equipLoc = GetItemInfo(itemLink)
    if not equipLoc or equipLoc == "" then return false end

    -- Basic check: is it armor/weapon?
    if itemType ~= "Armor" and itemType ~= "Weapon" then
        return false
    end

    return true
end

--- Get upgrade status for display
-- @return "upgrade", "downgrade", "sidegrade", or nil
function GearUpgrade:GetStatus(itemLink, itemLevel)
    local diff = self:GetUpgradeLevel(itemLink, itemLevel)
    if not diff then return nil end

    if diff > 0 then
        return "upgrade", diff
    elseif diff < 0 then
        return "downgrade", diff
    else
        return "sidegrade", 0
    end
end

--- Debug command
SLASH_ZENGEAR1 = "/zengear"
SlashCmdList["ZENGEAR"] = function(msg)
    print("|cFF00FF00ZenBags Gear:|r")

    local slotNames = {
        [1] = "Head", [2] = "Neck", [3] = "Shoulder", [4] = "Shirt",
        [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
        [9] = "Wrist", [10] = "Hands", [11] = "Ring1", [12] = "Ring2",
        [13] = "Trinket1", [14] = "Trinket2", [15] = "Back",
        [16] = "MainHand", [17] = "OffHand", [18] = "Ranged"
    }

    for slot = 1, 18 do
        local eq = GearUpgrade.equipped[slot]
        if eq then
            print(string.format("  %s: iLvl %d", slotNames[slot] or slot, eq.iLevel or 0))
        end
    end
end
