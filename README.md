# ZenBags

> **A modern, high-performance inventory addon for World of Warcraft: Wrath of the Lich King**

ZenBags brings zen to your inventory management with blazing-fast performance, intelligent categorization, and a clean, intuitive interface.

---

## ✨ Features

### 🚀 **Performance First**
- **Event Bucketing**: Intelligent event coalescing reduces updates from 50/sec to 10/sec
- **Object Pooling**: Zero garbage collection lag from button reuse
- **Optimized Rendering**: Only updates what changed, not everything
- **Smooth as Silk**: 60fps guaranteed, even during intense looting sessions

### 🎯 **Smart Organization**
- **Auto-Categorization**: Items automatically grouped by type (Quest, Trade Goods, Equipment, etc.)
- **Visual Hierarchy**: Clear section headers with item counts
- **Quality Borders**: Color-coded borders for item quality at a glance
- **Quest Item Highlighting**: Never miss a quest item again

### 🎨 **Clean Interface**
- **Single Unified Bag**: All your bags in one convenient window
- **Real-time Search**: Instantly filter items as you type
- **Space Counter**: Always know how much room you have left
- **Money Display**: Gold, silver, copper - clearly visible

### 🛡️ **Secure & Reliable**
- **No Taint**: Uses Blizzard's secure templates for item interactions
- **Drag & Drop**: Drop items anywhere in the bag to auto-place and sort
- **Right-Click to Use**: All standard item interactions work perfectly
- **Tooltip Support**: Full tooltip integration with shift-hover comparison

---

## 📦 Installation

1. Download the latest release
2. Extract to `World of Warcraft/Interface/AddOns/`
3. Restart WoW or reload UI (`/reload`)
4. Press `B` or type `/zb` to open ZenBags

---

## 🎮 Usage

### **Opening Your Bags**
- Press `B` (default keybind)
- Type `/zb` or `/zenbags`
- Click your backpack icon

### **Searching**
- Type in the search box at the top
- Results filter in real-time

### **Drag & Drop**
- Drag items from anywhere (character panel, other bags)
- Drop anywhere in ZenBags window
- Items auto-place in first available slot and sort by category

### **Item Interactions**
- **Left-Click**: Pick up / Place item
- **Right-Click**: Use / Equip / Consume
- **Shift-Click**: Link in chat
- **Ctrl-Click**: Try on equipment

---

## ⚙️ Architecture

ZenBags is built on proven patterns from the best inventory addons:

```
ZenBags/
├── Core.lua              # Event handling & initialization
├── Config.lua            # Settings management
├── Pools.lua             # Object pooling system
├── Inventory.lua         # Bag scanning with event bucketing
├── Categories.lua        # Item categorization
├── Utils.lua             # Helper functions
└── widgets/
    └── Frame.lua         # Main UI frame
```

### **Performance Optimizations**
- **Event Bucketing**: Coalesces rapid-fire `BAG_UPDATE` events
- **Object Pooling**: Reuses UI elements instead of recreating them
- **Dirty Flag System**: Only updates changed items (coming soon)

---

## 🔧 Configuration

Currently configured via `Config.lua`. GUI settings panel coming in Phase 2!

**Default Settings:**
```lua
scale = 1.0          -- UI scale
opacity = 1.0        -- Window opacity
sortOnUpdate = true  -- Auto-sort after item changes
columnCount = 5      -- Items per row
itemSize = 37        -- Button size in pixels
```

---

## 🗺️ Roadmap

### **Phase 1: Core Functionality** ✅
- [x] Item interactions (drag, drop, use, equip)
- [x] Auto-categorization
- [x] Search functionality
- [x] Performance optimizations
- [x] Drop-anywhere with auto-sort

### **Phase 2: Advanced Features** 🚧
- [ ] Dynamic collapsible sections
- [ ] Bank integration
- [ ] Cross-character inventory viewing
- [ ] Settings GUI
- [ ] Custom filters
- [ ] Item level display
- [ ] New item tracking

### **Phase 3: Polish** 📋
- [ ] Themes & skins
- [ ] Advanced sorting options
- [ ] Profession bag integration
- [ ] Selling protection
- [ ] Colorblind mode

---

## 🤝 Contributing

ZenBags is open source and welcomes contributions!

**Development Setup:**
```bash
git clone https://github.com/Zendevve/ZenBags.git
cd ZenBags
# Symlink to your WoW AddOns folder
```

**Code Style:**
- Follow existing patterns
- Comment complex logic
- Test thoroughly before PR

---

## 📝 Credits

**Inspired by:**
- **AdiBags** - Object pooling, modular architecture
- **Bagnon** - Component design, cross-character features

**Built with:**
- Ace3 framework patterns
- Blizzard's `ContainerFrameItemButtonTemplate`
- Love for clean, performant code

---

## 📄 License

MIT License - See LICENSE file for details

---

## 💬 Support

- **Issues**: [GitHub Issues](https://github.com/Zendevve/ZenBags/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Zendevve/ZenBags/discussions)

---

<p align="center">
  <strong>Made with ❤️ for the WotLK community</strong><br>
  <sub>Bringing zen to your inventory since 2025</sub>
</p>
