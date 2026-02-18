-- =============================================================================
-- OmniInventory List View
-- =============================================================================
-- Purpose: Data-dense table view with columns for name, type, qty, etc.
-- Uses virtual scrolling for large inventories.
-- =============================================================================

local addonName, Omni = ...

Omni.ListView = {}
local ListView = Omni.ListView

-- =============================================================================
-- Constants
-- =============================================================================

local ROW_HEIGHT = 20
local COLUMNS = {
    { name = "Icon", width = 24 },
    { name = "Name", width = 150 },
    { name = "Type", width = 80 },
    { name = "Qty", width = 30 },
    { name = "iLvl", width = 30 },
}

-- =============================================================================
-- Layout
-- =============================================================================

function ListView:GetRowCount(itemCount)
    return itemCount
end

function ListView:GetTotalHeight(itemCount)
    return itemCount * ROW_HEIGHT
end

function ListView:GetColumns()
    return COLUMNS
end

print("|cFF00FF00OmniInventory|r: ListView loaded")
