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
Omni.author = "Synastria"

-- =============================================================================
-- Event Handler
-- =============================================================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

-- ʕ •ᴥ•ʔ✿ Track invocations of the bag toggle so /oi debug can confirm
-- that the keybind is actually reaching addon code in (and out of) combat. ✿ ʕ •ᴥ•ʔ
Omni._toggleStats = {
    total = 0,
    inCombat = 0,
    lastEvent = nil,
    lastWasCombat = false,
    shownBefore = nil,
    shownAfter = nil,
    showCalls = 0,
    hideCalls = 0,
    showOK = 0,
    hideOK = 0,
    lastShowErr = nil,
    lastHideErr = nil,
    lastBlocked = nil,
    lastBlockedFunc = nil,
}

-- ʕ •ᴥ•ʔ✿ Capture ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN so /oi debug
-- can tell us the exact protected function the engine refused. ✿ ʕ •ᴥ•ʔ
local blockedSink = CreateFrame("Frame")
blockedSink:RegisterEvent("ADDON_ACTION_BLOCKED")
blockedSink:RegisterEvent("ADDON_ACTION_FORBIDDEN")
blockedSink:SetScript("OnEvent", function(_, ev, addon, func)
    if addon == "OmniInventory" or addon == nil then
        Omni._toggleStats.lastBlocked = ev
        Omni._toggleStats.lastBlockedFunc = tostring(func)
    end
end)

-- Masque Support
local Masque = LibStub("Masque", true)
if Masque then
    Omni.MasqueGroup = Masque:Group("OmniInventory")
end

-- ʕ •ᴥ•ʔ✿ Bag-function overrides hoisted to module scope so we can re-apply
-- on PLAYER_ENTERING_WORLD / after combat. Some addons (and the default UI
-- after a UI reload) re-bind the global bag functions, which silently breaks
-- our toggle path. Re-applying defensively guarantees our keybind reaches
-- Omni.Frame:Toggle. ✿ ʕ •ᴥ•ʔ
local function recordEntry(reason)
    Omni._toggleStats.total = Omni._toggleStats.total + 1
    Omni._toggleStats.lastEvent = reason or "toggle"
    Omni._toggleStats.lastWasCombat = (InCombatLockdown and InCombatLockdown()) and true or false
    if Omni._toggleStats.lastWasCombat then
        Omni._toggleStats.inCombat = Omni._toggleStats.inCombat + 1
    end
    Omni._toggleStats.shownBefore =
        (Omni.Frame and Omni.Frame.IsShown and Omni.Frame:IsShown()) and true or false
end

local function recordExit()
    Omni._toggleStats.shownAfter =
        (Omni.Frame and Omni.Frame.IsShown and Omni.Frame:IsShown()) and true or false
end

local function SafeToggle(reason)
    recordEntry(reason or "toggle")
    if Omni.Frame then
        local shownBefore = Omni._toggleStats.shownBefore
        if shownBefore then
            Omni._toggleStats.hideCalls = Omni._toggleStats.hideCalls + 1
            local ok, err = pcall(Omni.Frame.Hide, Omni.Frame)
            if ok then Omni._toggleStats.hideOK = Omni._toggleStats.hideOK + 1
            else Omni._toggleStats.lastHideErr = tostring(err) end
        else
            Omni._toggleStats.showCalls = Omni._toggleStats.showCalls + 1
            local ok, err = pcall(Omni.Frame.Show, Omni.Frame)
            if ok then Omni._toggleStats.showOK = Omni._toggleStats.showOK + 1
            else Omni._toggleStats.lastShowErr = tostring(err) end
        end
    end
    recordExit()
end

local function SafeShow(reason)
    recordEntry(reason or "show")
    if Omni.Frame then
        Omni._toggleStats.showCalls = Omni._toggleStats.showCalls + 1
        local ok, err = pcall(Omni.Frame.Show, Omni.Frame)
        if ok then Omni._toggleStats.showOK = Omni._toggleStats.showOK + 1
        else Omni._toggleStats.lastShowErr = tostring(err) end
    end
    recordExit()
end

local function SafeHide(reason)
    recordEntry(reason or "hide")
    if Omni.Frame then
        Omni._toggleStats.hideCalls = Omni._toggleStats.hideCalls + 1
        local ok, err = pcall(Omni.Frame.Hide, Omni.Frame)
        if ok then Omni._toggleStats.hideOK = Omni._toggleStats.hideOK + 1
        else Omni._toggleStats.lastHideErr = tostring(err) end
    end
    recordExit()
end

