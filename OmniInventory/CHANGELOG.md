# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Guild Bank Frame** (`docs/Features/guild-bank-frame.md`): Complete Omni
  override of Blizzard's guild bank UI, event-driven on
  `GUILDBANKFRAME_OPENED` / `GUILDBANKFRAME_CLOSED`. Renders a left-side
  column of custom tab buttons and a 7×14 slot grid, supports left-click
  pickup / place, shift-click link, split-stack, tooltip compare, and
  search-dim. Right-click any tab for a context menu with rename, info-text
  edit, and Smart Deposit category assignment (Weapons / Armor / Jewelry).
  Guild masters see a "Buy Tab N" button. Footer hosts deposit / withdraw
  money dialogs and a one-click Smart Deposit that scans your bags and moves
  every BoE or account-attunable weapon, armor, or jewelry piece into its
  mapped tab. Default `GuildBankFrame` is suppressed via `Blizzard_GuildBankUI`
  ADDON_LOADED hook.
- **Combat-Safe Slot Buttons** (`docs/Features/combat-safe-bags.md`): Every
  physical bag slot now has a persistent `ItemButton` pre-parented and
  `SetID`'d out of combat. Items that appear mid-combat (loot, quest
  rewards, crafting output) are immediately visible AND clickable via
  Blizzard's secure `ContainerFrameItemButton_OnClick` — no more waiting
  for `PLAYER_REGEN_ENABLED` to see a new drop.

### Changed

- `UI/Frame.lua` `RenderFlowView` rebuilt around a persistent
  `slotButtons[bagID][slotID]` map instead of per-render pool acquire /
  release. Empty slots park in a trailing "overflow" strip at alpha 0 so
  every slot always has a valid on-screen position.
- `UI/Frame.lua` `RenderFlowView` now pins the **BoE** category to the
  tail of the priority order so it renders last inside the normal
  dual-lane flow (always present in flow mode, even when the player
  holds zero BoE equipment). The overflow strip anchors to BoE's own
  half-width lane and continues directly under its last item row, so
  any item that lands in a previously-empty slot during combat visually
  appears "under BoE" without breaking the two-sided category split.
- `UI/Frame.lua` `RefreshCombatContent` now iterates the full slot-button
  map instead of only the last-render's populated list. Visibility is
  driven by `SetAlpha` (insecure) rather than `Show`/`Hide` (protected).

### Fixed

- **Invisible items during combat**: Previously, items that dropped into
  slots that were empty at the last OOC render were completely invisible
  and uninteractable until combat ended. They now render immediately in
  the overflow strip and are clickable via the secure item-button path.

## [2.0-alpha] - 2025-12-26

### Added

- **Bank Support**: Added "Bank" tab to main window. Toggle between Bags and Bank views.
- **Sell Junk**: Added button to footer (visible at vendors) to automatically sell all grey items.
- **Options Panel**: New configuration UI (`/oi config`) for Frame Scale, View Mode, and Sort Mode.
- **Secure Item Buttons**: Re-implemented item buttons using `SecureActionButtonTemplate` to fix "Action blocked" errors.
- **Sorting**: Implemented Stable Merge Sort with multi-tier business rules (Type -> Rarity -> Name).
- **Categorization**: Added Smart Categorizer with priority-based rule engine.
- **Visual Category Editor**: Full UI for managing categories and rules.
- **Visual Polish**: Masque support, smooth Window Fade-in, and efficient `AnimationGroup` item glows.
- **Offline Bank**: Bank contents are now cached and viewable anywhere.
- **Integrations**: Added Pawn upgrade arrows and Auctionator price hooks.
- **Event Handling**: Robust event system including Bank and Merchant events.

### Changed

- Refactored `UI/Frame.lua` to support multiple view modes (Grid, Flow, List).
- Updated API shim (`Omni/API.lua`) to support bank bag enumeration.
- Improved `UpdateLayout` performance with differential updates.

### Fixed

- Fixed issue where clicking items would not use them (caused by non-secure frames).
- Fixed bag slot counting to correctly include bank bags when in bank mode.