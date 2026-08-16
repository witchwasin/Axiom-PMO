# Resume point — Phase 5 test porting

**Updated:** 2026-08-16, after adversarial-review-tests.ps1 landed and was
independently verified by Claude (see below). **tests/ porting is now
genuinely 100% complete.** A full independent file-sweep (every `.ps1` under
`tests/helpers/` and `tests/e2e/`, not just the ones on a prior "what's left"
list) confirms it — see "Final sweep" below.
**Branch:** `feat/migrate-interpreter-to-node-ts`
**Last commit:** `d2c9f9c` — "test(phase-5): port adversarial-review tests (AREV-001..007), finish tests/"
**Working tree:** clean, nothing uncommitted, nothing pushed to origin.

## Overall migration status: ~100% of tests/ (24,181-line original scope)

| Surface | Status |
|---|---|
| All validators (63 differential probe cases) | ✅ 100% — differential-green vs PowerShell |
| All 13 orchestrators | ✅ 100% — ported, verified |
| Tests porting | ✅ 100% — every `.ps1` under `tests/helpers/` and `tests/e2e/` accounted for |

### Final sweep (independent, per the rule below)

Ran `find tests -name "*.ps1"` fresh (not from memory of a prior list): 28
files total.

- 26 map to one of the 24 existing `.test.ts` files (`tests/e2e/{lite,standard,strict,handoff}.ps1`
  + `tests/e2e/lib/fill-project.ps1` all fold into `src/tools/e2e.test.ts`;
  `tests/helpers/scope-diff-tests.ps1` maps to both `src/tools/scope-diff.test.ts`
  and `src/rules/scope-diff-matcher.test.ts`). Confirmed via each file's own
  `// Ported from tests/helpers/...` header comment, not assumed.
- 2 are correctly *not* ported, matching Phase 0's own disposition
  (`Fixed_plan/phase0/tests-disposition.md:46-47`, both marked `retire`):
  `tests/helpers/exit-1.ps1` (1 line, literally `exit 1` — a child-process
  fixture other suites spawn to test exit-code propagation, not a test
  itself) and `tests/golden/capture-examples.ps1` (75 lines — the
  golden-capture tool for the PowerShell *reference* side; its job ends at
  Phase 9, not before). 75 + 1 = 76 lines, matching the "2 files, 76 lines"
  retire bucket from the original Phase 0 count exactly.

No third omission found this round.

### FreeBuFF AI sessions (verified by Claude, all claims checked and matched)

| Commit | File | Assertions | PS reference |
|---|---|---:|---|
| `feb6930` | plugin-package-tests.ps1 | 41 | PASS=41 ✅ |
| `629d335` | hook-advisory-tests.ps1 | 59 | PASS=59 ✅ |
| `4908675` | visual-proof-tests.ps1 | 12 | PASS=12 ✅ |
| `69afd27` | release-evidence-tests.ps1 | 26 | PASS=26 ✅ |
| `81a2910` | scope-diff-tests.ps1 | 45 | PASS=45 ✅ |
| `203b200` | e2e (lite/standard/strict/handoff) | 4 scenarios | 4/4 exit 0 ✅ |
| `3f2d027` | execution-contract-tests.ps1 | 127 (73 cases) | PASS=127 ✅ |
| `d2c9f9c` | adversarial-review-tests.ps1 | 47 (24 cases) | PASS=47 ✅ |

Independently rebuilt (`npx tsc`) and reran everything after every handoff:
all 7 probes green (63/63) and the full unit suite matches exactly each time
(109/0/1 → 182/0/1 → **206/0/1** after adversarial-review landed). Several
claims were spot-checked directly in the diffs, not just taken on narrative:
the e2e Strict-filler regex capture-group fix (`203b200`), the
execution-contract port's use of real in-process entrypoints (`3f2d027`), and
— the most substantial one — `d2c9f9c`'s rewrite of
`testExternallyObservedReviewBinding` in
`src/exec/adversarial-review-validator.ts` (+141 lines). Before this commit
the `externally-observed` provenance tier was an unconditional fail-closed
stub; the new code implements the full PS reference logic line-for-line
(confirmed against `scripts/lib/adversarial-review-validator.ps1:145-280`):
check-run lookup → head_sha/status match → check_suite → workflow-run *path*
attribution (with the `@ref`-suffix-stripping normalization the PS comments
call out as a "round-2 compatibility finding") → Binding 1 (real artifact
digest present in the check run's own API-attested output, not a
self-reported claim) → Binding 2 (pinned workflow's git-blob bytes at the
exact commit under verification hash-match the policy-pinned digest). All
real, all matching the reference, not a superficial port.

