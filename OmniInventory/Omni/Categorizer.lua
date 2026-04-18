-- =============================================================================
-- OmniInventory Smart Categorization Engine
-- =============================================================================
-- Purpose: Automatically assign items to logical categories using a
-- priority-based pipeline (Quest > Equipment > Consumables > etc.)
-- =============================================================================

local addonName, Omni = ...

Omni.Categorizer = {}
local Categorizer = Omni.Categorizer

-- =============================================================================
-- Category Registry
-- =============================================================================

local categories = {}  -- { name = { priority, icon, color, filter } }
local categoryOrder = {}  -- Sorted by priority

-- Default colors for categories
local CATEGORY_COLORS = {
    ["Perishable"]      = { r = 1.0, g = 0.3, b = 0.3 },
    ["Quest Items"]     = { r = 1.0, g = 0.82, b = 0.0 },
    ["Attunable"]       = { r = 0.0, g = 0.9, b = 0.5 },
    ["BoE"]             = { r = 0.4, g = 0.9, b = 1.0 },
    ["Equipment"]       = { r = 0.0, g = 0.8, b = 0.0 },
    ["Equipment Sets"]  = { r = 0.4, g = 0.8, b = 1.0 },
    ["Consumables"]     = { r = 1.0, g = 0.5, b = 0.5 },
    ["Trade Goods"]     = { r = 0.8, g = 0.6, b = 0.4 },
    ["Reagents"]        = { r = 0.6, g = 0.4, b = 0.8 },
    ["Junk"]            = { r = 0.6, g = 0.6, b = 0.6 },
    ["New Items"]       = { r = 0.0, g = 1.0, b = 0.5 },
    ["Miscellaneous"]   = { r = 0.5, g = 0.5, b = 0.5 },
    ["Keys"]            = { r = 1.0, g = 0.9, b = 0.4 },
    ["Bags"]            = { r = 0.6, g = 0.4, b = 0.2 },
    ["Ammo"]            = { r = 0.8, g = 0.7, b = 0.5 },
    ["Glyphs"]          = { r = 0.5, g = 0.8, b = 1.0 },
}

-- =============================================================================
-- New Items Tracking (Session-based)
-- =============================================================================

local sessionItems = {}  -- Items present at login
local newItems = {}      -- Items acquired this session

local function SnapshotInventory()
    sessionItems = {}
    local API = Omni.API
    for bagID = 0, 4 do
        local numSlots = GetContainerNumSlots(bagID) or 0
        for slot = 1, numSlots do
            local link = API and API:GetItemLinkBySlot(bagID, slot) or GetContainerItemLink(bagID, slot)
            if link then
                local itemID = API and API:GetIdFromLink(link) or tonumber(string.match(link, "item:(%d+)"))
                if itemID then
                    sessionItems[itemID] = true
                end
            end
        end
    end
end

-- Public API for new item tracking
function Categorizer:IsNewItem(itemID)
    if not itemID then return false end
    return newItems[itemID] == true
end

function Categorizer:MarkAsNew(itemID)
    if itemID and not sessionItems[itemID] then
        newItems[itemID] = true
    end
end

function Categorizer:ClearNewItem(itemID)
    if itemID then
        newItems[itemID] = nil
    end
end

function Categorizer:ClearAllNewItems()
    newItems = {}
end

function Categorizer:SnapshotInventory()
    SnapshotInventory()
end

-- =============================================================================
-- Perishable Items Registry
-- =============================================================================
-- ʕ •ᴥ•ʔ✿ Time-limited items that must be turned in before they expire ✿ ʕ •ᴥ•ʔ

local PERISHABLE_ITEMS = {
    [50289] = true,  -- Blacktip Shark (1 hour turn-in)
}

function Categorizer:IsPerishableItem(itemID)
    if not itemID then return false end
    if PERISHABLE_ITEMS[itemID] then return true end
    if OmniInventoryDB and OmniInventoryDB.perishableItems
        and OmniInventoryDB.perishableItems[itemID] then
        return true
    end
    return false
end

function Categorizer:AddPerishableItem(itemID)
    if not itemID then return end
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.perishableItems = OmniInventoryDB.perishableItems or {}
    OmniInventoryDB.perishableItems[itemID] = true
end

function Categorizer:RemovePerishableItem(itemID)
    if not itemID then return end
    if OmniInventoryDB and OmniInventoryDB.perishableItems then
        OmniInventoryDB.perishableItems[itemID] = nil
    end
end

-- =============================================================================
-- Category Filters
-- =============================================================================

