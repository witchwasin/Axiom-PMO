# Phase 0/5 — `tests/` disposition (29 files, 9,636 lines)

**Author:** Claude (Opus 5), produced in parallel with Phase 2-4 work — analysis only, no
source files touched.
**Status:** FIRST PASS. Classified from each file's header comment plus a content skim
(not a full line-by-line read of all 9,636 lines). Closes the open follow-up left in
`disposition-matrix.md`'s `## tests/` section, which deferred this to "the Phase 2-5
window" with a placeholder grouping (`port-or-rederive` for all 28 non-capture files).

Per master-plan.md v3 §6.3 (F3): "A test suite ported by the same agent that ports the
implementation is not an independent oracle." This disposition does not resolve that
concern — it only replaces the group-level placeholder with a per-file decision, so
whoever does the Phase 5 port work has a concrete list instead of "decide later."

Disposition legend: `retire` (superseded, no Node equivalent needed) · `re-derive`
(the existing golden-master + differential-harness proof already covers what this file
asserts, so a bespoke Node test is largely redundant) · `port` (tests something a
golden/output comparison cannot capture — process behavior, packaging, live
integration, git-state manipulation, or business-logic invariants — needs a genuine
Node-native test).

---

## Summary

| Disposition | Files | Lines |
|---|---:|---:|
| `retire` | 2 | 76 |
| `re-derive` (golden covers the bulk of it) | 2 | 734 |
| `port` | 25 | 8,826 |
| **Total** | **29** | **9,636** |

`port` is not "translate line by line" — several of these files test properties no
output-diff can see (packaging structure, live GitHub API calls, filesystem mutation
safety, git-state sequences). Line count is a rough proxy for effort, not a promise of
1:1 translation size.

---

## Per-file disposition

### `retire` (2 files, 76 lines)

| File | Lines | Why |
|---|---:|---|
| `tests/golden/capture-examples.ps1` | 75 | Golden-capture tool for the *reference* (PowerShell) side. Its job ends when PowerShell is deleted (Phase 9). Already correctly marked `temporary-oracle` in `disposition-matrix.md`; restated here as `retire` for the tests/ pass specifically. |
| `tests/helpers/exit-1.ps1` | 1 | Not a test — a one-line child-process fixture (`exit 1`) used by other suites to test exit-code propagation. Trivially replaced by an inline `process.exit(1)` helper wherever the Node test suite needs it; no dedicated file required. |

### `re-derive` — golden/differential harness covers the bulk (2 files, 734 lines)

| File | Lines | Why |
|---|---:|---|
| `tests/helpers/m2-m3-tests.ps1` | 160 | Pattern: call `validate-project.ps1` via a `Invoke-ValidationJson` helper against a fixture, assert specific JSON fields. This is exactly what the golden-master + differential harness already proves for any fixture with a captured golden. Re-derive the assertions from the golden content; only port a case if it asserts something the golden's structure doesn't already encode (e.g. a transient/process-level property). |
| `tests/helpers/m4-m6-tests.ps1` | 574 | Same `Invoke-ValidationJson` pattern as above, larger case count. Same treatment — re-derive from golden where the assertion is "this fixture produces this JSON," port only the residual cases that check something beyond fixture-in/JSON-out. |

Both files should be re-read case-by-case before Phase 5 execution to confirm none of
their individual cases smuggle in a non-output assertion (e.g. a side-effect check) —
this pass only established the dominant pattern from the file header and structure, not
a case-by-case audit.

### `port` (25 files, 8,826 lines)

**Mandated by the new plan itself, not just carried over:**

| File | Lines | Why |
|---|---:|---|
| `tests/helpers/config-mutation-tests.ps1` | 336 | Directly implements CR-003/CR-006's requirement: "config-mutation tests must prove that every load-bearing policy key still drives the Node implementation." Not optional — the new plan requires this class of test to exist regardless of what the old suite did. |

**Stateful/mutating-command coverage (CR-015):**

| File | Lines | Why |
|---|---:|---|
| `tests/helpers/setup-integration-tests.ps1` | 710 | The only Milestone-6 code that writes to a file the *user* owns; header says the suite is "written from the position that it is guilty until proven innocent." This is precisely the fresh-tree, before/after-manifest testing §8.6 already calls for — highest-priority port in this list. |
| `tests/e2e/handoff.ps1`, `lite.ps1`, `standard.ps1`, `strict.ps1` (4 files) | 260 | Full generator → fill → validate flows exercising `new-project.ps1` (stateful, CR-015) end to end. |
| `tests/e2e/lib/fill-project.ps1` | 308 | Not a standalone test — shared fixture infrastructure the four e2e files above depend on. Ports alongside them as a shared helper module, not independently. |

**Large behavior suites where golden coverage exists but is shallower than the suite (golden proves the shape is right for a handful of cases; these files carry the edge-case depth):**

