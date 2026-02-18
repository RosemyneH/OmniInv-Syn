# ADR-001: API Shim Architecture

Status: Implemented
Date: 2024-12-25
Owner: Zendevve
Related Features: [API Shim](../Features/api-shim.md)
Supersedes: N/A
Superseded by: N/A

---

## Context

OmniInventory targets WoW 3.3.5a (WotLK) but must be architecturally forward-compatible with modern Retail APIs (Dragonflight/The War Within).

**Problem:**
- WotLK uses global functions: `GetContainerItemInfo(bag, slot)` returning multiple values
- Retail uses namespaced tables: `C_Container.GetContainerItemInfo(bag, slot)` returning a table
- Return values differ significantly between versions
- Writing code twice (one for each API) is unmaintainable

**Constraints:**
- Must work on 3.3.5a client now
- Must be easily portable to Retail later
- Must not sacrifice performance
- Must provide additional data not returned by legacy API (itemID, isBound)

---

## Decision

Create an **API Abstraction Layer (Shim)** that:

1. Defines a global `OmniC_Container` namespace mirroring Retail's `C_Container`
2. Wraps legacy 3.3.5a API calls
3. Returns modern table structures
4. Synthesizes missing data (itemID, isBound) through parsing and tooltip scanning

Key points:

- Core addon logic is written using modern syntax (`OmniC_Container.GetContainerItemInfo`)
- The Shim module translates this to legacy API calls
- When porting to Retail, disable the Shim and use native `C_Container` directly

---

## Alternatives considered

### Write Legacy Code Directly

- Pros: Simple, no abstraction layer
- Cons: Complete rewrite needed for Retail; code is not self-documenting
- Rejected because: Violates forward-compatibility requirement

### Conditional Logic Throughout

- Pros: No separate module
- Cons: if/else scattered everywhere; hard to maintain; easy to miss paths
- Rejected because: Unmaintainable and error-prone

---

## Consequences

### Positive

- Single codebase works on both 3.3.5a and (future) Retail
- Modern table returns are self-documenting
- Easy to test Shim layer in isolation
- Clear upgrade path

### Negative / risks

- Slight overhead from wrapper functions
- Mitigation: Functions are simple; overhead is negligible
- Risk: Tooltip scanning for isBound is expensive
- Mitigation: Cache results per session; only scan when needed

---

## Impact

### Code

- Affected modules: All modules that read inventory data
- New boundaries: `Omni/API.lua` owns all WoW API translation
- Other modules NEVER call raw WoW container APIs directly

### Data / configuration

- No data model changes
- No config changes

### Documentation

- Feature doc created: `docs/Features/api-shim.md`
- AGENTS.md updated with WoW 3.3.5a constraints

---

## Verification

### Objectives

- OmniC_Container functions return correct data for all item types
- Performance: No frame drop when iterating all bags

### Test scenarios

| ID | Scenario | Expected result |
|----|----------|-----------------|
| TST-001 | Get item info for occupied slot | Returns table with iconFileID, stackCount, quality, itemID |
| TST-002 | Get item info for empty slot | Returns nil |
| TST-003 | Get bag slot count | Returns correct number |
| TST-004 | Iterate all bags | No errors, all items retrieved |
| TST-005 | Performance: 100 items | < 10ms to iterate |

### How to verify

1. `/reload` in-game
2. Run debug command (when implemented): `/oi api-test`
3. Verify output matches expected

---

## References

- [WoW 3.3.5a API Documentation](https://wowpedia.fandom.com/wiki/World_of_Warcraft_API)
- [Retail C_Container API](https://warcraft.wiki.gg/wiki/API_C_Container.GetContainerItemInfo)

---

## Filing checklist

- [x] File saved under `docs/ADR/ADR-001-api-shim-architecture.md`
- [x] Status reflects real state: Implemented
- [x] Links to related features filled in
