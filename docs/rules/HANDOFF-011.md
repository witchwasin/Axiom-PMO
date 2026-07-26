# HANDOFF-011 - Declared sensitive-data capability lacks a decision

| | |
|---|---|
| Level | FAIL |
| Gate | Handoff |
| Applies to | Standard, Strict |
| Artifacts | `DESIGN/BUILD-SPEC.md` |

## What this rule checks

In the `### Security, Privacy and Data Inventory` table:

1. Every row **declares** whether it contains sensitive data. A value that is neither a yes nor a no — blank, `maybe`, `unclear`, `probably not` — is an *undeclared* classification, not a negative one, and fails. Treating vagueness as "no" would let any row opt out of this rule by being imprecise, which is the opposite of what a data inventory is for.
2. Every row declared sensitive carries a `Classification Decision` and a `Retention Decision`, each leading with a resolvable reference.

The accepted yes/no vocabularies are in `pmo-config/handoff-policy.json` under `sensitive_data`.

## Why it blocks

Privacy contradictions in a handoff are rarely a missing policy - they are a policy that contradicts a feature nobody connected it to. A project can state "we store no personal data" on one page and specify a photo upload on another, and both authors are being honest about their own page.

Declaring the inventory forces the two statements onto the same table, where the contradiction is visible.

## What the validator never does

**It does not decide what is sensitive.** It reads the `Contains Sensitive Data` column that the author wrote. It insists that the column contains an answer; it never supplies one. A row called "vehicle photo" marked `no` does not fail this rule, because deciding whether a photograph of a vehicle constitutes personal data is a legal judgement about a specific jurisdiction and a specific use - not something a regex can settle.

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
