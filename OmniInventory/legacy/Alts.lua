local addonName, NS = ...

NS.Alts = {}
local Alts = NS.Alts

-----------------------------------------------------------
-- Cross-Character Data System
-- Purpose: Track inventory across all characters on realm
-----------------------------------------------------------

--- Get current character key (Name-Realm)
function Alts:GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return name .. "-" .. realm
end

--- Initialize the alts database
function Alts:Init()
    if not ZenBagsDB then ZenBagsDB = {} end
    if not ZenBagsDB.alts then ZenBagsDB.alts = {} end

    -- Scan current character on login
    self:ScanCurrentCharacter()
end

--- Scan and store current character's inventory
function Alts:ScanCurrentCharacter()
    local key = self:GetCharacterKey()
    local data = {
        name = UnitName("player"),
        realm = GetRealmName(),
        class = select(2, UnitClass("player")),
        level = UnitLevel("player"),
        gold = GetMoney(),
        lastSeen = time(),
        bags = {},
        bank = {},
    }

    -- Scan bags (0-4)
    for bagID = 0, 4 do
        local numSlots = GetContainerNumSlots(bagID)
        if numSlots then
            for slotID = 1, numSlots do
                local itemID = GetContainerItemID(bagID, slotID)
                if itemID then
                    local _, count = GetContainerItemInfo(bagID, slotID)
                    data.bags[itemID] = (data.bags[itemID] or 0) + (count or 1)
                end
            end
        end
    end

    -- Scan bank if open (-1, 5-11)
    if NS.Data and NS.Data:IsBankOpen() then
        for _, bagID in ipairs({-1, 5, 6, 7, 8, 9, 10, 11}) do
            local numSlots = GetContainerNumSlots(bagID)
            if numSlots then
                for slotID = 1, numSlots do
                    local itemID = GetContainerItemID(bagID, slotID)
                    if itemID then
                        local _, count = GetContainerItemInfo(bagID, slotID)
                        data.bank[itemID] = (data.bank[itemID] or 0) + (count or 1)
                    end
                end
            end
        end
    end

    ZenBagsDB.alts[key] = data
end

--- Get all characters with cached data
function Alts:GetAllCharacters()
    local chars = {}
    local currentKey = self:GetCharacterKey()

    for key, data in pairs(ZenBagsDB.alts or {}) do
        table.insert(chars, {
            key = key,
            name = data.name,
            realm = data.realm,
            class = data.class,
            level = data.level,
            gold = data.gold,
            lastSeen = data.lastSeen,
            isCurrent = (key == currentKey)
        })
    end

    -- Sort: current first, then by name
    table.sort(chars, function(a, b)
        if a.isCurrent then return true end
        if b.isCurrent then return false end
        return a.name < b.name
    end)

    return chars
end

--- Get character data by key
function Alts:GetCharacter(key)
    return ZenBagsDB.alts and ZenBagsDB.alts[key]
end

--- Get item count for a specific item across all characters
function Alts:GetTotalItemCount(itemID)
    local total = 0
    local breakdown = {}

    for key, data in pairs(ZenBagsDB.alts or {}) do
        local charCount = 0

        if data.bags and data.bags[itemID] then
            charCount = charCount + data.bags[itemID]
        end
        if data.bank and data.bank[itemID] then
            charCount = charCount + data.bank[itemID]
        end

        if charCount > 0 then
            total = total + charCount
            table.insert(breakdown, {
                name = data.name,
                count = charCount
            })
        end
    end

    return total, breakdown
end

--- Get total gold across all characters
function Alts:GetTotalGold()
    local total = 0
    for _, data in pairs(ZenBagsDB.alts or {}) do
        total = total + (data.gold or 0)
    end
    return total
end

--- Delete character data
function Alts:DeleteCharacter(key)
    if ZenBagsDB.alts then
        ZenBagsDB.alts[key] = nil
    end
end

--- Debug command
SLASH_ZENALTS1 = "/zenalts"
SlashCmdList["ZENALTS"] = function(msg)
    print("|cFF00FF00ZenBags Alts:|r")
    local chars = NS.Alts:GetAllCharacters()
    for _, char in ipairs(chars) do
        local gold = math.floor((char.gold or 0) / 10000)
        local status = char.isCurrent and "|cFF00FF00(current)|r" or ""
        print(string.format("  %s Lv%d %s - %dg %s",
            char.name, char.level or 0, char.class or "", gold, status))
    end
    print(string.format("  |cFFFFD700Total Gold:|r %dg",
        math.floor(NS.Alts:GetTotalGold() / 10000)))
end
