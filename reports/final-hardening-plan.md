# Final Hardening Plan (Round 3 — one short round, then stop)

Date: 2026-07-12
Trigger: GPT-5.6 independent review of merged `0.5.0` (`main` @ `9bb18b8`) —
verdict 8.4/10. **Every finding was re-verified against the actual source in
this repo before entering this plan; all confirmed real.** Target: close the
5 named gaps, re-verify, publish a real 0.5.x acceptance — then stop.
Explicitly out of scope: new Cores/skills/artifacts, architecture refactors,
cross-platform, web UI (reviewer and owner agree the architecture phase is done).

## Verified findings (with exact locations)

### F1 — Lite Release work-item bypass (most severe)
`scripts/lib/workitem-validator.ps1:97`:
```powershell
if (-not (Test-Path ... $DeliveryPath) -and $ProjectText -notmatch '(?i)work item') {
```
Any occurrence of the substring "work item" anywhere in PROJECT.md satisfies
the check; `$workItems` stays empty, so every Release completion check
(RELEASE-STATUS-001 / TEST-EVIDENCE-001 / REVIEW-001) silently skips.
A Lite project with the sentence "no work item needed" ships.

### F2 — Test Summary `pending` still releases
`scripts/lib/rtm-validator.ps1:14` (`Get-ReleaseRegistry`) collects only
`TEST-###` IDs — never reads the `Result` or `Evidence` columns. The
placeholder scanner doesn't catch it either (`Test-PlaceholderContent` for
.md is `<...>|TODO|TBD` — "pending" isn't in it; the *cell-level*
`Test-PlaceholderValue` does include "pending" but is never applied to Test
Summary rows). Confirmed live: our own Strict E2E passes at Release with all
three template TEST rows still `pending` and Evidence empty —
`tests/e2e/lib/fill-project.ps1` never touches Test Summary.

### F3 — RTM is row-by-row but not full-chain
`scripts/lib/rtm-validator.ps1:67-68`: evidence check is
`-notmatch '^DEC-\d{3}$' -or ($DecisionIds -contains ...)` — i.e. **any free
text that doesn't look like a DEC id passes** ("manual-proof", "finished").
`source_ref`, `design_ref` (file existence), and `status` are never checked.
The typed `Resolve-Reference` from P2.2 exists but is not called here.

### F4 — Lite evidence is unverifiable free text
`scripts/lib/source-validator.ps1:99`: `$requireDecisionEvidence = ($Mode -ne "Lite")`
disables the typed-reference resolution entirely for Lite approvals.
`scripts/lib/release-validator.ps1:231`: Lite work-item Evidence Ref only
checked non-empty. **Note: the original Round-2 plan (P2.2) already specified
"free text → WARN_BLOCKING at Lite" — this is an incomplete implementation,
not a new requirement.**

### F5 — GitHub Issues task source is documented but not implemented
`AGENTS.md` rule 7, skills, and templates all say DELIVERY.md *or* GitHub
Issues; `artifact-policy.json` unconditionally requires DELIVERY.md at
Standard/Strict Release and no `TASK-003`/github-path exists anywhere in
`scripts/` (grep = 0 hits). The Round-2 plan (P1.4) specified this and it was
never built. Docs and runtime are two different truths.

### F6 — Supporting gaps (reviewer's "not per plan" list, all confirmed)
- `result-writer.ps1` emits `{level, rule_id, message, blocking}` — plan
  called for `artifact`, `field`, `item_id` as well.
- `validation-rules.json` has 31 rules; runtime uses ~15 more that are absent
  (MODE-001/002/003, APPROVAL-003, RTM-002..007, QA-REVIEW-001,
  SECURITY-REVIEW-001, RELEASE-STATUS-001, RELEASE-SCOPE-001,
  TEST-EVIDENCE-001, REVIEW-001, DOCTOR-006, FIELD/SENTINEL).
- CI (`pmo-checks.yml`) runs `run-all-checks.ps1` bare: fault injection
  (`-TestChildScript`) and golden-master verify (`-VerifyGolden`) are never
  exercised in CI — the two strongest regression checks are opt-in only.
- `reports/current-acceptance.md` is still the **0.4.0** acceptance carrying
  the old 9.03 score while VERSION is 0.5.0, and README links to it as
  current. (Round2-final-gate honestly said no new score was computed — but
  the stale doc is still presented as current.)

## Work items

### H1 — Close the Lite work-item bypass *(fixes F1)*
**Decision needed (owner):** (a) parse a real Work Items table in PROJECT.md,
or (b) require DELIVERY.md for every Lite Release.
**Recommendation: (b)** — one work-item parser, no duplicate table contract;
one small file is not heavy for Lite (reviewer independently recommends the
same). Implementation: drop the `'(?i)work item'` escape hatch; artifact
policy gains `DELIVERY.md` under Lite/Release; update `context-map.json`
Lite `qa_release` (DELIVERY becomes required), Lite fixtures/examples, and
the Lite E2E. Negative test: Lite Release, no DELIVERY.md, PROJECT.md
containing the words "work item" → must FAIL.

