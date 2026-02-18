# AGENTS.md

OmniInventory — Lua/WoW 3.3.5a Addon

Follows [MCAF](https://mcaf.managed-code.com/)

---

## Conversations (Self-Learning)

Learn the user's habits, preferences, and working style. Extract rules from conversations, save to "## Rules to follow", and generate code according to the user's personal rules.

**Update requirement (core mechanism):**

Before doing ANY task, evaluate the latest user message.
If you detect a new rule, correction, preference, or change → update `AGENTS.md` first.
Only after updating the file you may produce the task output.
If no new rule is detected → do not update the file.

**When to extract rules:**

- prohibition words (never, don't, stop, avoid) or similar → add NEVER rule
- requirement words (always, must, make sure, should) or similar → add ALWAYS rule
- memory words (remember, keep in mind, note that) or similar → add rule
- process words (the process is, the workflow is, we do it like) or similar → add to workflow
- future words (from now on, going forward) or similar → add permanent rule

**Preferences → add to Preferences section:**

- positive (I like, I prefer, this is better) or similar → Likes
- negative (I don't like, I hate, this is bad) or similar → Dislikes
- comparison (prefer X over Y, use X instead of Y) or similar → preference rule

**Corrections → update or add rule:**

- error indication (this is wrong, incorrect, broken) or similar → fix and add rule
- repetition frustration (don't do this again, you ignored, you missed) or similar → emphatic rule
- manual fixes by user → extract what changed and why

**Strong signal (add IMMEDIATELY):**

- swearing, frustration, anger, sarcasm → critical rule
- ALL CAPS, excessive punctuation (!!!, ???) → high priority
- same mistake twice → permanent emphatic rule
- user undoes your changes → understand why, prevent

**Ignore (do NOT add):**

- temporary scope (only for now, just this time, for this task) or similar
- one-off exceptions
- context-specific instructions for current task only

**Rule format:**

- One instruction per bullet
- Tie to category (Testing, Code, Docs, etc.)
- Capture WHY, not just what
- Remove obsolete rules when superseded

---

## Rules to follow (Mandatory, no exceptions)

### Commands

> Note: WoW addons have no build/test commands. Verification is manual in-game.

- **reload**: `/reload` in-game to reload UI
- **test**: Manual in-game testing with specific scenarios
- **format**: Follow Lua style conventions (see Code Style)
- **analyze**: Manual code review for WoW API compatibility

### Task Delivery (ALL TASKS)

1. Read assignment, inspect code and docs before planning
2. Write multi-step plan before implementation (in task.md artifact)
3. Write feature doc BEFORE heavy coding (docs/Features/)
4. Implement code and tests together
5. Document verification steps for manual in-game testing
6. Run format checks (consistent style)
7. Update docs when behaviour changes
8. Commit with conventional commit messages
9. Summarize changes and verification results before marking complete

### Documentation (ALL TASKS)

- All docs live in `docs/`
- Feature docs: `docs/Features/{feature-name}.md`
- ADRs: `docs/ADR/ADR-{number}-{title}.md`
- Testing: `docs/Testing/`
- Development: `docs/Development/`
- Update feature docs when behaviour changes
- Update ADRs when architecture changes

### Testing (ALL TASKS)

> WoW addons cannot use automated testing frameworks. All testing is manual in-game.

**Verification approach:**

- Each feature has documented test scenarios in its feature doc
- Test scenarios include: positive flows, negative flows, edge cases
- Manual verification steps are explicit and repeatable
- Results are documented (what worked, what failed)

**Test categories:**

- **Functional**: Does the feature do what it should?
- **Performance**: No FPS drops, no memory leaks, no stuttering
- **Compatibility**: Works with default UI and common addons
- **Edge cases**: Empty bags, full bags, bank, special items

**No mocking philosophy (adapted for WoW):**

- Use real WoW API calls, not simulated data
- Test with actual items, not hardcoded test data
- Verify against real game state

### Code Style

**Lua conventions:**

- 4-space indentation
- `local` for all variables and functions where possible
- CamelCase for classes/modules: `Omni.Categorizer`
- camelCase for local functions: `local function parseItemLink()`
- UPPER_SNAKE for constants: `local MAX_BAG_SLOTS = 5`
- No magic literals — extract to named constants

**WoW addon patterns:**

- Use addon namespace: `local addonName, Omni = ...`
- All modules under `Omni.` namespace
- Explicit nil checks before API calls
- Cache API results when appropriate

**File structure:**

- One module per file
- Core logic in `Omni/`
- UI components in `UI/`
- Load order defined in `.toc` file

### Autonomy

- Start work immediately — no permission seeking for routine tasks
- Questions only for architecture blockers not covered by ADR
- Report only when task is complete
- Commit frequently with clear messages

### Critical (NEVER violate)

- Never commit secrets, API keys, or personal data
- Never skip documented verification steps
- Never delete working code without understanding why it exists
- Never ignore user feedback — extract rules immediately
- Never approve or merge (human decision)
- Never assume WoW API behaviour — verify in docs or test

### Boundaries

**Always:**

- Read AGENTS.md and relevant docs before editing code
- Write feature doc before implementing new features
- Update docs when changing existing features
- Test in-game before marking complete

**Ask first:**

- Changing public addon interface (slash commands, frames)
- Adding new SavedVariables fields
- Major architectural changes
- Deleting feature code

---

## Project-Specific Rules

### WoW 3.3.5a Constraints

- API compatibility: WotLK client (build 30300)
- No C_Container namespace — use Shim layer (`OmniC_Container`)
- No C_Timer — use OnUpdate frame timers
- Limited tooltip scanning methods
- SavedVariables file format restrictions

### OmniInventory Architecture

- **Shim Layer** (`Omni/API.lua`): Bridges 3.3.5a to Retail-style APIs
- **Event Bucketing** (`Omni/Events.lua`): Coalesces rapid events
- **Object Pool** (`Omni/Pool.lua`): Frame recycling for performance
- **Categorizer** (`Omni/Categorizer.lua`): Item classification engine
- **Views** (`UI/`): Grid, Flow, List modes

### Performance Requirements

- No frame drops when opening/closing bags
- Event bucketing prevents spam during mass looting
- Object pooling prevents GC stutter
- Lazy loading for bank/offline data

---

## Preferences

### Likes

- UX-first design (convenience, speed, clarity)
- Clean, minimal UI with purpose
- Comprehensive feature docs before coding
- Small, focused commits

### Dislikes

- Placeholder code without clear TODO
- Magic numbers scattered in code
- Incomplete features marked as done
- Undocumented architectural decisions

---

## Learned Rules (from conversations)

### PRG (Personal Repository Guidelines) — MANDATORY

> User mandated PRG compliance. OmniInventory is a **Gold Tier** project.

**Project Classification:**
- **Tier**: Gold (8+ hours of work, genuine product, unique branding)
- **Naming**: `Application-Brand-Name` format → "OmniInventory"
- **README**: Must follow Gold tier requirements

**README Structure (Gold Tier Required):**
- Header with banner/icon (clickable, links to demo/repo)
- Badges (technologies with versions, PRG tier badge)
- Description with screenshots/GIFs
- Table of Contents
- Features section
- Background Story
- Getting Started (Dependencies, Installation)
- What's Inside (file tree)
- Closing remarks
- What's Next (roadmap)
- Contributing section
- Resources section
- License (GNU GPLv3 recommended for Gold)
- Footer with credits and icon

**Repository Files (Required):**
- `README.md` — comprehensive, follows Gold template
- `LICENSE` — GNU GPLv3 for Gold tier
- `.gitignore` — exclude build artifacts, editor files
- `docs/` folder — features, ADRs, testing (MCAF)

**Repository Files (Optional but Encouraged):**
- `.github/CREDITS.md`
- `.github/CHANGELOG.md`
- `.github/CONTRIBUTING.md`
- `.github/CODE_OF_CONDUCT.md`

**Branding (Gold Tier):**
- `icon.png` — 414×414px application icon
- `banner_large.png` — 1280×260px for README header
- `banner_social.png` — 1280×640px for GitHub social preview
- Use vector design tools (Figma/Sketch), export @2x
- Consistent color palette

**PRG Badge for Gold:**
```markdown
[![PRG Gold](https://img.shields.io/badge/PRG-Gold_Project-FFD700?style=for-the-badge&logo=...)](URL)
```

---

### User Preferences (Extracted)

- User prefers "OmniInventory" as the definitive bag addon — aim for feature completeness
- User values UX-first approach: conversion and convenience
- User mandated MCAF compliance — all work must follow MCAF framework
- User mandated PRG compliance — all documentation must follow PRG guidelines
- User prefers comprehensive documentation before coding
- User wants forward-compatible architecture (3.3.5a → Retail)
