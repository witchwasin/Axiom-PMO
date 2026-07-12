# Upgrade Manifest (Round 2)

Tracks phase status for `reports/upgrade-plan-9plus.md` (v2 unified).
Rule: a phase is "done" only after human diff review + local commit.

| Phase | Scope | Status |
|---|---|---|
| 0 | Baseline, branch `remediation/9plus-v2`, reports | done |
| 1 | Validator integrity (P1.1 not_required · P1.2 source/warn taxonomy · P1.3 effective mode · P1.4 artifact matrix) | done — ready to commit |
| 2 | RTM.json + reference resolver + approval integrity | done — committed (a7a8428, c838082) |
| 3 | Release enforcement (completion, QA/security, rollback) | done — committed (8837945) |
| 4 | Modular refactor (golden-master control) | done — ready to commit |
| 5 | Testing upgrade (20+ negatives, generator E2E, PSScriptAnalyzer, CI gate) | pending |
| 6 | Context map JSON + skills alignment | done in Track B worktree (`remediation/9plus-v2-codex`) — ready to merge at Phase 8 |
| 7 | Governance/versioning (§7.4 branch protection: **deferred by owner 2026-07-12**) | 7.4/7.5 done in Track B; 7.1-7.3 pending in Track A |
| 8 | Final Acceptance Gate | pending |