-- Check if item is a quest item
local function IsQuestItem(itemInfo)
    if not itemInfo or not itemInfo.bagID or not itemInfo.slotID then
        return false
    end

    -- GetContainerItemQuestInfo was added in 3.3.3
    local isQuestItem, questId, isActive = GetContainerItemQuestInfo(itemInfo.bagID, itemInfo.slotID)
    return isQuestItem or false
end

-- ʕ •ᴥ•ʔ✿ Native-first equipment manager membership check ✿ ʕ •ᴥ•ʔ
local function IsEquipmentSetItem(itemInfo)
    if not itemInfo then return false end

    -- Preferred path: ask the C extension about this exact slot instance.
    local API = Omni.API
    if API and itemInfo.bagID and itemInfo.slotID then
        local inSet = API:IsItemInEquipmentSet(itemInfo.bagID, itemInfo.slotID)
        if inSet ~= nil then
            return inSet
        end
    end

    -- Fallback: iterate saved sets by itemID (slower, misses specific instances).
    if not itemInfo.hyperlink then return false end

    local numSets = GetNumEquipmentSets and GetNumEquipmentSets() or 0
    for i = 1, numSets do
        local name = GetEquipmentSetInfo(i)
        if name then
            local itemIDs = GetEquipmentSetItemIDs(name)
            if itemIDs then
                for _, itemID in pairs(itemIDs) do
                    if itemID == itemInfo.itemID then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function GetItemID(itemInfo)
    if not itemInfo then
        return nil
    end
    if itemInfo.itemID then
        return itemInfo.itemID
    end
    if itemInfo.hyperlink then
        if Omni.API then
            return Omni.API:GetIdFromLink(itemInfo.hyperlink)
        end
        return tonumber(string.match(itemInfo.hyperlink, "item:(%d+)"))
    end
    return nil
end

local function IsAttunableItem(itemInfo)
    local itemID = GetItemID(itemInfo)
    if not itemID then
        return false
    end

    -- Must be attunable by THIS character (class/level/proficiency aware)
    if not _G.CanAttuneItemHelper or CanAttuneItemHelper(itemID) < 1 then
        return false
    end

    -- Optional safety: if API says nobody can attune it at all, reject
    if _G.IsAttunableBySomeone then
        local accountCheck = IsAttunableBySomeone(itemID)
        if not accountCheck or accountCheck == 0 then
            return false
        end
    end

    -- ʕ •ᴥ•ʔ✿ Highest attune across forges/affixes via native C extension ✿ ʕ •ᴥ•ʔ
    local API = Omni.API
    local progress
    if API then
        progress = API:GetHighestAttunePct(itemID, -1)
    end

    -- Legacy fallback when the shim or native API isn't available
    if type(progress) ~= "number" then
        if _G.GetItemAttuneProgress then
            local titanforged
            if _G.GetItemLinkTitanforge and itemInfo and itemInfo.hyperlink then
                local forge = GetItemLinkTitanforge(itemInfo.hyperlink)
                if type(forge) == "number" and forge > 0 then
                    titanforged = forge
                end
            elseif _G.GetItemAttuneForge then
                local forge = GetItemAttuneForge(itemID)
                if type(forge) == "number" and forge > 0 then
                    titanforged = forge
                end
            end
            progress = GetItemAttuneProgress(itemID, nil, titanforged)
        end

        if type(progress) ~= "number" and _G.GetItemLinkAttuneProgress and itemInfo and itemInfo.hyperlink then
            progress = GetItemLinkAttuneProgress(itemInfo.hyperlink)
        end
    end

    -- If no progress is resolvable at all, fail closed so the category stays strict
    if type(progress) ~= "number" then
        return false
    end

    return progress < 100
end

-- Get item type fields from itemInfo or GetItemInfo fallback
local function GetItemTypeInfo(itemInfo)
    if not itemInfo then
        return nil, nil, nil
    end

    local itemType = itemInfo.itemType
    local itemSubType = itemInfo.itemSubType
    local equipSlot = itemInfo.equipSlot

    if itemType then
        return itemType, itemSubType, equipSlot
    end

    if not itemInfo.hyperlink then
        return nil, nil, nil
    end

    local _, _, _, _, _, resolvedType, resolvedSubType, _, resolvedEquipSlot = GetItemInfo(itemInfo.hyperlink)
    return resolvedType, resolvedSubType, resolvedEquipSlot
end

local function IsEquipmentItem(itemInfo)
    local itemType, _, equipSlot = GetItemTypeInfo(itemInfo)
    if equipSlot and equipSlot ~= "" and equipSlot ~= "INVTYPE_BAG" and equipSlot ~= "INVTYPE_QUIVER" then
        return true
    end

    -- Fallback for uncached equip slots
    return itemType == "Armor" or itemType == "Weapon"
