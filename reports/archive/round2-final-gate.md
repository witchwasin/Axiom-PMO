# Round 2 Final Acceptance Gate

Date: 2026-07-12
Branch: `remediation/9plus-v2` (not pushed)
Merge commit: `<commit>` (Track B `<commit>` merged into Track A)
Baseline: 8.3/10 (`reports/upgrade-plan-9plus.md` v2 unified)

Checklist below follows `reports/upgrade-plan-9plus.md` §"Phase 8 — Final
Acceptance Gate" line by line, each item backed by a real command run today,
not a self-report.

## Validator correctness

| Item | Status | Evidence |
|---|---|---|
| `not_required` only where config allows | done | P1.1, `pmo-config/policy.json.sentinel_rules`; `not-required-in-*` negative fixtures FAIL |
| CLI cannot downgrade mode | done | P1.3, `scripts/lib/mode-resolver.ps1`; `mode-downgrade-*` fixtures FAIL |
| Effective mode shows reason | done | `Requested Mode` / `Effective Mode` + reason string in every run's output |
| Artifacts match Mode x Gate | done | P1.4 + P5 RTM.json fix, `scripts/lib/artifact-policy.ps1` genuinely config-driven (proven by artifact-policy config-mutation test) |
| Source warnings never block unreasonably | done | P1.2, `valid-source-others-and-sensitive`, `source-broken-link-non-blocking` PASS with `-FailOnWarning` |
| RTM per-row chain complete | done | P2.1, `rtm-*` negative fixtures (delivery/test/evidence/release ref, orphan row, duplicate) all FAIL correctly |
| Evidence + approval refs resolve | done | P2.2/P2.3, `scripts/lib/reference-resolver.ps1`; `approval-evidence-freetext-rejected`, `malformed-external-evidence` FAIL |
| Release scope all Done | done | P3.1, `RELEASE-STATUS-001`/`RELEASE-SCOPE-001`; `release-status-not-done` FAILs, `STANDARD-FEATURE` D-002 exclusion PASSes |
| QA/Security parsed from real rows | done | P3.2, `QA-REVIEW-001`/`SECURITY-REVIEW-001`; `qa-review-missing`, `security-review-pending` FAIL |
| Rollback rows real | done | P3.3, `RELEASE-001`; Lite waiver alternative also enforced (`invalid-not-required-rollback` FAILs, `valid-lite-rollback-waiver` PASSes) |

## Reproduce-my-bypasses

**Must now FAIL** (all verified in the 79-case fixture matrix, run today):
- All-`not_required` fixture (approval/workitem/rollback variants) — FAIL
- `STRICT-HIGH-RISK` via `-Mode Lite` — FAIL (`mode-downgrade-project-default`)
- Free-text evidence — FAIL (`approval-evidence-freetext-rejected`)
- Non-Done release scope — FAIL (`release-status-not-done`)

**Must now PASS** (same matrix run):
- Standard at Draft with `PROJECT.md` only — PASS (`standard-draft-no-delivery-release-required`)
- Generated Strict project with filled templates — PASS (Strict E2E, real `new-project.ps1` output filled deterministically, no example copy-over)
- `Others/` TODO + sensitive filename in source with `-FailOnWarning` — PASS (`others-and-sensitive-source-do-not-fail-release`)

## Templates/contract

- Template = generator = examples = validator on one schema: confirmed by the
  rebuilt generator-to-Release E2E (P5), which exercises the real
  `new-project.ps1` output (not a curated example) through every gate for all
  3 modes.
- `RTM.json` canonical: `templates/RTM.json`, `examples/STRICT-HIGH-RISK/RTM.json`,
  and the Strict E2E's generated `RTM.json` all match the
  `{schema_version, project, traceability[]}` shape validated by
  `scripts/lib/rtm-validator.ps1`.
- `schema_version` everywhere: all 6 `pmo-config/*.json` files (`policy`,
  `artifact-policy`, `reference-types`, `skill-manifest`, `validation-rules`,
  `context-map`) plus `RTM.json`, checked by `DOCTOR-006` (framework config)
  and `RTM-001` (per-project artifact) respectively.
- Lite has no artifacts beyond policy: `artifact_matrix.Lite.*` is `[]` at
  every gate in `pmo-config/artifact-policy.json`.

## Tests

Real run today, this exact merge commit:

