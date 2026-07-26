# HANDOFF-011 - Declared sensitive-data capability lacks a decision

| | |
|---|---|
| Level | FAIL |
| Gate | Handoff |
| Applies to | Standard, Strict |
| Artifacts | `DESIGN/BUILD-SPEC.md` |

## What this rule checks

In the `### Security, Privacy and Data Inventory` table, every row whose `Contains Sensitive Data` column says yes must also carry:

- a `Classification Decision`
- a `Retention Decision`

Neither may be blank or a placeholder.

## Why it blocks

Privacy contradictions in a handoff are rarely a missing policy - they are a policy that contradicts a feature nobody connected it to. A project can state "we store no personal data" on one page and specify a photo upload on another, and both authors are being honest about their own page.

Declaring the inventory forces the two statements onto the same table, where the contradiction is visible.

## What the validator never does

**It does not decide what is sensitive.** It reads the `Contains Sensitive Data` column that the author wrote. A row called "vehicle photo" marked `no` does not fail this rule, because deciding whether a photograph of a vehicle constitutes personal data is a legal judgement about a specific jurisdiction and a specific use - not something a regex can settle.

Challenging that declaration is the `privacy_and_data_classification` review lens, and the resulting finding needs a human to close it.

## How to fix

```markdown
### Security, Privacy and Data Inventory

Status: specified

| Data Element | Contains Sensitive Data | Classification Decision | Retention Decision |
|---|---|---|---|
| Part photo | yes | DEC-007 internal-only, no faces in frame | DEC-008 purge on demo reset |
| Part code | no | not applicable | retained with the record |
```

A row marked `yes` must **lead** with a resolvable reference — `DEC-007`, `ISSUE:42`, `FILE:...`, `URL:...`. The human-readable gloss after it is encouraged; prose on its own is not. "Internal only, we agreed verbally" describes a decision rather than recording one, and nothing can be traced back to it.

## Related

`HANDOFF-005` (section completeness), `SENSITIVE-001` (sensitive files on disk), `docs/concepts/risk-modes.md`.
