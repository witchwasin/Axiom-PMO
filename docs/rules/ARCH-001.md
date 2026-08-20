# ARCH-001 - Technology Decisions completeness and decision log linkage

| | |
|---|---|
| Level | FAIL |
| Gate | Handoff, Release |
| Applies to | Strict (when `Spec depth: full`) |
| Artifacts | `DESIGN/BUILD-SPEC.md` |

## What this rule checks

In `DESIGN/BUILD-SPEC.md` under `### Technology Decisions`:
1. Strict mode projects under full specification depth must declare technology decisions.
2. Every row must declare `Decision ID`, `Area`, `Chosen`, `Alternatives Considered`, `Rationale`, and `Trade-offs Accepted`.
3. Every `Decision Ref` must resolve to a valid `DEC-###` entry in `decision-log.md`.
4. Every `Source Ref` must match the source reference pattern.

## Why it blocks

Engineering handoff without documented technology trade-offs leads to architectural divergence. Developers need to know why specific frameworks, databases, or protocols were selected and what alternatives were rejected.

## How to fix

Record technology decisions in `decision-log.md` and link them in the `Technology Decisions` table of `DESIGN/BUILD-SPEC.md`:

```markdown
| Decision ID | Area | Chosen | Alternatives Considered | Rationale | Trade-offs Accepted | Decision Ref | Source Ref |
|---|---|---|---|---|---|---|---|
| TD-001 | Storage | PostgreSQL 16 | DynamoDB, MongoDB | Strong ACID transactions and JSONB support | Higher operational overhead | DEC-001 | MOM-20260710 item-1 |
```
