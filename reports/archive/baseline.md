# Baseline Report

> **ARCHIVED** — this is a Phase-0 snapshot from before the `remediation-plan.md` (v3)
> work. Superseded by `reports/remediation-plan.md` § Verified-findings appendix and
> `reports/current-acceptance.md`. Kept for historical reference only.

Date: 2026-07-10  
Repo: `Axiom-PMO`  
Baseline version: `0.3.0-lite-ai-guardrails`

## Git Status

- Branch: `main`
- Remote tracking: `origin/main`
- Working tree at baseline: clean
- Latest commit at baseline: `cf28023 Add versioned mode examples`
- Known local warning: Git cannot access `<home>/.config/git/ignore`; this does not affect repository validation.

## Active Skills

- Active skill folders before patch: 43
- Target active skill folders after patch: 7

## Legacy Path / Wording Scan

Legacy wording scan count before patch: 42 matches.

Patterns scanned:

- `SystemFlow`
- `UserFlow`
- `UseCase`
- `Wireframe`
- `TaskBreakdown`
- `Logging every`
- `log every`
- `ทุก Action`
- `ทุก action`

Notes:

- Some matches are acceptable legacy mapping references in user-facing docs.
- Active runtime must remove legacy-path dependence and route through the new 7 skill groups.

## Baseline Doctor And Test Suite

Commands run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/pmo-doctor.ps1 -RepoPath <local-repo>
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-validation-tests.ps1 -RepoPath <local-repo>
```

Results:

- Doctor: PASS=25 WARN=0 FAIL=0
- Validation fixtures: PASS=10 FAIL=0

## Core Context Size

Estimated context size from core files:

| File | Chars | Words | Lines |
|---|---:|---:|---:|
| `AGENTS.md` | 8126 | 1119 | 181 |
| `CLAUDE.md` | 5820 | 778 | 159 |
| `CONTEXT-ROUTER.md` | 3322 | 518 | 80 |
| `pmo-config/context-map.yaml` | 1967 | 191 | 104 |

Total estimated words: 2606

## Baseline Assessment

The repository is a strong pilot and near-stable Standard-mode framework. The biggest remaining architectural gap is that active skills are still numerous and legacy-named, while the current lightweight PMO architecture expects a smaller runtime surface.

