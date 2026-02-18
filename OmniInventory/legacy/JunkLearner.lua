local addonName, NS = ...

NS.JunkLearner = {}
local JunkLearner = NS.JunkLearner

-----------------------------------------------------------
-- Smart Junk Learning System
-- Purpose: Learn what users sell and auto-mark as junk
-----------------------------------------------------------

-- Thresholds
local SELL_COUNT_THRESHOLD = 3 -- Sell 3x to learn
local MAX_QUALITY_FOR_JUNK = 2 -- Don't auto-junk green+ items

--- Initialize the junk learning system
function JunkLearner:Init()
    if not ZenBagsDB then ZenBagsDB = {} end
    if not ZenBagsDB.junkLearning then
        ZenBagsDB.junkLearning = {
            enabled = true,
            mode = "prompt", -- "auto", "prompt", "manual"
            sellCounts = {}, -- itemID -> count
            learnedJunk = {}, -- itemID -> true
            neverJunk = {}, -- itemID -> true (whitelist)
            safeItems = {}, -- itemID -> true (expensive items user kept)
        }
    end

    self.data = ZenBagsDB.junkLearning

    -- Hook merchant events
    self:HookMerchant()
end

--- Hook into merchant selling
function JunkLearner:HookMerchant()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("MERCHANT_SHOW")
    frame:RegisterEvent("MERCHANT_CLOSED")
    frame:RegisterEvent("BAG_UPDATE")

    local merchantOpen = false
    local previousItems = {}

    frame:SetScript("OnEvent", function(self, event)
        if event == "MERCHANT_SHOW" then
            merchantOpen = true
            -- Snapshot current inventory
            wipe(previousItems)
            for bagID = 0, 4 do
                local numSlots = GetContainerNumSlots(bagID)
                if numSlots then
                    for slotID = 1, numSlots do
                        local itemID = GetContainerItemID(bagID, slotID)
                        if itemID then
                            local _, count = GetContainerItemInfo(bagID, slotID)
                            previousItems[itemID] = (previousItems[itemID] or 0) + (count or 1)
                        end
                    end
                end
            end

        elseif event == "BAG_UPDATE" and merchantOpen then
            -- Check what was sold
            local currentItems = {}
            for bagID = 0, 4 do
                local numSlots = GetContainerNumSlots(bagID)
                if numSlots then
                    for slotID = 1, numSlots do
                        local itemID = GetContainerItemID(bagID, slotID)
                        if itemID then
                            local _, count = GetContainerItemInfo(bagID, slotID)
                            currentItems[itemID] = (currentItems[itemID] or 0) + (count or 1)
                        end
                    end
                end
            end

            -- Find sold items
            for itemID, oldCount in pairs(previousItems) do
                local newCount = currentItems[itemID] or 0
                if newCount < oldCount then
                    -- Item was sold
                    JunkLearner:RecordSale(itemID, oldCount - newCount)
                end
            end

            previousItems = currentItems

        elseif event == "MERCHANT_CLOSED" then
            merchantOpen = false
            wipe(previousItems)
        end
    end)
end

--- Record a sale for learning
function JunkLearner:RecordSale(itemID, count)
    if not self.data.enabled then return end

    -- Check quality
    local _, _, quality = GetItemInfo(itemID)
    if quality and quality > MAX_QUALITY_FOR_JUNK then return end

    -- Check if whitelisted
    if self.data.neverJunk[itemID] then return end

    -- Increment sell count
    self.data.sellCounts[itemID] = (self.data.sellCounts[itemID] or 0) + 1

    -- Check if threshold reached
    if self.data.sellCounts[itemID] >= SELL_COUNT_THRESHOLD then
        if self.data.mode == "auto" then
            self:LearnAsJunk(itemID)
        elseif self.data.mode == "prompt" then
            self:PromptLearn(itemID)
        end
    end
end

--- Learn item as junk
function JunkLearner:LearnAsJunk(itemID)
    self.data.learnedJunk[itemID] = true
    local name = GetItemInfo(itemID)
    print(string.format("|cFF00FF00ZenBags:|r Learned '%s' as junk.", name or itemID))
