# DOCTOR-014 - Experimental rule severity ceiling

| | |
|---|---|
| Level | FAIL |
| Runs when | `node cli/axiom.mjs doctor` is invoked |
| Artifacts | `pmo-config/validation-rules.json` |

## What this rule checks

Any rule catalog entry carrying `"lifecycle": "experimental"` must have
`severity` of `info` or `warn` -- never `fail` or `fail_release`. A rule with
no `lifecycle` field is implicitly `enforced`
(`pmo-config/learning-policy.json rule_lifecycle.default_when_absent`) and is
not checked by this rule.

## Why it exists

Milestone 9's governed learning loop proposes new rules as `experimental`
before a Human Owner promotes them to `enforced`
(`pmo-config/learning-policy.json rule_lifecycle.invariant`: promotion
requires a `DEC-###` and a `ROADMAP.md` entry). If an experimental rule could
block a real gate, the experimental stage would be theatre -- an unreviewed
rule would already be exerting the same authority a reviewed one has. This is
the deterministic half of the boundary `ROADMAP.md`'s Permanent Non-Goals
section states in prose: an AI may observe, aggregate, and propose a rule; it
may never let that proposal act with enforcement authority on its own.

## How to fix

Set the rule's severity to `info` or `warn` while it is experimental. To make
it blocking, record a `DEC-###` promoting it to `enforced` and add the
corresponding `ROADMAP.md` entry, then remove or change the `lifecycle` field.

## See also

`pmo-config/learning-policy.json rule_lifecycle`.
