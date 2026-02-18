local addonName, NS = ...

NS.ItemCache = {}
local ItemCache = NS.ItemCache

-- Cache storage
local cache = {}
local queryQueue = {}
local QUERY_THROTTLE = 5 -- queries per second
local lastQueryTime = 0

--- Get cached item data or queue for fetch
function ItemCache:Get(itemID)
    if cache[itemID] then
        return cache[itemID]
    end
    return nil
end

--- Queue item for async fetch
function ItemCache:Queue(itemID)
    if not itemID or cache[itemID] then return end
    queryQueue[itemID] = true
end

--- Process query queue (called from OnUpdate)
function ItemCache:ProcessQueue()
    local now = GetTime()
    if now - lastQueryTime < (1 / QUERY_THROTTLE) then return end

    for itemID in pairs(queryQueue) do
        local name, link, quality, iLevel, _, itemType, subType, _, equipLoc, texture, sellPrice = GetItemInfo(itemID)
        if name then
            cache[itemID] = {
                name = name,
                link = link,
                quality = quality,
                iLevel = iLevel,
                itemType = itemType,
                subType = subType,
                equipLoc = equipLoc,
                texture = texture,
                sellPrice = sellPrice
            }
            queryQueue[itemID] = nil
            lastQueryTime = now
            return -- Process one per frame
        end
    end
end

--- Store item data directly
function ItemCache:Store(itemID, data)
    cache[itemID] = data
end

--- Clear cache
function ItemCache:Clear()
    cache = {}
    queryQueue = {}
end

--- Initialize
function ItemCache:Init()
    -- Create frame for OnUpdate
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnUpdate", function()
            ItemCache:ProcessQueue()
        end)
    end
end
