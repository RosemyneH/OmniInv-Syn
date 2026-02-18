# AGENTS.md

**ZenBags v2.0** — WoW Addon (Lua, WotLK 3.3.5a)

Follows [MCAF](https://mcaf.managed-code.com/)

---

## Project Overview

ZenBags is a comprehensive "One Bag" inventory management addon for World of Warcraft WotLK 3.3.5a. The v2.0 "Omni Inventory" project transforms it into a cross-character inventory operating system.

**Tech Stack:**
- Language: Lua 5.1 (WoW embedded)
- Platform: World of Warcraft 3.3.5a (Interface: 30403)
- No external build tools - addon loads directly from `.toc` file

---

## Conversations (Self-Learning)

Learn the user's habits, preferences, and working style. Extract rules from conversations, save to "## Rules to follow", and generate code according to the user's personal rules.

**Update requirement (core mechanism):**

Before doing ANY task, evaluate the latest user message.
If you detect a new rule, correction, preference, or change → update `AGENTS.md` first.
Only after updating the file you may produce the task output.
If no new rule is detected → do not update the file.

---

## Rules to follow (Mandatory, no exceptions)

### Commands

- **test**: `/reload` in WoW game client, then test functionality manually
- **format**: Maintain consistent Lua formatting (4-space indent, local variables)
- **deploy**: Copy addon folder to WoW `Interface/AddOns/` directory

### Task Delivery (ALL TASKS)

- Read AGENTS.md and relevant docs before editing code
- Check `.toc` file load order before adding new modules
- Write feature doc in `docs/Features/` before heavy coding
- Test after EACH module addition (user does `/reload` + `B` key)
- Commit after each working state with descriptive message
- Never break the addon - if it stops loading, fix immediately

### Documentation (ALL TASKS)

- All docs live in `docs/`
- Feature docs: `docs/Features/`
- ADRs: `docs/ADR/`
- Testing: `docs/Testing/`
- Development: `docs/Development/`
- Templates: `docs/templates/`

### Testing (ALL TASKS)

- **WotLK 3.3.5a has NO automated test framework**
- Testing = manual verification in WoW client
- Test procedure: `/reload` → Press `B` → Check if bags open
- Debug with `print()` statements in Lua code
- Verify module loads by checking for debug output in chat

### WotLK-Specific Rules (CRITICAL)

- **NO C_Timer** - doesn't exist, use frame-based timers with OnUpdate
- **NO modern APIs** - check if API exists in 3.3.5a before using
- Use `GetContainerItemInfo()` not `C_Container.GetContainerItemInfo()`
- Use `GetContainerNumSlots()` not `C_Container.GetContainerNumSlots()`
- Use frame:SetScript("OnUpdate") for delayed execution
- Always wrap module inits in `if NS.ModuleName then` checks

### Code Style

- Local variables: `local addonName, NS = ...`
- Module pattern: `NS.ModuleName = {}`
- Init functions: `function ModuleName:Init()`
- Use descriptive function names
- Comment complex logic
- No magic literals - use constants or config values

### Critical (NEVER violate)

- Never use APIs that don't exist in WotLK 3.3.5a
- Never cache NS.* values at file load time (they may not exist yet)
- Never skip testing after adding a module
- Never commit without verifying addon still loads
- Never force push without user approval

### Boundaries

**Always:**
- Check `.toc` load order when adding files
- Add new modules to Core.lua init sequence
- Test that bags still open after changes

**Ask first:**
- Changing SavedVariables schema
- Removing existing functionality
- Modifying the UI layout significantly

---

## Preferences

### Likes

- Test after each small change
- Git commits with descriptive messages
- Debug print statements during development
- Clean removal of debug code before final commit

### Dislikes

- Breaking changes without testing
- Using modern WoW APIs that don't exist in 3.3.5a
- Long debugging sessions caused by untested code
- Caching module references before they're created

---

## Current Development Phase

**ZenBags v2.0 "Omni Inventory" Roadmap:**

- [x] Phase 1: Performance Core (ItemCache, Filter, Sorter, Layout)
- [x] Phase 2.1: Alt Data System (Alts.lua)
- [x] Phase 2.2: Omni-Search (Search.lua)
- [ ] Phase 3: Rule-Based Category Engine (RuleEngine.lua)
- [ ] Phase 4: Smart Junk Learning System (JunkLearner.lua)
- [ ] Phase 5: Dual-View Layout System (ViewToggle.lua)
- [ ] Phase 6: Visual Rule Editor

---

## File Structure

```
ZenBags-dev/
├── Core.lua           # Main addon initialization
├── Config.lua         # Configuration management
├── Pools.lua          # Object pooling for UI elements
├── ItemCache.lua      # Item data caching singleton
├── Filter.lua         # Item filtering module
├── Sorter.lua         # Item sorting module
├── Layout.lua         # Layout calculation module
├── Utils.lua          # Utility functions
├── Data.lua           # Data layer (character switching)
├── Alts.lua           # Cross-character data tracking
├── Search.lua         # Omni-search module
├── Categories.lua     # Item categorization
├── Inventory.lua      # Inventory scanning
├── widgets/
│   ├── Settings.lua   # Settings UI
│   ├── Frame.lua      # Main bag frame
│   ├── Dropdown.lua   # Character dropdown
│   ├── Tabs.lua       # Bag/Bank tabs
│   └── Info.lua       # Info panel
├── docs/
│   ├── Features/
│   ├── ADR/
│   ├── Testing/
│   └── Development/
├── ZenBags.toc        # Addon manifest (load order)
└── AGENTS.md          # This file
```
