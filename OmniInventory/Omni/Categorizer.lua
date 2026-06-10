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
local categoryOrder = {}
local categoryOrderIndex = nil
local USER_CATEGORY_COLOR = { r = 0.25, g = 1.0, b = 0.35 }

local DEFAULT_CATEGORY_ORDER = {
    "Tools",
    "Perishable",
    "Quest Items",
    "Mythic+",
    "Tier Token",
    "Mystic Enchants",
    "Upgradable Items",
    "Attunable",
    "Account Attunable",
    "Transmog",
    "Ascension",
    "Vanity",
    "New Items",
    "BoE",
    "Equipment Sets",
    "Equipment",
    "Consumables",
    "Trade Goods",
    "Reagents",
    "Keys",
    "Bags",
    "Ammo",
    "Glyphs",
    "Junk",
    "Miscellaneous",
}

local function TrimCategoryName(name)
    name = tostring(name or "")
    return (string.gsub(name, "^%s*(.-)%s*$", "%1"))
end

local function CopyColor(color)
    if type(color) ~= "table" then
        return { r = USER_CATEGORY_COLOR.r, g = USER_CATEGORY_COLOR.g, b = USER_CATEGORY_COLOR.b }
    end
    return {
        r = tonumber(color.r or color[1]) or USER_CATEGORY_COLOR.r,
        g = tonumber(color.g or color[2]) or USER_CATEGORY_COLOR.g,
        b = tonumber(color.b or color[3]) or USER_CATEGORY_COLOR.b,
    }
end

local function GetUserCategories()
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.global = OmniInventoryDB.global or {}
    if type(OmniInventoryDB.global.userCategories) ~= "table" then
        OmniInventoryDB.global.userCategories = {}
    end
    return OmniInventoryDB.global.userCategories
end

local function GetHiddenCategories()
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.global = OmniInventoryDB.global or {}
    if type(OmniInventoryDB.global.hiddenCategories) ~= "table" then
        OmniInventoryDB.global.hiddenCategories = {}
    end
    return OmniInventoryDB.global.hiddenCategories
end

local function IsCategoryHiddenName(name)
    name = TrimCategoryName(name)
    if name == "" or name == "Miscellaneous" then return false end
    return GetHiddenCategories()[name] == true
end

local function IsCategoryVisible(name)
    return not IsCategoryHiddenName(name)
end

local function CopyDefaultCategoryOrder()
    local copy = {}
    for i, name in ipairs(DEFAULT_CATEGORY_ORDER) do
        copy[i] = name
    end
    return copy
end

local function EnsureCategoryInSavedOrder(name)
    name = TrimCategoryName(name)
    if name == "" then return end

    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.global = OmniInventoryDB.global or {}
    if type(OmniInventoryDB.global.categoryOrder) ~= "table" then
        OmniInventoryDB.global.categoryOrder = CopyDefaultCategoryOrder()
    end

    for _, categoryName in ipairs(OmniInventoryDB.global.categoryOrder) do
        if categoryName == name then
            return
        end
    end

    table.insert(OmniInventoryDB.global.categoryOrder, name)
    categoryOrderIndex = nil
end

local function RemoveCategoryFromSavedOrder(name)
    if not OmniInventoryDB or not OmniInventoryDB.global
            or type(OmniInventoryDB.global.categoryOrder) ~= "table" then
        return
    end

    for i = #OmniInventoryDB.global.categoryOrder, 1, -1 do
        if OmniInventoryDB.global.categoryOrder[i] == name then
            table.remove(OmniInventoryDB.global.categoryOrder, i)
        end
    end
    categoryOrderIndex = nil
end

local function GetSavedCategoryOrder()
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.global = OmniInventoryDB.global or {}
    if type(OmniInventoryDB.global.categoryOrder) ~= "table" then
        OmniInventoryDB.global.categoryOrder = CopyDefaultCategoryOrder()
    end
    local seen = {}
    for _, name in ipairs(OmniInventoryDB.global.categoryOrder) do
        seen[name] = true
    end
    for name in pairs(GetUserCategories()) do
        if type(name) == "string" and name ~= "" and not seen[name] then
            table.insert(OmniInventoryDB.global.categoryOrder, name)
            seen[name] = true
        end
    end
    return OmniInventoryDB.global.categoryOrder
end

local function GetCategoryOrderIndex(name)
    if not categoryOrderIndex then
        categoryOrderIndex = {}
        for i, categoryName in ipairs(GetSavedCategoryOrder()) do
            if type(categoryName) == "string" and not categoryOrderIndex[categoryName] then
                categoryOrderIndex[categoryName] = i
            end
        end
        for i, categoryName in ipairs(DEFAULT_CATEGORY_ORDER) do
            if not categoryOrderIndex[categoryName] then
                categoryOrderIndex[categoryName] = i
            end
        end
    end
    return categoryOrderIndex[name] or 10000
end

