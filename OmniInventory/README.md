<div align="center">
    <a href="https://github.com/Zendevve/OmniInventory" target="_blank">
        <img src=".assets/Icon.jpg" width="200" height="200" alt="OmniInventory"/>
    </a>
</div>

<h1 align="center">Omni Inventory</h1>

<p align="center">
    <em>The definitive inventory management addon for World of Warcraft 3.3.5a</em>
</p>

<p align="center">
    <a href="https://github.com/Zendevve/OmniInventory">
        <img src="https://img.shields.io/badge/PRG-Gold_Project-FFD700?style=for-the-badge" alt="PRG Gold"/>
    </a>
    <a href="https://www.lua.org/">
        <img src="https://img.shields.io/badge/Lua-5.1-2C2D72?style=for-the-badge&logo=lua" alt="Lua 5.1"/>
    </a>
    <a href="#">
        <img src="https://img.shields.io/badge/WoW-3.3.5a-C79C6E?style=for-the-badge" alt="WoW 3.3.5a"/>
    </a>
    <a href="LICENSE">
        <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License"/>
    </a>
</p>

---

## Table of Contents

- [Features](#features)
- [Background Story](#background-story)
- [Getting Started](#getting-started)
  - [Dependencies](#dependencies)
  - [Installation](#installation)
- [What's Inside](#whats-inside)
- [Architecture](#architecture)
- [What's Next](#whats-next)
- [Contributing](#contributing)
- [Resources](#resources)
- [License](#license)

---

## Features

### 🔄 Multi-Mode View Engine
Switch between three view modes on the fly:
- **Grid View** (Bagnon-style) — Unified container, familiar layout
- **Flow View** (AdiBags-style) — Smart categories with dynamic sections
- **List View** (Sorted-style) — Data-dense spreadsheet layout

### 🧠 Smart Categorization
- Automatic item classification (Quest, Equipment, Consumables, Trade Goods)
- Rule-based custom categories for power users
- Stable merge-sort eliminates "dancing items"

### ⚡ Performance First
- **Event Bucketing** — Coalesces rapid BAG_UPDATE events (no spam)
- **Object Pooling** — Zero GC churn, no frame drops
- **Lazy Loading** — Bank data loads on demand

### 💰 Economic Intelligence
- Integrates with Auctionator/TSM for item pricing
- "Sell Junk" button at vendors
- Total inventory value display

### 📊 Cross-Character Data
- See items across all alts
- "Also on: Alt (20)" in tooltips
- Offline bank viewing

### 🔮 Future-Proof Architecture
- API Shim layer bridges 3.3.5a to Retail
- Portable codebase for Dragonflight/War Within

---

## Background Story

The WoW 3.3.5a addon ecosystem has long been fragmented:
- **Bagnon** offers simplicity but no organization
- **AdiBags** offers categories but "layout jitter"
- **ArkInventory** offers power but overwhelming complexity

**OmniInventory** unifies the best of all worlds — the visual simplicity of Bagnon, the intelligent sorting of AdiBags, and the configurability of ArkInventory — while solving the performance issues that plague older addons.

Built from the ground up with forward-compatible architecture, OmniInventory is designed to be the last bag addon you'll ever need.

---

## Getting Started

### Dependencies

- World of Warcraft 3.3.5a client
- No external libraries required (self-contained)

### Installation

1. Download the latest release
2. Extract to your WoW AddOns folder:
   ```
   {WoW Install}/Interface/AddOns/OmniInventory/
   ```
3. Restart WoW or `/reload`
4. Press **B** to open bags or type `/omni`

### Commands

| Command | Action |
|---------|--------|
| `/omni` or `/oi` | Toggle bags |
| `/oi config` | Open settings |
| `/oi debug` | Show pool stats |

---

## What's Inside

```
OmniInventory/
├── OmniInventory.toc       # Addon manifest
├── Core.lua                # Entry point, slash commands
├── AGENTS.md               # AI agent instructions (MCAF)
├── Omni/                   # Core logic modules
│   ├── API.lua             # Shim layer (3.3.5a → Retail)
│   ├── Events.lua          # Event bucketing
│   ├── Pool.lua            # Object recycling
│   ├── Utils.lua           # Helper functions
│   ├── Data.lua            # SavedVariables
│   ├── Categorizer.lua     # Item classification
│   ├── Sorter.lua          # Sort algorithms
│   └── Rules.lua           # Custom rule engine
├── UI/                     # Visual components
│   ├── Frame.lua           # Main window
│   ├── ItemButton.lua      # Item slot widget
│   ├── GridView.lua        # Grid layout
│   ├── FlowView.lua        # Category flow layout
│   └── ListView.lua        # List/table layout
├── docs/                   # Documentation (MCAF)
│   ├── Features/           # Feature specifications
│   ├── ADR/                # Architecture decisions
│   ├── Testing/            # Test strategy
│   └── Development/        # Setup guides
└── legacy/                 # ZenBags v1 archive
```

---

## Architecture

OmniInventory uses a layered architecture:

```
┌─────────────────────────────────────────────┐
│                    UI Layer                  │
│    (Frame, GridView, FlowView, ListView)     │
├─────────────────────────────────────────────┤
│               Logic Layer                    │
│    (Categorizer, Sorter, Rules, Pool)        │
├─────────────────────────────────────────────┤
│               Data Layer                     │
│    (Data, Events, SavedVariables)            │
├─────────────────────────────────────────────┤
│            API Shim Layer                    │
│    (OmniC_Container → WoW API)               │
└─────────────────────────────────────────────┘
```

The **API Shim** (`Omni/API.lua`) wraps legacy 3.3.5a calls into modern table-returning functions, enabling portability to Retail with minimal changes.

---

## What's Next
- [x] Phase 1: Foundation
- [x] Phase 2: Filter Engine (Visual Editor)
- [x] Phase 3: Visual Polish & Masque
- [x] Phase 4: Integrations (Offline Bank, Pawn)
- [ ] Phase 5: Release v2.0-beta

### Future Roadmap
- Cross-character viewing (UI pending)
- Search History
- Item Set Manager integration

---

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](.github/CONTRIBUTING.md) first.

1. Fork the repository
2. Create a feature branch
3. Write feature doc (MCAF workflow)
4. Implement and test in-game
5. Submit a Pull Request

---

## Resources

- [WoW 3.3.5a API Documentation](https://wowpedia.fandom.com/wiki/World_of_Warcraft_API)
- [MCAF Framework](https://mcaf.managed-code.com/)
- [PRG Guidelines](https://github.com/scottgriv/PRG-Personal-Repository-Guidelines)
- [Lua 5.1 Reference](https://www.lua.org/manual/5.1/)

---

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

---

<div align="center">
    <a href="https://github.com/Zendevve" target="_blank">
        <img src=".assets/Icon.jpg" width="100" height="100" alt="Zendevve"/>
    </a>
    <br>
    <sub>Made with ❤️ by <a href="https://github.com/Zendevve">Zendevve</a></sub>
</div>
