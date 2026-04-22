<div align="center">

<img src=".assets/Icon.jpg" width="160" height="160" alt="OmniInventory logo"/>

# Omni Inventory · **Syn**

**Inventory addon for World of Warcraft 3.3.5a** — grid, category flow, or list view. Sorted, rule-aware, performance-minded.

*Fork of [Zendevve/OmniInv-WoW](https://github.com/Zendevve/OmniInv-WoW).*

[![Release](https://img.shields.io/github/v/release/RosemyneH/OmniInv-Syn?sort=semver&style=flat-square&label=release)](https://github.com/RosemyneH/OmniInv-Syn/releases)
[![License](https://img.shields.io/github/license/RosemyneH/OmniInv-Syn?style=flat-square)](LICENSE)
[![Lua](https://img.shields.io/badge/Lua-5.1-2C2D72?style=flat-square&logo=lua)](https://www.lua.org/manual/5.1/)
[![WoW](https://img.shields.io/badge/client-3.3.5a-C79C6E?style=flat-square)](https://github.com/RosemyneH/OmniInv-Syn#readme)

[**Download**](https://github.com/RosemyneH/OmniInv-Syn/releases/latest) · [**Issues**](https://github.com/RosemyneH/OmniInv-Syn/issues) · [**Contributing**](CONTRIBUTING.md) · [**Changelog**](CHANGELOG.md)

</div>

---

## Highlights

| | |
|:---:|:---|
| **Views** | Grid · Flow (categories) · List |
| **Logic** | Auto categories, custom rules, stable merge sort |
| **Performance** | Object pooling, coalesced bag events |

---

## Install

1. Download the [latest release](https://github.com/RosemyneH/OmniInv-Syn/releases/latest).
2. Extract so this path exists: `Interface/AddOns/OmniInventory/OmniInventory.toc` (folder name must match).
3. Restart the client or run `/reload`.

## In-game

| Command | Action |
|:---|:---|
| `/omni` or `/oi` | Toggle bags |
| `/oi config` | Options |
| `/oi debug` | Pool / toggle diagnostics |

Default bag key **`B`** still opens Omni when the addon is enabled.

---

## Repository layout

```
OmniInventory/
├── OmniInventory.toc    manifest
├── Core.lua             entry, slash commands, hooks
├── Omni/                API shim, data, events, pool, sort, rules
├── UI/                  main frame, views, options, category editor
└── docs/                feature specs & ADRs
```

---


## Ingame

<img width="1037" height="992" alt="image" src="https://github.com/user-attachments/assets/1131f8da-5e88-4925-93c4-3fa044a5253d" />

## License

[MIT](LICENSE) · [Synastria](https://github.com/synastria) · upstream by [Zendevve](https://github.com/Zendevve)