Minor note (not a correctness issue): `3f2d027`'s commit message said "~2,900
lines" for the port; actual is 3,335 (1,684 src + 1,651 compiled dist). The
load-bearing numbers (127 assertions, 73 cases) were exact. `d2c9f9c`'s
numbers were exact on first check.

## tests/ porting: complete

Every `.ps1` file under `tests/helpers/` and `tests/e2e/` now has a
corresponding `.test.ts` port, or is correctly retired per Phase 0's own
disposition. See "Final sweep" above for the file-by-file accounting. Phase 5
as a whole is complete — next would be the full Phase 6 gate (see
"still-open questions" below for what has to be resolved first).

**Keep doing the independent full-sweep check before any future "done"
claim** for whatever comes next (Phase 6 and beyond) — it caught a real
omission once already and cost nothing to repeat.

## How to continue (the pattern that's been working)

For each file:
1. Read the full `.ps1` file first — several files in this batch turned out to need *more* than a mechanical translation (m2-m3/m4-m6 were reclassified from "re-derive from golden" to full native ports after reading them; plugin-install-spike surfaced a real missing feature). Don't assume `tests-disposition.md`'s original bucket is final — verify by reading.
2. Check whether the underlying TS functions/validators it exercises are already ported (they almost certainly are at this point — everything under `src/rules/`, `src/exec/`, `src/tools/` is done).
3. Port as a native `node:test` file calling the TS functions **in-process**, not by spawning subprocesses — this has been the pattern throughout (`src/rules/*.test.ts`, `src/tools/*.test.ts`, etc.), except where the test's actual subject is subprocess/CLI behavior itself (plugin-install-spike's Node CLI case, ci-check-evidence-live's `gh` calls).
4. **Always verify against the PS reference before committing** — run the original `.ps1` file with `<pinned-pwsh-path>` and confirm the pass count matches. This caught real discrepancies every time it was skipped-then-checked.
5. Run the full regression before committing: all 7 probes (`node dist/probe/*.js`) + full unit suite (`node --test dist/**/*.test.js`). `AXIOM_PWSH=<pinned-pwsh-path>` must be exported in the **same** shell command as the run — it does not persist across separate tool calls.
6. Commit with a message that states what was verified (PS pass count, probe regression status), not just what was written.

## Known environment facts (don't rediscover these)

- Portable `pwsh` 7.6.4 lives at `<pinned-pwsh-path>` (not on PATH). No `brew install` needed.
- `export AXIOM_PWSH=<pinned-pwsh-path>` before any command that spawns PowerShell or the differential probes.
- Full differential probe list: `differential-probe.js` (38), `execution-probe.js` (3), `marker-probe.js` (16), `marker-io-probe.js` (6), `doctor-probe.js` (58 rows), `stateful-probe.js` (6), `setup-probe.js` (4) = **63 total, all in `dist/probe/`**.
- Build with `npx tsc` before running anything from `dist/`.

## Real gaps found and fixed while porting (not just translation work)

1. `scripts/lib/framework-checkout.ps1` (FRAMEWORK-001 guard) had never been ported at all — `pmo-doctor.ts` had no protection against running outside a real checkout. Fixed in `c6edb7d`: added `src/core/framework-checkout.ts`, wired into `runPmoDoctor`.
2. `src/probe/stateful-probe.ts` had a real (not random) flake: it creates two independent git fixture repos and byte-compares their exported contracts, which embed `base_sha` (a git commit hash). `git commit` timestamps are second-resolution, so a >=1s skew between the two `git commit` calls under load produces genuinely different SHAs from identical tree content. Fixed in `91382ad` by pinning `GIT_AUTHOR_DATE`/`GIT_COMMITTER_DATE` for the fixture commits. If a similarly-shaped flake shows up elsewhere, check for this same pattern (two independently-created git fixtures being byte-compared) before assuming it's unrelated noise.

## Still-open questions (not blocking test porting, but will matter before Phase 6)

- **CLI rewire (`cli/axiom.mjs`)** — ambiguous whether wiring it to call the TS library in-process belongs to Phase 5 (needs *a* way to run Node-only per the exit criteria) or is exclusively Phase 8 (cutover) territory. Not resolved. `plugin-install-spike.test.ts`'s Node-CLI case deliberately tests the *current* (still-spawns-pwsh) behavior as-is rather than assuming an answer.
- **Named security reviewer (CR-017)** — still no name assigned. Needed before Phase 8.
- Phase 6 full gate, Phase 7 (settling window N), Phase 8 (cutover), Phase 9 (deletion) are all untouched — correctly, per the hard gates in `master-plan.md` v3.
