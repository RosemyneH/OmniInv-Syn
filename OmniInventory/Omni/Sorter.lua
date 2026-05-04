-- =============================================================================
-- OmniInventory Stable Item Sort
-- =============================================================================
-- Purpose: Deterministic, stable ordering (no "dancing items"). Uses
-- table.sort with index tie-break; comparators unchanged from merge era.
-- =============================================================================

local addonName, Omni = ...

Omni.Sorter = {}
local Sorter = Omni.Sorter

-- Decorate-sort-undecorate scratch (stable tie-break on original index)
local stableSortRows = {}

-- =============================================================================
-- Comparator Functions
-- =============================================================================

-- Get category priority for sorting
local function GetCategoryPriority(item)
    if item and item._oiSortCache and item._oiSortCache.catPriority then
        return item._oiSortCache.catPriority
    end
    if not item or not item.category then
        return 99
    end

    if Omni.Categorizer then
        local catInfo = Omni.Categorizer:GetCategoryInfo(item.category)
        return catInfo and catInfo.priority or 99
    end

    return 99
end

-- Get item name (cached from GetItemInfo)
local function GetItemName(item)
    if item and item._oiSortCache and item._oiSortCache.name then
        return item._oiSortCache.name
    end
    if not item or not item.hyperlink then
        return "zzz"  -- Sort unknown items last
    end

    local name = GetItemInfo(item.hyperlink)
    return name or "zzz"
end

-- Get item level
local function GetItemLevel(item)
    if item and item._oiSortCache and item._oiSortCache.ilvl then
        return item._oiSortCache.ilvl
    end
    if not item or not item.hyperlink then
        return 0
    end

    local _, _, _, iLvl = GetItemInfo(item.hyperlink)
    return iLvl or 0
end

-- =============================================================================
-- Comparator Chain (Multi-tier)
-- =============================================================================

-- Returns true if a should come before b
local function DefaultComparator(a, b)
    if not a and not b then return false end
    if not a then return false end
    if not b then return true end

    -- 0. Pinned/Favorite items first
    local pinnedA = (a._oiSortCache and a._oiSortCache.pinned)
        or (a.itemID and Omni.Data and Omni.Data:IsPinned(a.itemID))
    local pinnedB = (b._oiSortCache and b._oiSortCache.pinned)
        or (b.itemID and Omni.Data and Omni.Data:IsPinned(b.itemID))
    if pinnedA and not pinnedB then return true end
    if pinnedB and not pinnedA then return false end

    -- 1. Category Priority (lower number = higher priority)
    local catA = GetCategoryPriority(a)
    local catB = GetCategoryPriority(b)
    if catA ~= catB then
        return catA < catB
    end

    -- 2. Quality (Higher first: Purple > Blue > Green)
    local qualA = a.quality or 0
    local qualB = b.quality or 0
    if qualA ~= qualB then
        return qualA > qualB
    end

    -- 3. Item Level (Higher first)
    local ilvlA = GetItemLevel(a)
    local ilvlB = GetItemLevel(b)
    if ilvlA ~= ilvlB then
        return ilvlA > ilvlB
    end

    -- 4. Name (Alphabetical)
    local nameA = GetItemName(a)
    local nameB = GetItemName(b)
    if nameA ~= nameB then
        return nameA < nameB
    end

    -- 5. Stack Count (Higher first)
    local stackA = a.stackCount or 1
    local stackB = b.stackCount or 1
    if stackA ~= stackB then
        return stackA > stackB
    end

    -- 6. Fallback: Bag/Slot order (for absolute stability)
    local posA = ((a.bagID or 0) * 100) + (a.slotID or 0)
    local posB = ((b.bagID or 0) * 100) + (b.slotID or 0)
    return posA < posB
end

local function BuildSortCaches(items)
    if not items then
        return
    end
    for _, item in ipairs(items) do
        if item then
            local cache = {}
            cache.catPriority = GetCategoryPriority(item)
            cache.name = GetItemName(item)
            cache.ilvl = GetItemLevel(item)
            cache.pinned = item.itemID and Omni.Data and Omni.Data:IsPinned(item.itemID) or false
            item._oiSortCache = cache
        end
    end
end

local function ClearSortCaches(items)
    if not items then
        return
    end
    for _, item in ipairs(items) do
        if item then
            item._oiSortCache = nil
        end
    end
end