-- Default colors for categories
local CATEGORY_COLORS = {
    ["Perishable"]      = { r = 1.0, g = 0.3, b = 0.3 },
    ["Quest Items"]     = { r = 1.0, g = 0.82, b = 0.0 },
    ["Mythic+"]         = { r = 0.95, g = 0.35, b = 1.0 },
    ["Tier Token"]      = { r = 1.0, g = 0.64, b = 0.20 },
    ["Mystic Enchants"] = { r = 0.35, g = 0.85, b = 1.0 },
    ["Upgradable Items"] = { r = 1.0, g = 0.7, b = 0.2 },
    ["Attunable"]       = { r = 0.0, g = 0.9, b = 0.5 },
    ["Account Attunable"] = { r = 0.85, g = 0.45, b = 1.0 },
    ["Transmog"]        = { r = 0.95, g = 0.55, b = 1.0 },
    ["Ascension"]       = { r = 1.0, g = 0.78, b = 0.25 },
    ["Vanity"]          = { r = 0.82, g = 0.62, b = 1.0 },
    ["BoE"]             = { r = 0.4, g = 0.9, b = 1.0 },
    ["Equipment"]       = { r = 0.0, g = 0.8, b = 0.0 },
    ["Equipment Sets"]  = { r = 0.4, g = 0.8, b = 1.0 },
    ["Consumables"]     = { r = 1.0, g = 0.5, b = 0.5 },
    ["Trade Goods"]     = { r = 0.8, g = 0.6, b = 0.4 },
    ["Reagents"]        = { r = 0.6, g = 0.4, b = 0.8 },
    ["Tools"]           = { r = 0.6, g = 0.8, b = 1.0 },
    ["Junk"]            = { r = 0.6, g = 0.6, b = 0.6 },
    ["New Items"]       = { r = 0.0, g = 1.0, b = 0.5 },
    ["Miscellaneous"]   = { r = 0.5, g = 0.5, b = 0.5 },
    ["Keys"]            = { r = 1.0, g = 0.9, b = 0.4 },
    ["Bags"]            = { r = 0.6, g = 0.4, b = 0.2 },
    ["Ammo"]            = { r = 0.8, g = 0.7, b = 0.5 },
    ["Glyphs"]          = { r = 0.5, g = 0.8, b = 1.0 },
}

local DEFAULT_CATEGORY_RULES = {
    ["Perishable"] = {
        "Item ID is listed as perishable or added to the perishable SavedVariables list.",
    },
    ["Quest Items"] = {
        "Container slot is marked as a quest item by GetContainerItemQuestInfo().",
        "Fallback item type is Quest.",
    },
    ["Mythic+"] = {
        "Ascension instant item description contains a Mythic marker.",
    },
    ["Tier Token"] = {
        "Ascension instant item description identifies the item as a tier token.",
    },
    ["Mystic Enchants"] = {
        "Ascension instant item description contains the @re enchant marker.",
    },
    ["Upgradable Items"] = {
        "Item ID is included in the curated upgradable-item allowlist.",
    },
    ["Attunable"] = {
        "Current character can attune the item and link-based progress is below 100%.",
    },
    ["Account Attunable"] = {
        "BoE equipment cannot be attuned by this character but can be attuned by another character on the account.",
    },
    ["Equipment Sets"] = {
        "Item is present in an equipment set by slot-aware API or saved equipment-set item IDs.",
    },
    ["BoE"] = {
        "Item is unbound equipment or bind state cannot be scanned by the client.",
    },
    ["Transmog"] = {
        "Ascension equipment appearance has not been collected.",
    },
    ["Ascension"] = {
        "Ascension vanity item is registered in the global vanity table.",
    },
    ["Vanity"] = {
        "Ascension quality-6 vanity-style item is detected.",
    },
    ["New Items"] = {
        "Session tracking marks newly acquired item IDs for highlighting; primary category stays unchanged.",
    },
    ["Equipment"] = {
        "Item has an equipment slot or falls back to Armor/Weapon item type.",
    },
    ["Consumables"] = {
        "Item type or subtype maps to consumable behavior.",
    },
    ["Trade Goods"] = {
        "Item type or subtype maps to trade goods, recipes, gems, or profession materials.",
    },
    ["Reagents"] = {
        "Item type is Reagent.",
    },
    ["Tools"] = {
        "Item ID is included in the curated tools allowlist.",
    },
    ["Keys"] = {
        "Item type is Key.",
    },
    ["Bags"] = {
        "Item type is Container, Quiver, or bag-style container.",
    },
    ["Ammo"] = {
        "Item type is Projectile.",
    },
    ["Glyphs"] = {
        "Item type is Glyph.",
    },
    ["Junk"] = {
        "Item quality is poor/grey.",
    },
    ["Miscellaneous"] = {
        "Fallback when no visible category rule matches.",
    },
}