| File | Lines | Golden now covers | Note |
|---|---:|---|---|
| `tests/helpers/execution-contract-tests.ps1` | 2,060 | EXEC-001..008 (8 goldens, Phase 0) | Largest single file in the entire migration — larger than `handoff-validator.ps1` itself. Exercises real subprocesses over disposable git repos; do not assume the 8 rule-level goldens make this redundant, they were captured from single representative scenarios each. |
| `tests/helpers/adversarial-review-tests.ps1` | 753 | AREV-001..007 (7 goldens, Phase 0) | Same relationship — goldens are the minimum-viable trigger for each rule, this file almost certainly covers more combinations. |
| `tests/helpers/scope-diff-tests.ps1` | 504 | SCOPE-DIFF-001..005 (5 goldens, Phase 0) | Manipulates real git state across many scenarios (case-sensitivity, exclude precedence — already partly reflected in the 8/8 unit tests the scope-diff port added, per commit `2431e81`). Cross-check before assuming full duplication. |
| `tests/helpers/release-evidence-tests.ps1` | 448 | TEST-EVIDENCE-003 (1 golden, Phase 0) | Reconciles passed-test evidence against git ground truth across git-state variations a single golden cannot enumerate. |
| `tests/helpers/visual-proof-tests.ps1` | 427 | VPROOF-001/002 (2 goldens, Phase 0) | Same relationship. |

**Process/packaging/integration — golden-diff cannot see these by construction:**

| File | Lines | Why golden can't cover it |
|---|---:|---|
| `tests/helpers/hook-advisory-tests.ps1` | 437 | Tests the optional scope-advisory *hook*, a separate integration surface from the validator's own diagnostic output. |
| `tests/helpers/plugin-package-tests.ps1` | 364 | Tests the packaging *contract* (what's in the plugin bundle), not any validator output. |
| `tests/helpers/clean-room-tests.ps1` | 361 | Tests "does installing this break what's already there" — a property of the install process, not of any single command's stdout. |
| `tests/helpers/plugin-install-spike-tests.ps1` | 349 | Same family as `plugin-package-tests.ps1` — install-time behavior. |
| `tests/helpers/ci-check-evidence-live-tests.ps1` | 321 | Explicitly a *live* integration test against a real external adapter (GitHub API surface); needs a Node-native mock/stub strategy, not a golden. |
| `tests/helpers/diagnostics-contract-tests.ps1` | 219 | Validates the diagnostics JSON shape against `pmo-config/diagnostics-schema.json`. Consider merging this into the Phase 6 schema-validation gate (§8.4 already requires schema validation as "a hard, independent gate") rather than porting it as a freestanding legacy-style suite — avoids maintaining the same assertion twice. |
| `tests/helpers/learning-registry-tests.ps1` | 178 | Tests `aggregate-diagnostics.ps1`, which is not ported yet at all (isolated-directory event aggregation — a filesystem-state property). |
| `tests/helpers/ci-profile-tests.ps1` | 165 | Tests `ci-profile.ps1`'s path→profile classification logic directly (dot-sourced, not subprocess) — must be ported alongside `ci-profile.ps1` itself, which is not yet ported. |
| `tests/helpers/doctor-markdown-tests.ps1` | 115 | Markdown-parsing edge cases specific to `markdown-files.ps1`; the assertions are about parser behavior, not full validator output. |
| `tests/helpers/status-tests.ps1` | 106 | Tests the `axiom status` verb directly; that orchestrator isn't ported yet. |
| `tests/helpers/demo-smoke-tests.ps1` | 80 | Smoke-tests the 3-minute demo script end to end. Small, low-risk port. |

**Business-logic invariants (not just "does output match," but "does the *algorithm's shape* hold"):**

| File | Lines | Why |
|---|---:|---|
| `tests/helpers/handoff-assessment-tests.ps1` | 171 | Tests `assess-handoff.ps1`'s readiness-scoring algorithm — explicitly that the score "does NOT collapse into one boolean" and "cannot be inflated past what the evidence supports." This is an invariant about the algorithm's behavior across inputs, not a single fixture's output. |

**Needs adaptation, not pure translation:**

| File | Lines | Why |
|---|---:|---|
| `tests/helpers/line-ending-tests.ps1` | 154 | The underlying concern (CRLF vs LF correctness across checkouts) is still real in Node — cross-platform line-ending bugs don't disappear with the runtime change. The *test mechanism* (PowerShell-specific host/encoding assumptions) needs to change, but the property under test should not be dropped. |

---

## Open items for whoever executes Phase 5

1. The two `re-derive` files (`m2-m3-tests.ps1`, `m4-m6-tests.ps1`) need a case-by-case
   read before their bulk is discarded — this pass only identified the dominant pattern,
   not audited every individual case block.
2. `diagnostics-contract-tests.ps1` — decide whether it becomes a standalone Node suite
   or gets folded into the Phase 6 schema-validation gate; recorded here as a choice, not
   decided.
3. For the five "golden covers a handful, suite covers more" files (execution-contract,
   adversarial-review, scope-diff, release-evidence, visual-proof — 4,192 lines
   combined), confirm during port whether the suite's extra scenarios reveal cases that
   deserve their *own* golden capture (raising Phase 0's coverage further) rather than
   only becoming Node-native unit tests with no PowerShell-side comparison at all.
4. This file does not re-litigate whether `tests/` should be ported by the same agent
   that ports the implementation (F3's independent-oracle concern) — it only inventories
   what exists. That decision remains open per master-plan.md v3 §6.3.
