# Patch Manifest

> **ARCHIVED** — this is the original Phase-0 patch plan, superseded by the more
> thorough `reports/remediation-plan.md` (v3), which incorporated two independent
> reviews and fixed gaps this plan did not cover. Kept for historical reference only.

Objective: move `PMO-Template-Personal` from pilot-grade `0.3.0-lite-ai-guardrails` toward a stable candidate by aligning runtime skills, router policy, templates, validation, doctor checks, permissions, examples, tests, and docs.

## Execution Rules

- Do not edit or delete user source files.
- Do not commit, push, tag, or deploy during this patch.
- Archive legacy skills instead of deleting them.
- Run checks after each major phase.
- Do not claim 9+ score until final acceptance criteria pass.

## Planned Phases

| Phase | Scope | Status |
|---|---|---|
| 0 | Baseline reports and current metrics | done |
| 1 | Active skill runtime and skill manifest | done |
| 2 | Core rules, router, context policy, central enums | done |
| 3 | Template normalization | done |
| 4 | Validator rule IDs, JSON output, stronger checks | done |
| 5 | Framework doctor upgrade | done |
| 6 | Permission policy alignment | done |
| 7 | Automated test matrix expansion | done |
| 8 | Team automation scripts | done |
| 9 | README, TESTING, SECURITY, MIGRATION docs | done |
| 10 | Final release gate report | done |

## Final Check Summary

- Framework doctor: PASS=42 WARN=0 FAIL=0.
- Validation matrix: PASS=32 FAIL=0 (7 positive, 25 negative).
- Lite example validation: PASS=13 WARN=0 FAIL=0.
- Standard example validation: PASS=21 WARN=0 FAIL=0.
- Strict example validation: PASS=23 WARN=0 FAIL=0.
- Git object check: `git fsck --no-progress` clean.
- Commit, push, and tag are release operations after final user approval.

## Files Expected To Change

- `AGENTS.md`
- `CLAUDE.md`
- `CONTEXT-ROUTER.md`
- `.claude/settings.json`
- `.claude/skills/**`
- `.claude-archive/**`
- `pmo-config/context-map.yaml`
- `pmo-config/skill-manifest.yaml`
- `pmo-config/policy.yaml`
- `pmo-config/validation-rules.yaml`
- `templates/**`
- `scripts/**`
- `tests/fixtures/**`
- `reports/**`
- `README.md`
- `TESTING.md`
- `SECURITY.md`
- `MIGRATION.md`
- `CHANGELOG.md`
- `VERSION`

