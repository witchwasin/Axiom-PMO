# Resume point — Phase 5 test porting

**Paused:** 2026-08-16, by user request ("พักก่อน... commit และ note ไว้ก่อน")
**Branch:** `feat/migrate-interpreter-to-node-ts`
**Last commit:** `91382ad` — "test(phase-5): port clean-room tests, fix real stateful-probe flake"
**Working tree:** clean, nothing uncommitted, nothing pushed to origin.

## Overall migration status: ~77% (18,620 / 24,181 lines)

| Surface | Status |
|---|---|
| All validators (63 differential probe cases) | ✅ 100% — differential-green vs PowerShell |
| All 13 orchestrators | ✅ 100% — ported, verified |
| Tests porting | 🔶 4,075 / 9,636 lines (42%) |

## What's left — 5,561 lines across 7 file groups

In recommended order (smallest/most-tractable first, biggest last):

| Order | File | Lines | Notes |
|---|---|---:|---|
| 1 | `tests/helpers/plugin-package-tests.ps1` | 364 | Process/packaging test, similar shape to the already-ported plugin-install-spike |
| 2 | `tests/helpers/hook-advisory-tests.ps1` | 437 | Tests the optional scope-advisory hook (separate from the main validator chain) |
| 3 | `tests/helpers/visual-proof-tests.ps1` | 427 | VPROOF-001/002 have goldens already; this file goes deeper |
| 4 | `tests/helpers/release-evidence-tests.ps1` | 448 | TEST-EVIDENCE-003 has a golden already; git-state manipulation |
| 5 | `tests/helpers/scope-diff-tests.ps1` | 504 | scope-diff-validator already ported + probe-verified; should be fast |
| 6 | `tests/e2e/*.ps1` (5 files: handoff, lite, standard, strict, lib/fill-project) | 568 | Stateful E2E — generator → fill → validate. Needs §8.6 fresh-tree care like setup-integration/clean-room did |
| 7 | **`tests/helpers/execution-contract-tests.ps1`** | **2,060** | **Largest file in the whole migration.** Do this as its own dedicated session/block, not squeezed in — it alone is bigger than everything else on this list combined |

## How to continue (the pattern that's been working)

For each file:
1. Read the full `.ps1` file first — several files in this batch turned out to need *more* than a mechanical translation (m2-m3/m4-m6 were reclassified from "re-derive from golden" to full native ports after reading them; plugin-install-spike surfaced a real missing feature). Don't assume `tests-disposition.md`'s original bucket is final — verify by reading.
2. Check whether the underlying TS functions/validators it exercises are already ported (they almost certainly are at this point — everything under `src/rules/`, `src/exec/`, `src/tools/` is done).
3. Port as a native `node:test` file calling the TS functions **in-process**, not by spawning subprocesses — this has been the pattern throughout (`src/rules/*.test.ts`, `src/tools/*.test.ts`, etc.), except where the test's actual subject is subprocess/CLI behavior itself (plugin-install-spike's Node CLI case, ci-check-evidence-live's `gh` calls).
4. **Always verify against the PS reference before committing** — run the original `.ps1` file with `/Users/arm/tools/pwsh/pwsh` and confirm the pass count matches. This caught real discrepancies every time it was skipped-then-checked.
5. Run the full regression before committing: all 7 probes (`node dist/probe/*.js`) + full unit suite (`node --test dist/**/*.test.js`). `AXIOM_PWSH=/Users/arm/tools/pwsh/pwsh` must be exported in the **same** shell command as the run — it does not persist across separate tool calls.
6. Commit with a message that states what was verified (PS pass count, probe regression status), not just what was written.

## Known environment facts (don't rediscover these)

- Portable `pwsh` 7.6.4 lives at `/Users/arm/tools/pwsh/pwsh` (not on PATH). No `brew install` needed.
- `export AXIOM_PWSH=/Users/arm/tools/pwsh/pwsh` before any command that spawns PowerShell or the differential probes.
- Full differential probe list: `differential-probe.js` (38), `execution-probe.js` (3), `marker-probe.js` (16), `marker-io-probe.js` (6), `doctor-probe.js` (58 rows), `stateful-probe.js` (6), `setup-probe.js` (4) = **63 total, all in `dist/probe/`**.
- Build with `npx tsc` before running anything from `dist/`.

## Real gaps found and fixed while porting (not just translation work)

1. `scripts/lib/framework-checkout.ps1` (FRAMEWORK-001 guard) had never been ported at all — `pmo-doctor.ts` had no protection against running outside a real checkout. Fixed in `c6edb7d`: added `src/core/framework-checkout.ts`, wired into `runPmoDoctor`.
2. `src/probe/stateful-probe.ts` had a real (not random) flake: it creates two independent git fixture repos and byte-compares their exported contracts, which embed `base_sha` (a git commit hash). `git commit` timestamps are second-resolution, so a >=1s skew between the two `git commit` calls under load produces genuinely different SHAs from identical tree content. Fixed in `91382ad` by pinning `GIT_AUTHOR_DATE`/`GIT_COMMITTER_DATE` for the fixture commits. If a similarly-shaped flake shows up elsewhere, check for this same pattern (two independently-created git fixtures being byte-compared) before assuming it's unrelated noise.

## Still-open questions (not blocking test porting, but will matter before Phase 6)

- **CLI rewire (`cli/axiom.mjs`)** — ambiguous whether wiring it to call the TS library in-process belongs to Phase 5 (needs *a* way to run Node-only per the exit criteria) or is exclusively Phase 8 (cutover) territory. Not resolved. `plugin-install-spike.test.ts`'s Node-CLI case deliberately tests the *current* (still-spawns-pwsh) behavior as-is rather than assuming an answer.
- **Named security reviewer (CR-017)** — still no name assigned. Needed before Phase 8.
- Phase 6 full gate, Phase 7 (settling window N), Phase 8 (cutover), Phase 9 (deletion) are all untouched — correctly, per the hard gates in `master-plan.md` v3.