end

local function IsBoEItem(itemInfo)
    if not itemInfo then
        return false
    end
    if itemInfo.bindType ~= "BoE" then
        return false
    end
    return IsEquipmentItem(itemInfo)
end

-- =============================================================================
-- Heuristic Classification
-- =============================================================================

local TYPE_TO_CATEGORY = {
    -- Main types
    ["Armor"]         = "Equipment",
    ["Weapon"]        = "Equipment",
    ["Consumable"]    = "Consumables",
    ["Trade Goods"]   = "Trade Goods",
    ["Reagent"]       = "Reagents",
    ["Recipe"]        = "Trade Goods",
    ["Gem"]           = "Trade Goods",
    ["Quest"]         = "Quest Items",
    ["Key"]           = "Keys",
    ["Miscellaneous"] = "Miscellaneous",
    ["Container"]     = "Bags",
    ["Projectile"]    = "Ammo",
    ["Quiver"]        = "Bags",
    ["Glyph"]         = "Glyphs",

    -- Subtypes (for more specific matching)
    ["Potion"]        = "Consumables",
    ["Elixir"]        = "Consumables",
    ["Flask"]         = "Consumables",
    ["Food & Drink"]  = "Consumables",
    ["Bandage"]       = "Consumables",
    ["Scroll"]        = "Consumables",
    ["Other"]         = "Consumables",  -- Consumable subtype
    ["Leather"]       = "Trade Goods",
    ["Metal & Stone"] = "Trade Goods",
    ["Cloth"]         = "Trade Goods",
    ["Herb"]          = "Trade Goods",
    ["Enchanting"]    = "Trade Goods",
    ["Jewelcrafting"] = "Trade Goods",
    ["Parts"]         = "Trade Goods",
    ["Devices"]       = "Trade Goods",
    ["Explosives"]    = "Trade Goods",
    ["Mount"]         = "Miscellaneous",
    ["Companion Pets"] = "Miscellaneous",
    ["Holiday"]       = "Miscellaneous",
}

local function ClassifyByItemType(itemInfo)
    local itemType, itemSubType = GetItemTypeInfo(itemInfo)

    if not itemType then
        return "Miscellaneous"
    end

    -- Equipment must win over subtype names like "Cloth"/"Leather".
    if IsEquipmentItem(itemInfo) then
        return "Equipment"
    end

    -- These top-level types are unambiguous.
    if itemType == "Trade Goods" then return "Trade Goods" end
    if itemType == "Reagent" then return "Reagents" end
    if itemType == "Container" then return "Bags" end
    if itemType == "Projectile" then return "Ammo" end
    if itemType == "Glyph" then return "Glyphs" end
    if itemType == "Quest" then return "Quest Items" end
    if itemType == "Key" then return "Keys" end

    -- Check subtype first for more specific classification
    if itemSubType then
        local subCategory = TYPE_TO_CATEGORY[itemSubType]
        if subCategory then
            return subCategory
        end
    end

    -- Fallback to main type
    return TYPE_TO_CATEGORY[itemType] or "Miscellaneous"
end

-- =============================================================================
-- Priority Pipeline
-- =============================================================================

function Categorizer:GetCategory(itemInfo)
    if not itemInfo then
        return "Miscellaneous"
    end

    -- Priority 1: Manual Override
    if itemInfo.itemID and OmniInventoryDB and OmniInventoryDB.categoryOverrides then
        local override = OmniInventoryDB.categoryOverrides[itemInfo.itemID]
        if override then
            return override
        end
    end

    -- Priority 1.5: Custom Rules Engine
    if Omni.Rules then
        local matchedRule = Omni.Rules:FindMatchingRule(itemInfo)
        if matchedRule and matchedRule.category then
            return matchedRule.category
        end
    end

    -- Priority 1.75: Perishable / time-limited turn-in items
    if self:IsPerishableItem(GetItemID(itemInfo)) then
        return "Perishable"
    end

    -- Priority 2: Quest Items
    if IsQuestItem(itemInfo) then
        return "Quest Items"
    end

    -- Priority 3: Attunable
    if IsAttunableItem(itemInfo) then
        return "Attunable"
    end

    -- Priority 4: Equipment Sets
    if IsEquipmentSetItem(itemInfo) then
        return "Equipment Sets"
    end

    -- Priority 5: BoE equipment
    if IsBoEItem(itemInfo) then
        return "BoE"
    end

    -- Priority 6: New Items (session-based)
    if self:IsNewItem(itemInfo.itemID) then
        -- Don't return here, just mark - new items also belong to a real category
        -- We'll handle "New" as a special overlay, not a category
    end

    -- Priority 7: Check quality for junk
    if itemInfo.quality == 0 then
        return "Junk"
    end

    -- Priority 10+: Heuristic classification
    return ClassifyByItemType(itemInfo)
