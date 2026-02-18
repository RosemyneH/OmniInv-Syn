# OmniInventory Testing Strategy

## Testing Philosophy

WoW addons cannot use automated testing frameworks. All testing is **manual in-game verification** with documented, repeatable scenarios.

### Core Principles

1. **Document test scenarios** - Every feature has explicit test flows
2. **Use real game state** - No simulated data, test with actual items
3. **Cover edge cases** - Empty bags, full bags, special items
4. **Verify performance** - No FPS drops, no memory spikes

---

## Test Categories

### Functional Tests
> Does the feature do what it should?

- Verify expected behaviour works
- Verify error cases are handled
- Verify edge cases don't crash

### Performance Tests
> Is the addon lightweight?

- Open/close bags: no frame drop
- Loot 10 items rapidly: no stutter
- Open with 100+ items: responsive
- Leave open for 10 minutes: no memory leak

### Compatibility Tests
> Works with other addons?

- Default UI: bags still work if addon disabled
- Common addons: ElvUI, WeakAuras, DBM
- Bank: functions at bank NPC

### Regression Tests
> Did we break anything?

- After each change, verify core flows still work
- Search, sort, category, view modes

---

## Test Environment

### Minimum Setup
- WoW 3.3.5a client
- Character with items in bags (10+ items)
- Access to bank NPC
- Access to vendor NPC

### Recommended Setup
- Character with nearly full bags
- Mix of item qualities (grey, green, blue, purple)
- Quest items in inventory
- Stackable items (partial and full stacks)
- Profession bags (if applicable)

---

## Standard Test Scenarios

### Scenario 1: Basic Open/Close
1. Press B to open bags
2. Verify all items visible
3. Press B or click X to close
4. Verify no errors in chat

### Scenario 2: Search
1. Open bags
2. Type "potion" (or any item name)
3. Verify matching items highlighted
4. Press Escape
5. Verify search cleared

### Scenario 3: Sorting
1. Open bags with unsorted items
2. Click Sort button
3. Verify items reordered logically
4. Verify no items lost

### Scenario 4: View Mode Toggle
1. Open bags
2. Switch to Grid view
3. Switch to Flow view
4. Switch to List view
5. Verify each mode displays correctly

### Scenario 5: Vendor Selling
1. Open vendor
2. Verify "Sell Junk" button appears
3. Click "Sell Junk"
4. Verify grey items sold
5. Verify gold message appears

### Scenario 6: Bank Integration
1. Open bank NPC
2. Verify bank items visible
3. Close bank
4. Verify cached bank view (if implemented)

---

## Reporting Results

When documenting test results:

```
## Test: [Scenario Name]
Date: YYYY-MM-DD
Version: X.X

### Steps Performed
1. ...
2. ...

### Expected Result
- ...

### Actual Result
- PASS / FAIL
- Notes: ...

### Issues Found
- None / Issue description
```

---

## Performance Benchmarks

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Open time | < 100ms | Visual observation |
| FPS impact | < 1 FPS drop | /fstack |
| Memory | < 2MB increase | /run print(GetAddOnMemoryUsage("OmniInventory")) |
| Event handling | No spam | Watch chat for repeated messages |
