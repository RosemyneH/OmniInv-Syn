local addonName, NS = ...

NS.Config = {}

local defaults = {
    scale = 1.0,
    opacity = 1.0,
    sortOnUpdate = true,
    columnCount = 5,
    itemSize = 37,
    padding = 5,
    showTooltips = true,
    enableSearch = true,
    collapsedSections = {},  -- Track which category sections are collapsed
    layoutMode = "category", -- "category" or "grid"
    -- New Item Glow Settings
    newItemGlowEnabled = true,
    newItemGlowColor = { r = 1, g = 1, b = 0 }, -- Yellow
    newItemGlowScale = 1.8,
    newItemGlowIgnoreJunk = true, -- Ignore grey quality items
    -- Tooltip Enhancements
    showTotalItemCount = true, -- Show total count across all bags in tooltip
    -- Smart Sorting (UX: Most used items at top)
    itemUsage = {},  -- { [itemID] = usageCount }
}

function NS.Config:Init()
    ZenBagsDB = ZenBagsDB or {}

    -- Merge defaults
    for k, v in pairs(defaults) do
        if ZenBagsDB[k] == nil then
            ZenBagsDB[k] = v
        end
    end
end

function NS.Config:Get(key)
    return ZenBagsDB[key] or defaults[key]
end

function NS.Config:Set(key, value)
    ZenBagsDB[key] = value
end

function NS.Config:IsSectionCollapsed(categoryName)
    if not ZenBagsDB.collapsedSections then
        ZenBagsDB.collapsedSections = {}
    end
    return ZenBagsDB.collapsedSections[categoryName] == true
end

function NS.Config:ToggleSectionCollapsed(categoryName)
    if not ZenBagsDB.collapsedSections then
        ZenBagsDB.collapsedSections = {}
    end

    if ZenBagsDB.collapsedSections[categoryName] then
        ZenBagsDB.collapsedSections[categoryName] = nil
    else
        ZenBagsDB.collapsedSections[categoryName] = true
    end
end

function NS.Config:GetDefaults()
    return defaults
end

function NS.Config:Reset()
    for k, v in pairs(defaults) do
        ZenBagsDB[k] = v
    end
    -- Preserve collapsed sections if desired, or reset them too
    -- ZenBagsDB.collapsedSections = {}
end

-- ==========================================================
-- SMART SORTING (UX: Most used items at top)
-- ==========================================================

function NS.Config:TrackItemUsage(itemID)
    if not itemID then return end

    ZenBagsDB.itemUsage = ZenBagsDB.itemUsage or {}
    ZenBagsDB.itemUsage[itemID] = (ZenBagsDB.itemUsage[itemID] or 0) + 1
end

function NS.Config:GetItemUsage(itemID)
    if not itemID or not ZenBagsDB.itemUsage then return 0 end
    return ZenBagsDB.itemUsage[itemID] or 0
end

function NS.Config:GetItemUsageSortValue(itemID)
    -- Higher usage = lower sort value (appears first)
    return -self:GetItemUsage(itemID)
end