-- Quality-only comparator
local function QualityComparator(a, b)
    if not a and not b then return false end
    if not a then return false end
    if not b then return true end

    local qualA = a.quality or 0
    local qualB = b.quality or 0
    if qualA ~= qualB then
        return qualA > qualB
    end

    return DefaultComparator(a, b)
end

-- Name-only comparator
local function NameComparator(a, b)
    if not a and not b then return false end
    if not a then return false end
    if not b then return true end

    local nameA = GetItemName(a)
    local nameB = GetItemName(b)
    if nameA ~= nameB then
        return nameA < nameB
    end

    return DefaultComparator(a, b)
end

-- iLvl-only comparator
local function ILvlComparator(a, b)
    if not a and not b then return false end
    if not a then return false end
    if not b then return true end

    local ilvlA = GetItemLevel(a)
    local ilvlB = GetItemLevel(b)
    if ilvlA ~= ilvlB then
        return ilvlA > ilvlB
    end

    return DefaultComparator(a, b)
end

-- =============================================================================
-- Public API
-- =============================================================================

local COMPARATORS = {
    category = DefaultComparator,
    quality = QualityComparator,
    name = NameComparator,
    ilvl = ILvlComparator,
}

--- Sort items (stable ordering via decorated table.sort)
---@param items table Array of item info tables
---@param mode string Optional sort mode: "category", "quality", "name", "ilvl"
---@return table Sorted array (new table)
function Sorter:Sort(items, mode)
    local perfToken = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("sorter.Sort.total")
    if not items or #items == 0 then
        if Omni._perfEnabled and Omni.Perf then
            Omni.Perf:End("sorter.Sort.total", perfToken)
        end
        return {}
    end

    -- Copy array (don't modify original)
    local sorted = {}
    for i, item in ipairs(items) do
        sorted[i] = item
    end

    -- Get comparator
    local comparator = COMPARATORS[mode] or DefaultComparator

    local perfCache = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("sorter.Sort.cache")
    BuildSortCaches(sorted)
    if Omni._perfEnabled and Omni.Perf then
        Omni.Perf:End("sorter.Sort.cache", perfCache, { itemCount = #sorted })
    end

    local perfMerge = Omni._perfEnabled and Omni.Perf and Omni.Perf:Begin("sorter.Sort.merge")
    local n = #sorted
    for i = 1, n do
        local row = stableSortRows[i]
        if not row then
            row = {}
            stableSortRows[i] = row
        end
        row.idx = i
        row.item = sorted[i]
    end
    for j = n + 1, #stableSortRows do
        stableSortRows[j] = nil
    end

    table.sort(stableSortRows, function(a, b)
        local ia, ib = a.item, b.item
        if comparator(ia, ib) then return true end
        if comparator(ib, ia) then return false end
        return a.idx < b.idx
    end)

    for i = 1, n do
        sorted[i] = stableSortRows[i].item
    end
    if Omni._perfEnabled and Omni.Perf then
        Omni.Perf:End("sorter.Sort.merge", perfMerge, { itemCount = #sorted })
    end
    ClearSortCaches(sorted)

    if Omni._perfEnabled and Omni.Perf then
        Omni.Perf:End("sorter.Sort.total", perfToken, { itemCount = #sorted, mode = mode or "category" })
    end
    return sorted
end

--- Sort items within their categories
---@param categorizedItems table { categoryName = { items } }
---@return table Same structure with sorted items
function Sorter:SortCategorized(categorizedItems)
    local result = {}

    for category, items in pairs(categorizedItems) do
        result[category] = self:Sort(items, "category")
    end

    return result
end

--- Get available sort modes
---@return table Array of mode names
function Sorter:GetModes()
    return { "category", "quality", "name", "ilvl" }
end

--- Get current default sort mode
---@return string
function Sorter:GetDefaultMode()
    if OmniInventoryDB and OmniInventoryDB.global then
        return OmniInventoryDB.global.sortMode or "category"
    end
    return "category"
end

--- Set default sort mode
---@param mode string
function Sorter:SetDefaultMode(mode)
    if COMPARATORS[mode] then
        OmniInventoryDB = OmniInventoryDB or {}
        OmniInventoryDB.global = OmniInventoryDB.global or {}
        OmniInventoryDB.global.sortMode = mode
    end
end

-- =============================================================================
-- Initialization
-- =============================================================================

function Sorter:Init()
    -- Nothing to initialize, but maintain interface consistency
end

print("|cFF00FF00OmniInventory|r: Sorter loaded (stable table.sort)")
