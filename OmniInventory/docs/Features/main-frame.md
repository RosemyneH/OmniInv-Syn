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

---

## Definition of Done

- [x] Frame displays with proper backdrop
- [x] Header with title, close button
- [x] Search box functional
- [x] Position saves between sessions
- [x] B key toggles
- [x] ESC closes
