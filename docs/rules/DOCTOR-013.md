# DOCTOR-013 - Onboarding question coverage

| | |
|---|---|
| Level | FAIL |
| Runs when | `node cli/axiom.mjs doctor` is invoked |
| Artifacts | `pmo-config/policy.json`, `pmo-config/onboarding-questions.json` |

## What this rule checks

That `pmo-config/onboarding-questions.json`'s `questions` keys are **exactly**
`pmo-config/policy.json`'s `enums.strict_triggers` -- no trigger without a
question, no question for a trigger that no longer exists.

## Why it exists

`axiom init`'s interactive "Help me decide" path asks one question per strict
trigger, with wording read from `onboarding-questions.json` keyed by trigger
id. The trigger list itself -- and the mode-escalation logic it drives -- stays
in `policy.json`; `onboarding-questions.json` supplies presentation text only,
never a second definition of what a strict trigger is.

Without this check, adding a trigger to `policy.json` without adding its
question would make that trigger silently unaskable in the wizard, and a
trigger removed from `policy.json` could leave a stale question asking about
something that no longer escalates anything.

## How to fix

Add or remove the matching entry in `pmo-config/onboarding-questions.json` so
its keys exactly match `policy.json`'s `enums.strict_triggers`.

## See also

- [`docs/concepts/execution-paths.md`](../concepts/execution-paths.md)
