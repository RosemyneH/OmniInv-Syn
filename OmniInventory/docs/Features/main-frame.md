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

### Edge Case: Drag Within Bags

**Precondition:** Main frame is in `flow` view with at least one draggable item

1. Drag an item between two bag slots inside OmniInventory
2. Verify the layout does not jump while the cursor is still carrying the item
3. Drop the item and verify flow mode refreshes once the move completes

**Expected:** Internal drag targets stay stable during the drag, then the category layout reconciles immediately after drop

---

## Definition of Done

- Frame displays with proper backdrop
- Header with title, close button
- Search box functional
- Position saves between sessions
- B key toggles
- ESC closes
