# Upgrade Manifest (Round 2)

Tracks phase status for `reports/upgrade-plan-9plus.md` (v2 unified).
Rule: a phase is "done" only after human diff review + local commit.

| Phase | Scope | Status |
|---|---|---|
| 0 | Baseline, branch `remediation/9plus-v2`, reports | done |
| 1 | Validator integrity (P1.1 not_required · P1.2 source/warn taxonomy · P1.3 effective mode · P1.4 artifact matrix) | done — committed (ce1f9e7) |
| 2 | RTM.json + reference resolver + approval integrity | done — committed (a7a8428, c838082) |
| 3 | Release enforcement (completion, QA/security, rollback) | done — committed (8837945) |
| 4 | Modular refactor (golden-master control) | done — committed (75ff32a) |
| 5 | Testing upgrade (E2E rebuilt without example copy-over, new negatives, 3rd config-mutation, CI gate wiring) | done — committed (2027eed). P5.3 PSScriptAnalyzer explicitly skipped by owner 2026-07-12 (not installed on this machine) |
| 6 | Context map JSON + skills alignment | done — committed on Track B (187d3c3), merged into Track A (015aed0) |
| 7 | Governance/versioning (§7.4 branch protection: **deferred 2026-07-12**) | 7.1 verified correct (no action needed) · 7.3 done — committed (66f0fe8) · 7.2 VERSION bump to 0.5.0 done as part of Phase 8 below · 7.4/7.5 done in Track B (187d3c3) |
| 8 | Final Acceptance Gate — see `reports/round2-final-gate.md` | done — merge (015aed0), VERSION 0.5.0, config-mutation now rule-id-asserted, `run-all-checks.ps1` green. Ready to commit. Remote CI / PR review NOT done (nothing pushed — separate future decision). |