-- ʕ •ᴥ•ʔ✿ Stable identity for our overrides so /oi debug can detect when
-- another addon has stolen them. ✿ ʕ •ᴥ•ʔ
local OmniToggleAll   = function() SafeToggle("ToggleAllBags") end
local OmniOpenAll     = function() SafeShow("OpenAllBags") end
local OmniCloseAll    = function() SafeHide("CloseAllBags") end
local OmniToggleBack  = function() SafeToggle("ToggleBackpack") end
local OmniOpenBack    = function() SafeShow("OpenBackpack") end
local OmniCloseBack   = function() SafeHide("CloseBackpack") end
local OmniToggleBag   = function(_) SafeToggle("ToggleBag") end
local OmniOpenBag     = function(_) SafeShow("OpenBag") end
local OmniCloseBag    = function(_) SafeHide("CloseBag") end

Omni._overrideMarker = OmniToggleAll

-- ʕ •ᴥ•ʔ✿ Reassigning these globals is insecure and always allowed -- it's
-- the per-frame Hide / UnregisterAllEvents / SetScript on the protected
-- Blizzard ContainerFrames + BankFrame that gets us into combat-lockdown
-- trouble. We split the two so we can safely re-apply the global overrides
-- from any event (including PLAYER_ENTERING_WORLD after an in-combat
-- /reload) without firing "Interface action failed because of an AddOn."
-- The Blizzard-frame suppression is performed only out of combat; the
-- OnShow/OnEvent hooks installed there persist across reloads anyway. ✿ ʕ •ᴥ•ʔ
local blizzardSuppressionDone = false

local function SuppressBlizzardBagFrames()
    if blizzardSuppressionDone then return end
    if InCombatLockdown and InCombatLockdown() then return end

    for i = 1, 13 do
        local containerFrame = _G["ContainerFrame" .. i]
        if containerFrame then
            pcall(containerFrame.Hide, containerFrame)
            pcall(containerFrame.UnregisterAllEvents, containerFrame)
            pcall(containerFrame.SetScript, containerFrame, "OnShow",
                function(self) if not InCombatLockdown() then pcall(self.Hide, self) end end)
        end
    end

    if _G.BankFrame then
        pcall(_G.BankFrame.UnregisterAllEvents, _G.BankFrame)
        pcall(_G.BankFrame.Hide, _G.BankFrame)
        pcall(_G.BankFrame.SetScript, _G.BankFrame, "OnShow",
            function(self) if not InCombatLockdown() then pcall(self.Hide, self) end end)
        pcall(_G.BankFrame.SetScript, _G.BankFrame, "OnEvent", nil)
    end

    blizzardSuppressionDone = true
end

local function OverrideBags()
    ToggleAllBags  = OmniToggleAll
    OpenAllBags    = OmniOpenAll
    CloseAllBags   = OmniCloseAll
    ToggleBackpack = OmniToggleBack
    OpenBackpack   = OmniOpenBack
    CloseBackpack  = OmniCloseBack
    ToggleBag      = OmniToggleBag
    OpenBag        = OmniOpenBag
    CloseBag       = OmniCloseBag

    SuppressBlizzardBagFrames()
end

