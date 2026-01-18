-- =============================================================================
-- OmniInventory Core Entry Point
-- =============================================================================
-- The definitive inventory management addon for WoW 3.3.5a
-- Architecturally forward-compatible with Retail
-- =============================================================================

local addonName, Omni = ...

-- =============================================================================
-- Namespace Setup
-- =============================================================================

_G.OmniInventory = Omni

Omni.version = "2.0-alpha"
Omni.author = "Zendevve"

-- =============================================================================
-- Event Handler
-- =============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

-- Masque Support
local Masque = LibStub("Masque", true)
if Masque then
    Omni.MasqueGroup = Masque:Group("OmniInventory")
end

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Initialize SavedVariables
        OmniInventoryDB = OmniInventoryDB or {}

        -- Initialize Data module
        if Omni.Data then
            Omni.Data:Init()
        end

        print("|cFF00FF00Omni|r |cFFFFFFFFInventory|r v" .. Omni.version .. " loaded. By |cFF00FFFF" .. Omni.author .. "|r")
        print("  Type |cFFFFFF00/omni|r or |cFFFFFF00/oi|r to toggle.")

    elseif event == "PLAYER_LOGIN" then
        -- Initialize all modules
        if Omni.Pool then Omni.Pool:Init() end
        if Omni.Events then Omni.Events:Init() end
        if Omni.Categorizer then Omni.Categorizer:Init() end
        if Omni.Sorter then Omni.Sorter:Init() end
        if Omni.Rules then Omni.Rules:Init() end
        if Omni.Frame then Omni.Frame:Init() end
        if Omni.Settings then Omni.Settings:Init() end
        if Omni.MinimapButton then Omni.MinimapButton:Init() end

        -- Override default bag functions
        local function OverrideBags()
            -- Debounce mechanism to prevent double toggles
            local lastToggleTime = 0
            local TOGGLE_DEBOUNCE = 0.1  -- 100ms debounce

            local function SafeToggle()
                local now = GetTime()
                if now - lastToggleTime < TOGGLE_DEBOUNCE then
                    return  -- Ignore rapid toggles
                end
                lastToggleTime = now
                if Omni.Frame then
                    Omni.Frame:Toggle()
                end
            end

            ToggleAllBags = function()
                SafeToggle()
            end

            OpenAllBags = function()
                if Omni.Frame then
                    Omni.Frame:Show()
                end
            end

            CloseAllBags = function()
                if Omni.Frame then
                    Omni.Frame:Hide()
                end
            end

            ToggleBackpack = function()
                SafeToggle()
            end

            OpenBackpack = function()
                if Omni.Frame then
                    Omni.Frame:Show()
                end
            end

            CloseBackpack = function()
                if Omni.Frame then
                    Omni.Frame:Hide()
                end
            end

            ToggleBag = function(id)
                SafeToggle()
            end

            -- CRITICAL: Override OpenBag to prevent default frames from showing
            OpenBag = function(id)
                if Omni.Frame then
                    Omni.Frame:Show()
                end
            end

            -- Hide all default container frames permanently
            for i = 1, 13 do
                local containerFrame = _G["ContainerFrame" .. i]
                if containerFrame then
                    containerFrame:Hide()
                    containerFrame:UnregisterAllEvents()
                    containerFrame:SetScript("OnShow", function(self) self:Hide() end)
                end
            end
        end

        -- Apply bag overrides
        OverrideBags()

        -- Close any default bags that might be open (use internal API)
        for i = 0, 4 do
            local containerFrame = _G["ContainerFrame" .. (i + 1)]
            if containerFrame then
                containerFrame:Hide()
            end
        end
    end
end)

-- =============================================================================
-- Slash Commands
-- =============================================================================

SLASH_OMNIINVENTORY1 = "/omniinventory"
SLASH_OMNIINVENTORY2 = "/omni"
SLASH_OMNIINVENTORY3 = "/oi"

SLASH_ZENBAGS1 = "/zb"
SLASH_ZENBAGS2 = "/zenbags"

local function HandleSlashCommand(msg)
    msg = string.lower(msg or "")

    if msg == "config" or msg == "settings" or msg == "options" then
        if Omni.Settings then
            Omni.Settings:Toggle()
        else
            print("|cFF00FF00OmniInventory|r: Settings panel not yet implemented.")
        end

    elseif msg == "pool" or msg == "debug" then
        if Omni.Pool then
            Omni.Pool:Debug()
        end

    elseif msg == "reset" then
        print("|cFF00FF00OmniInventory|r: Resetting...")
        if Omni.MinimapButton then
            Omni.MinimapButton:ResetPosition()
            print("  Minimap button position reset.")
        end
        -- Add other resets here if needed

    elseif msg == "help" then
        print("|cFF00FF00OmniInventory|r Commands:")
        print("  |cFFFFFF00/zb|r or |cFFFFFF00/oi|r - Toggle bags")
        print("  |cFFFFFF00/zb config|r - Open settings")
        print("  |cFFFFFF00/zb reset|r - Reset addon data/positions")
        print("  |cFFFFFF00/zb debug|r - Show pool stats")

    else
        -- Default: toggle bags
        if Omni.Frame then
            Omni.Frame:Toggle()
        else
            print("|cFF00FF00OmniInventory|r: UI not initialized yet.")
        end
    end
end

SlashCmdList["OMNIINVENTORY"] = HandleSlashCommand
SlashCmdList["ZENBAGS"] = HandleSlashCommand

print("|cFF00FF00OmniInventory|r: Core module loaded")
