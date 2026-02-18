# ZenBags

**A modern, high-performance inventory addon for World of Warcraft: Wrath of the Lich King**

ZenBags brings zen to your inventory management with blazing-fast performance, intelligent categorization, and a clean, intuitive interface. Whether you're a casual player looking for simplicity or a power user seeking customization, ZenBags has you covered.

---

## 🎉 v1.0 Release - "Omni Inventory"

**Major new features:**
- ✅ **Cross-Character Inventory** - View other characters' bags from character dropdown
- ✅ **Omni-Search** - Search items across all characters with `/zensearch <item>`
- ✅ **Gear Upgrade Detection** - Green arrow on items that are upgrades, dimmed for downgrades
- ✅ **Smart Junk Learning** - Learns what you sell and auto-marks similar items
- ✅ **Dual-View Toggle** - Switch between Category view and Grid view
- ✅ **Rule-Based Categories** - Custom categorization rules via `/zenrules`
- ✅ **Alt Gold Tracking** - See gold across all characters with `/zenalts`

**Plus all previous features:**
- Search highlighting, new item glow, vendor trash button
- Bank integration with offline caching, collapsible sections
- Quality borders, item level display, tooltip enhancements


---

## ✨ Features

### 🚀 Performance First
- **Event Bucketing**: Intelligent event coalescing reduces updates from 50/sec to 10/sec
- **Object Pooling**: Zero garbage collection lag from button reuse
- **Optimized Rendering**: Only updates what changed, not everything
- **Smooth as Silk**: 60fps guaranteed, even during intense looting sessions

### 🎯 Smart Organization
- **Auto-Categorization**: Items automatically grouped by type (Quest, Trade Goods, Equipment, etc.)
- **Recent Items Tracking**: Newly looted or bought items appear in a dedicated "Recent Items" category with a glowing animation
- **Collapsible Sections**: Click section headers to expand/collapse categories (right-click Recent Items to clear)
- **Visual Hierarchy**: Clear section headers with item counts
- **Quality Borders**: Color-coded borders for item quality at a glance
- **Quest Item Highlighting**: Never miss a quest item again

### 🎨 Clean Interface
- **Single Unified Bag**: All your bags in one convenient window
- **Bank Integration**: Seamless bank viewing with offline caching
- **Real-time Search**: Instantly filter items as you type
- **Space Counter**: Always know how much space you have left
- **Money Display**: Gold, silver, copper - clearly visible
- **In-Game Settings Panel**: Configure everything without editing files

### 🔒 Secure & Reliable
- **No Taint**: Uses Blizzard's secure templates for item interactions
- **Drag & Drop**: Drop items anywhere in the bag to auto-place and sort
- **Right-Click to Use**: All standard item interactions work perfectly
- **Tooltip Support**: Full tooltip integration for both live and cached items

---

## 📦 Installation

