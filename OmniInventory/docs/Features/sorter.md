# Feature: Stable Merge Sort

## Purpose

The Sorter provides a deterministic, stable sorting algorithm that ensures items maintain consistent positions between refreshes. This eliminates the "dancing items" problem where items swap positions due to unstable sort algorithms.

## Related

- Code: `Omni/Sorter.lua`
- Feature: [Categorizer](categorizer.md)

---

## Business Rules

1. Sorting MUST be stable (items with equal keys keep relative order)
2. Multi-tier comparator: Category → Quality → iLvl → Name → Stack
3. Same inputs MUST always produce same outputs
4. Sort is applied after categorization

---

## Algorithm: Merge Sort

Merge sort is chosen over quicksort because:
- **Stable**: Equal elements maintain relative order
- **Predictable**: O(n log n) worst case, no degenerate cases
- **Deterministic**: Same input always produces same output

```
[Unsorted]     → [Divide]      → [Merge Sorted]
[4,2,7,1,5,3]  → [4,2,7][1,5,3] → [1,2,3,4,5,7]
               → [4][2,7]...
```

---

## Comparator Chain

When comparing two items a and b:

```lua
1. Category Priority:
   if categoryPriority(a) ~= categoryPriority(b) then
     return categoryPriority(a) < categoryPriority(b)
   end

2. Quality (Higher first):
   if a.quality ~= b.quality then
     return a.quality > b.quality
   end

3. Item Level (Higher first):
   if a.iLvl ~= b.iLvl then
     return a.iLvl > b.iLvl
   end

4. Name (Alphabetical):
   if a.name ~= b.name then
     return a.name < b.name
   end

5. Stack Count (Higher first):
   if a.stackCount ~= b.stackCount then
     return a.stackCount > b.stackCount
   end

6. Fallback: Bag/Slot order (for stability)
   return (a.bagID * 100 + a.slotID) < (b.bagID * 100 + b.slotID)
```

---

## API Reference

### Sorter:Sort(items, mode) → table
Sort items using specified mode.

**Parameters:**
- `items` — Array of item info tables
- `mode` — "category", "quality", "name", "ilvl", or custom

**Returns:**
- Sorted array (new table, original unchanged)

### Sorter:GetModes() → table
Returns available sort modes.

---

## Test Flows

### Positive Flow: Stable Sort

**Precondition:** Two items with identical sort keys

1. Sort items A and B (same quality, name, etc.)
2. Sort again
3. Verify A and B keep same relative order both times

**Expected:** Stable - order preserved

### Positive Flow: Quality Sort

**Precondition:** Items of different qualities

1. Sort items: Epic, Common, Rare
2. Verify order: Epic → Rare → Common

**Expected:** Higher quality first

---

## Definition of Done

- [x] Merge sort algorithm implemented
- [x] Multi-tier comparator chain
- [x] Stable: same inputs = same outputs
- [x] No dancing items on refresh
- [x] Verified in-game
