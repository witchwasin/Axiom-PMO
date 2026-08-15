# Phase 0 — Function/module-level dependency graph (machine-derived)

**Status:** DERIVED — all numbers below are produced by the reproduction commands
listed, not estimated. Scope: `scripts/*.ps1` (top-level orchestrators) **and**
`scripts/lib/*.ps1` (inter-module dot-sources); `tests/*.ps1` are excluded from fan-in
so the sequencing reflects production wiring, not test harness reach.

Reproduce fan-in (per lib module, excluding the module's own file):

```bash
for lib in scripts/lib/*.ps1; do name=$(basename "$lib"); \
  n=$(grep -lE "$name" scripts/*.ps1 scripts/lib/*.ps1 | grep -v "^$lib$" | wc -l); \
  printf '%s %s\n' "$name" "$n"; done | sort -k2 -rn
```

Reproduce the hub count:

```bash
grep -oE 'lib/[a-z0-9-]+\.ps1' scripts/validate-project.ps1 | sort -u | wc -l   # 24
```

This graph — not the Group A/B/C table in `master-plan.md` §6.3 — sequences Phases 2–4
(CR-012 / G2).

## Hub: validate-project.ps1 (root orchestrator)

Dot-sources **24 lib modules** (the full validator surface):

```
validate-project.ps1
├── config-loader · markdown-table-parser · reference-resolver · result-writer
├── mode-resolver · execution-path-validator · artifact-policy · approval-validator
├── source-validator · workitem-validator · rtm-validator · release-validator
├── handoff-validator · design-system-validator · visual-proof-validator
├── change-control-validator · path-containment · artifact-hash
├── externalization-validator · research-validator · design-provider-validator
└── scope-diff-matcher · scope-diff-git-adapter · scope-diff-validator
```

## Fan-in (scripts scope; how many files depend on the module)

| Module | Fan-in | Sequencing meaning |
|---|---:|---|
| pwsh-host.ps1 | 11 | **retire** (drop-5.1) — removed first, no TS order dependency |
| scope-diff-matcher.ps1 | 7 | port early — shared matcher |
| scope-diff-git-adapter.ps1 | 7 | port early (after matcher) — git-backed |
| markdown-table-parser.ps1 | 7 | port early — table parsing shared |
| config-loader.ps1 | 7 | port first — everything reads policy |
| handoff-validator.ps1 | 6 | composite — depends on many leaves |
| framework-checkout.ps1 | 6 | port early — clean-room helper |
| execution-contract-schema.ps1 | 6 | port early — EXEC schema shape |
| ordinal-sort.ps1 | 5 | port early — deterministic collation (golden-critical) |
| mode-resolver.ps1 | 5 | port early — mode/gate branching |
| execution-contract-validator.ps1 | 5 | composite — depends on schema+git |
| result-writer.ps1 | 4 | port early — output/exit contract |
| reference-resolver.ps1 | 4 | port early — FILE: ref resolution |
| markdown-files.ps1 | 4 | port early — markdown discovery |
| execution-contract-git.ps1 | 4 | port after schema — git adapter |
| execution-contract-evidence.ps1 | 3 | composite |
| design-provider-validator.ps1 | 3 | leaf validator |
| artifact-hash.ps1 | 3 | port early — F8 digest contract |
| visual-proof-validator.ps1 | 2 | leaf validator |
| scope-diff-validator.ps1 | 2 | **Phases 2–4 start group** |
| execution-path-validator.ps1 | 2 | core |
| remaining leaf validators | 1 | workitem, source, rtm, release, research, path-containment, marker-block, golden-normalizer, externalization, design-system, change-control, artifact-policy, approval, adversarial-review |

## Dependency-ordered port sequence (derived, for Phases 2–4)

1. **Leaf, no deps:** `ordinal-sort`, `artifact-hash`, `markdown-files`,
   `markdown-table-parser`, `path-containment`, `config-loader`, `golden-normalizer`,
   `result-writer`.
2. **Core (depends on 1):** `mode-resolver`, `artifact-policy`, `reference-resolver`,
   `execution-path-validator`, `scope-diff-matcher`, `scope-diff-git-adapter`,
   `framework-checkout`, `execution-contract-schema`.
3. **Leaf validators (depends on 1+2):** `scope-diff-validator` (start group),
   `source-validator`, `workitem-validator`, `rtm-validator`, `release-validator`,
   `approval-validator`, `change-control-validator`, `externalization-validator`,
   `research-validator`, `design-provider-validator`, `design-system-validator`,
   `visual-proof-validator`.
4. **Composite validators (largest, depends on 1+2+3):** `handoff-validator`,
   `execution-contract-validator`, `execution-contract-git`, `execution-contract-evidence`,
   `adversarial-review-validator`.
5. **Orchestrators/tools (last):** `validate-project.ps1`, `pmo-doctor.ps1`,
   `pmo-status.ps1`, `assess-handoff.ps1`, `verify-execution-result.ps1`, the digest
   tools, `ci-profile.ps1`, `run-ci-suite.ps1`, `run-all-checks.ps1`, stateful commands
   (`new-project`, `setup-claude-integration`, `export-execution-contract`,
   `run-execution-command`), release/hook/plugin tools.
6. **Retire:** `pwsh-host.ps1` (drop-5.1). **Temporary oracle:** `run-validation-tests.ps1`.

`scope-diff-validator` remains the Phases 2–4 start group (self-contained, git-backed,
~5 rules) — consistent with the plan's recommendation; the graph confirms it depends
only on `scope-diff-matcher` + `scope-diff-git-adapter` (both layer 2).
