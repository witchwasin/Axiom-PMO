# Resume point — Phase 5 test porting

**Updated:** 2026-08-16, after execution-contract-tests.ps1 landed (verified by
Claude — see below). **Correction included:** the previous version of this
file claimed Phase 5 would be complete after execution-contract-tests.ps1.
That was wrong — `adversarial-review-tests.ps1` (753 lines) was dropped from
the "what's left" list by Claude's own mistake in an earlier edit of this
file and was never assigned to anyone. It is still unported. See below.
**Branch:** `feat/migrate-interpreter-to-node-ts`
**Last commit:** `3f2d027` — "test(phase-5): port execution-contract tests (M5), finishing tests/ porting"
**Working tree:** clean, nothing uncommitted, nothing pushed to origin.

## Overall migration status: ~97% (23,428 / 24,181 lines)

| Surface | Status |
|---|---|
| All validators (63 differential probe cases) | ✅ 100% — differential-green vs PowerShell |
| All 13 orchestrators | ✅ 100% — ported, verified |
| Tests porting | 🔶 8,883 / 9,636 lines (92%) |

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

Independently rebuilt (`npx tsc`) and reran everything after both handoffs: all
7 probes green (63/63) and the full unit suite matches exactly each time
(109/0/1 after the first session, **182/0/1** after execution-contract landed).
Two specific claims were spot-checked directly in the diffs, not just taken on
narrative: the e2e Strict-filler regex capture-group fix (`203b200`), and the
execution-contract port's use of the real in-process entrypoints rather than
internal rule calls (`3f2d027`). Both real.

Minor note (not a correctness issue): `3f2d027`'s commit message said "~2,900
lines" for the port; actual is 3,335 (1,684 src + 1,651 compiled dist). The
load-bearing numbers (127 assertions, 73 cases) were exact.

## What's left — 753 lines, one file (Claude's omission, now corrected)

| File | Lines | Notes |
|---|---:|---|
| **`tests/helpers/adversarial-review-tests.ps1`** | **753** | AREV-001..007 already have goldens (Phase 0) and the adversarial-review-validator itself is ported + differentially verified (part of the 63 probe cases, from commit `f12097b`). This file is the same *shape* of gap execution-contract-tests.ps1 was: a deep behavior test (real subprocess execution, disposable git fixtures, adversarial cases against the AREV threat model) that goes well beyond what the goldens and the general validator probe cover. Same pattern as execution-contract.test.ts should apply directly. |

Once this lands, tests/ porting is genuinely done (100%) and Phase 5 as a
whole is complete — next would be the full Phase 6 gate (see "still-open
questions" below for what has to be resolved first). **Do not declare Phase 5
complete again without independently listing every file in `tests/helpers/`
and `tests/e2e/` and confirming each has a corresponding `.test.ts` — that
cross-check is what caught this omission and should be repeated before the
next "done" claim.**

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
