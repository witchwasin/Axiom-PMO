# REQ-TYPE-001 - Requirement type validation

| | |
|---|---|
| Level | FAIL |
| Gate | Draft, Scope, Design, Handoff, Release |
| Applies to | All modes when `Spec depth: full` or `Type` column is present |
| Artifacts | `PROJECT.md` |

## What this rule checks

When the In Scope table in `PROJECT.md` includes a `Type` column, or when the project declares `Spec depth: full`:
1. Every requirement row must declare a `Type`.
2. The `Type` value must be one of the enum values defined in `pmo-config/policy.json` `enums.requirement_types`:
   `functional`, `non_functional`, `constraint`, `interface`, `data`.

## Why it blocks

Unclassified requirements conceal non-functional risks and integration constraints as generic features. Classifying requirements enables mode-scaled depth checks across SRS and test coverage matrices.

## What the validator deliberately does not decide

The validator checks that the declared type matches the enum. It does not judge whether a functional requirement was misclassified as a constraint; domain classification belongs to human scope review.

## How to fix

Ensure every row in the `In Scope` table in `PROJECT.md` has a valid `Type`:

```markdown
| ID | Type | Requirement | Source Ref | Evidence Status |
|---|---|---|---|---|
| REQ-001 | functional | User can login via OAuth2 | MOM-20260710 item-1 | supported |
```
