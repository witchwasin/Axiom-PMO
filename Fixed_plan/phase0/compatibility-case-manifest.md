# Phase 0 — Compatibility-case manifest (v0.1, §8.3)

**Status:** FIRST PASS. Extracted from the two golden runners. This is the *index* of the
invocation-tuple space; the authoritative list is the source (`scripts/run-validation-tests.ps1`
`$cases` + `tests/golden/capture-examples.ps1` `$cmds`), which Phase 1's differential harness
will parse rather than re-hand-maintain.

## Invocation tuple (CR-006)

```text
entrypoint + project + mode + gate + format + FailOnWarning + optional flags
+ cwd + environment + git state + platform
```

## Entrypoints

| Entrypoint | Format | Optional flags that change behavior |
|---|---|---|
| `scripts/validate-project.ps1` | Text / Json | `-FailOnWarning`, `-ScopeDiffBase`+`-ScopeDiffHead` (+`-ScopeDiffRepoRoot`), `-ReleaseDiffBase`+`-ReleaseDiffHead`, `-Release` |
| `scripts/pmo-doctor.ps1` | Text | `-SkillRootOverride`, `-TemplateRootOverride` |
| `scripts/verify-execution-result.ps1` | Json/Text | (execution-contract + adversarial-review entrypoint) |
| `tests/golden/capture-examples.ps1` | Json | 4 example cases |

## Case dimensions (from `$cases`, 153 validator cases + 5 doctor cases pre-expansion)

| Dimension | Values present |
|---|---|
| Mode | Lite, Standard, Strict |
| Gate | Draft, Scope, Design, Handoff, Release |
| Format | Json (all golden cases) |
| FailOnWarning | present on WARN-sensitive cases |
| Project | `tests/fixtures/*`, `examples/*` |
| Platform | pwsh 7 (local capture); Windows 5.1 retired (DEC-026 Phase 0) |

## Golden-corpus coverage status (FINAL — Phase 0 complete)

| Metric | Value |
|---|---|
| Catalog rules | 138 → **136** after drop-5.1 (DOCTOR-010/011 retired) |
| Rules covered in goldens (start) | 63 / 138 (46%) |
| Rules covered in goldens (final) | **135 / 136 real firing rules (~99%)** |
| Remaining | `GENERAL-001` only — a fallback default (`Add-Result`'s `$RuleId` default), never a distinct firing rule |

### How coverage was raised (46% → ~99%)

| Capture | Golden files | Rules added |
|---|---|---|
| OPTIONAL-TRACKS @ 3 gates | `optional-tracks-{design,handoff,release}.txt` | CHANGE-001/002, TEST-DESIGN-001/002, EXT-001..004, RESEARCH-002..007, DPROV-002..007 |
| `pmo-doctor` baseline | `doctor-baseline.txt` | DOCTOR-* (14) + PERMISSION-* (8) + TABLE-001 |
| SCOPE-DIFF fixtures | `scope-diff-00{1..5}.txt` | SCOPE-DIFF-001..005 |
| EXEC fixtures | `exec-00{1..8}.txt` | EXEC-001..008 |
| AREV fixtures | `arev-00{1..7}.txt` | AREV-001..007 |
| Validator edge fixtures | `mode-002-research-001-dprov-001.txt`, `change-003.txt`, `vproof-001-002.txt` | MODE-002, RESEARCH-001, DPROV-001, CHANGE-003, VPROOF-001/002 |
| Release evidence fixture | `test-evidence-003.txt` | TEST-EVIDENCE-003 |
| Doctor legacy fixture | `doctor-legacy.txt` | DOCTOR-002, DOCTOR-004 |

### Non-numeric rule IDs (covered, but invisible to the `-\d{3}` regex)

`DOCTOR-EXAMPLE`, `DOCTOR-HOOK`, `DOCTOR-STRUCT` fire from `pmo-doctor.ps1` and are
present in `doctor-baseline.txt`, but carry no numeric suffix so the coverage regex
misses them. Counted as covered here.

### Golden capture scripts (retained as reproducibility evidence)

All under `Fixed_plan/phase0/capture-*.ps1` — each replicates the fixture machinery from
the corresponding `tests/helpers/*.ps1` verbatim, runs the real entrypoint, and stores
canonical (`Get-CanonicalGoldenText`) output with `<REPO_ROOT>` path normalization.