end

--- Prompt user to learn item as junk
function JunkLearner:PromptLearn(itemID)
    local name, link = GetItemInfo(itemID)
    if not name then return end

    -- Already prompted?
    if self.data.learnedJunk[itemID] or self.data.neverJunk[itemID] then return end

    print(string.format("|cFFFFD700ZenBags:|r You've sold %s %d times. Mark as junk? /zenjunk yes %d or /zenjunk no %d",
        link, SELL_COUNT_THRESHOLD, itemID, itemID))
end

--- Check if item is learned junk
function JunkLearner:IsJunk(itemID)
    if not self.data then return false end
    return self.data.learnedJunk[itemID] == true
end

--- Whitelist an item (never mark as junk)
function JunkLearner:NeverJunk(itemID)
    self.data.neverJunk[itemID] = true
    self.data.learnedJunk[itemID] = nil
    local name = GetItemInfo(itemID)
    print(string.format("|cFF00FF00ZenBags:|r '%s' will never be marked as junk.", name or itemID))
end

--- Forget an item's junk status
function JunkLearner:ForgetItem(itemID)
    self.data.learnedJunk[itemID] = nil
    self.data.neverJunk[itemID] = nil
    self.data.sellCounts[itemID] = nil
    local name = GetItemInfo(itemID)
    print(string.format("|cFF00FF00ZenBags:|r Forgot junk status for '%s'.", name or itemID))
end

--- Get all learned junk items
function JunkLearner:GetLearnedJunk()
    local items = {}
    for itemID in pairs(self.data.learnedJunk or {}) do
        local name, link = GetItemInfo(itemID)
        table.insert(items, {
            itemID = itemID,
            name = name or ("Item " .. itemID),
            link = link
        })
    end
    table.sort(items, function(a, b) return a.name < b.name end)
    return items
end

--- Debug/control command
SLASH_ZENJUNK1 = "/zenjunk"
SlashCmdList["ZENJUNK"] = function(msg)
    local cmd, arg = string.match(msg, "^(%S+)%s*(.*)$")
    cmd = cmd and string.lower(cmd) or ""

    if cmd == "" or cmd == "help" then
        print("|cFF00FF00ZenBags Junk Learner:|r")
        print("  /zenjunk list - Show learned junk items")
        print("  /zenjunk mode [auto|prompt|manual] - Set learning mode")
        print("  /zenjunk yes <itemID> - Mark item as junk")
        print("  /zenjunk no <itemID> - Never mark as junk")
        print("  /zenjunk forget <itemID> - Reset item status")
        print("  /zenjunk clear - Clear all learned junk")

    elseif cmd == "list" then
        local junkItems = NS.JunkLearner:GetLearnedJunk()
        print(string.format("|cFF00FF00ZenBags:|r %d learned junk items:", #junkItems))
        for i, item in ipairs(junkItems) do
            print(string.format("  %d. %s", i, item.link or item.name))
        end

    elseif cmd == "mode" then
        if arg == "auto" or arg == "prompt" or arg == "manual" then
            NS.JunkLearner.data.mode = arg
            print(string.format("|cFF00FF00ZenBags:|r Junk learning mode set to '%s'", arg))
        else
            print(string.format("|cFF00FF00ZenBags:|r Current mode: %s", NS.JunkLearner.data.mode))
        end

    elseif cmd == "yes" then
        local itemID = tonumber(arg)
        if itemID then NS.JunkLearner:LearnAsJunk(itemID) end

    elseif cmd == "no" then
        local itemID = tonumber(arg)
        if itemID then NS.JunkLearner:NeverJunk(itemID) end

    elseif cmd == "forget" then
        local itemID = tonumber(arg)
        if itemID then NS.JunkLearner:ForgetItem(itemID) end

    elseif cmd == "clear" then
        wipe(NS.JunkLearner.data.learnedJunk)
        wipe(NS.JunkLearner.data.sellCounts)
        print("|cFF00FF00ZenBags:|r Cleared all learned junk items.")
    end
end
