# DOCTOR-015 - Template BUILD-SPEC sections and table columns match policy

| | |
|---|---|
| Level | FAIL |
| Runs when | `node cli/axiom.mjs doctor` is invoked |
| Artifacts | `templates/BUILD-SPEC.md`, `pmo-config/handoff-policy.json` |

## What this rule checks

Every `### ` section heading in `templates/BUILD-SPEC.md` must match the declared
headings in `pmo-config/handoff-policy.json` under `build_spec.sections[].heading`.
Additionally, for every section declared as a table (`table: true`), the column
headers in `templates/BUILD-SPEC.md` must match the declared `columns` in the policy
by name and order.

## Why it blocks

When framework developers update `handoff-policy.json` or `templates/BUILD-SPEC.md`
independently, silent template drift occurs. Projects initialized from drifted
templates fail `HANDOFF-005` or `HANDOFF-013` at Handoff validation immediately upon
creation, confusing users with diagnostics that point at generated template files.

`DOCTOR-015` turns template-to-policy drift into an early diagnostic during framework
development before drifted templates reach scaffolding.

## What the validator deliberately does not decide

`DOCTOR-015` checks structural agreement between the template and its governing
policy file. It does not judge whether the specification content in a project is
semantically adequate or complete—that judgement belongs to downstream handoff
readiness validation and semantic human reviews.

## How to fix

Update `templates/BUILD-SPEC.md` or `pmo-config/handoff-policy.json` so that all
section headings and table column headers match.