### H2 — Test Summary must be passed + evidenced *(fixes F2)*
`Get-ReleaseRegistry` returns full rows. New checks at Release
(Standard+Strict): every Test Summary row referenced by release scope /
RTM must have `Result = passed` (config enum: `passed` only; `pending`,
`failed`, blank → FAIL `TEST-RESULT-001`) and an Evidence cell that resolves
via `Resolve-Reference` (FAIL `TEST-EVIDENCE-002`). A `skipped` result is
allowed only with a reason in Notes (config-driven allowlist, mirroring the
rollback-waiver pattern). Update: templates comment, examples
(STANDARD/STRICT already use `passed` + DEC-003 — verify), E2E filler must
set `passed` + evidence explicitly (it currently passes by accident).
Negative tests: pending row, failed row, passed-without-evidence.

### H3 — RTM full-chain resolution *(fixes F3)*
In `rtm-validator.ps1`, per row: `source_ref` must match the policy
source-ref regex (RTM-008); `design_ref` must resolve to an existing file
when it looks like a path (reuse `Get-DesignPathFromRef`, RTM-009);
`status` must be in the evidence-status enum (RTM-010); `evidence_ref` goes
through `Resolve-Reference` — typed and resolvable, free text FAILs
(tighten RTM-005). Negative tests for each.

### H4 — Lightweight-but-typed Lite evidence *(fixes F4, completes P2.2)*
Lite approvals and Lite work-item evidence go through `Resolve-Reference`;
unrecognized/unresolvable → **WARN_BLOCKING** (exactly what P2.2 already
specified — Lite stays light in artifacts, not in truthfulness; `ISSUE:123`,
`FILE:...`, `TEST-###`, `DEC-###` all remain one short string). Verify the
existing `valid-lite-*` fixtures use typed refs (they already use ISSUE-123
— confirm the resolver accepts the bare `ISSUE-\d+` legacy form or migrate
fixtures to `ISSUE:` form; do not widen the resolver silently). Negative
test: `approved-by-chat` at Lite Release with `-FailOnWarning` → blocked.

### H5 — GitHub Issues: implement the minimal contract *(fixes F5)*
**Decision needed (owner):** implement vs delete the claim from docs.
**Recommendation: implement the minimal P1.4 version** — it's already
spec'd: when `PROJECT.md` declares `Task source: github` **and** names a
repository, `DELIVERY.md` becomes optional at Release and the validator
emits `TASK-003 WARN_NON_BLOCKING` ("GitHub state not verifiable offline").
H1's Lite-requires-DELIVERY rule then applies only to `task_source: file`
projects. If the owner prefers deletion instead: strip the claim from
AGENTS.md/CLAUDE.md/skills/templates in one commit. Either way docs ==
runtime at the end.

### H6 — Rule catalog + result schema + CI gate *(fixes F6)*
- Add every runtime rule id to `validation-rules.json` with severity +
  description; new doctor check `DOCTOR-007`: scan `scripts/**` for
  `Add-Result` rule ids and fail on any id missing from the catalog (and
  vice versa for dead catalog entries).
- Extend `Add-Result`/`result-writer.ps1` with optional `artifact`, `field`,
  `item_id` fields (default empty — additive, JSON output only grows keys).
  Golden master will change shape: one deliberate re-capture, reviewed.
- CI: `run-all-checks.ps1` gains `-VerifyGolden` pass-through to the fixture
  runner, and the workflow adds fault injection
  (`-TestChildScript tests/helpers/exit-1.ps1`) so both regression nets run
  on every push/PR.

### H7 — Honest acceptance for 0.5.x *(fixes the governance finding)*
Move `reports/current-acceptance.md` (the 0.4.0 report) to
`reports/archive/acceptance-0.4.0.md`. Write a new
`reports/current-acceptance.md` for this round: final SHA, the §9 rubric
actually computed with per-dimension justification, GPT-5.6's 8.4 recorded
as the round's opening baseline, remote CI run URL, PR link. README link
then points at a document that is true.

## Execution rules (unchanged from Round 2)
Branch `hardening/0.5.x` off `main`. Per-item: fix → fixtures/negatives →
golden-master re-capture *only* where behavior intentionally changed (diff
reviewed, not blind) → run-all-checks green → human diff review → local
commit. No push without explicit per-push confirmation. Never edit
`source/`-class dirs; never weaken a check to make a test pass; PS 5.1 only.
Suggested order: H1 → H2 → H3 → H4 → H5 → H6 → H7 (H6's schema change last
before H7 so goldens are re-captured once).

## Exit criteria
All 5 reviewer bypasses have negative tests that FAIL; docs == runtime on
task source; catalog complete + DOCTOR-007 green; CI runs golden + fault
injection; new acceptance published for the real SHA. Expected honest score
per reviewer's own rubric: **9.0–9.2**. Then stop — no further rounds
without a new external finding.
