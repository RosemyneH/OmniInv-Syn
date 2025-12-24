# OmniInventory Development Setup

## Prerequisites

- World of Warcraft 3.3.5a client
- Text editor (VS Code recommended with Lua extension)
- Git

## Installation

1. Clone the repository:
```bash
git clone https://github.com/Zendevve/OmniInventory.git
```

2. Symlink or copy to WoW addons folder:
```
{WoW Install}/Interface/AddOns/OmniInventory/
```

3. Enable the addon in-game character selection screen.

## Project Structure

```
OmniInventory/
├── OmniInventory.toc    # Addon manifest, load order
├── Core.lua             # Entry point, slash commands
├── AGENTS.md            # AI agent instructions (MCAF)
├── Omni/                # Core logic modules
│   ├── API.lua          # Shim layer (3.3.5a → Retail)
│   ├── Events.lua       # Event bucketing
│   ├── Pool.lua         # Object recycling
│   ├── Utils.lua        # Helper functions
│   ├── Data.lua         # SavedVariables
│   ├── Categorizer.lua  # Item classification
│   ├── Sorter.lua       # Sort algorithms
│   └── Rules.lua        # Custom rule engine
├── UI/                  # Visual components
│   ├── Frame.lua        # Main window
│   ├── ItemButton.lua   # Item slot widget
│   ├── GridView.lua     # Grid layout
│   ├── FlowView.lua     # Category flow layout
│   └── ListView.lua     # List/table layout
├── docs/                # Documentation (MCAF)
└── legacy/              # ZenBags v1 archive
```

## Development Commands

| Action | Command |
|--------|---------|
| Reload UI | `/reload` (in-game) |
| Toggle bags | `/omni` or `/oi` |
| Debug pools | `/oi debug` |
| Settings | `/oi config` |

## Coding Standards

- See `AGENTS.md` for full code style rules
- 4-space indentation
- `local` for all variables
- CamelCase modules, camelCase functions
- No magic literals

## Making Changes

1. Read feature doc in `docs/Features/` (create if needed)
2. Write/update tests in feature doc
3. Implement changes
4. Test in-game
5. Update docs
6. Commit with conventional message

## Commit Message Format

```
type: short description

- Detail 1
- Detail 2
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `chore`
