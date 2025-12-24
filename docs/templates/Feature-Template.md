# Feature: {{Feature Name}}

## Purpose

{{One sentence describing what this feature does and why it exists.}}

## Related

- ADR: {{Link to ADR if architectural decision exists}}
- Code: {{Primary code files/modules}}

---

## Business Rules

1. {{Rule 1}}
2. {{Rule 2}}

---

## Main Flow

```mermaid
{{Diagram showing main flow or interaction}}
```

---

## Test Flows

### Positive Flow: {{Happy Path Name}}

**Precondition:** {{Required state before test}}

1. {{Step 1}}
2. {{Step 2}}
3. {{Step 3}}

**Expected:** {{What should happen}}

### Negative Flow: {{Error Case Name}}

**Precondition:** {{Required state}}

1. {{Step 1}}
2. {{Step 2}}

**Expected:** {{Error handling behaviour}}

### Edge Case: {{Edge Case Name}}

**Precondition:** {{Special conditions}}

1. {{Step 1}}

**Expected:** {{Boundary behaviour}}

---

## Definition of Done

- [ ] Feature implemented
- [ ] All test flows verified in-game
- [ ] Documentation updated
- [ ] ADR created (if needed)
- [ ] Code follows AGENTS.md rules
