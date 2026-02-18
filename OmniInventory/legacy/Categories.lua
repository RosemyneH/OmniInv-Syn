local addonName, NS = ...

NS.Categories = {}
local Categories = NS.Categories

-- Constants for Categories
local CAT_ARMOR = "Armor"
local CAT_WEAPON = "Weapon"
local CAT_JEWELRY = "Jewelry"
local CAT_QUEST = "Quest"
local CAT_TRADE = "Trade Goods"
local CAT_CONSUMABLE = "Consumable"
local CAT_CONTAINER = "Bag"
local CAT_GEM = "Gem"
local CAT_GLYPH = "Glyph"
local CAT_MISC = "Miscellaneous"
local CAT_JUNK = "Junk"
local CAT_RECENT = "Recent Items"

-- Lookup tables for O(1) category access
local categoryByName = {}
local categoryById = {}
local categoryList = {}

-- Equipment Slot Mapping
local EQUIP_LOC_MAP = {
    INVTYPE_HEAD = CAT_ARMOR,
    INVTYPE_SHOULDER = CAT_ARMOR,
    INVTYPE_BODY = CAT_ARMOR,
    INVTYPE_CHEST = CAT_ARMOR,
    INVTYPE_ROBE = CAT_ARMOR,
    INVTYPE_WAIST = CAT_ARMOR,
    INVTYPE_LEGS = CAT_ARMOR,
    INVTYPE_FEET = CAT_ARMOR,
    INVTYPE_WRIST = CAT_ARMOR,
    INVTYPE_HAND = CAT_ARMOR,
    INVTYPE_CLOAK = CAT_ARMOR,

    INVTYPE_WEAPON = CAT_WEAPON,
    INVTYPE_SHIELD = CAT_WEAPON,
    INVTYPE_2HWEAPON = CAT_WEAPON,
    INVTYPE_WEAPONMAINHAND = CAT_WEAPON,
    INVTYPE_WEAPONOFFHAND = CAT_WEAPON,
    INVTYPE_HOLDABLE = CAT_WEAPON,
    INVTYPE_RANGED = CAT_WEAPON,
    INVTYPE_THROWN = CAT_WEAPON,
    INVTYPE_RANGEDRIGHT = CAT_WEAPON,
    INVTYPE_RELIC = CAT_JEWELRY,

    INVTYPE_NECK = CAT_JEWELRY,
    INVTYPE_FINGER = CAT_JEWELRY,
    INVTYPE_TRINKET = CAT_JEWELRY,

    INVTYPE_BAG = CAT_CONTAINER,
    INVTYPE_TABARD = CAT_MISC,
}

-- Priority List (Lower index = Higher priority in UI)
Categories.Priority = {
    [CAT_RECENT] = 0, -- Highest Priority
    [CAT_QUEST] = 1,
    [CAT_WEAPON] = 2,
    [CAT_ARMOR] = 3,
    [CAT_JEWELRY] = 4,
    [CAT_CONSUMABLE] = 5,
    [CAT_TRADE] = 6,
    [CAT_GEM] = 7,
    [CAT_GLYPH] = 8,
    [CAT_CONTAINER] = 9,
    [CAT_MISC] = 10,
    [CAT_JUNK] = 11,
}

-- Initialize lookup tables
local function InitializeCategoryLookup()
    local categories = {
        { id = "recent", name = CAT_RECENT, priority = 0 },
        { id = "quest", name = CAT_QUEST, priority = 1 },
        { id = "weapon", name = CAT_WEAPON, priority = 2 },
        { id = "armor", name = CAT_ARMOR, priority = 3 },
        { id = "jewelry", name = CAT_JEWELRY, priority = 4 },
        { id = "consumable", name = CAT_CONSUMABLE, priority = 5 },
        { id = "trade", name = CAT_TRADE, priority = 6 },
        { id = "gem", name = CAT_GEM, priority = 7 },
        { id = "glyph", name = CAT_GLYPH, priority = 8 },
        { id = "container", name = CAT_CONTAINER, priority = 9 },
        { id = "misc", name = CAT_MISC, priority = 10 },
        { id = "junk", name = CAT_JUNK, priority = 11 },
    }

    for _, cat in ipairs(categories) do
        categoryByName[cat.name] = cat
        categoryById[cat.id] = cat
        table.insert(categoryList, cat)
    end
end

-- Call initialization
InitializeCategoryLookup()

-- Helper functions for O(1) lookups
function Categories:GetCategoryByName(name)
    return categoryByName[name]
end

function Categories:GetCategoryById(id)
    return categoryById[id]
end

function Categories:GetAllCategories()
    return categoryList
end

function Categories:GetCategory(itemLink, isRecent)
    if not itemLink then return "Empty" end

    -- DEBUG: Log categorization with stack trace
    if isNew then
        print("ZenBags DEBUG: GetCategory called with isNew=TRUE for " .. (itemLink or "nil"))
        print("  Stack: " .. debugstack(2, 1, 0))
    end

    -- 0. Recent Items (Highest Priority)
    if isRecent then
        return CAT_RECENT
    end

    local name, _, quality, _, _, itemType, itemSubType, _, equipLoc = GetItemInfo(itemLink)

    if not itemType then return "Unknown" end

    -- 1. Quest Items (Highest Priority)
    if itemType == "Quest" or quality == 7 then -- 7 is Heirloom, treating as special/quest-like for visibility or add separate
        return CAT_QUEST
    end

    -- 2. Equipment (Using Slot Mapping)
    if EQUIP_LOC_MAP[equipLoc] then
        return EQUIP_LOC_MAP[equipLoc]
    end

    -- 3. Standard Types
    if itemType == "Consumable" then return CAT_CONSUMABLE end
    if itemType == "Trade Goods" then return CAT_TRADE end
    if itemType == "Container" then return CAT_CONTAINER end
    if itemType == "Gem" then return CAT_GEM end
    if itemType == "Glyph" then return CAT_GLYPH end
    if itemType == "Recipe" then return CAT_TRADE end -- Group recipes with trade goods

    -- 4. Junk
    if quality == 0 then return CAT_JUNK end

    return CAT_MISC
end

-- Sort comparator
function Categories:CompareItems(a, b)
    -- 1. Category Priority
    local catA = a.category or CAT_MISC
    local catB = b.category or CAT_MISC

    local prioA = self.Priority[catA] or 99
    local prioB = self.Priority[catB] or 99

    if prioA ~= prioB then
        return prioA < prioB
    end

    -- 2. Quality (High to Low)
    if a.quality ~= b.quality then
        return (a.quality or 0) > (b.quality or 0)
    end

    -- 3. Name
    local nameA = GetItemInfo(a.link) or ""
    local nameB = GetItemInfo(b.link) or ""
    return nameA < nameB
end
