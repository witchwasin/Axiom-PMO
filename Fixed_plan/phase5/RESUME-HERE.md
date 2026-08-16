# Resume point — Phase 5 test porting

**Updated:** 2026-08-16, after FreeBuFF AI's session (verified by Claude — see below)
**Branch:** `feat/migrate-interpreter-to-node-ts`
**Last commit:** `203b200` — "test(phase-5): port e2e suite (lite/standard/strict/handoff)"
**Working tree:** clean, nothing uncommitted, nothing pushed to origin.

## Overall migration status: ~88% (21,368 / 24,181 lines)

| Surface | Status |
|---|---|
| All validators (63 differential probe cases) | ✅ 100% — differential-green vs PowerShell |
| All 13 orchestrators | ✅ 100% — ported, verified |
| Tests porting | 🔶 6,823 / 9,636 lines (71%) |

### FreeBuFF AI session (verified by Claude, all claims checked and matched)

| Commit | File | Assertions | PS reference |
|---|---|---:|---|
| `feb6930` | plugin-package-tests.ps1 | 41 | PASS=41 ✅ |
| `629d335` | hook-advisory-tests.ps1 | 59 | PASS=59 ✅ |
| `4908675` | visual-proof-tests.ps1 | 12 | PASS=12 ✅ |
| `69afd27` | release-evidence-tests.ps1 | 26 | PASS=26 ✅ |
| `81a2910` | scope-diff-tests.ps1 | 45 | PASS=45 ✅ |
| `203b200` | e2e (lite/standard/strict/handoff) | 4 scenarios | 4/4 exit 0 ✅ |

Independently rebuilt (`npx tsc`) and reran everything after the handoff: all 7
probes green (63/63), full unit suite **109 pass / 0 fail / 1 pre-existing
skip** — matches FreeBuFF's reported numbers exactly. One specific bug-fix
claim (Strict e2e filler dropped a regex capture-group wrap on the escaped QA
row, `$1` resolved empty, wiped the row) was checked directly in the `203b200`
diff and is real, not just narrative.

One gap from that session: `RESUME-HERE.md` itself wasn't updated before
pausing (FreeBuFF flagged this as a pending action). This edit is that update.

## What's left — 2,060 lines, one file

| File | Lines | Notes |
|---|---:|---|
| **`tests/helpers/execution-contract-tests.ps1`** | **2,060** | **Largest file in the whole migration** — bigger than everything ported in the FreeBuFF session combined. Do as its own dedicated session/block. EXEC-*/AREV-* rules already have goldens (Phase 0) and `execution-probe.js` (3 cases) already differentially verifies the core verify-execution-result path — this file goes much deeper (real subprocess execution, disposable git fixtures, adversarial cases per its own header comment) |

Once this lands, tests/ porting is done and Phase 5 as a whole is complete —
next would be the full Phase 6 gate (see "still-open questions" below for what
has to be resolved first).

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