Omni._OverrideBags = OverrideBags

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        OmniInventoryDB = OmniInventoryDB or {}

        if Omni.Data then
            Omni.Data:Init()
        end

        print("|cFF00FF00Omni|r |cFFFFFFFFInventory|r v" .. Omni.version .. " loaded. By |cFF00FFFF" .. Omni.author .. "|r")
        print("  Type |cFFFFFF00/omni|r or |cFFFFFF00/oi|r to toggle.")

    elseif event == "PLAYER_LOGIN" then
        if Omni.Pool then Omni.Pool:Init() end
        if Omni.Events then Omni.Events:Init() end
        if Omni.Categorizer then Omni.Categorizer:Init() end
        if Omni.Sorter then Omni.Sorter:Init() end
        if Omni.Rules then Omni.Rules:Init() end
        if Omni.Utils and Omni.Utils.EnsureBlizzardContainerItemButtons then
            Omni.Utils:EnsureBlizzardContainerItemButtons()
        end
        if Omni.Frame then Omni.Frame:Init() end
        if Omni.BankFrame then Omni.BankFrame:Init() end
        if Omni.Settings then Omni.Settings:Init() end

        OverrideBags()

        -- ʕ •ᴥ•ʔ✿ Claim AttuneHelper right away so its default frame never
        -- flashes on screen before the bag takes it hostage. ✿ ʕ •ᴥ•ʔ
        if Omni.Frame and Omni.Frame.HideAttuneHelperUntilOpened then
            Omni.Frame:HideAttuneHelperUntilOpened()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Re-apply: late-loading addons may have replaced our globals.
        -- Safe in combat -- the Blizzard-frame suppression inside
        -- OverrideBags is itself combat-gated.
        OverrideBags()

        if Omni.Frame and Omni.Frame.HideAttuneHelperUntilOpened then
            Omni.Frame:HideAttuneHelperUntilOpened()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Same defensive re-apply once combat lockdown lifts; this also
        -- gives SuppressBlizzardBagFrames a chance to run if an
        -- in-combat /reload deferred it.
        OverrideBags()
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

    elseif msg == "pool" then
        if Omni.Pool then
            Omni.Pool:Debug()
        end

    elseif msg == "debug" then
        local stats = Omni._toggleStats or {}
        print("|cFF00FF00OmniInventory|r debug:")
        print(string.format("  Toggle invocations: %d (in combat: %d)",
            stats.total or 0, stats.inCombat or 0))
        print(string.format("  Last entry path: %s (was combat: %s)",
            tostring(stats.lastEvent), tostring(stats.lastWasCombat)))
        print(string.format("  Last shown before/after: %s -> %s",
            tostring(stats.shownBefore), tostring(stats.shownAfter)))
        print(string.format("  Show calls: %d (ok: %d), Hide calls: %d (ok: %d)",
            stats.showCalls or 0, stats.showOK or 0, stats.hideCalls or 0, stats.hideOK or 0))
        if stats.lastShowErr then
            print("  Last Show err: " .. stats.lastShowErr)
        end
        if stats.lastHideErr then
            print("  Last Hide err: " .. stats.lastHideErr)
        end
        if stats.lastBlocked then
            print(string.format("  Last engine block: %s on %s",
                tostring(stats.lastBlocked), tostring(stats.lastBlockedFunc)))
        end
        print(string.format("  Frame shown: %s",
            tostring(Omni.Frame and Omni.Frame:IsShown() or false)))
        print(string.format("  InCombatLockdown(): %s",
            tostring(InCombatLockdown and InCombatLockdown() or false)))
        print(string.format("  ToggleAllBags is ours: %s",
            tostring(ToggleAllBags == Omni._overrideMarker)))
        local mf = _G.OmniInventoryFrame
        if mf then
            print(string.format("  OmniInventoryFrame protected: %s",
                tostring(mf.IsProtected and mf:IsProtected() or "n/a")))
            print(string.format("  OmniInventoryFrame forbidden: %s",
                tostring(mf.IsForbidden and mf:IsForbidden() or "n/a")))
        end
        if Omni.Pool then Omni.Pool:Debug() end

    elseif msg == "forceshow" then
        -- ʕ •ᴥ•ʔ✿ Bypass every Omni layer and call the bare frame method
        -- directly. If THIS triggers the popup the issue is not in our
        -- toggle plumbing -- it's lockdown on the frame itself. ✿ ʕ •ᴥ•ʔ
        local mf = _G.OmniInventoryFrame
        if not mf then
            print("|cFFFF4040OmniInventory|r: OmniInventoryFrame not created yet.")
        else
            print(string.format("|cFF00FF00OmniInventory|r forceshow: combat=%s shown=%s protected=%s",
                tostring(InCombatLockdown and InCombatLockdown() or false),
                tostring(mf:IsShown()),
                tostring(mf.IsProtected and mf:IsProtected() or "n/a")))
            local ok, err = pcall(mf.Show, mf)
            print("  raw mf:Show -> ok=" .. tostring(ok) .. " err=" .. tostring(err))
        end

    elseif msg == "forcehide" then
        local mf = _G.OmniInventoryFrame
        if not mf then
            print("|cFFFF4040OmniInventory|r: OmniInventoryFrame not created yet.")
        else
            local ok, err = pcall(mf.Hide, mf)
            print("|cFF00FF00OmniInventory|r forcehide: ok=" .. tostring(ok) .. " err=" .. tostring(err))
        end

    elseif msg == "reapply" then
        if Omni._OverrideBags then
            Omni._OverrideBags()
            print("|cFF00FF00OmniInventory|r: bag overrides re-applied.")
        end

    elseif msg == "reset" then
        print("|cFF00FF00OmniInventory|r: Resetting...")

    elseif msg == "help" then
        print("|cFF00FF00OmniInventory|r Commands:")
        print("  |cFFFFFF00/oi|r - Toggle bags")
        print("  |cFFFFFF00/oi config|r - Open settings")
        print("  |cFFFFFF00/oi debug|r - Toggle stats / combat / overrides")
        print("  |cFFFFFF00/oi forceshow|r - Bypass and try raw mainFrame:Show")
        print("  |cFFFFFF00/oi forcehide|r - Bypass and try raw mainFrame:Hide")
        print("  |cFFFFFF00/oi pool|r - Pool stats")
        print("  |cFFFFFF00/oi reapply|r - Re-apply bag function overrides")

    else
        SafeToggle("slash")
    end
end

SlashCmdList["OMNIINVENTORY"] = HandleSlashCommand
SlashCmdList["ZENBAGS"] = HandleSlashCommand

print("|cFF00FF00OmniInventory|r: Core module loaded")