### Option 1: Download Release
1. Download the latest release from [GitHub Releases](https://github.com/Zendevve/ZenBags/releases)
2. Extract to `World of Warcraft/Interface/AddOns/`
3. Restart WoW or reload UI (`/reload`)

### Option 2: Clone Repository
1. Download or clone this repository:
   ```bash
   git clone https://github.com/Zendevve/ZenBags.git
   ```
2. Copy the `ZenBags` folder to your WoW addons directory:
   ```
   World of Warcraft/Interface/AddOns/ZenBags
   ```
3. Restart WoW or type `/reload` if already in-game

Once installed, press `B` or type `/zb` to open ZenBags!

---

## 🎮 Usage

### Opening Your Bags
- Press `B` (default keybind)
- Type `/zb` or `/zenbags`
- Click your backpack icon

### Accessing Settings
- Click the **gear icon** in the bag header
- Type `/zb config`, `/zb settings`, or `/zb options`

### Searching
- Type in the search box at the top
- Results filter in real-time
- Toggle search bar visibility in settings

### Managing Sections
- Click section headers to collapse/expand categories
- Collapsed state persists between sessions
- **Right-click "Recent Items"** header to clear all recent item highlights

### Recent Items
- Newly looted or bought items appear in the "Recent Items" category at the top
- Items have a glowing yellow animation
- Hover over an item to remove its "new" status
- Right-click the "Recent Items" header to clear all highlights at once

### Vendor Trash
- A coin button appears when you open a merchant
- Click to instantly sell all gray (poor quality) items
- Hover to see total vendor value before selling

### Drag & Drop
- Drag items from anywhere (character panel, other bags)
- Drop anywhere in ZenBags window
- Items auto-place in first available slot and sort by category

### Item Interactions
- **Left-Click**: Pick up / Place item
- **Right-Click**: Use / Equip / Consume
- **Shift-Click**: Link in chat
- **Ctrl-Click**: Try on equipment

---

## ⚙️ Configuration

Access the settings panel via the gear icon or `/zb config`.

**Available Settings:**

| Setting | Description | Default |
|---------|-------------|---------|
| **UI Scale** | Adjust the overall size of the bag window | 1.0 |
| **Opacity** | Control window transparency | 1.0 |
| **Item Size** | Size of item buttons in pixels | 37 |
| **Item Spacing** | Padding between items | 5 |
| **Enable Search** | Show/hide the search bar | On |
| **Show Tooltips** | Display item tooltips on hover | On |
| **Auto-Sort** | Automatically sort items on update | On |
| **Enable New Item Glow** | Show spinning glow on newly acquired items | On |
| **Don't Glow Junk Items** | Skip glow effect for gray quality items | On |
| **Show Total Item Count** | Display total count across bags/bank in tooltips | On |

All settings update in real-time with a **Reset to Defaults** button available.

---

## 🏗️ Architecture

ZenBags is built on proven patterns from the best inventory addons, optimized for WotLK Classic.

```
ZenBags/
├── Core.lua              # Event handling & initialization
├── Config.lua            # Settings management with SavedVariables
├── Pools.lua             # Object pooling system for UI elements
├── Inventory.lua         # Bag scanning with event bucketing & caching
├── Categories.lua        # Item categorization logic
├── Utils.lua             # Helper functions
└── widgets/
    ├── Frame.lua         # Main UI frame with masonry layout
    └── Settings.lua      # In-game configuration panel
```

### Technical Highlights
- **Event Bucketing**: Coalesces rapid-fire `BAG_UPDATE` events to prevent UI lag
- **Object Pooling**: Reuses button frames instead of recreating them
- **Count-Based Item Tracking**: Robust new item detection using total item counts (inspired by AdiBags)
- **Dirty Flag System**: Tracks changed slots for minimal updates
- **Masonry Layout**: Dynamic column calculation for responsive design
- **Dummy Overlay Pattern**: Handles tooltips for offline/cached items without UI interference

---

## 🗺️ Roadmap

### Phase 1: Core Functionality ✅
- [x] Item interactions (drag, drop, use, equip)
- [x] Auto-categorization
- [x] Search functionality
- [x] Performance optimizations (event bucketing, object pooling)
- [x] Drop-anywhere with auto-sort
- [x] Collapsible sections
- [x] Bank integration with offline caching
- [x] In-game settings panel

### Phase 2: Advanced Features 🚧
- [x] Search highlighting (dim non-matching items)
- [x] Item count badges (show total count across bags)
- [x] New item glow/tracking (Recent Items)
- [ ] Cross-character inventory viewing
- [ ] Custom category filters
- [x] Item level display on equipment
- [ ] Profession bag integration
- [ ] Bag slot management UI
- [x] Vendor trash button (sell all gray items at merchants)

### Phase 3: Polish & Quality of Life 📋
- [ ] Themes & skins
- [ ] Advanced sorting options (by name, quality, ilvl)
- [ ] Selling protection (lock valuable items)
- [ ] Colorblind mode
- [ ] Keybind customization
- [ ] Sound effects toggle
- [ ] Export/import settings profiles

---

## 🤝 Contributing

ZenBags is open source and welcomes contributions! Whether you're fixing bugs, adding features, or improving documentation, your help is appreciated.

**Development Setup:**
```bash
git clone https://github.com/Zendevve/ZenBags.git
cd ZenBags
# Symlink to your WoW AddOns folder for live testing
```

**Code Style:**
- Follow existing patterns and naming conventions
- Comment complex logic and performance-critical sections
- Test thoroughly before submitting a PR
- Ensure compatibility with WotLK Classic (3.3.5a)

**Reporting Issues:**
- Use [GitHub Issues](https://github.com/Zendevve/ZenBags/issues)
- Include WoW version, addon version, and steps to reproduce
- Attach error messages from `/console scriptErrors 1`

---

## 🙏 Credits

**Inspired by:**
- **AdiBags** - Object pooling, modular architecture, section design
- **Bagnon** - Component patterns, cross-character features, caching system

**Built with:**
- Ace3 framework patterns
- Blizzard's `ContainerFrameItemButtonTemplate`
- Clean, performant code principles
- Love for the WotLK community ❤️

---

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details.

---

## 💬 Support

- **Issues**: [GitHub Issues](https://github.com/Zendevve/ZenBags/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Zendevve/ZenBags/discussions)
- **Discord**: Coming soon!

---

<p align="center">
  <strong>Made with care for the WotLK community</strong><br>
  <sub>Bringing zen to your inventory since 2025</sub>
</p>
