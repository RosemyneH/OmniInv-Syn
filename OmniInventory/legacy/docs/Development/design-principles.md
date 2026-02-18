# ZenBags Design Principles

Based on [Laws of UX](https://lawsofux.com/) - applied to WoW addon UI design.

---

## Core Principles Applied

### Aesthetic-Usability Effect
> Users perceive aesthetically pleasing design as more usable.

**In ZenBags:**
- Clean, flat dark UI theme with consistent styling
- Quality borders for visual feedback
- Professional visual hierarchy

### Hick's Law
> Decision time increases with number and complexity of choices.

**In ZenBags:**
- Categories reduce cognitive load by grouping similar items
- Search filters immediately narrow options
- Grid vs Category toggle simplifies view choice

### Fitts's Law
> Acquisition time depends on distance and size of target.

**In ZenBags:**
- Large 37px item buttons for easy clicking
- 5px padding between items prevents misclicks
- Close button in predictable top-right corner

### Law of Proximity
> Objects near each other tend to be grouped together.

**In ZenBags:**
- Items in same category are visually grouped
- Section headers clearly separate groups
- Money display grouped at bottom

### Chunking (Miller's Law)
> Break information into meaningful groups of 5-9 items.

**In ZenBags:**
- Categories break 100+ items into ~8 manageable groups
- Collapsible sections let users focus on what matters
- 5-column default keeps rows scannable

### Doherty Threshold
> Productivity soars with <400ms response times.

**In ZenBags:**
- Event bucketing for instant response
- Object pooling eliminates lag spikes
- Target: <50ms for full bag update

### Von Restorff Effect
> Distinctive items are remembered better.

**In ZenBags:**
- Quest items highlighted with yellow glow
- New items have spinning glow animation
- Quality borders (epic purple, legendary orange)

### Goal-Gradient Effect
> Motivation increases as goal approaches.

**In ZenBags:**
- Bag space counter shows progress toward "full"
- Visual feedback when vendoring junk

### Cognitive Load
> Reduce mental effort required to use interface.

**In ZenBags:**
- Auto-categorization reduces manual organizing
- Smart defaults require no configuration
- Consistent patterns across all features

### Jakob's Law
> Users expect your site to work like others they know.

**In ZenBags:**
- Standard bag interactions (left-click, right-click, shift-click)
- Familiar search box behavior
- Settings panel mirrors WoW's Interface Options

---

## Design Tokens

```lua
-- Colors
BACKGROUND = { 0.08, 0.08, 0.08, 0.95 }
BORDER = { 0.35, 0.35, 0.35, 1 }
HIGHLIGHT = { 0.3, 0.3, 0.3, 1 }
HEADER = { 0.12, 0.12, 0.12, 1 }
TEXT = { 0.9, 0.9, 0.9 }

-- Spacing
ITEM_SIZE = 37
PADDING = 5
COLUMN_COUNT = 5

-- Quality Colors (Blizzard standard)
POOR = { 0.62, 0.62, 0.62 }      -- Grey
COMMON = { 1, 1, 1 }             -- White
UNCOMMON = { 0.12, 1, 0 }        -- Green
RARE = { 0, 0.44, 0.87 }         -- Blue
EPIC = { 0.64, 0.21, 0.93 }      -- Purple
LEGENDARY = { 1, 0.5, 0 }        -- Orange
```

---

## Performance Targets (Doherty Threshold)

| Operation | Target | Actual |
|-----------|--------|--------|
| Full bag update | <50ms | ✅ |
| Search filter | <100ms | ✅ |
| Category toggle | <200ms | ✅ |
| Memory usage | <5MB | ✅ |

---

## Accessibility Considerations

- **Color Blindness**: Quality indicators use brightness + saturation, not just hue
- **Motion Sensitivity**: Glow animations can be disabled in settings
- **Screen Readers**: Standard Blizzard tooltips work with accessibility tools
- **Motor Impairment**: Large click targets (37px), generous spacing (5px)
