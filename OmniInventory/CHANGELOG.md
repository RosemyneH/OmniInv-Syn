# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
