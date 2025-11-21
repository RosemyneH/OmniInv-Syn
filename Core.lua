-- Namespace
local addonName, NS = ...

-- Global DB
ZenBagsDB = ZenBagsDB or {}

-- Event Handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Initialize DB defaults
        if not ZenBagsDB.settings then
            ZenBagsDB.settings = {
                scale = 1.0,
                columns = 10,
            }
        end
        print("|cFF00FF00ZenBags|r loaded. Type /zb to toggle.")
        
    elseif event == "PLAYER_LOGIN" then
        -- Initialize modules
        if NS.Inventory then NS.Inventory:Init() end
        if NS.Frames then NS.Frames:Init() end
        if NS.Utils then NS.Utils:Init() end
        
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
    end
end)

-- Slash Commands
SLASH_ZENBAGS1 = "/zb"
SLASH_ZENBAGS2 = "/zenbags"

SlashCmdList["ZENBAGS"] = function(msg)
    if NS.Frames then
        NS.Frames:Toggle()
    else
        print("ZenBags UI not initialized.")
    end
end