end

-- =============================================================================
-- Manual Override Management
-- =============================================================================

function Categorizer:SetManualOverride(itemID, categoryName)
    if not itemID or not categoryName then return end

    OmniInventoryDB.categoryOverrides = OmniInventoryDB.categoryOverrides or {}
    OmniInventoryDB.categoryOverrides[itemID] = categoryName
end

function Categorizer:ClearManualOverride(itemID)
    if not itemID then return end

    if OmniInventoryDB and OmniInventoryDB.categoryOverrides then
        OmniInventoryDB.categoryOverrides[itemID] = nil
    end
end

-- =============================================================================
-- Category Registry
-- =============================================================================

function Categorizer:RegisterCategory(name, priority, icon, color, filterFunc)
    categories[name] = {
        name = name,
        priority = priority,
        icon = icon,
        color = color or CATEGORY_COLORS[name] or { r = 0.5, g = 0.5, b = 0.5 },
        filter = filterFunc,
    }

    -- Rebuild sorted order
    categoryOrder = {}
    for catName, catDef in pairs(categories) do
        table.insert(categoryOrder, catDef)
    end
    table.sort(categoryOrder, function(a, b)
        return a.priority < b.priority
    end)
end

function Categorizer:GetCategoryInfo(name)
    return categories[name] or {
        name = name,
        priority = 99,
        color = CATEGORY_COLORS[name] or { r = 0.5, g = 0.5, b = 0.5 },
    }
end

function Categorizer:GetAllCategories()
    return categoryOrder
end

function Categorizer:GetCategoryColor(name)
    local info = self:GetCategoryInfo(name)
    return info.color.r, info.color.g, info.color.b
end

-- =============================================================================
-- Categorize All Items
-- =============================================================================

function Categorizer:CategorizeItems(items)
    local categorized = {}  -- { categoryName = { items } }

    for _, itemInfo in ipairs(items) do
        local category = self:GetCategory(itemInfo)

        if not categorized[category] then
            categorized[category] = {}
        end

        itemInfo.category = category
        table.insert(categorized[category], itemInfo)
    end

    return categorized
end

-- =============================================================================
-- Initialization
-- =============================================================================

function Categorizer:Init()
    -- Register default categories
    self:RegisterCategory("Perishable", 1, nil, CATEGORY_COLORS["Perishable"])
    self:RegisterCategory("Quest Items", 2, nil, CATEGORY_COLORS["Quest Items"])
    self:RegisterCategory("Attunable", 3, nil, CATEGORY_COLORS["Attunable"])
    self:RegisterCategory("Equipment Sets", 4, nil, CATEGORY_COLORS["Equipment Sets"])
    self:RegisterCategory("BoE", 5, nil, CATEGORY_COLORS["BoE"])
    self:RegisterCategory("New Items", 6, nil, CATEGORY_COLORS["New Items"])
    self:RegisterCategory("Equipment", 10, nil, CATEGORY_COLORS["Equipment"])
    self:RegisterCategory("Consumables", 11, nil, CATEGORY_COLORS["Consumables"])
    self:RegisterCategory("Trade Goods", 12, nil, CATEGORY_COLORS["Trade Goods"])
    self:RegisterCategory("Reagents", 13, nil, CATEGORY_COLORS["Reagents"])
    self:RegisterCategory("Keys", 15, nil, CATEGORY_COLORS["Keys"])
    self:RegisterCategory("Bags", 16, nil, CATEGORY_COLORS["Bags"])
    self:RegisterCategory("Ammo", 17, nil, CATEGORY_COLORS["Ammo"])
    self:RegisterCategory("Glyphs", 18, nil, CATEGORY_COLORS["Glyphs"])
    self:RegisterCategory("Junk", 90, nil, CATEGORY_COLORS["Junk"])
    self:RegisterCategory("Miscellaneous", 99, nil, CATEGORY_COLORS["Miscellaneous"])

    -- Initialize manual overrides
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.categoryOverrides = OmniInventoryDB.categoryOverrides or {}
    OmniInventoryDB.perishableItems = OmniInventoryDB.perishableItems or {}

    -- Snapshot current inventory for "new items" tracking
    SnapshotInventory()
end

print("|cFF00FF00OmniInventory|r: Categorizer loaded")
