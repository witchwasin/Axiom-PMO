# Upgrade Manifest (Round 2)

Tracks phase status for `reports/upgrade-plan-9plus.md` (v2 unified).
Rule: a phase is "done" only after human diff review + local commit.

| Phase | Scope | Status |
|---|---|---|
| 0 | Baseline, branch `remediation/9plus-v2`, reports | in progress |
| 1 | Validator integrity (P1.1 not_required · P1.2 source/warn taxonomy · P1.3 effective mode · P1.4 artifact matrix) | pending |
| 2 | RTM.json + reference resolver + approval integrity | pending |
| 3 | Release enforcement (completion, QA/security, rollback) | pending |
| 4 | Modular refactor (golden-master control) | pending |
| 5 | Testing upgrade (20+ negatives, generator E2E, PSScriptAnalyzer, CI gate) | pending |
| 6 | Context map JSON + skills alignment | pending |
| 7 | Governance/versioning (§7.4 branch protection: **deferred by owner 2026-07-12**) | pending |
| 8 | Final Acceptance Gate | pending |
