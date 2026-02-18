local addonName, NS = ...

NS.Filter = {}
local Filter = NS.Filter

--- Filter items based on search text
function Filter:BySearch(items, searchText)
    if not searchText or searchText == "" then
        return items
    end

    local filtered = {}
    searchText = string.lower(searchText)

    for _, item in ipairs(items) do
        if item.link then
            local name = GetItemInfo(item.link)
            if name and string.find(string.lower(name), searchText, 1, true) then
                table.insert(filtered, item)
            end
        end
    end

    return filtered
end

--- Filter items by quality
function Filter:ByQuality(items, minQuality)
    if not minQuality then return items end

    local filtered = {}
    for _, item in ipairs(items) do
        if item.quality and item.quality >= minQuality then
            table.insert(filtered, item)
        end
    end

    return filtered
end

--- Filter items by category
function Filter:ByCategory(items, category)
    if not category then return items end

    local filtered = {}
    for _, item in ipairs(items) do
        if item.category == category then
            table.insert(filtered, item)
        end
    end

    return filtered
end

--- Apply all active filters
function Filter:Apply(items, options)
    options = options or {}
    local result = items

    if options.search then
        result = self:BySearch(result, options.search)
    end

    if options.minQuality then
        result = self:ByQuality(result, options.minQuality)
    end

    if options.category then
        result = self:ByCategory(result, options.category)
    end

    return result
end

function Filter:Init()
    -- Nothing to init
end
