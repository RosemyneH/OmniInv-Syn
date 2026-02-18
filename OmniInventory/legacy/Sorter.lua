local addonName, NS = ...

NS.Sorter = {}
local Sorter = NS.Sorter

--- Sort by item name
function Sorter:ByName(items)
    table.sort(items, function(a, b)
        local nameA = a.link and GetItemInfo(a.link) or ""
        local nameB = b.link and GetItemInfo(b.link) or ""
        return nameA < nameB
    end)
    return items
end

--- Sort by quality (highest first)
function Sorter:ByQuality(items)
    table.sort(items, function(a, b)
        return (a.quality or 0) > (b.quality or 0)
    end)
    return items
end

--- Sort by item level (highest first)
function Sorter:ByItemLevel(items)
    table.sort(items, function(a, b)
        local ilvlA = a.iLevel or 0
        local ilvlB = b.iLevel or 0
        return ilvlA > ilvlB
    end)
    return items
end

--- Sort by category then name
function Sorter:ByCategoryThenName(items)
    table.sort(items, function(a, b)
        if a.category ~= b.category then
            return (a.category or "ZZZ") < (b.category or "ZZZ")
        end
        local nameA = a.link and GetItemInfo(a.link) or ""
        local nameB = b.link and GetItemInfo(b.link) or ""
        return nameA < nameB
    end)
    return items
end

-- ==========================================================
-- SMART SORTING (UX: Most used items at top)
-- ==========================================================
function Sorter:ByUsage(items)
    table.sort(items, function(a, b)
        local usageA = 0
        local usageB = 0

        if a.link and NS.Config then
            local idA = tonumber(string.match(a.link, "item:(%d+)"))
            usageA = NS.Config:GetItemUsage(idA) or 0
        end
        if b.link and NS.Config then
            local idB = tonumber(string.match(b.link, "item:(%d+)"))
            usageB = NS.Config:GetItemUsage(idB) or 0
        end

        -- Higher usage comes first
        if usageA ~= usageB then
            return usageA > usageB
        end

        -- Tie-breaker: quality (higher first)
        if (a.quality or 0) ~= (b.quality or 0) then
            return (a.quality or 0) > (b.quality or 0)
        end

        -- Tie-breaker: name
        local nameA = a.link and GetItemInfo(a.link) or ""
        local nameB = b.link and GetItemInfo(b.link) or ""
        return nameA < nameB
    end)
    return items
end

--- Apply sort by mode
function Sorter:Apply(items, mode)
    mode = mode or "usage"  -- Default to usage-based sorting

    if mode == "usage" then
        return self:ByUsage(items)
    elseif mode == "name" then
        return self:ByName(items)
    elseif mode == "quality" then
        return self:ByQuality(items)
    elseif mode == "ilvl" then
        return self:ByItemLevel(items)
    elseif mode == "category" then
        return self:ByCategoryThenName(items)
    end

    return items
end

function Sorter:Init()
    -- Nothing to init
end
