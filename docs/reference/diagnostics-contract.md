# Structured diagnostics contract

Machine-readable output of `scripts/validate-project.ps1 -Format Json` and `scripts/assess-handoff.ps1 -Format Json`.

The authoritative definition is [`pmo-config/diagnostics-schema.json`](../../pmo-config/diagnostics-schema.json). This page explains the intent and the compatibility rules around it.

Current version: **`diagnostics_schema_version` 1.1**, introduced in Axiom-PMO 1.1.0.

---

## Why this exists

A validator that only prints text can tell a person what is wrong. It cannot tell a CI job which file to annotate, a dashboard which work item is blocked, or a fix-it tool where to put the cursor. v1.0 emitted four fields — level, rule id, message, blocking — which is enough to decide pass/fail and nothing else.

v1.1 answers four more questions for every finding: **where** (artifact, item, field), **how to fix it** (suggestion), and **where to read more** (documentation url).

---

## Shape

```json
{
  "schema_version": "1.1",
  "project": "/abs/path/to/project",
  "requested_mode": "Standard",
  "effective_mode": "Standard",
  "gate": "Handoff",
  "summary": { "pass": 24, "warn": 1, "warn_blocking": 0, "fail": 2, "exit_code": 1 },
  "results": [
    {
      "schema_version": "1.1",
      "level": "FAIL",
      "rule_id": "HANDOFF-004",
      "message": "Build sequence is not executable as declared: step 2 depends on D-005, which is scheduled at step 4 (not before it)",
      "blocking": true,
      "artifact": "HANDOFF.md",
      "item_id": "step 2",
      "field": "Build Sequence and Dependencies",
      "suggestion": "Give every Build Now item a step, declare its dependencies (or 'none'), and move shared prerequisites to an earlier step than the items that consume them.",
      "documentation_url": "https://github.com/witchwasin/Axiom-PMO/blob/main/docs/rules/HANDOFF-004.md"
    }
  ]
}
```

### Fields

| Field | Since | Meaning |
|---|---|---|
| `schema_version` | 1.1 | Shape of this row. Repeated per row so an extracted diagnostic is self-describing. |
| `level` | 1.0 | `PASS`, `WARN`, `FAIL`, `INFO`. |
| `rule_id` | 1.0 | Catalog rule id. Always present in `pmo-config/validation-rules.json`. |
| `message` | 1.0 | One sentence naming what is wrong. |
| `blocking` | 1.0 | Whether a `WARN` becomes a non-zero exit under `-FailOnWarning`. |
| `artifact` | 1.1 | Project-relative file, or `null`. |
| `item_id` | 1.1 | Row id inside that file (`D-002`, `REQ-001`, `AC-003`), or `null`. |
| `field` | 1.1 | Column or section inside that row, or `null`. |
| `suggestion` | 1.1 | What to do about it. `null` on `PASS`/`INFO`. |
| `documentation_url` | 1.1 | Rule reference page. `null` on `PASS`/`INFO`, and `null` for rules with no page yet. |

---

## Compatibility policy

**Additive.** The four v1.0 fields keep their names, their meanings, and their relative order. A consumer written against v1.0 reads v1.1 output correctly without changes.

**Ignore what you do not know.** Consumers must tolerate unrecognized fields. A future minor version may add fields; it will not remove or repurpose one.

**Always present, sometimes null.** Every field defined in the schema appears on every row. A field that does not apply is `null` — never omitted, never `""`. This is deliberate: a consumer can index every row identically instead of probing for key presence. The contract test `tests/helpers/diagnostics-contract-tests.ps1` fails the build if an empty string ever appears where `null` belongs.

**Deprecation.** A field is documented as deprecated here and in the schema for at least one minor release before it can be removed. Removal requires a major bump of `diagnostics_schema_version`.

**Breaking-change signal.** Consumers should compare the major component of `diagnostics_schema_version` against what they were built for and refuse input from a higher major.

### Coverage of the location fields

`artifact`, `item_id`, and `field` are populated where the emitting check knows them. All `HANDOFF-*` rules populate them. Older rules populate them progressively; where a check has not yet been annotated the fields are `null`, which is a valid state, not a bug. `null` never means "this rule cannot have a location" — only "this emission did not supply one".

---

## Exit codes

| Code | Meaning |
|---|---|
| 0 | No `FAIL`, and no blocking `WARN` when `-FailOnWarning` was passed. |
| 1 | At least one `FAIL`. |
| 2 | `-FailOnWarning` was passed and at least one blocking `WARN` was emitted. |
| 127 | PowerShell could not be located. Emitted by `scripts/check.sh`, `scripts/check.cmd`, and `cli/axiom.mjs` — never by the validator itself. |

The CLI (`cli/axiom.mjs`) forwards these unchanged.

---

## Sensitive-data policy

**A diagnostic locates a problem. It never reproduces it.**

Diagnostics are written to CI logs, pull request annotations, and dashboards — surfaces with a wider audience than the repository. A message that quotes a requirement or an approval note has moved confidential source material somewhere it was never reviewed for.

Never in a diagnostic:

- requirement or acceptance-criteria prose from `PROJECT.md` or `DELIVERY.md`
- approval evidence text, approver contact details, signature blocks
- any content read from `source/`, `MOM/`, `REQ/`, `Transcript/`, or `Others/`
- customer names, account identifiers, monetary amounts, credentials

Safe in a diagnostic:

- artifact paths relative to the project root
- governed identifiers: `REQ-001`, `D-002`, `AC-003`, `DEC-004`
- table column names and section headings
- enum values from `pmo-config/policy.json`

The contract test enforces two proxies for this: a message may not span multiple lines, and may not exceed 400 characters. Neither proves compliance, but both catch the usual way it breaks — pasting a table row into the message.

---

## Adding a rule

1. Add the entry to `pmo-config/validation-rules.json` with `severity`, `description`, and a `suggestion`. `DOCTOR-008` fails the build without a suggestion on any fail/warn rule.
2. Add `documentation` pointing at a `docs/rules/<RULE>.md` page if the rule is actionable enough to deserve one. `DOCTOR-009` fails the build if the file does not exist.
3. Emit it with `Add-Result`, passing `-Artifact`, `-ItemId`, and `-Field` wherever the check knows them.
4. Add a fixture asserting the specific rule id and level. `DOCTOR-007` fails the build if a catalog entry is never emitted or an emitted id is not catalogued.

`suggestion` and `documentation_url` are resolved from the catalog automatically — do not pass them at the call site unless the site can say something more specific than the rule's general advice.