-- Curated allowlist of item IDs that participate in upgrade paths and should
-- stay grouped together instead of being absorbed by broader heuristics.
local UPGRADABLE_ITEMS = {
    [2944] = true,
    [4243] = true,
    [4246] = true,
    [4255] = true,
    [4368] = true,
    [4385] = true,
    [5966] = true,
    [7387] = true,
    [10026] = true,
    [10500] = true,
    [10502] = true,
    [10543] = true,
    [14044] = true,
    [16666] = true,
    [16667] = true,
    [16668] = true,
    [16669] = true,
    [16670] = true,
    [16671] = true,
    [16672] = true,
    [16673] = true,
    [16674] = true,
    [16675] = true,
    [16676] = true,
    [16677] = true,
    [16678] = true,
    [16679] = true,
    [16680] = true,
    [16681] = true,
    [16682] = true,
    [16683] = true,
    [16684] = true,
    [16685] = true,
    [16686] = true,
    [16687] = true,
    [16688] = true,
    [16689] = true,
    [16690] = true,
    [16691] = true,
    [16692] = true,
    [16693] = true,
    [16694] = true,
    [16695] = true,
    [16696] = true,
    [16697] = true,
    [16698] = true,
    [16699] = true,
    [16700] = true,
    [16701] = true,
    [16702] = true,
    [16703] = true,
    [16704] = true,
    [16705] = true,
    [16706] = true,
    [16707] = true,
    [16708] = true,
    [16709] = true,
    [16710] = true,
    [16711] = true,
    [16712] = true,
    [16713] = true,
    [16714] = true,
    [16715] = true,
    [16716] = true,
    [16717] = true,
    [16718] = true,
    [16719] = true,
    [16720] = true,
    [16721] = true,
    [16722] = true,
    [16723] = true,
    [16724] = true,
    [16725] = true,
    [16726] = true,
    [16727] = true,
    [16728] = true,
    [16729] = true,
    [16730] = true,
    [16731] = true,
    [16732] = true,
    [16733] = true,
    [16734] = true,
    [16735] = true,
    [16736] = true,
    [16737] = true,
    [17074] = true,
    [17193] = true,
    [17204] = true,
    [18608] = true,
    [21160] = true,
    [21196] = true,
    [21197] = true,
    [21198] = true,
    [21199] = true,
    [21201] = true,
    [21202] = true,
    [21203] = true,
    [21204] = true,
    [21206] = true,
    [21207] = true,
    [21208] = true,
    [21209] = true,
    [23563] = true,
    [23564] = true,
    [28425] = true,
    [28426] = true,
    [28428] = true,
    [28429] = true,
    [28431] = true,
    [28432] = true,
    [28434] = true,
    [28435] = true,
    [28437] = true,
    [28438] = true,
    [28440] = true,
    [28441] = true,
    [28483] = true,
    [28484] = true,
    [32461] = true,
    [32472] = true,
    [32473] = true,
    [32474] = true,
    [32475] = true,
    [32476] = true,
    [32478] = true,
    [32479] = true,
    [32480] = true,
    [32494] = true,
    [32495] = true,
    [32649] = true,
    [34167] = true,
    [34169] = true,
    [34170] = true,
    [34180] = true,
    [34186] = true,
    [34188] = true,
    [34192] = true,
    [34193] = true,
    [34195] = true,
    [34202] = true,
    [34208] = true,
    [34209] = true,
    [34211] = true,
    [34212] = true,
    [34215] = true,
    [34216] = true,
    [34229] = true,
    [34233] = true,
    [34234] = true,
    [34243] = true,
    [34244] = true,
    [34245] = true,
    [34332] = true,
    [34339] = true,
    [34342] = true,
    [34345] = true,
    [34350] = true,
    [34351] = true,
    [40585] = true,
    [40586] = true,
    [41245] = true,
    [41355] = true,
    [41520] = true,
    [44934] = true,
    [44935] = true,
    [45688] = true,
    [45689] = true,
    [45690] = true,
    [45691] = true,
    [48954] = true,
    [48955] = true,
    [48956] = true,
    [48957] = true,
    [49302] = true,
    [49496] = true,
    [49888] = true,
    [50078] = true,
    [50079] = true,
    [50080] = true,
    [50081] = true,
    [50082] = true,
    [50087] = true,
    [50088] = true,
    [50089] = true,
    [50090] = true,
    [50094] = true,
    [50095] = true,
    [50096] = true,
    [50097] = true,
    [50098] = true,
    [50105] = true,
    [50106] = true,
    [50107] = true,
    [50108] = true,
    [50109] = true,
    [50113] = true,
    [50114] = true,
    [50115] = true,
    [50116] = true,
    [50117] = true,
    [50118] = true,
    [50240] = true,
    [50241] = true,
    [50242] = true,
    [50243] = true,
    [50244] = true,
    [50275] = true,
    [50276] = true,
    [50277] = true,
    [50278] = true,
    [50279] = true,
    [50324] = true,
    [50325] = true,
    [50326] = true,
    [50327] = true,
    [50328] = true,
    [50391] = true,
    [50392] = true,
    [50393] = true,
    [50394] = true,
    [50396] = true,
    [50765] = true,
    [50766] = true,
    [50767] = true,
    [50768] = true,
    [50769] = true,
    [50819] = true,
    [50820] = true,
    [50821] = true,
    [50822] = true,
    [50823] = true,
    [50824] = true,
    [50825] = true,
    [50826] = true,
    [50827] = true,
    [50828] = true,
    [50830] = true,
    [50831] = true,
    [50832] = true,
    [50833] = true,
    [50834] = true,
    [50835] = true,
    [50836] = true,
    [50837] = true,
    [50838] = true,
    [50839] = true,
    [50841] = true,
    [50842] = true,
    [50843] = true,
    [50844] = true,
    [50845] = true,
    [50846] = true,
    [50847] = true,
    [50848] = true,
    [50849] = true,
    [50850] = true,
    [50853] = true,
    [50854] = true,
    [50855] = true,
    [50856] = true,
    [50857] = true,
    [50860] = true,
    [50861] = true,
    [50862] = true,
    [50863] = true,
    [50864] = true,
    [50865] = true,
    [50866] = true,
    [50867] = true,
    [50868] = true,
    [50869] = true,
    [51125] = true,
    [51126] = true,
    [51127] = true,
    [51128] = true,
    [51129] = true,
    [51130] = true,
    [51131] = true,
    [51132] = true,
    [51133] = true,
    [51134] = true,
    [51135] = true,
    [51136] = true,
    [51137] = true,
    [51138] = true,
    [51139] = true,
    [51140] = true,
    [51141] = true,
    [51142] = true,
    [51143] = true,
    [51144] = true,
    [51145] = true,
    [51146] = true,
    [51147] = true,
    [51148] = true,
    [51149] = true,
    [51150] = true,
    [51151] = true,
    [51152] = true,
    [51153] = true,
    [51154] = true,
    [51155] = true,
    [51156] = true,
    [51157] = true,
    [51158] = true,
    [51159] = true,
    [51160] = true,
    [51161] = true,
    [51162] = true,
    [51163] = true,
    [51164] = true,
    [51165] = true,
    [51166] = true,
    [51167] = true,
    [51168] = true,
    [51169] = true,
    [51170] = true,
    [51171] = true,
    [51172] = true,
    [51173] = true,
    [51174] = true,
    [51175] = true,
    [51176] = true,
    [51177] = true,
    [51178] = true,
    [51179] = true,
    [51180] = true,
    [51181] = true,
    [51182] = true,
    [51183] = true,
    [51184] = true,
    [51185] = true,
    [51186] = true,
    [51187] = true,
    [51188] = true,
    [51189] = true,
    [51190] = true,
    [51191] = true,
    [51192] = true,
    [51193] = true,
    [51194] = true,
    [51195] = true,
    [51196] = true,
    [51197] = true,
    [51198] = true,
    [51199] = true,
    [51200] = true,
    [51201] = true,
    [51202] = true,
    [51203] = true,
    [51204] = true,
    [51205] = true,
    [51206] = true,
    [51207] = true,
    [51208] = true,
    [51209] = true,
    [51210] = true,
    [51211] = true,
    [51212] = true,
    [51213] = true,
    [51214] = true,
    [51215] = true,
    [51216] = true,
    [51217] = true,
    [51218] = true,
    [51219] = true,
}

