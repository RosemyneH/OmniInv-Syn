-- =============================================================================
-- OmniInventory Stable Merge Sort
-- =============================================================================
-- Purpose: Deterministic, stable sorting algorithm that eliminates
-- "dancing items" problem. Same inputs always produce same outputs.
-- =============================================================================

local addonName, Omni = ...

Omni.Sorter = {}
local Sorter = Omni.Sorter

-- =============================================================================
-- Merge Sort Implementation (Stable)
-- =============================================================================

-- Merge two sorted sub-arrays into one
local function Merge(arr, left, mid, right, comparator)
    local n1 = mid - left + 1
    local n2 = right - mid

    -- Create temp arrays
    local L = {}
    local R = {}

    for i = 1, n1 do
        L[i] = arr[left + i - 1]
    end
    for j = 1, n2 do
        R[j] = arr[mid + j]
    end

    -- Merge temp arrays back into arr
    local i = 1
    local j = 1
    local k = left

    while i <= n1 and j <= n2 do
        -- Use <= for stability (left element wins on tie)
        if comparator(L[i], R[j]) or not comparator(R[j], L[i]) then
            arr[k] = L[i]
            i = i + 1
        else
            arr[k] = R[j]
            j = j + 1
        end
        k = k + 1
    end

    -- Copy remaining elements
    while i <= n1 do
        arr[k] = L[i]
        i = i + 1
        k = k + 1
    end

    while j <= n2 do
        arr[k] = R[j]
        j = j + 1
        k = k + 1
    end
end

-- Recursive merge sort
local function MergeSort(arr, left, right, comparator)
    if left < right then
        local mid = math.floor((left + right) / 2)

        MergeSort(arr, left, mid, comparator)
        MergeSort(arr, mid + 1, right, comparator)
        Merge(arr, left, mid, right, comparator)
    end
end

-- =============================================================================
-- Comparator Functions
-- =============================================================================

-- Get category priority for sorting
local function GetCategoryPriority(item)
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
    if not item or not item.hyperlink then
        return "zzz"  -- Sort unknown items last
    end

    local name = GetItemInfo(item.hyperlink)
    return name or "zzz"
end

-- Get item level
local function GetItemLevel(item)
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
    local pinnedA = a.itemID and Omni.Data and Omni.Data:IsPinned(a.itemID)
    local pinnedB = b.itemID and Omni.Data and Omni.Data:IsPinned(b.itemID)
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

--- Sort items using stable merge-sort
---@param items table Array of item info tables
---@param mode string Optional sort mode: "category", "quality", "name", "ilvl"
---@return table Sorted array (new table)
function Sorter:Sort(items, mode)
    if not items or #items == 0 then
        return {}
    end

    -- Copy array (don't modify original)
    local sorted = {}
    for i, item in ipairs(items) do
        sorted[i] = item
    end

    -- Get comparator
    local comparator = COMPARATORS[mode] or DefaultComparator

    -- Apply stable merge sort
    MergeSort(sorted, 1, #sorted, comparator)

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

print("|cFF00FF00OmniInventory|r: Sorter loaded (stable merge-sort)")
