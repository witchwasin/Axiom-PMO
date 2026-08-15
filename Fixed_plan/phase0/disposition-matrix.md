# Phase 0 — 89-file `.ps1` disposition matrix (first pass)

**Status:** FIRST PASS. Disposition + role + direct lib dependencies are machine-derived
from `git ls-files '*.ps1'`, `wc -l`, and the dot-source graph (`. (Join-Path $PSScriptRoot
"lib/*.ps1")`). Callers / filesystem side effects / retirement criterion are populated to
the extent determinable statically; full side-effect finalization is gated on the pwsh
test run (see baseline-fingerprint.md "Blockers").

Disposition legend: `port` (reimplement in TS) · `replace` (superseded by a Node surface)
· `temporary-oracle` (kept only until final differential proof) · `retire-with-evidence`
(deleted with a recorded reason).

## scripts/lib/ — 35 modules (9,277 lines)

| File | Lines | Disposition | Role / notes |
|---|---:|---|---|
| handoff-validator.ps1 | 1283 | port | largest domain validator; handoff gate rules |
| execution-contract-validator.ps1 | 727 | port | EXEC-* firing conditions |
| adversarial-review-validator.ps1 | 570 | port | AREV-* firing conditions |
| marker-block.ps1 | 559 | port | mutates user-owned agent files (stateful) |
| visual-proof-validator.ps1 | 480 | port | VPROOF-* firing conditions |
| execution-contract-evidence.ps1 | 456 | port | EXEC evidence binding |
| execution-contract-schema.ps1 | 443 | port | EXEC schema/shape |
| research-validator.ps1 | 437 | port | RESEARCH-* firing conditions |
| design-provider-validator.ps1 | 410 | port | DPROV-* firing conditions |
| release-validator.ps1 | 346 | port | RELEASE-* firing conditions |
| rtm-validator.ps1 | 308 | port | RTM-* firing conditions |
| result-writer.ps1 | 238 | port | Text/JSON output + exit code contract |
| externalization-validator.ps1 | 234 | port | EXT-* firing conditions |
| source-validator.ps1 | 226 | port | SOURCE-* firing conditions |
| scope-diff-matcher.ps1 | 221 | port | scope-diff matching (shared) |
| execution-contract-git.ps1 | 216 | port | git adapter for EXEC evidence |
| design-system-validator.ps1 | 202 | port | DESIGN-* firing conditions |
| scope-diff-validator.ps1 | 178 | port | SCOPE-DIFF-* (Phases 2–4 start here) |
| config-loader.ps1 | 173 | port | BOM/no-BOM tolerant JSON loader |
| artifact-policy.ps1 | 150 | port | policy-driven artifact requirements |
| golden-normalizer.ps1 | 144 | port | canonical comparator (BOM/EOL/path ignores) |
| pwsh-host.ps1 | 141 | **retire-with-evidence** | host detection; no Node equivalent needed |
| scope-diff-git-adapter.ps1 | 130 | port | git adapter for scope-diff |
| approval-validator.ps1 | 113 | port | APPROVAL-* firing conditions |
| workitem-validator.ps1 | 108 | port | WORKITEM-* firing conditions |
| markdown-table-parser.ps1 | 102 | port | markdown table parsing |
| change-control-validator.ps1 | 96 | port | CHANGE-* firing conditions |
| reference-resolver.ps1 | 92 | port | FILE: ref resolution + containment |
| markdown-files.ps1 | 87 | port | markdown file discovery |
| framework-checkout.ps1 | 86 | port | clean-room checkout helper |
| execution-path-validator.ps1 | 79 | port | execution_path gate |
| mode-resolver.ps1 | 77 | port | mode/gate resolution |
| path-containment.ps1 | 71 | port | symlink/junction-safe containment (security) |
| artifact-hash.ps1 | 60 | port | canonical SHA-256 (F8 frozen contract) |
| ordinal-sort.ps1 | 34 | port | deterministic collation (golden-critical) |

## scripts/ — 25 orchestrators + tools (5,268 lines)

| File | Lines | Disposition | Role / notes |
|---|---:|---|---|
| pmo-doctor.ps1 | 758 | port | DOCTOR-* rule registry + emitters (needs typed rule-ID registry) |
| assess-handoff.ps1 | 472 | port | handoff assessment entrypoint |
| run-validation-tests.ps1 | 424 | temporary-oracle | golden capture/verify runner → replaced by differential harness |
| aggregate-diagnostics.ps1 | 318 | port | learning registry aggregation |
| setup-claude-integration.ps1 | 303 | port | stateful `setup` (mutates files) |
| ci-profile.ps1 | 273 | port | CI risk classifier (single source of truth) |
| pmo-status.ps1 | 255 | port | `axiom status` verb |
| export-execution-contract.ps1 | 226 | port | stateful `export` |
| validate-project.ps1 | 219 | port | **root orchestrator** — dot-sources 23 lib modules |
| new-project.ps1 | 212 | port | stateful `init` |
| run-execution-command.ps1 | 201 | port | stateful `run` (arbitrary child exit propagation) |
| hook-scope-advisory.ps1 | 190 | port | advisory hook (report-only) |
| capture-plugin-load-evidence.ps1 | 177 | port | plugin load evidence |
| prepare-public-release.ps1 | 170 | port | release tooling |
| demo.ps1 | 154 | port | demo entrypoint |
| run-all-checks.ps1 | 153 | port | CI orchestrator |
| check-public-hygiene.ps1 | 151 | port | owns 15 rule IDs with no catalog entry |
| verify-execution-result.ps1 | 119 | port | EXEC verification entrypoint |
| build-plugin-package.ps1 | 117 | port | plugin packaging |
| run-ci-suite.ps1 | 98 | port | CI suite runner |
| design-provider-digest.ps1 | 81 | port | DPROV digest (F8) |
| update-source-snapshot.ps1 | 73 | port | source snapshot |
| handoff-digest.ps1 | 60 | port | handoff digest (F8) |
| visual-proof-digest.ps1 | 34 | port | VPROOF digest (F8) |
| measure-context.ps1 | 30 | port | context measurement |

## tests/ — 29 files (9,636 lines)

| Group | Count | Disposition | Notes |
|---|---:|---|---|
| tests/golden/capture-examples.ps1 | 1 | temporary-oracle | golden capture tool (reference side) |
| tests/helpers/*.ps1 | 23 | port-or-rederive | assertion-style PS tests; **not** an independent oracle |
| tests/e2e/*.ps1 (+lib) | 5 | port-or-rederive | end-to-end; re-derive from goldens where possible |

**Open follow-up (not decided here):** the plan requires an explicit port-vs-rederive
decision per test file. That decision is deferred to the Phase 2–5 window once goldens
reach ~100% (which needs pwsh).
