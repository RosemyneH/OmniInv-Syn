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
    ["Upgradable Items"] = { r = 1.0, g = 0.7, b = 0.2 },
    ["Attunable"]       = { r = 0.0, g = 0.9, b = 0.5 },
    ["Account Attunable"] = { r = 0.85, g = 0.45, b = 1.0 },
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
    if itemInfo.bindType ~= "BoE" then
        return false
    end
    return IsEquipmentItem(itemInfo)
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

    -- ʕ ● ᴥ ●ʔ Custom Rules Engine disabled — module is no longer loaded (see OmniInventory.toc)

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

    -- Priority 4.5: Account Attunable (BoE that an alt can attune)
    if IsAccountAttunableItem(itemInfo) then
            return "Account Attunable"
        end

    -- Prio 5 : Tools
    if IsToolsItem(itemInfo) then
        return "Tools"
    end

    -- Priority 6: BoE equipment
    if IsBoEItem(itemInfo) then
        return "BoE"
    end

    -- Priority 7: Explicit upgradable-item allowlist  6 7 6 7 6 7 6  7 6 7 6 7 6 7 6 7 6 7 6 7 6 7 6 7 6 7 6 7 6 7
    if IsUpgradableItem(itemInfo) then
        return "Upgradable Items"
    end

    -- Priority 88: Check quality for junk
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
    self:RegisterCategory("Upgradable Items", 1.8, nil, CATEGORY_COLORS["Upgradable Items"])
    self:RegisterCategory("Quest Items", 2, nil, CATEGORY_COLORS["Quest Items"])
    self:RegisterCategory("Attunable", 3, nil, CATEGORY_COLORS["Attunable"])
    self:RegisterCategory("Equipment Sets", 4, nil, CATEGORY_COLORS["Equipment Sets"])
    self:RegisterCategory("Account Attunable", 4.5, nil, CATEGORY_COLORS["Account Attunable"])
    self:RegisterCategory("BoE", 5, nil, CATEGORY_COLORS["BoE"])
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
end

print("|cFF00FF00OmniInventory|r: Categorizer loaded")
