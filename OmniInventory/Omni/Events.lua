-- =============================================================================
-- OmniInventory Event Bucketing System
-- =============================================================================
-- Purpose: Coalesce rapid BAG_UPDATE events into single UI refresh
-- Prevents frame drops when looting multiple items at once
-- =============================================================================

local addonName, Omni = ...

Omni.Events = {}
local Events = Omni.Events

-- =============================================================================
-- Configuration
-- =============================================================================

local BUCKET_DELAY = 0.05  -- 50ms window for coalescing events

-- =============================================================================
-- State
-- =============================================================================

local buckets = {}  -- { eventName = { timer, callback, payload } }
local eventFrame = CreateFrame("Frame")

-- =============================================================================
-- Bucket Manager
-- =============================================================================

--- Register an event with bucketing
---@param eventName string The WoW event to listen for
---@param callback function Called when bucket fires, receives aggregated payload
function Events:RegisterBucketEvent(eventName, callback)
    if buckets[eventName] then
        return -- Already registered
    end

    buckets[eventName] = {
        timer = nil,
        callback = callback,
        payload = {},
        timerFrame = CreateFrame("Frame"),
    }

    local bucket = buckets[eventName]
    bucket.timerFrame:Hide()
    bucket.timerFrame.elapsed = 0

    bucket.timerFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + (elapsed or 0)
        if self.elapsed >= BUCKET_DELAY then
            self:Hide()
            -- Fire the callback with accumulated payload
            local payload = bucket.payload
            bucket.payload = {}  -- Reset for next batch
            bucket.callback(payload)
        end
    end)

    eventFrame:RegisterEvent(eventName)
end

--- Unregister a bucketed event
---@param eventName string
function Events:UnregisterBucketEvent(eventName)
    if not buckets[eventName] then return end

    eventFrame:UnregisterEvent(eventName)
    buckets[eventName].timerFrame:Hide()
    buckets[eventName] = nil
end

--- Direct event registration (no bucketing)
---@param eventName string
---@param callback function
function Events:RegisterEvent(eventName, callback)
    eventFrame:RegisterEvent(eventName)
    eventFrame[eventName] = callback
end

--- Unregister direct event
---@param eventName string
function Events:UnregisterEvent(eventName)
    eventFrame:UnregisterEvent(eventName)
    eventFrame[eventName] = nil
end

-- =============================================================================
-- Event Handler
-- =============================================================================

eventFrame:SetScript("OnEvent", function(self, event, ...)
    -- Check for bucketed events
    local bucket = buckets[event]
    if bucket then
        -- Add to payload
        local arg1 = ...
        if arg1 ~= nil then
            bucket.payload[arg1] = true  -- Use table as set for deduplication
        else
            bucket.payload["_trigger"] = true
        end

        -- Start/restart the timer
        bucket.timerFrame.elapsed = 0
        bucket.timerFrame:Show()
        return
    end

    -- Direct event handling
    if self[event] then
        self[event](...)
    end
end)

-- =============================================================================
-- Pre-registered Common Events
-- =============================================================================

--- Initialize with common bag events
function Events:Init()
    -- These are the primary events that can cause rapid updates
    -- The callback receives a table of modified bagIDs

    self:RegisterBucketEvent("BAG_UPDATE", function(modifiedBags)
        -- Detect new items in modified bags
        if Omni.Categorizer then
            for bagID in pairs(modifiedBags) do
                if type(bagID) == "number" and bagID >= 0 and bagID <= 4 then
                    local numSlots = GetContainerNumSlots(bagID) or 0
                    for slot = 1, numSlots do
                        local link = GetContainerItemLink(bagID, slot)
                        if link then
                            local itemID = tonumber(string.match(link, "item:(%d+)"))
                            if itemID then
                                -- Mark as new if not in session snapshot
                                Omni.Categorizer:MarkAsNew(itemID)
                            end
                        end
                    end
                end
            end
        end

        -- Update the frame
        if Omni.Frame then
            Omni.Frame:UpdateLayout(modifiedBags)
        end
    end)

    -- Bank events
    self:RegisterEvent("BANKFRAME_OPENED", function()
        if Omni.Data then Omni.Data:SaveBankItems() end
        if Omni.Frame then
            Omni.Frame:SetBankOpen(true)
            Omni.Frame:SetMode("bank")
            Omni.Frame:Show()
        end
    end)

    self:RegisterEvent("PLAYERBANKSLOTS_CHANGED", function()
        if Omni.Data then Omni.Data:SaveBankItems() end
        if Omni.Frame then Omni.Frame:UpdateLayout() end
    end)

    self:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED", function()
        if Omni.Data then Omni.Data:SaveBankItems() end
         if Omni.Frame then Omni.Frame:UpdateLayout() end
    end)

    self:RegisterEvent("BANKFRAME_CLOSED", function()
        if Omni.Frame then
            Omni.Frame:SetBankOpen(false)
            Omni.Frame:SetMode("bags")
        end
    end)

    -- Player money changed
    self:RegisterEvent("PLAYER_MONEY", function()
        if Omni.Frame then
            Omni.Frame:UpdateMoney()
        end
    end)

    -- Item info received (async data load)
    self:RegisterBucketEvent("GET_ITEM_INFO_RECEIVED", function()
        if Omni.Frame and Omni.Frame:IsShown() then
            -- Refresh layout to fix "Miscellaneous" items that now have data
            Omni.Frame:UpdateLayout()
        end
    end)

    -- Player entering world (session start)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        if Omni.Categorizer and Omni.Categorizer.SnapshotInventory then
            -- Note: Snapshot is already called in Categorizer:Init(),
            -- but re-snapshotting here ensures it catches late-loading items
            Omni.Categorizer:SnapshotInventory()
        end
    end)
end

print("|cFF00FF00OmniInventory|r: Event Bucketing system loaded")
