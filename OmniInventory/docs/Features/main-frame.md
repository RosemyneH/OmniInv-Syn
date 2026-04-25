# Feature: Main Frame

## Purpose

The main frame is the primary window for OmniInventory, providing the container for all view modes and controls. It handles window management, positioning, and user interactions.

## Related

- Code: `UI/Frame.lua`
- Pool: `Omni/Pool.lua`

---

## Business Rules

1. Frame replaces default bags when addon is enabled
2. Position persists between sessions
3. Frame is movable and resizable
4. ESC closes the frame
5. B key toggles visibility
6. Flow mode should re-pack categories as soon as the client reflects an item entering or leaving a bag slot, even if the bucketed `BAG_UPDATE` refresh has not fired yet
7. The header includes a left-of-bag helper button that opens the `.finddungeon` popup wrapper
8. When enabled, pressing AttuneHelper's mini sort button switches OmniInventory into bag preview for the configured target bag (`0` backpack or `1` first bag) before AttuneHelper moves items
9. AttuneHelper mini-frame embedding is frame-level only: OmniInventory may parent, show, hide, and style the mini frame, but AttuneHelper owns child button visibility and layout

---

## Components

```
┌──────────────────────────────────────────────────┐
│  [Icon] OmniInventory            [View] [X]      │ ← Header
├──────────────────────────────────────────────────┤
│  [🔍 Search...                              ]    │ ← Search Bar
├──────────────────────────────────────────────────┤
│                                                  │
│                                                  │
│              Item View Area                      │ ← ScrollFrame
│           (Grid/Flow/List)                       │
│                                                  │
│                                                  │
├──────────────────────────────────────────────────┤
│  [⬡ 45/120]           💰 1234g 56s 78c          │ ← Footer
└──────────────────────────────────────────────────┘
```

---

## API Reference

### Frame:Init()

Create and initialize the main frame.

### Frame:Show()

Show the frame, refresh items.

### Frame:Hide()

Hide the frame, release pooled buttons.

### Frame:Toggle()

Toggle visibility.

### Frame:UpdateLayout(changedBags)

Refresh item display for changed bags.

### Frame:RequestOptimisticFlowRefresh(bagID, slotID, options)

Watch a source bag slot after a user action and trigger an early full flow-mode re-render as soon as the live slot state changes.

### Frame:SetView(mode)

Switch view mode: "grid", "flow", "list"

### Frame:SetAttuneHelperSortBagView()

Switch to bag view and select the configured AttuneHelper mini-sort target bag when the integration setting is enabled.

---

## Dungeon Radar Presets

- Vanilla Dungeons: `.finddungeon vanilla notraid`
- Vanilla Raids: `.finddungeon vanilla raid`
- TBC Normal Dungeons: `.finddungeon tbc notheroic notmythic notraid`
- TBC Heroic Dungeons: `.finddungeon tbc heroic`
- TBC Raids: `.finddungeon tbc raid`
- TBC Mythic Dungeons: `.finddungeon tbc mythic`
- WotLK Normal Dungeons: `.finddungeon wotlk notheroic notraid notmythic`
- WotLK Heroic Dungeons: `.finddungeon wotlk heroic notraid`
- WotLK Raids: `.finddungeon wotlk raid`
- WotLK 10-Man Raids: `.finddungeon wotlk raid not25-man`
- WotLK 25-Man Raids: `.finddungeon wotlk raid 25-man`
- WotLK Mythic Dungeons: `.finddungeon wotlk mythic`

---

## Test Flows

### Positive Flow: Open/Close

1. Press B
2. Verify frame opens
3. Press B again
4. Verify frame closes

### Positive Flow: Search

1. Open frame
2. Type "potion"
3. Verify matching items highlighted
4. Press ESC
5. Verify search cleared

### Positive Flow: Find Dungeon Helper

**Precondition:** Main frame is open and the player is out of combat