```
scripts/pmo-doctor.ps1            -> PASS=51 WARN=0 FAIL=0
scripts/run-validation-tests.ps1  -> PASS=79 FAIL=0 (16 positive + 54 negative
                                      + 5 doctor-negative + 4 new P8-era cases)
tests/helpers/config-mutation-tests.ps1 -> 4/4 scenarios, each asserting the
                                      specific expected rule_id (ENUM-001,
                                      DOCTOR-001, STRUCT-001, DOCTOR-006),
                                      not just a non-zero exit code
tests/e2e/{lite,standard,strict}.ps1    -> 3/3 PASS, real generator content
tests/golden/ (70 fixture cases + 3 example commands = 74) -> byte-identical
                                      after the Phase 4 refactor and every
                                      subsequent change
```

`scripts/run-all-checks.ps1` (calls all of the above in sequence) exits 0.

**Not done:** PSScriptAnalyzer static analysis (P5.3) — module is not
installed on this machine; deferred it on 2026-07-12 rather
than have me pull an unreviewed package from the PowerShell Gallery
unsupervised. This is a known, recorded gap, not a silent omission.

**Environment:** every command above ran on Windows PowerShell 5.1
(`$PSVersionTable.PSVersion` = 5.1.26100.8737) — no PS7-only syntax used
anywhere in `scripts/lib/*.ps1` or the test harness.

## CI / governance

| Item | Status |
|---|---|
| §7.4 branch-protection decision recorded and applied | done — `reports/current-acceptance.md`, option (C) platform constraint |
| LICENSE decision recorded | done — explicitly deferred, not omitted |
| `VERSION` = `0.5.0`, matches `CHANGELOG.md` top entry, `README.md`, all 6 `pmo-config/*.json` | done — `DOCTOR-005` PASS |
| Working tree clean before this report | to be confirmed after this round's commit |
| Two prior process violations still resolved (unaffected by Round 2) | yes — `reports/process-violation.md` unchanged |
| No push happened without explicit per-push confirmation | true — nothing has been pushed this round |
| **Remote CI green on this merge SHA** | **not applicable yet — branch has not been pushed** |
| **PR opened and human-approved** | **not applicable yet — no PR exists for this round** |

The last two items are outside what a local session can complete: they
require the owner to explicitly decide to push `remediation/9plus-v2` and
open a PR, which is a separate confirmation from everything done so far (see
`AGENTS.md` rule 10: push and PR review require explicit human action, not
inferred from "continue the phases").

## Bugs found and fixed this round (not present at the 8.3 baseline)

1. PowerShell `@($x).Count` reports 1 instead of 0 for a `$null` value bound
   through a function parameter, and separately for a never-initialized
   script variable — both fixed with explicit `[bool]$x` guards
   (`scripts/lib/release-validator.ps1`, `scripts/lib/workitem-validator.ps1`).
2. `RTM.json`'s required/optional status was hardcoded Strict-only instead of
   config-driven via the artifact matrix (`scripts/lib/artifact-policy.ps1`).
3. `new-project.ps1 -Mode Lite` generated a work item defaulting to Standard
   mode with a design ref Lite never creates, silently escalating every fresh
   Lite project.
4. `<PROJECT-CODE>` was never substituted in generated `RELEASE.md` /
   `RAID-log.md` / `decision-log.md` / `RTM.json`.
5. `DOCTOR-004`'s legacy-pattern scan flagged a skill correctly *prohibiting*
   over-logging as if it contained the anti-pattern itself (negation-blind
   substring match) — now negation-aware.
6. Config-mutation tests only asserted a non-zero exit code, not the specific
   rule that should have fired — a mutation could vacuously "pass" the test
   by breaking something unrelated. All 4 scenarios now assert rule_id.

## Score

No formal §9 rubric recomputation was requested for this round; the honest
qualitative read is that every P0 identified against the 8.3 baseline is
closed, with real regression control (golden master, rule-id-asserted
mutation tests) rather than test-count claims. The two outstanding
governance items (remote CI, PR review) are structurally blocked on a push
decision the owner has not yet made — the framework's own rule (`AGENTS.md`
#10) is what's holding that back, not an oversight.

## Sign-off

Working tree and this report reflect the state immediately after merging
Track A and Track B. No commit, tag, or push has happened yet for this
Phase 8 work — pending explicit confirmation.