local TOOLS_ITEMS = {
    [7453] = true,
    [45120] = true,
    [6256] = true,
    [6366] = true,
    [6367] = true,
    [6365] = true,
    [25978] = true,
    [44050] = true,
    [45991] = true,
    [45858] = true,
    [15846] = true,
    [45992] = true,
    [19970] = true,
    [7005] = true,
    [2901] = true,
    [5956] = true,
    [6219] = true,
    [10498] = true,
    [20815] = true,
    [20824] = true,
    [39505] = true,
    [6218] = true,
    [6339] = true,
    [11130] = true,
    [11145] = true,
    [16207] = true,
    [22461] = true,
    [22462] = true,
    [22463] = true,
    [44452] = true,
    [40772] = true,
    [23821] = true,
    [9149] = true,
    [6954] = true,
    [13503] = true,
    [35751] = true,
    [35748] = true,
    [35750] = true,
    [35749] = true,
    [44322] = true,
    [44323] = true,
    [44324] = true,
    [49040] = true,
    [6948] = true,
    [40768] = true,
    [6265] = true,
    [22057] = true,
    [12534] = true,
    [10818] = true,
    [19931] = true,
    [21986] = true,
    [49633] = true,
    [49634] = true,
    [60274] = true,
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

    -- ʕ •ᴥ•ʔ✿ Strict hyperlink-only progress resolution ✿ ʕ •ᴥ•ʔ
    local progress
    if _G.GetItemLinkAttuneProgress and itemInfo and itemInfo.hyperlink then
        progress = GetItemLinkAttuneProgress(itemInfo.hyperlink)
    end

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
    if itemInfo.bindType == "BoE" then
        return IsEquipmentItem(itemInfo)
    end
    if itemInfo.isBound == true or itemInfo.bindType == "BoP" then
        return false
    end

    local API = Omni.API
    if API and API.hasCustomSoulbound == false then
        return IsEquipmentItem(itemInfo)
    end

    return false
end

local function IsUpgradableItem(itemInfo)
    local itemID = GetItemID(itemInfo)
    if not itemID then
        return false
    end
    return UPGRADABLE_ITEMS[itemID] == true
end

local function IsToolsItem(itemInfo)
    local itemID = GetItemID(itemInfo)
    if not itemID then
        return false
    end
    return TOOLS_ITEMS[itemID] == true
end

local ascensionInstantCache = {}
local ascensionInstantDetected = nil

local function GetAscensionInstantInfo(itemID)
    if not itemID or ascensionInstantDetected == false or type(_G.GetItemInfoInstant) ~= "function" then
        return nil
    end
    if ascensionInstantCache[itemID] then
        return ascensionInstantCache[itemID]
    end

    local info = GetItemInfoInstant(itemID)
    if type(info) == "table" and (info.description ~= nil or info.inventoryType ~= nil) then
        ascensionInstantDetected = true
        ascensionInstantCache[itemID] = info
        return info
    end
    if ascensionInstantDetected == nil then
        ascensionInstantDetected = false
    end
    return nil
end

local function HasMythicDescription(description)
    return type(description) == "string"
        and (string.find(description, "@Mythic %d") or string.find(description, "@Mythic Level", 1, true))
end

local function IsUncollectedAppearance(itemID, itemSubType)
    if itemID == 5956 or itemSubType == "Thrown" then
        return false
    end
    if not (_G.C_Appearance and C_Appearance.GetItemAppearanceID
            and _G.C_AppearanceCollection and C_AppearanceCollection.IsAppearanceCollected) then
        return false
    end

    local appearanceID = C_Appearance.GetItemAppearanceID(itemID)
    return appearanceID and not C_AppearanceCollection.IsAppearanceCollected(appearanceID)
end

local function GetAscensionCategory(itemInfo)
    local itemID = GetItemID(itemInfo)
    if not itemID then
        return nil
    end

    local itemType, itemSubType = GetItemTypeInfo(itemInfo)
    local isEquipment = itemType == "Weapon" or itemType == "Armor"
    local ascensionInfo = GetAscensionInstantInfo(itemID)
    local description = ascensionInfo and ascensionInfo.description

    if HasMythicDescription(description) then
        return "Mythic+"
    end

    if isEquipment then
        if IsUncollectedAppearance(itemID, itemSubType) then
            return "Transmog"
        end
    elseif type(description) == "string" then
        if ascensionInfo.inventoryType == 0
                and (string.find(description, "This Token", 1, true)
                    or string.find(description, "This token", 1, true)) then
            return "Tier Token"
        end
        if string.find(description, "@re", 1, true) then
            return "Mystic Enchants"
        end
    end

    if itemInfo.quality == 6 and (ascensionInfo or type(_G.VANITY_ITEMS) == "table") then
        local vanityEntry = _G.VANITY_ITEMS and _G.VANITY_ITEMS[itemID]
        if type(vanityEntry) == "table" and tonumber(vanityEntry.itemid or 0) > 0 then
            return "Ascension"
        end
        return "Vanity"
    end

    return nil
end

-- ʕ ◕ᴥ◕ ʔ✿ Account Attunable: BoE equipment that THIS character cannot
-- attune but some OTHER character on the account can, and that isn't
-- already fully attuned. Helps surface gear to mail off to alts instead
-- of vendoring it alongside regular BoE drops. ✿ ʕ ◕ᴥ◕ ʔ
local function IsAccountAttunableItem(itemInfo)
    if not IsBoEItem(itemInfo) then
        return false
    end

    local itemID = GetItemID(itemInfo)
    if not itemID then
        return false
    end

    -- Current character must NOT be able to attune it
    if _G.CanAttuneItemHelper and CanAttuneItemHelper(itemID) >= 1 then
        return false
    end

    -- SOMEONE on the account must be able to attune it
    local isAttunableForAccount = itemInfo.isAttunable
    if isAttunableForAccount == nil and _G.IsAttunableBySomeone then
        local check = IsAttunableBySomeone(itemID)
        isAttunableForAccount = check ~= nil and check ~= 0 and check ~= false
    end
    if not isAttunableForAccount then
        return false
    end

    -- ʕ •ᴥ•ʔ✿ Progress < 100%: prefer link-based API so affix variants
    -- resolve correctly (matches IsAttunableItem's resolve chain). ✿ ʕ •ᴥ•ʔ
    local progress
    if _G.GetItemLinkAttuneProgress and itemInfo.hyperlink then
        progress = GetItemLinkAttuneProgress(itemInfo.hyperlink)
    end
    if type(progress) ~= "number" and _G.GetItemAttuneProgress then
        progress = GetItemAttuneProgress(itemID)
    end

    -- Unknown progress on an account-attunable BoE is still worth
    -- surfacing (it's something an alt could use), so fail open here.
    if type(progress) ~= "number" then
        return true
    end

    return progress < 100
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

local function EndGetCategoryPerf(perfToken, result)
    if Omni._perfEnabled and Omni.Perf then
        Omni.Perf:End("categorizer.GetCategory", perfToken, result and { result = result } or nil)
    end
end

local function ResolveAutomaticCategory(self, itemInfo, perfToken)
    if not itemInfo then
        EndGetCategoryPerf(perfToken)
        return "Miscellaneous"
    end

    -- ʕ ● ᴥ ●ʔ Custom Rules Engine disabled — module is no longer loaded (see OmniInventory.toc)

    -- Priority 1.75: Perishable / time-limited turn-in items
    if IsCategoryVisible("Perishable") and self:IsPerishableItem(GetItemID(itemInfo)) then
        EndGetCategoryPerf(perfToken)
        return "Perishable"
    end



    -- Priority 2: Quest Items
    if IsCategoryVisible("Quest Items") and IsQuestItem(itemInfo) then
        EndGetCategoryPerf(perfToken)
        return "Quest Items"
    end

    local ascensionCategory = GetAscensionCategory(itemInfo)
    if ascensionCategory and IsCategoryVisible(ascensionCategory) then
        EndGetCategoryPerf(perfToken)
        return ascensionCategory
    end

    -- Priority 3: Attunable
    if IsCategoryVisible("Attunable") and IsAttunableItem(itemInfo) then
        EndGetCategoryPerf(perfToken)
        return "Attunable"
    end

    -- Priority 4: Equipment Sets
    if IsCategoryVisible("Equipment Sets") and IsEquipmentSetItem(itemInfo) then
        EndGetCategoryPerf(perfToken)
        return "Equipment Sets"
    end

    -- Priority 4.5: Account Attunable (BoE that an alt can attune)
    if IsCategoryVisible("Account Attunable") and IsAccountAttunableItem(itemInfo) then
        EndGetCategoryPerf(perfToken)
        return "Account Attunable"
    end

    -- Prio 5 : Tools
    if IsCategoryVisible("Tools") and IsToolsItem(itemInfo) then
        EndGetCategoryPerf(perfToken)
        return "Tools"
    end

    -- Priority 6: BoE equipment
    if IsCategoryVisible("BoE") and IsBoEItem(itemInfo) then
        EndGetCategoryPerf(perfToken)
        return "BoE"
    end

    -- Priority 7: Explicit upgradable-item allowlist  6 7 6 7 6 7 6  7 6 7 6 7 6 7 6 7 6 7 6 7 6 7 6 7 6 7 6 7 6 7
    if IsCategoryVisible("Upgradable Items") and IsUpgradableItem(itemInfo) then
        EndGetCategoryPerf(perfToken)
        return "Upgradable Items"
    end

    -- Priority 88: Check quality for junk
    if IsCategoryVisible("Junk") and itemInfo.quality == 0 then
        EndGetCategoryPerf(perfToken)
        return "Junk"
    end

    

    -- Priority 10+: Heuristic classification
    local out = ClassifyByItemType(itemInfo)
    if not IsCategoryVisible(out) then
        out = "Miscellaneous"
    end
    EndGetCategoryPerf(perfToken, out)
    return out
end

function Categorizer:GetAutomaticCategory(itemInfo)
    local perfToken = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("categorizer.GetCategory")
    return ResolveAutomaticCategory(self, itemInfo, perfToken)
end

function Categorizer:GetCategory(itemInfo)
    local perfToken = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("categorizer.GetCategory")
    if not itemInfo then
        EndGetCategoryPerf(perfToken)
        return "Miscellaneous"
    end

    -- Priority 1: Manual Override
    if itemInfo.itemID and OmniInventoryDB and OmniInventoryDB.categoryOverrides then
        local override = OmniInventoryDB.categoryOverrides[itemInfo.itemID]
        if override and IsCategoryVisible(override) then
            EndGetCategoryPerf(perfToken)
            return override
        end
    end

    return ResolveAutomaticCategory(self, itemInfo, perfToken)
end

-- =============================================================================
-- Manual Override Management
-- =============================================================================

function Categorizer:SetManualOverride(itemID, categoryName)
    if not itemID or not categoryName then return end

    OmniInventoryDB.categoryOverrides = OmniInventoryDB.categoryOverrides or {}
    categoryName = TrimCategoryName(categoryName)
    if categoryName == "" then return end

    if not categories[categoryName] then
        self:CreateUserCategory(categoryName)
    else
        EnsureCategoryInSavedOrder(categoryName)
    end

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

local function CompareCategoryNames(a, b)
    local orderA = GetCategoryOrderIndex(a)
    local orderB = GetCategoryOrderIndex(b)
    if orderA ~= orderB then
        return orderA < orderB
    end

    local infoA = categories[a]
    local infoB = categories[b]
    local priorityA = infoA and infoA.priority or 99
    local priorityB = infoB and infoB.priority or 99
    if priorityA ~= priorityB then
        return priorityA < priorityB
    end

    return tostring(a) < tostring(b)
end

local function RebuildCategoryOrder()
    categoryOrder = {}
    for _, catDef in pairs(categories) do
        if catDef and IsCategoryVisible(catDef.name) then
            table.insert(categoryOrder, catDef)
        end
    end
    table.sort(categoryOrder, function(a, b)
        return CompareCategoryNames(a.name, b.name)
    end)
end

function Categorizer:RegisterCategory(name, priority, icon, color, filterFunc)
    categories[name] = {
        name = name,
        priority = priority,
        icon = icon,
        color = color or CATEGORY_COLORS[name] or { r = 0.5, g = 0.5, b = 0.5 },
        filter = filterFunc,
    }

    RebuildCategoryOrder()
end

function Categorizer:GetCategoryInfo(name)
    local userCategory = GetUserCategories()[name]
    if userCategory then
        return {
            name = name,
            priority = userCategory.priority or 80,
            color = CopyColor(userCategory.color),
        }
    end

    return categories[name] or {
        name = name,
        priority = 99,
        color = CATEGORY_COLORS[name] or { r = 0.5, g = 0.5, b = 0.5 },
    }
end

function Categorizer:GetCategoryRuleDescriptions(name)
    local source = DEFAULT_CATEGORY_RULES[name]
    local rules = {}
    for i, description in ipairs(source or {}) do
        rules[i] = description
    end
    return rules
end

function Categorizer:GetAllCategories()
    return categoryOrder
end

function Categorizer:GetCategorySortIndex(name)
    return GetCategoryOrderIndex(name)
end

function Categorizer:SortCategoryNames(names)
    table.sort(names, CompareCategoryNames)
end

function Categorizer:GetCategoryOrder()
    local visible = {}
    for _, name in ipairs(GetSavedCategoryOrder()) do
        if IsCategoryVisible(name) then
            visible[#visible + 1] = name
        end
    end
    return visible
end

function Categorizer:IsCategoryHidden(name)
    return IsCategoryHiddenName(name)
end

function Categorizer:HideCategory(name)
    name = TrimCategoryName(name)
    if name == "" or name == "Miscellaneous" then return false end
    if not categories[name] and not GetUserCategories()[name] then return false end

    GetHiddenCategories()[name] = true
    categoryOrderIndex = nil
    RebuildCategoryOrder()
    return true
end

function Categorizer:SetCategoryOrder(order)
    if type(order) ~= "table" then return end

    local cleaned = {}
    local seen = {}
    for _, name in ipairs(order) do
        if type(name) == "string" and name ~= "" and not seen[name] then
            cleaned[#cleaned + 1] = name
            seen[name] = true
        end
    end
    for _, name in ipairs(DEFAULT_CATEGORY_ORDER) do
        if not seen[name] then
            cleaned[#cleaned + 1] = name
            seen[name] = true
        end
    end

    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.global = OmniInventoryDB.global or {}
    OmniInventoryDB.global.categoryOrder = cleaned
    categoryOrderIndex = nil
    RebuildCategoryOrder()
end

function Categorizer:ResetCategoryOrder()
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.global = OmniInventoryDB.global or {}
    OmniInventoryDB.global.categoryOrder = CopyDefaultCategoryOrder()
    OmniInventoryDB.global.hiddenCategories = {}
    for name in pairs(GetUserCategories()) do
        table.insert(OmniInventoryDB.global.categoryOrder, name)
    end
    categoryOrderIndex = nil
    RebuildCategoryOrder()
end

function Categorizer:CreateUserCategory(name)
    name = TrimCategoryName(name)
    if name == "" then return nil end

    local userCategories = GetUserCategories()
    if not categories[name] and not userCategories[name] then
        userCategories[name] = {
            priority = 80,
            color = CopyColor(USER_CATEGORY_COLOR),
        }
    end

    if userCategories[name] then
        local def = userCategories[name]
        self:RegisterCategory(name, def.priority or 80, nil, CopyColor(def.color))
    end

    GetHiddenCategories()[name] = nil
    EnsureCategoryInSavedOrder(name)
    RebuildCategoryOrder()
    return name
end

function Categorizer:IsUserCategory(name)
    return GetUserCategories()[name] ~= nil
end

function Categorizer:GetUserCategoryNames()
    local names = {}
    for name in pairs(GetUserCategories()) do
        if IsCategoryVisible(name) then
            names[#names + 1] = name
        end
    end
    table.sort(names, CompareCategoryNames)
    return names
end

function Categorizer:RenameUserCategory(oldName, newName)
    oldName = TrimCategoryName(oldName)
    newName = TrimCategoryName(newName)
    if oldName == "" or newName == "" then return false end
    if oldName == newName then return true end

    local userCategories = GetUserCategories()
    local def = userCategories[oldName]
    if not def or categories[newName] or userCategories[newName] then
        return false
    end

    userCategories[oldName] = nil
    userCategories[newName] = def
    categories[oldName] = nil
    local hiddenCategories = GetHiddenCategories()
    if hiddenCategories[oldName] then
        hiddenCategories[oldName] = nil
        hiddenCategories[newName] = true
    end

    if OmniInventoryDB and OmniInventoryDB.categoryOverrides then
        for itemID, categoryName in pairs(OmniInventoryDB.categoryOverrides) do
            if categoryName == oldName then
                OmniInventoryDB.categoryOverrides[itemID] = newName
            end
        end
    end

    if OmniInventoryDB and OmniInventoryDB.global and type(OmniInventoryDB.global.categoryOrder) == "table" then
        for i, categoryName in ipairs(OmniInventoryDB.global.categoryOrder) do
            if categoryName == oldName then
                OmniInventoryDB.global.categoryOrder[i] = newName
            end
        end
    end

    self:RegisterCategory(newName, def.priority or 80, nil, CopyColor(def.color))
    categoryOrderIndex = nil
    RebuildCategoryOrder()
    return true
end

function Categorizer:DeleteUserCategory(name)
    name = TrimCategoryName(name)
    if name == "" or not GetUserCategories()[name] then return false end

    GetUserCategories()[name] = nil
    categories[name] = nil
    GetHiddenCategories()[name] = nil
    RemoveCategoryFromSavedOrder(name)

    if OmniInventoryDB and OmniInventoryDB.categoryOverrides then
        for itemID, categoryName in pairs(OmniInventoryDB.categoryOverrides) do
            if categoryName == name then
                OmniInventoryDB.categoryOverrides[itemID] = nil
            end
        end
    end

    RebuildCategoryOrder()
    return true
end

function Categorizer:GetCategoryColor(name)
    local info = self:GetCategoryInfo(name)
    return info.color.r, info.color.g, info.color.b
end

-- =============================================================================
-- Categorize All Items
-- =============================================================================

function Categorizer:CategorizeItems(items)
    local perfToken = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("categorizer.CategorizeItems")
    local categorized = {}  -- { categoryName = { items } }

    for _, itemInfo in ipairs(items) do
        local category = self:GetCategory(itemInfo)

        if not categorized[category] then
            categorized[category] = {}
        end

        itemInfo.category = category
        table.insert(categorized[category], itemInfo)
    end

    if Omni._perfEnabled and Omni.Perf then
        Omni.Perf:End("categorizer.CategorizeItems", perfToken, { itemCount = items and #items or 0 })
    end
    return categorized
end

-- =============================================================================
-- Initialization
-- =============================================================================

function Categorizer:Init()
    -- Register default categories
    self:RegisterCategory("Perishable", 1, nil, CATEGORY_COLORS["Perishable"])
    self:RegisterCategory("Mythic+", 1.3, nil, CATEGORY_COLORS["Mythic+"])
    self:RegisterCategory("Tier Token", 1.4, nil, CATEGORY_COLORS["Tier Token"])
    self:RegisterCategory("Mystic Enchants", 1.5, nil, CATEGORY_COLORS["Mystic Enchants"])
    self:RegisterCategory("Upgradable Items", 1.8, nil, CATEGORY_COLORS["Upgradable Items"])
    self:RegisterCategory("Quest Items", 2, nil, CATEGORY_COLORS["Quest Items"])
    self:RegisterCategory("Attunable", 3, nil, CATEGORY_COLORS["Attunable"])
    self:RegisterCategory("Equipment Sets", 4, nil, CATEGORY_COLORS["Equipment Sets"])
    self:RegisterCategory("Account Attunable", 4.5, nil, CATEGORY_COLORS["Account Attunable"])
    self:RegisterCategory("BoE", 5, nil, CATEGORY_COLORS["BoE"])
    self:RegisterCategory("Transmog", 5.2, nil, CATEGORY_COLORS["Transmog"])
    self:RegisterCategory("Ascension", 5.4, nil, CATEGORY_COLORS["Ascension"])
    self:RegisterCategory("Vanity", 5.6, nil, CATEGORY_COLORS["Vanity"])
    self:RegisterCategory("New Items", 6, nil, CATEGORY_COLORS["New Items"])
    self:RegisterCategory("Equipment", 10, nil, CATEGORY_COLORS["Equipment"])
    self:RegisterCategory("Consumables", 11, nil, CATEGORY_COLORS["Consumables"])
    self:RegisterCategory("Trade Goods", 12, nil, CATEGORY_COLORS["Trade Goods"])
    self:RegisterCategory("Reagents", 13, nil, CATEGORY_COLORS["Reagents"])
    self:RegisterCategory("Tools", 14, nil, CATEGORY_COLORS["Tools"])
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
    GetUserCategories()
    for name, def in pairs(OmniInventoryDB.global.userCategories) do
        self:RegisterCategory(name, def.priority or 80, nil, CopyColor(def.color))
        EnsureCategoryInSavedOrder(name)
    end
end

print("|cFF00FF00OmniInventory|r: Categorizer loaded")
