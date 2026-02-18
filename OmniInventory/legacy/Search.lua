local addonName, NS = ...

NS.Search = {}
local Search = NS.Search

-----------------------------------------------------------
-- Omni-Search System
-- Purpose: Search items across all characters using inverted index
-----------------------------------------------------------

local searchIndex = {} -- word -> { itemID -> true }

--- Build inverted index from all character data
function Search:BuildIndex()
    wipe(searchIndex)

    if not ZenBagsDB or not ZenBagsDB.alts then return end

    for charKey, charData in pairs(ZenBagsDB.alts) do
        -- Index bag items
        for itemID in pairs(charData.bags or {}) do
            self:IndexItem(itemID)
        end

        -- Index bank items
        for itemID in pairs(charData.bank or {}) do
            self:IndexItem(itemID)
        end
    end
end

--- Add item to search index
function Search:IndexItem(itemID)
    local name = GetItemInfo(itemID)
    if not name then return end

    -- Tokenize name into words
    for word in string.gmatch(string.lower(name), "%w+") do
        if #word >= 2 then -- Skip single-character words
            searchIndex[word] = searchIndex[word] or {}
            searchIndex[word][itemID] = true
        end
    end
end

--- Search for items matching query
function Search:Query(query)
    if not query or query == "" then return {} end

    local results = {}
    query = string.lower(query)

    -- Find all matching item IDs
    local matchingItems = {}

    for word, items in pairs(searchIndex) do
        if string.find(word, query, 1, true) then
            for itemID in pairs(items) do
                matchingItems[itemID] = true
            end
        end
    end

    -- Build results with character breakdown
    for itemID in pairs(matchingItems) do
        local total, breakdown = NS.Alts:GetTotalItemCount(itemID)
        if total > 0 then
            local name, link = GetItemInfo(itemID)
            table.insert(results, {
                itemID = itemID,
                name = name or ("Item " .. itemID),
                link = link,
                total = total,
                breakdown = breakdown
            })
        end
    end

    -- Sort by name
    table.sort(results, function(a, b) return a.name < b.name end)

    return results
end

--- Get total item count across all characters for an item
function Search:GetTotalItemCount(itemID)
    if NS.Alts then
        return NS.Alts:GetTotalItemCount(itemID)
    end
    return 0, {}
end

--- Initialize
function Search:Init()
    -- Build index on login (delayed to allow item cache)
    local timerFrame = CreateFrame("Frame")
    timerFrame.elapsed = 0
    timerFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 2 then
            Search:BuildIndex()
            self:SetScript("OnUpdate", nil)
        end
    end)
end

--- Debug command
SLASH_ZENSEARCH1 = "/zensearch"
SlashCmdList["ZENSEARCH"] = function(msg)
    if msg == "" then
        print("|cFF00FF00ZenBags Search:|r Usage: /zensearch <item name>")
        return
    end

    local results = NS.Search:Query(msg)
    if #results == 0 then
        print("|cFFFF0000ZenBags:|r No items found matching '" .. msg .. "'")
        return
    end

    print("|cFF00FF00ZenBags Search:|r Found " .. #results .. " items")
    for i, result in ipairs(results) do
        if i <= 10 then -- Limit to 10 results
            local charList = {}
            for _, char in ipairs(result.breakdown) do
                table.insert(charList, char.name .. ":" .. char.count)
            end
            print(string.format("  %s x%d (%s)",
                result.link or result.name,
                result.total,
                table.concat(charList, ", ")))
        end
    end
    if #results > 10 then
        print("  ..." .. (#results - 10) .. " more results")
    end
end