1. Hover the helper button to the left of the bag icons
2. Verify the tooltip explains the dungeon helper in a playful way
3. Click the helper button
4. Verify the popup opens to the left of the main frame with Vanilla, TBC, and WotLK presets plus a custom filter row
5. Verify the Mythic buttons are blue and sit at the bottom of the TBC and WotLK columns

**Expected:** The main frame exposes `.finddungeon` through an Omni-styled popup without requiring manual command typing

### Positive Flow: Fast Bank Deposit In Flow Mode

**Precondition:** Main frame is in `flow` view, bank is open, and a category has at least two items in the player bags

1. Deposit the first visible item from that category into the bank
2. Watch the remaining items in the same category
3. Verify the next item slides into the lead slot as soon as the source bag slot changes, without waiting for the later bucketed refresh

**Expected:** Flow layout feels immediate while still settling to the same final order after normal bag events finish

### Positive Flow: Loot Item While Bags Stay Open

**Precondition:** Main frame is in `flow` view with bags already open

1. Loot, receive, or otherwise add a brand-new item to your bags while the frame stays open
2. Watch where the new item appears
3. Verify it lands in its proper category immediately after the bag slot fills, without waiting for the delayed burst refresh

**Expected:** New acquisitions categorize into their final flow section as soon as the live bag contents change

### Positive Flow: Fast Merchant Sale In Flow Mode

**Precondition:** Main frame is in `flow` view, merchant is open, and a category has multiple sellable items

1. Sell the first visible item in a category
2. Watch the category header and first item slot
3. Verify the category collapses forward immediately after the item leaves the source slot

**Expected:** Selling items rapidly does not leave stale gaps at the front of flow-mode categories

### Positive Flow: AttuneHelper Mini Sort Bag Preview

**Precondition:** AttuneHelper is loaded, its mini buttons are embedded, and `AH Sort View` is enabled in OmniInventory settings

1. Open OmniInventory
2. Set `AH Sort Bag` to `Bag 1`
3. Press `AttuneHelperMiniSortButton` or run AttuneHelper's prepare-disenchant mini sort action
4. Verify OmniInventory switches to `Bag` view and highlights bag 1
5. Change `AH Sort Bag` to `Backpack`
6. Press the mini sort button again
7. Verify OmniInventory switches to `Bag` view and highlights bag 0

**Expected:** Bag events from AttuneHelper's item moves refresh the selected destination bag instead of leaving the layout scoped to the wrong bag.

### Edge Case: AttuneHelper Dynamic Mini Buttons

**Precondition:** AttuneHelper is loaded, mini mode is embedded, and OmniInventory is open

1. Press AttuneHelper mini buttons that toggle between sort/vendor-style states
2. Verify OmniInventory does not force hidden AttuneHelper child buttons visible
3. Verify AttuneHelper's own mini button layout remains intact across repeated presses

**Expected:** OmniInventory embeds the mini frame without overriding AttuneHelper's child button layout decisions.

### Edge Case: Drag Within Bags

**Precondition:** Main frame is in `flow` view with at least one draggable item

1. Drag an item between two bag slots inside OmniInventory
2. Verify the layout does not jump while the cursor is still carrying the item
3. Drop the item and verify flow mode refreshes once the move completes

**Expected:** Internal drag targets stay stable during the drag, then the category layout reconciles immediately after drop

### Positive Flow: Drop Into Empty Slot In Grid/Bag View

**Precondition:** Main frame is in `grid` or `bag` view and at least one visible slot is empty

1. Pick up any inventory item from a populated slot
2. Drag it onto a visible empty slot cell in OmniInventory
3. Drop the item
4. Verify the item lands in that exact target slot

**Expected:** Empty cells in `grid` and `bag` views are real `(bagID, slotID)` slots and accept drag/drop directly

---

## Definition of Done

- Frame displays with proper backdrop
- Header with title, close button
- Search box functional
- Position saves between sessions
- B key toggles
- ESC closes

