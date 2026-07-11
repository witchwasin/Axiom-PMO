# Upgrade Baseline (Round 2: 8.3 → 9+)

Date: 2026-07-12
Branch created: `remediation/9plus-v2` (from `main` @ `c2c9ee6`)
Plan: `reports/upgrade-plan-9plus.md` (v2 unified)

## Git state at baseline

- `main` = `origin/main` = `c2c9ee6` ("Post-merge cleanup...")
- Working tree at branch creation: `M CHANGELOG.md` (factual fix for the
  "main was never affected" error — pre-existing, to be committed in Phase 0),
  untracked `reports/upgrade-plan-9plus.md` (the plan itself), untracked
  `tests - Shortcut.lnk` (stray Windows shortcut, not ours, left untouched).

## Baseline check results (real runs)

| Check | Result | Exit |
|---|---|---:|
| `scripts/pmo-doctor.ps1` | PASS=48 WARN=0 FAIL=0 | 0 |
| `scripts/run-validation-tests.ps1` | PASS=53 FAIL=0 (12 pos + 36 neg + 5 doctor-neg) | 0 |

## Metrics

- Active skills: 7
- Tracked files: 428
- Validation matrix: 53 cases
- VERSION: `0.4.0`

## Honest score at baseline

**8.3/10** (GPT-5.6 independent static review, endorsed after all its P0 findings
were reproduced live — see plan header). Known-open P0s at baseline:
P1.1 `not_required` bypass · P1.3 CLI mode downgrade · P1.4 gate-blind artifact
requirements · P2.1 RTM template/validator schema mismatch · P5.2 E2E example
copy-over masking.
