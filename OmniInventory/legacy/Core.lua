-- Namespace
local addonName, NS = ...

-- Global DB
ZenBagsDB = ZenBagsDB or {}

-- Event Handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_CLOSED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Initialize Config (must be first)
        if NS.Config then
            NS.Config:Init()
        end

        -- Initialize Data Layer (must be before Inventory)
        if NS.Data then
            NS.Data:Init()
        end

        -- Initialize Pools (must be before other modules)
        if NS.Pools then
            NS.Pools:Init()
        end

        -- Initialize ItemCache
        if NS.ItemCache then
            NS.ItemCache:Init()
        end

        print("|cFF00FF00ZenBags v1.0|r loaded. Made by |cFF00FFFFZendevve|r. Type /zb to toggle.")

    elseif event == "PLAYER_LOGIN" then
        -- Initialize modules
        if NS.Inventory then NS.Inventory:Init() end
        if NS.Frames then NS.Frames:Init() end
        if NS.Utils then NS.Utils:Init() end
        if NS.Settings then NS.Settings:Init() end
        if NS.Alts then NS.Alts:Init() end -- Cross-character data
        if NS.Search then NS.Search:Init() end -- Omni-search
        if NS.RuleEngine then NS.RuleEngine:Init() end -- Rule-based categories
        if NS.JunkLearner then NS.JunkLearner:Init() end -- Smart junk learning
        if NS.GearUpgrade then NS.GearUpgrade:Init() end -- Gear upgrade detection

        -- ==========================================================
        -- SMART SORTING (UX: Track item usage)
        -- ==========================================================
        local originalUseContainerItem = UseContainerItem
        UseContainerItem = function(bag, slot, ...)
            -- Track the usage
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemID = tonumber(string.match(link, "item:(%d+)"))
                if itemID and NS.Config then
                    NS.Config:TrackItemUsage(itemID)
                end
            end
            -- Call original function
            return originalUseContainerItem(bag, slot, ...)
        end

        -- Close any default bags that might be open
        CloseBackpack()
        for i = 1, NUM_BAG_SLOTS do
            CloseBag(i)
        end

        -- Overwrite Global Bag Functions to redirect to ZenBags
        function ToggleAllBags()
            if NS.Frames then NS.Frames:Toggle() end
        end

        function OpenAllBags(force)
            if NS.Frames then NS.Frames:Show() end
        end

        function CloseAllBags()
            if NS.Frames then NS.Frames:Hide() end
        end

        function ToggleBackpack()
            if NS.Frames then NS.Frames:Toggle() end
        end

        function OpenBackpack()
            if NS.Frames then NS.Frames:Show() end
        end

        function CloseBackpack()
            if NS.Frames then NS.Frames:Hide() end
        end

        function ToggleBag(id)
            if NS.Frames then NS.Frames:Toggle() end
        end

    -- Merchant events (for Sell Junk button)
    elseif event == "MERCHANT_SHOW" then
        if NS.Frames and NS.Frames.sellJunkBtn then
            NS.Frames.sellJunkBtn:Show()
        end
    elseif event == "MERCHANT_CLOSED" then
        if NS.Frames and NS.Frames.sellJunkBtn then
            NS.Frames.sellJunkBtn:Hide()
        end
    end
end)

-- Slash Commands
SLASH_ZENBAGS1 = "/zenbags"
SLASH_ZENBAGS2 = "/zb"
SlashCmdList["ZENBAGS"] = function(msg)
    if msg == "config" or msg == "settings" or msg == "options" then
        if NS.Settings then
            NS.Settings:Toggle()
        else
            print("ZenBags Settings UI not initialized.")
        end
    else
        if NS.Frames then
            NS.Frames:Toggle()
        else
            print("ZenBags UI not initialized.")
        end
    end
end
