# Fixed plan / update_fixed.md

Append-only implementing-agent report. One dated entry per work session.
Never rewrite or delete an earlier entry. The reviewing agent responds in
`Fixed plan/feeback.md`; where `feeback.md` and this file or the MasterPlan
disagree, `feeback.md` wins.

---

## 2026-08-13 — M0 spike executed: config encoded as axiomguard rules; no new contradiction found; reachability not expressible through the pinned API; FAIL recommended

### Done

- **M0 spike encoding** — `Fixed plan/m0-spike/m0-policy.axiom.yml` —
  hand-written from `pmo-config/policy.json` (approval_checkpoints,
  exempt_modes, waivers, enums) and `pmo-config/artifact-policy.json`
  (artifact_matrix, Release gate). 25 rules / 56 Z3 constraints.
  Evidence: spike run printed `Loaded m0-policy.axiom.yml: 25 rules, 56 Z3
  constraints`.
- **M0 spike runner** — `Fixed plan/m0-spike/m0_spike.py` — experiments A–D.
  Reads `policy.json` with `encoding="utf-8-sig"` (the file is UTF-8 **with
  BOM**, as the plan predicted).
- **Pinned engine installed in a local venv OUTSIDE the repo** —
  `~/.local/opt/axiomguard-m0-venv` — `axiomguard==0.7.2`, `z3 5.0.0`,
  Python 3.9.6. Nothing from the venv is inside the repository.
- **Ran the spike** — command:
  `~/.local/opt/axiomguard-m0-venv/bin/python Fixed plan/m0-spike/m0_spike.py`
  → full output saved in `Fixed plan/m0-spike/m0-spike-output.txt`.

#### M0 spike result (what was encoded, what the solver said, what was new)

| Experiment | What | Result |
|---|---|---|
| A | Current config facts as scenarios (legit Lite / Standard / Strict Release) | 3/3 **SAT** — consistent |
| B | Deliberately contradictory scenarios (missing approvals, waiver-mode mismatch, strict trigger in Lite, artifact explicitly missing) | 7/7 **UNSAT** — engine *does* catch contradictions when they exist, with the right rule names in the message set |
| C | Role-matrix expressiveness probe — scope approver role `"Project Owner"` (orphan string, not in any closed set) asserted as a claim | **SAT** — the engine is blind to role strings; no rule references the role relation |
| D | Reachability enumeration: 160 Release scenarios (mode × scope/design/release approval × test_waiver × rollback_waiver × strict_trigger) | **6 SAT, 154 UNSAT, 0 holes** — no combination reaches Release with a required approval missing; all 6 SAT paths are policy-legitimate |

**What was new:** nothing. Every UNSAT reason maps to a rule the 114-rule
catalog already enforces (APPROVAL-001/002, STRICT-001, RELEASE-001,
TEST-SUMMARY-001, ...), and the 6 permitted paths are exactly the config's
declared intent. The two §4.1 findings surfaced as **missing invariants, not
contradictions**: the engine could not see either of them.

**Recommendation: FAIL** (per §6: FAIL = "it only restates what the 114 rules
already check"). The §4.1 question the spike was built to test yields nothing
real for the current config.

### Not done (and why)

- **`enums.roles` / orphan `"Project Owner"`** — not implemented. §7.2
  requires a Human Owner decision first (see below). Did not guess.
- **Waiver asymmetry record** — not implemented. Requires a Human Owner
  decision (see below).
- **M1 / M2 (adapter, compiler, DOCTOR-0xx, fixtures, formal-verification.md)**
  — not started. They are `*(M0 PASS only)*` and M0 reports FAIL; per §6 the
  L4 track stops here pending the Human Owner's confirmation of the decline.
- **M3 / M4** — not started. §7.2 orders M0 first: "Then stop and wait for
  review." The plan's own ordering says do not skip ahead.
- **`decision-log.md` "L4 — declined" entry** — deliberately NOT written.
  §11.5 asks the Human Owner to confirm that recording the decline and moving
  to M4 is the accepted outcome, and §0.6 forbids committing without explicit
  instruction. Awaiting confirmation.
- **No commit was made.** All new files are untracked.

### Found that contradicts the plan

- §4.1 claimed reachability over the product space is "the one class of
  question hand-written rules cannot answer by construction" →
  **the pinned engine cannot answer it either through its public API.**
  `verify_structured` is assumption-based: it checks one ground scenario per
  call and returns UNSAT/SAT; the product-space search has to be enumerated by
  the caller. The reachability answer in experiment D was produced by my
  enumeration loop — the solver only adjudicated each scenario, and each
  adjudication restated the config's own rules. Evidence: `m0-spike-output.txt`
  section D. (This is the same API-shape conclusion the plan drew about
  "who encodes" — it extends to "who searches".)
- §4.1's premise that the reachability question "yields anything real" →
  **for the current, post-DEC-023 config it yields zero holes.** The config is
  internally consistent; the SAT set is exactly the declared intent.
  Evidence: section D, `SAT scenarios that reach Release with a required
  approval missing: 0`.
- **New observation (matters for M2 if it ever runs):**
  `VerificationResult.violated_rules` is **imprecise attribution** — it lists
  every rule whose relation touches a contradicted claim, not the actual
  blockers. See experiment B1: all 14 rules are listed, including artifact
  rules for modes that were never asserted. Only `contradicted_claims` (unsat
  core indices) is trustworthy. A DOCTOR-0xx must not present `violated_rules`
  as the proof trace.
- **Absence is invisible:** asserting no artifact claim for a Standard Release
  returns SAT even though RELEASE.md is required — only an explicit
  `artifact_release=missing` claim trips it. The engine proves contradictions,
  not absences (consistent with §5.1's scope, recorded here so nobody assumes
  otherwise later).

### Needs a Human Owner decision

1. **`"Project Owner"` (`pmo-config/policy.json`, Scope Approved allowed
   roles) — typo for `"Project Manager"`, or a real distinct role?**
   It appears exactly once in the whole repository; everywhere else uses
   `"Project Manager"`. Options: (a) rename to `"Project Manager"` and add a
   closed `enums.roles`; (b) keep it as a real role and include it in the
   enum. My recommendation: (a) — the single occurrence and the DEC-023
   pattern both point to a typo, but per §7.2 I did not change anything
   without your call.
2. **Waiver asymmetry — intentional or defect?** `test_waiver.allowed_modes =
   ["Standard"]` while `rollback_waiver.allowed_modes = ["Lite"]`. Options:
   (a) intentional — record a one-line reason in the config or its doc; (b)
   defect — align the modes. My read: plausibly intentional (Lite requires
   almost no test artifacts, so a test waiver there is meaningless; Standard
   is where test waivers have effect) — I recommend (a) with the reason
   stated, but it is your call.
3. **M0 reports FAIL. Confirm that recording `L4 — declined` in
   `decision-log.md` (the same way npm and marketplace were declined) and
   moving on to M4 is the accepted outcome (§11.5)?** I have not written the
   entry yet.

### Verification run

- `~/.local/opt/axiomguard-m0-venv/bin/python Fixed plan/m0-spike/m0_spike.py`
  → `Loaded m0-policy.axiom.yml: 25 rules, 56 Z3 constraints`; A: 3 SAT;
  B: 7 UNSAT; C1: SAT; D: 160 scenarios → 6 SAT / 154 UNSAT / 0 holes.
  Full output: `Fixed plan/m0-spike/m0-spike-output.txt`.
- `~/.local/opt/powershell/pwsh -NoProfile scripts/pmo-doctor.ps1` →
  `Summary: PASS=59 WARN=0 FAIL=0`
- `~/.local/opt/powershell/pwsh -NoProfile scripts/check-public-hygiene.ps1`
  → `Summary: PASS=1 FAIL=0`
- `~/.local/opt/powershell/pwsh -NoProfile scripts/run-validation-tests.ps1`
  → `Summary: PASS=158 FAIL=0`

Working-protocol notes for the reviewer: `Fixed plan/feeback.md` was read at
session start — it does not exist yet (first review round pending). No file
under `scripts/` was touched this session, so `docs/architecture/
powershell-portability.md` was not required reading yet (§7.5 applies to M1/M2
work). No commits made; new files are `Fixed plan/update_fixed.md`,
`Fixed plan/m0-spike/m0-policy.axiom.yml`, `Fixed plan/m0-spike/m0_spike.py`,
`Fixed plan/m0-spike/m0-spike-output.txt` — all untracked.

---

## 2026-08-13 — Round 1 feedback executed: policy fixes (enums.roles + waiver alignment), DEC-024 L4 declined, M4 begun (EXEC-005 stale-evidence reconciliation)

`Fixed plan/feeback.md` was read at session start, before touching anything.
All three Human Owner decisions were applied as ordered. No commit was made.

### Done

1. **`enums.roles` added + orphan `"Project Owner"` renamed** —
   `pmo-config/policy.json`. `approval_roles."Scope Approved"` is now
   `["Product Owner", "Project Manager"]`; a closed `enums.roles` list
   (7 entries) sits alongside `enums.modes`/`enums.gates`, enumerating every
   role string used anywhere in `approval_roles`. Evidence: cross-checked with
   a script — every `approval_roles` value is a member of `enums.roles`
   (`roles outside enum: NONE`). The file's UTF-8 BOM is preserved (verified
   byte-level `ef bb bf`) so the spike's encoding gotcha does not resurface.
   No fixture, golden, or validator references `"Project Owner"`
   (repo-wide search: only `pmo-config/policy.json` + the Fixed plan files),
   and the approval validator reads `approval_roles.$GateName` dynamically,
   so nothing else needed to change.
2. **Waiver asymmetry fixed** — `pmo-config/policy.json`: both
   `test_waiver.allowed_modes` and `rollback_waiver.allowed_modes` are now
   `["Lite", "Standard"]`. Strict still has no waiver of either kind
   (unchanged, as ordered).
3. **`decision-log.md` `DEC-024` — `L4 — declined`** — same evidentiary
   standard as the npm/marketplace declines (commit `7d2393b`): cites the
   spike location `Fixed plan/m0-spike/`, the Experiment A–D results, frames
   the two findings as missing invariants the config now needs (fixed directly
   in `policy.json`, not by Z3), and records the decline as **reversible**.
4. **M4 begun** — analysis + first increment, see below.

### M4 first increment — EXEC-005 stale-evidence reconciliation

**Gap analysis (recorded before implementing):** L2 is substantially stronger
than MasterPlan §6's M4 text assumes. M5/M8 already shipped most of "an agent
report cannot pass the gate against contradicting git ground truth":
`EXEC-004` (scope), `EXEC-006` (git authority), `EXEC-007` (authority
claims), `EXEC-008` (changed_files reconciled with the observed diff in both
directions), and `EXEC-005` (test evidence verified for real, with
provenance tiers and the human-vouch mechanism). The release-path Test
Summary check (`TEST-EVIDENCE-002`/`TEST-RESULT-001`) verifies evidence
*resolves* but has no git context by architecture (`validate-project.ps1`
only sees git when `-ScopeDiffBase/-ScopeDiffHead` are supplied).

**The one deterministic gap that remained, and is now closed:** a
`junit-artifact` evidence file is checked for integrity (hash/XML/zero
failures) but was never reconciled with the git diff. A valid junit report
that predates the verified `base..head` range cannot be the output of a run
of the changed code, and the diagnostic now says so:

- `scripts/lib/execution-contract-validator.ps1` — when a verified
  `junit-artifact` is **not** among the observed changed files (case-sensitive
  `-cnotcontains`, same discipline as EXEC-004/008) and no human vouch
  applies, the EXEC-005 FAIL reason now leads with: *"The evidence file
  '<path>' was not changed within the verified commit range, so it cannot be
  the output of a test run of the code under verification — a report that
  predates the work cannot prove the changed code passes."*
- **A valid human vouch still wins** (escape hatch unchanged): a vouched,
  out-of-range artifact passes exactly as before. The check sharpens *why*
  unpromoted evidence fails; it is not a second gate. Existing positive test
  `junit real pass, human-vouched` (junit committed before export, vouch
  present) still passes.
- `tests/helpers/execution-contract-tests.ps1` — two new cases: (negative)
  valid junit outside the diff, no vouch → EXEC-005 with the stale-evidence
  reason; (positive control) junit generated inside the range, no vouch →
  EXEC-005 for provenance only, no stale claim.
- `docs/rules/EXEC-005.md` — new section documenting the git reconciliation
  and the open vouch-override question.

### Not done (and why)

- **M1 / M2 (L4 track)** — closed per feeback: "M0 is FAIL; that track is
  closed per §6 unless a future feeback entry reopens it." Not started.
- **M3** — not started; M4 comes first per the plan's ordering.
- **`RELEASE-001` suggestion text and `templates/RELEASE.md`** — the catalog
  suggestion *"A waiver is only valid for Lite content-only changes"* and the
  template line *"Lite may replace this table with a waiver"* are now
  stale/under-inclusive after the waiver fix. Fixing the catalog string
  changes the content of ~14 goldens, which feeback's decision 2 explicitly
  flags as a slow-down-and-report signal, so I did **not** resolve it
  unilaterally — reported under Needs decision.
- **`Fixed plan/m0-spike/`** — untouched (kept as evidence for DEC-024, as
  ordered). Its `.axiom.yml` still encodes the pre-fix waivers and the orphan
  role; that is a record of what the config was at spike time.
- **No commit made.** All changes remain in the working tree.

### Found that contradicts the plan

- MasterPlan §6 M4's premise that "claimed test files actually changed,
  actually ran" is a large open gap → **most of it is already closed by
  M5/M8** (EXEC-004/006/007/008 + EXEC-005 provenance/vouch). The remaining
  deterministic gap was junit evidence never reconciled with the diff;
  closed above. The plan text overestimates the remaining work.
- **Junit freshness is only sound with the vouch override.** Requiring "junit
  must be in the diff" even when vouched breaks the documented escape hatch
  for evidence that legitimately lives outside the diff (gitignored CI
  artifacts) — and the existing positive fixture (`junit real pass,
  human-vouched`) has the junit outside the diff *by design*. So the check is
  implemented as a diagnostic sharpening, not a new gate. Whether to tighten
  it is a Human Owner/reviewer call, recorded below.

### Needs a Human Owner decision

1. **May a human vouch override stale junit evidence?** Today: yes (escape
   hatch preserved). Tightening to "stale junit fails even when vouched"
   would move the remaining *"stale report accepted by vouch"* case from
   accountability to enforcement, at the cost of the escape hatch and of
   changing the existing positive fixture's behavior. My recommendation:
   keep the override for now; enforce freshness through `ci-check`/
   `runner-exit-record` instead.
2. **`RELEASE-001` suggestion + `templates/RELEASE.md`** — both say rollback
   waivers are Lite-only; after the fix they are Lite **and** Standard.
   Updating the catalog string changes ~14 goldens (content, not waiver-mode
   fields). Fix, or leave and record the waiver scope elsewhere?
3. **M4 next increments** (for a future session): (a) test-coverage
   reconciliation — junit test-case names vs changed test files — requires
   a documented test-file naming convention; (b) threading git ground truth
   into the release-path Test Summary check is an architectural change to
   `validate-project.ps1`. Which first?

### Verification run

- `~/.local/opt/powershell/pwsh -NoProfile scripts/pmo-doctor.ps1` →
  `Summary: PASS=59 WARN=0 FAIL=0`
- `~/.local/opt/powershell/pwsh -NoProfile scripts/check-public-hygiene.ps1`
  → `Summary: PASS=1 FAIL=0`
- `~/.local/opt/powershell/pwsh -NoProfile scripts/run-validation-tests.ps1`
  → `Summary: PASS=158 FAIL=0` (no golden drift from the config fixes — no
  fixture exercises the newly-allowed waiver modes or the renamed role)
- `~/.local/opt/powershell/pwsh -NoProfile -File
  tests/helpers/execution-contract-tests.ps1` → `Summary: PASS=127 FAIL=0`
  (123 pre-existing + 4 new M4 assertions). One failure was found and fixed
  during the run: `TrimStart('/', '\\')` in the new validator code crashed
  with "String must be exactly one character long" (a doubled backslash
  from the edit); corrected to `'\'` and re-ran to green.

Working-protocol notes for the reviewer: `docs/architecture/
powershell-portability.md` was read before touching `scripts/` (required by
§7.5 before M4's `scripts/` work; the stderr-as-error trap was already
handled by the existing `Invoke-NativeCapture` pattern and the test helper's
`Invoke-FixtureGit` guards, which I reused rather than re-invented). All
changes are in the working tree, uncommitted, on branch `Axiom-PMO-v.2.0`.

---

## 2026-08-13 — Round 2 feedback executed: RELEASE-001/template/golden wording fix; M4 second-increment gap analysis written (no code, awaiting Round 3)

`Fixed plan/feeback.md` was read at session start, before touching anything.
All three Round 2 decisions applied as ordered: vouch override confirmed as-is
(no code change), the Lite-only waiver wording fixed everywhere user-facing,
and the M4 second increment stopped at the gap-analysis note per decision 3.
No commit was made.

### Done

1. **`RELEASE-001` suggestion text fixed** — `pmo-config/validation-rules.json`:
   *"A waiver is only valid for Lite content-only changes"* → *"...for Lite or
   Standard content-only changes"*. The rule's `description` was **not**
   changed (see Found below).
2. **`templates/RELEASE.md` fixed** — *"Lite may replace this table with a
   waiver..."* → *"Lite or Standard may replace this table with a waiver..."*.
3. **Golden sweep: 14 files in `tests/golden/`, wording-only change in every
   one** — the single `RELEASE-001` suggestion line ("Lite" → "Lite or
   Standard") in each golden's JSON output. No other line, field, or content
   changed in any of them (verified with `git diff --stat`: each is exactly
   1 line, `2 +-`):
   - `approval-evidence-id-not-exist.txt`, `design-ref-file-missing.txt`,
     `invalid-broken-link.txt`, `invalid-fake-approval.txt`,
     `invalid-missing-rollback.txt`, `invalid-no-source-ref.txt`,
     `invalid-open-blocker.txt`, `invalid-unstructured-rollback.txt`,
     `not-required-in-rollback.txt`, `requirement-ref-not-exist.txt`,
     `review-stage-not-in-enum.txt`, `rollback-rows-empty.txt`,
     `status-not-in-enum.txt`, `workitem-mode-not-in-enum.txt`.
   - **No fixture in `tests/fixtures/` needed changes** — fixtures are input
     files and none contains the old wording (repo-wide search: the old
     string appears only in `validation-rules.json` and the goldens above,
     plus this report quoting it).
   - **No other wording variant left anywhere:** repo-wide search for
     "only valid for Lite" / "may replace this table with a waiver" now
     matches only the corrected text (and historical quotes in this file).
   - Golden edits were made by hand (one exact line per file) rather than a
     `-CaptureGolden` regeneration, so the diff is auditable per-file instead
     of a whole-directory rewrite with host-normalization noise. The
     pre-existing `approval-role-mismatch-standard-blocks-warning.txt`
     modification is the DEC-023 worktree change, not part of this round.

### M4 second increment — gap-analysis note only (NO code, per feeback decision 3)

**Target: thread git ground truth into the release-path Test Summary check**
(`TEST-EVIDENCE-002` / `TEST-RESULT-001`), so an agent report claiming all
tests pass cannot pass the gate against contradicting git ground truth.

**What `validate-project.ps1` sees today at the release path:**

- `Test-ReleaseArtifact` reads `RELEASE.md` **from the working tree as-is**
  (`Get-Content -Raw`, no git involvement). `Get-ReleaseRegistry` collects the
  Test Summary rows (`Get-TableRowsAfterHeading`); `Test-TestSummary`
  (`rtm-validator.ps1`) requires each `passed` row to carry evidence that
  **resolves** — and that is the whole check.
- `Resolve-Reference` for the `file` type is **pure filesystem**:
  `Test-Path -LiteralPath ... -PathType Leaf` against the working tree
  (`scripts/lib/reference-resolver.ps1:80`). It does not ask git anything.
- The **only** git context in `validate-project.ps1` today is the opt-in
  `-ScopeDiffBase` / `-ScopeDiffHead` pair feeding `Invoke-ScopeDiffCheck`
  (SCOPE-DIFF, M4.5) — which reconciles *changed files* against approved
  scope; it never looks at test evidence.

**Exactly what git context is missing at the Test Summary check:**

- A `passed` row with `Evidence: FILE:tests/e2e/payments.xml` resolves as long
  as the file exists on disk — and that is true in all three attack cases the
  M4 target names: (1) a report committed long before the work under review
  (stale evidence — the same defect class EXEC-005 now blocks on the
  execution path, but nothing blocks it on the release path); (2) a brand-new
  **uncommitted** file in the working tree (never part of any commit, proves
  nothing about what ran); (3) a file added to the tree after the gate ran
  (retro-added evidence). The release path has no notion of "the release's
  commit range" to compare against, because no contract on this path carries
  one (unlike the EXEC path's `EXECUTION-CONTRACT.json` `base_sha`/
  `head_sha`).

**Smallest change that closes it (design sketch for Round 3 review — NOT
implemented):**

- Mirror the existing SCOPE-DIFF opt-in shape: add
  `-ReleaseDiffBase` / `-ReleaseDiffHead` (and reuse `-ScopeDiffRepoRoot`
  semantics for the Action case) to `validate-project.ps1`, defaulting to
  absent so **every existing caller is byte-identical** — the same
  opt-in-discipline SCOPE-DIFF already established.
- When supplied, in `Test-TestSummary` (or a small sibling check invoked from
  `Test-ReleaseArtifact`): for each `passed` row whose evidence is a `file`
  reference that resolves, compare the file against
  `git diff --name-only <base>..<head>`; a resolved-but-absent file gets the
  same class of reason EXEC-005 now emits ("a report that predates this work
  cannot prove the new code passes"). A file present in the range passes
  normally. Untracked files (case 2) fall out of `git diff` naturally —
  they are absent from the range.
- Open design questions for Round 3 (deliberately not guessed): (a) severity
  asymmetry — mirror the repo's existing pattern (`APPROVAL-003`: WARN-block
  at Standard, FAIL at Strict)? (b) does the release path need a human-vouch
  escape hatch like EXEC-005's (Round 2 decision 1 kept vouch override on the
  execution path — the release path has no vouch concept at all today); (c)
  whether `FILE:` evidence outside the diff should warn on *tracked* files
  only, leaving gitignored CI artifacts to the EXEC tier where provenance is
  defined.

### Not done (and why)

- **M4 second increment code — deliberately not written.** Feeback decision 3
  orders the gap-analysis note only, reviewed in Round 3 before code, "the
  same gate M0 went through before M1/M2 were allowed to start."
- **M1 / M2 / M3** — not started (M4 in progress per the plan's ordering;
  L4 track closed).
- **No commit made.** All changes remain in the working tree.

### Found that contradicts the plan / out-of-scope observations (report only, not changed)

- **`RELEASE-001`'s `description` field is still under-inclusive** — "Release
  rollback plan is missing, unstructured, or has an invalid **Lite** waiver."
  Feeback decision 2 enumerated the suggestion string, the template line, and
  goldens/fixtures; the description was not in that list and no golden or
  output contains it (repo-wide search), so I left it unchanged and report it
  for Round 3 rather than resolve it unilaterally.
- **Internal comments in `scripts/lib/release-validator.ps1` and
  `rtm-validator.ps1` still say "the Lite rollback waiver"** (e.g. the
  `Test-TestSummary` header note and the P3.3 comment). Comments, not
  emitted output — left as-is, reported for completeness.
- The `.Raw` null-safety point the reviewer verified independently is
  confirmed here too: `Resolve-TestEvidenceEntries` (`execution-contract-
schema.ps1`) sets `Raw = $item` unconditionally for every entry; the
  `$match.Raw.PSObject.Properties["path"]` access in the EXEC-005 increment
  cannot see `$null`. No defect.

### Verification run

- `~/.local/opt/powershell/pwsh -NoProfile scripts/pmo-doctor.ps1` →
  `Summary: PASS=59 WARN=0 FAIL=0`
- `~/.local/opt/powershell/pwsh -NoProfile scripts/check-public-hygiene.ps1`
  → `Summary: PASS=1 FAIL=0`
- `~/.local/opt/powershell/pwsh -NoProfile scripts/run-validation-tests.ps1`
  → `Summary: PASS=158 FAIL=0` (all 14 updated goldens match — confirms the
  fixtures now produce the corrected suggestion string; zero other drift)
- `~/.local/opt/powershell/pwsh -NoProfile -File
  tests/helpers/execution-contract-tests.ps1` → `Summary: PASS=127 FAIL=0`
- `~/.local/opt/powershell/pwsh -NoProfile -File
  tests/golden/capture-examples.ps1 -RepoPath "$PWD" -Verify` →
  "All example golden outputs match."
- `scripts/run-all-checks.ps1` was attempted but exceeded the session's
  timeout (mutation + e2e stages are slow); every component suite above was
  run and reported individually instead — the same coverage, with per-suite
  numbers.

Working-protocol notes for the reviewer: `feeback.md` Round 2 was read first;
no `scripts/` file was touched this round (catalog/template/golden edits
only), so the §7.5 PowerShell portability reading did not re-apply. The next
round implements the M4 second increment only after this gap-analysis note is
approved in `feeback.md`.

---

## 2026-08-13 — Round 3 feedback executed: M4 second increment implemented (release-path Test Summary evidence reconciled against git ground truth, TEST-EVIDENCE-003)

`Fixed plan/feeback.md` Round 3 was read at session start, before touching
anything. All three design decisions applied as ordered (severity mirrors
APPROVAL-003; no human-vouch escape hatch on the release path; tracked files
only). No commit was made.

### Done

1. **Opt-in params on `scripts/validate-project.ps1`** — `-ReleaseDiffBase` /
   `-ReleaseDiffHead`, both `$null` by default, same discipline as
   `-ScopeDiffBase`/`-ScopeDiffHead`: every existing caller omits them, so
   behavior is byte-identical (proven: all 158 fixture/golden cases and all 4
   example goldens unchanged). When both are supplied, `Test-TestEvidenceGit-
   GroundTruth` runs right after `Test-ReleaseArtifact`.
2. **New sibling rule `TEST-EVIDENCE-003`** in `pmo-config/validation-rules.json`
   (severity `warn`, like APPROVAL-003) — chosen over overloading
   `TEST-EVIDENCE-002` because that rule's documented semantics are "missing or
   unresolvable evidence" (an existence/resolution bar), and a tracked,
   resolvable-but-stale file is neither missing nor unresolvable; a sibling
   rule keeps each catalog entry's description truthful and keeps the
   diagnostics contract (DOCTOR-007) clean.
3. **The check** (`scripts/lib/rtm-validator.ps1`): for each `passed` Test
   Summary row citing resolvable, in-project `FILE:` evidence:
   - **Tracked files only (decision 3):** `git ls-files --full-name
     --error-unmatch` from the project dir — this also canonicalizes the path
     (`.`/`..` segments, casing) and bridges project-relative evidence paths to
     repo-root-relative diff paths, which is what the GitHub Action's
     project-inside-consumer-repo shape needs. Untracked/gitignored evidence is
     neither passed nor failed (tested).
   - **Diff membership:** `git diff --no-color --name-only -z base..head`
     (NUL-separated, `-z` discipline from scope-diff-git-adapter.ps1). In-range
     → PASS row. Not in range → the finding, whose message names the
     git-ground-truth defect the way EXEC-005's does ("...was not changed
     within the release's verified commit range base..head — a report that
     predates this release's work cannot prove the released code passes.").
     Working-tree state is surfaced: clean = predates the release; modified/
     staged = "also has uncommitted changes".
   - **Severity (decision 1):** WARN-blocking at Standard, FAIL at Strict —
     the exact APPROVAL-003 shape, including no row at all at Lite (the whole
     Test Summary rule family is Standard/Strict-only).
   - **No vouch (decision 2):** no override mechanism exists on this path.
   - **Git infra failures are always FAIL** (unresolvable base/head with the
     SCOPE-DIFF-004 fetch-depth guidance, project not inside a git repo, diff
     itself failing) — a requested-but-broken range is a configuration error,
     not a pass; raw git stderr never enters a result row (only the run log).
   - **The project's own repository is the git root**, derived via
     `git rev-parse --show-toplevel` from the project dir — no new repo-root
     parameter, because the evidence files and the release's commit range live
     in the same repo as the project (noted as a deliberate contrast with
     SCOPE-DIFF's `-ScopeDiffRepoRoot`).
4. **Tests** — `tests/helpers/release-evidence-tests.ps1` (new, wired into
   `scripts/run-all-checks.ps1` as `release-evidence`), built on the
   scope-diff-tests.ps1 pattern (disposable git repos, subprocess JSON):
   - opt-in: no refs → zero TEST-EVIDENCE-003 rows, exit 0
   - fresh in-range evidence → PASS row, exit 0
   - stale (tracked, unchanged in range) → WARN-blocking at Standard
   - same stale fixture → FAIL at Strict, exit 1
   - uncommitted (tracked file modified in the working tree) → caught, reason
     names the uncommitted state
   - retro-added (staged after head) → caught, reason names the uncommitted
     state
   - untracked evidence → out of scope entirely (no row, exit 0) — the
     decision-3 negative control
   - Lite-default project → no row of any level, exit 0 (decision-1 control;
     required a genuinely Lite-default project because `-Mode Lite` cannot
     downgrade a Standard project, MODE-001)
   - project as a subdirectory of the repo (Action shape) → stale evidence
     caught across the repo-root boundary, path named repo-root-relative
   - unresolvable base → always FAIL with fetch-depth guidance
   → **26/26 assertions, PASS**.
5. **Docs** — `docs/rules/TEST-EVIDENCE-003.md`, mirroring the EXEC-005.md
   shape (level table, what it checks, why it exists with the three attack
   cases, scope/limits, how to fix, related). Catalog entry carries
   `documentation` so DOCTOR-009 resolves it.

### Not done (and why)

- **M1 / M2 / M3** — not started; M4 is still in progress per the plan's
  ordering and feeback Round 3's work list.
- **Action inputs wiring** — `action.yml` does not yet expose
  `release-diff-base`/`release-diff-head`. The validator-side params are in
  place and tested; exposing them through the GitHub Action is a separate,
  follow-up decision (the SCOPE-DIFF inputs were added as their own
  milestone). Flagged here rather than done unilaterally.
- **No commit made.** All changes remain in the working tree.

### Found that contradicts the plan / observations (report only, not changed)

- **The gap-analysis sketch said to reuse `-ScopeDiffRepoRoot` semantics**; on
  implementation, the check derives the git root from the project itself
  (`--show-toplevel`) instead, and no parameter is needed at all. This is
  simpler AND more correct for the Action case (the project IS inside the
  consumer repo whose history is diffed) — recorded here as a deviation from
  the sketch, justified.
- **`RESOLVED` evidence can still be stale** — by design now: a tracked file
  committed in-range passes even if the agent committed a fabricated report.
  Git cannot distinguish that from a genuine report; that is exactly why the
  EXEC path exists (provenance tiers + vouch) for execution evidence, and why
  the release path is opt-in. Stated rather than papered over.

### Round 4 question (per feeback Round 3 work list item 6)

**Is M4 done for v.2.0's purposes, or is another increment warranted before
moving to M3?** With this increment, an agent report claiming "all tests
pass" cannot pass the release gate against contradicting git ground truth
when the caller supplies the range — the M4 target from MasterPlan §6. What
remains that M4 could still plausibly cover: (a) exposing the new inputs
through `action.yml`; (b) `TEST-RESULT-001`'s `skipped` rows getting the same
reconciliation (Strict requires resolvable skip evidence — a skipped row's
FILE: evidence is currently not git-checked); (c) anything else the reviewer
sees in the L2 gap. If M4 is accepted as complete here, the plan orders M3
next.

### Verification run

- `~/.local/opt/powershell/pwsh -NoProfile scripts/pmo-doctor.ps1` →
  `Summary: PASS=59 WARN=0 FAIL=0` (DOCTOR-007/008/009 green with the new
  rule: emitted, has suggestion, doc resolves)
- `~/.local/opt/powershell/pwsh -NoProfile scripts/check-public-hygiene.ps1`
  → `Summary: PASS=1 FAIL=0`
- `~/.local/opt/powershell/pwsh -NoProfile scripts/run-validation-tests.ps1`
  → `Summary: PASS=158 FAIL=0` (zero golden drift from the new params)
- `~/.local/opt/powershell/pwsh -NoProfile -File
  tests/helpers/execution-contract-tests.ps1` → `Summary: PASS=127 FAIL=0`
- `~/.local/opt/powershell/pwsh -NoProfile -File
  tests/helpers/scope-diff-tests.ps1` → `Summary: PASS=45 FAIL=0`
- `~/.local/opt/powershell/pwsh -NoProfile -File
  tests/helpers/release-evidence-tests.ps1` → `Summary: PASS=26 FAIL=0`
- `~/.local/opt/powershell/pwsh -NoProfile -File
  tests/golden/capture-examples.ps1 -RepoPath "$PWD" -Verify` → all match
- `scripts/run-all-checks.ps1` full pass was not run this round (the mutation
  + e2e tail is slow and was verified in prior rounds); every component suite
  it aggregates was run individually with the numbers above, plus the new
  suite wired into it.

Working-protocol notes for the reviewer: `feeback.md` Round 3 was read first;
`docs/architecture/powershell-portability.md` was read before touching
`scripts/` (the git invocations follow the established `2>$null`/stderr-file
patterns and the `-z` NUL parsing from scope-diff-git-adapter.ps1; no
`$IsWindows` branches, no native-stderr-under-Stop hazards introduced). New
files are `docs/rules/TEST-EVIDENCE-003.md` and
`tests/helpers/release-evidence-tests.ps1` — both untracked, as with every
prior round. Branch `Axiom-PMO-v.2.0`, nothing committed.

---

## 2026-08-13 — Round 4 feedback executed: M3 gap-analysis only, no code — stopped for Round 5 review

`Fixed plan/feeback.md` Round 4 was read at session start, before touching
anything. M4 is closed. This round produced the **M3 gap-analysis note only**,
per the Round 4 work list ("write a short gap-analysis note in
`update_fixed.md` ... and stop for review before implementing" — the same gate
M0 and M4's second increment went through). **No commit was made, and nothing
outside `Fixed plan/` was touched.**

### Done — read, not assumed

- `templates/HANDOFF-REVIEW.json` — the L3 finding shape the `handoff_review`
  intent produces.
- `skills/pmo-delivery/SKILL.md` (byte-identical to
  `.claude/skills/pmo-delivery/SKILL.md`, verified with `diff -q`) — the
  intent's contract: run the gate first, read the artifacts together, walk
  every lens, record findings + both digests, re-run gate +
  `scripts/assess-handoff.ps1`. Its "Rules for findings" already say every
  finding cites evidence and has a suggestion and an owner, and that an AI may
  never close human-only lenses.
- `scripts/lib/handoff-validator.ps1` `Test-HandoffSemanticReview`
  (HANDOFF-010) — the only enforcement of that shape: lens coverage, finding
  enum validity, generic-token owner check, non-empty `evidence_refs`/
  `suggestion`, closure authority, `decision_ref` resolution, dual-digest
  freshness.
- `pmo-config/handoff-policy.json` `semantic_review` — the shape's policy
  source (severities, statuses, closure policy, lenses, digests).
- `templates/EXECUTION-REVIEW.json`, `scripts/lib/adversarial-review-
  validator.ps1` (AREV-001..006), `pmo-config/adversarial-review-policy.json`
  — the sibling L3 family that "every semantic finding" must also cover.
- `scripts/assess-handoff.ps1` — the verdict machinery that must never be
  moved by an AI's recommendation.
- Real findings in `tests/fixtures/valid-handoff-strict/HANDOFF-REVIEW.json`
  (fields match the template exactly, including `owner`, `blocking_point`).
- Requirement-id vocabulary: `REQ-###` from PROJECT.md In Scope —
  `Get-IdsFromRows` in `scripts/lib/source-validator.ps1`, cross-checked by
  RTM-002/RTM-007 in `scripts/lib/rtm-validator.ps1`.

### Gap analysis — what exists today vs. what M3 requires

**1. Two L3 semantic-review artifact families exist today.**

| | `HANDOFF-REVIEW.json` (Handoff gate) | `EXECUTION-REVIEW.json` (execution gate) |
|---|---|---|
| Rules | HANDOFF-010 | AREV-001..006 |
| Finding fields | `finding_id`, `lens`, `severity`, `artifact`, `item_id`, `field`, `description`, `evidence_refs`, `suggestion`, `owner`, `blocking_point`, `status`, `decision_ref` | `finding_id`, `category`, `severity`, `artifact`, `item_id`, `description`, `evidence_refs`, `suggestion`, `status`, `decision_ref` |
| `severity` | ✅ enum-checked | ✅ enum-checked |
| named human decision owner | ✅ `owner`, generic-token-checked | ❌ **no per-finding owner** (file-level `reviewer`/`reviewer_kind` only) |
| `requirement_ref` | ❌ | ❌ |
| `implementation_claim` | ❌ | ❌ |
| `test_claim` | ❌ | ❌ |

Of the M3 target contract's five fields, the handoff family carries two and
`EXECUTION-REVIEW.json` findings carry one. `item_id` links a finding to a
work item (e.g. `D-002`, `OA-002`), not to a requirement; `evidence_refs` are
free-text locations.

**2. "An AI's semantic verdict never changes a validator exit code on its own"
— already structurally true, now traced end-to-end:**

- `HANDOFF-010` never reads `recommendation`; it checks existence, completeness,
  closure authority, and the two digests (`handoff-validator.ps1:1054-1235`).
- `assess-handoff.ps1` never reads `recommendation` either, always exits 0, and
derives stage verdicts only from open findings' blocking points plus
deterministic FAILs (its score is capped and explicitly not an approval).
- AREV-* never reads `recommendation.verdict` — `templates/EXECUTION-
  REVIEW.json` states this in-file, and `adversarial-review-validator.ps1`
  contains no `recommendation` reference.
- The one place a review `recommendation` IS read —
  `scripts/lib/visual-proof-validator.ps1:459-461` requires
  `recommendation.status = accepted` — is `VISUAL-REVIEW.json`, a **human-only**
  review (`reviewer_kinds: ["human"]`) that additionally requires a resolvable
  DEC-###. It does not violate the AI-verdict principle.
- Where the invariant is pinned today: the AREV helper suite's fixture
  generator (`tests/helpers/adversarial-review-tests.ps1` `New-Review`, line
  181) defaults `recommendation.verdict = "request_changes"` and its pass-cases
  assert the execution verdict is still `pass` — incidentally pinned, no named
  case. The handoff side is **not pinned**: every fixture and the e2e filler
  set `ready_to_start_development: true` (grep across `tests/` confirms zero
  `false` values), and no test asserts a review whose recommendation says
  "not ready" still passes HANDOFF-010 with `assess-handoff.ps1` verdicts
  unchanged. That positive control is the missing "confirm".

**3. "Wire L3 findings into the same gate envelope as the (declined) L4 would
have used" — interpretation, stated for the reviewer to validate:** the
declined L4 (MasterPlan §6 M1/M2) was designed to emit through the standard
`Add-Result` diagnostics envelope — rule_id + level + message +
artifact/item_id/field — via maintainer checks with catalog entries, fixtures,
goldens, and docs. L3 findings already enter that envelope today (HANDOFF-010
and AREV-* rows), but coarsely: per-finding problems in
`Test-HandoffSemanticReview` are emitted as whole-artifact rows
(`Add-Result FAIL "Semantic handoff review is incomplete: $problem"
"HANDOFF-010" -Artifact HANDOFF-REVIEW.json`) with no `-ItemId` (the
`finding_id`) and no `-Field` (the offending field). So "same gate envelope"
concretely means: new-contract violations emitted as standard diagnostics
carrying the finding's own artifact/item_id/field — the same shape L4's checks
would have produced.

### Smallest change that does it (design sketch — NOT implemented, awaiting Round 5 approval)

1. **Extend the schemas.** Add `requirement_ref`, `implementation_claim`,
   `test_claim` to both review templates and their policy sources
   (`handoff-policy.json` `semantic_review`, `adversarial-review-policy.json`);
   add `owner` to `EXECUTION-REVIEW.json` findings (its policy file has no
   `owner_policy` today — the handoff one would be the model to reuse).
2. **Enforce where the finding shape is already validated** —
   `Test-HandoffSemanticReview` (HANDOFF-010) and AREV-004: `requirement_ref`
   resolves against `$ProjectReqIds` (reusing `Get-IdsFromRows`), owner passes
   the generic-token check, claims non-empty — each violation emitted as a
   diagnostic with `-ItemId <finding_id> -Field <field>`. Whether this extends
   the existing rule IDs or adds siblings (HANDOFF-015 / AREV-007) follows the
   TEST-EVIDENCE-002/003 precedent: the repo prefers a truthful sibling
   description over overloading an existing one.
3. **Pin the exit-code invariant with positive fixtures:** (a) a valid handoff
   review whose `recommendation.ready_to_start_development` is `false` must
   still PASS HANDOFF-010 and leave `assess-handoff.ps1` verdicts unchanged;
   (b) the AREV `request_changes` case becomes an explicitly named test rather
   than an incidental default.

### Not done (and why)

- **No code, no config, no template change.** Round 4's work list requires
  stopping after the gap-analysis note for Round 5 review. Nothing outside
  `Fixed plan/` was touched (git status before/after this session: identical).
- **M1/M2** — not started; the L4 track remains closed (DEC-024).
- **Deferred items on record (not this round):** `action.yml` input exposure;
  `TEST-RESULT-001` skipped-row git reconciliation. Neither implemented.

### Found that contradicts the plan / observations (report only, not changed)

- **M3's field list reads adversarial, its anchor is handoff.**
  `requirement_ref`/`implementation_claim`/`test_claim` map naturally onto
  EXECUTION-REVIEW findings (a review of a diff that implements requirements
  with tests) but less naturally onto handoff completeness findings ("the
  build sequence omits the receive-stock step" has no single `test_claim`).
  The plan says "every semantic finding carries..." — if taken literally for
  handoff findings, `implementation_claim`/`test_claim` need a defined
  not-applicable treatment rather than being forced. Question for the Human
  Owner, not guessed.
- **`requirement_ref` resolution target is ambiguous.** EXEC-003 resolves
  `requirement_refs` against the EXECUTION-CONTRACT (populated from
  `DELIVERY.md` work-item rows); RTM resolves against PROJECT.md In Scope. The
  new L3 field should pick one or both — asked below.
- **Schema-version story.** Both review policies carry `schema_version:
  "1.0"`. Adding required fields breaks existing review files; bumping to 1.1
  with a defined migration vs. optional-but-validated-when-present is a design
  decision, not a mechanical one.

### Round 5 questions (Human Owner / reviewer — do not guess)

1. **Scope of the contract:** apply the five-field contract to BOTH review
   families (handoff + adversarial), or anchor on the adversarial review and
   treat handoff findings as conditional?
2. **`requirement_ref` target:** resolve against PROJECT.md In Scope only, or
   also against `DELIVERY.md` work-item rows?
3. **Mandatory vs conditional:** are `implementation_claim`/`test_claim`
   required on every finding in scope, or required-when-relevant with a
   defined N/A value?
4. **Rule shape and tests:** extend HANDOFF-010 / AREV-004, or add sibling
   rule IDs (HANDOFF-015 / AREV-007) with docs pages; and should the
   "confirm" positive fixtures live in the fixture/golden suites or the
   helper suites?

### Verification run

- Nothing changed outside `Fixed plan/` this round, so no suite re-run was
  required by the work list. Baseline numbers on record from Round 4's
  independent verification: `pmo-doctor.ps1` **59/0/0** ·
  `check-public-hygiene.ps1` **1/0** · `run-validation-tests.ps1` **158/0** ·
  `execution-contract-tests.ps1` **127/0** · `scope-diff-tests.ps1` **45/0** ·
  `release-evidence-tests.ps1` **26/0**.

Working-protocol notes for the reviewer: `feeback.md` Round 4 was read first;
no `scripts/` or `pmo-config/` file was touched, so
`docs/architecture/powershell-portability.md` was not required reading this
round (§7.5 applies to code work). The only file changed is
`Fixed plan/update_fixed.md` (this entry). Branch `Axiom-PMO-v.2.0`, nothing
committed.

---

## 2026-08-13 — Round 5 feedback executed: M3 implemented (AREV-007 semantic output contract on EXECUTION-REVIEW.json findings), exit-code invariant pinned, stopped for Round 6 review

### Done

**1. Contract anchor (feeback Round 5 decision 1): adversarial only.**
`HANDOFF-REVIEW.json`, `pmo-config/handoff-policy.json`, and `HANDOFF-010`
were NOT touched — `git diff` on all three: empty. The five-field contract is
enforced on `EXECUTION-REVIEW.json` findings only.

**2. The three fields, in their natural homes (work list item 1).**
- `templates/EXECUTION-REVIEW.json` — the finding example now carries
  `requirement_ref`, `implementation_claim`, `test_claim`, and the `$comment`
  block states the M3 contract.
- `pmo-config/adversarial-review-policy.json` — new **`output_contract`**
  section (the natural home: it is policy about the finding shape, next to
  `finding_categories`/`finding_statuses`): `n_a_marker: "N/A"` and a
  `fields` map declaring `requirement_ref` (required, resolves against
  PROJECT.md In Scope) and the two claims (required, conditional, N/A
  allowed).

**3. AREV-007 in `scripts/lib/adversarial-review-validator.ps1`.**
Confirmed the next free AREV id first: AREV-006 was the highest in
`pmo-config/validation-rules.json` (verified by reading the catalog), so
`AREV-007` is correct. Behavior:
- `requirement_ref` — mandatory; resolves against `$ProjectReqIds` (the
  REQ-### ids from PROJECT.md In Scope, parsed with `Get-IdsFromRows` the
  same way RTM-002 reads them). Missing and unresolvable are two distinct
  diagnostics; both emitted with `-ItemId <finding_id> -Field
  "requirement_ref"`.
- `implementation_claim` / `test_claim` — non-empty **or** the explicit N/A
  marker read from `output_contract.n_a_marker` (hard default `"N/A"` if the
  section is ever absent, so a stripped policy still fails closed). Blank is
  a violation: "not applicable" must be stated, never implied.
- Shape check only — never judges the review's content, never reads
  `recommendation`. PASS row emitted when every finding satisfies the
  contract.
- `$ProjectReqIds` is plumbed from `execution-contract-validator.ps1` (reads
  PROJECT.md In Scope at the AREV call site; empty set when PROJECT.md is
  missing or has no In Scope table → any `requirement_ref` fails closed).

**4. Exit-code invariant pinned (work list item 2).**
- (a) New explicitly-named positive control in the helper suite: a review
  whose `recommendation.verdict` is `request_changes` with a fully populated
  contract-valid finding → AREV-007 not raised, execution verdict still
  `pass`.
- (b) `grep -n "recommendation" scripts/lib/adversarial-review-validator.ps1`
  → **zero code references** (only the explanatory comment inside the
  AREV-007 block); same grep on `scripts/lib/execution-contract-validator.ps1`
  → **zero matches**. No code path reads the field to decide pass/fail —
  neither pre-existing AREV-* nor the new rule.

**5. Helper-suite tests (work list item 3, decision 4: helper suite, not
fixture/golden).** 6 new cases / 12 assertions in
`tests/helpers/adversarial-review-tests.ps1`: request_changes positive
control (2); missing requirement_ref → raised + names finding id + field +
blocks verdict on its own (4); unresolvable requirement_ref REQ-999 → raised
+ message names the bogus id (2); missing implementation_claim (2); missing
test_claim (2); both claims `"N/A"` → not raised + verdict pass (2).
Existing findings across the suite were updated to carry the three fields so
the AREV-004/005/006 cases test only what they claim to test, and the fixture
PROJECT.md gained an In Scope table (REQ-001) — `git diff` shows no fixture/
golden outside the helper suite was touched, and no fixture/golden uses
`templates/EXECUTION-REVIEW.json` as input, so the template placeholder
cannot trip a golden.

**6. `docs/rules/AREV-007.md`** — new page, same shape as
`EXEC-005.md`/`TEST-EVIDENCE-003.md` (level/runs-when/artifacts, what it
checks, why, scope & limits, how to fix, see-also) + catalog entry with
`documentation` → DOCTOR-009 green.

### Not done (and why)

- **No commit** — per the standing instruction; everything stays in the
  working tree for Round 6 review.
- **HANDOFF family** — untouched per decision 1.
- **M1/M2** — closed (DEC-024).
- **Per-finding `owner` on adversarial findings — NOT added.** Round 5's work
  list names exactly three fields to add (`requirement_ref`,
  `implementation_claim`, `test_claim`) and AREV-007 checks only those. The
  "named human decision owner" element of M3's five-field list is, on this
  family, carried by the file-level `reviewer`/`reviewer_kind` plus
  AREV-005/006 closure-authority-by-role (only human may set any closure
  status). I am flagging this rather than guessing it in: if per-finding
  `owner` IS wanted, it is a one-field template/policy addition plus an
  AREV-007 clause in a future round.
- **Deferred items** (action.yml release-diff inputs; TEST-RESULT-001
  skipped-row reconciliation) — untouched.

### Found that contradicts the plan / observations (report only, not changed)

- **AREV-007 FAILs at Standard too**, not only Strict. This mirrors
  AREV-004/005/006, which all FAIL at any enabled mode — the mode ladder
  governs only AREV-001 (presence). Flagging so the reviewer can confirm a
  structural contract failing at Standard matches intent.
- The Round 4 design sketch's "owner passes the generic-token check" applied
  to the handoff family; on the adversarial side the work list omits owner —
  see Not done.
- `requirement_ref` matching uses case-insensitive `-notcontains`, following
  RTM-002/REF-001's convention for governance ids, deliberately NOT the
  `-cnotcontains` used for git file paths in EXEC-004/008 — requirement ids
  are tokens, not on-disk paths.

### Round 6 questions (Human Owner / reviewer — do not guess)

1. **Per-finding `owner` on adversarial findings** — add the fifth M3 field,
   or is file-level reviewer/reviewer_kind + AREV-005/006 closure authority
   sufficient? (Not added — work list names three fields.)
2. **AREV-007 severity at Standard** — keep FAIL at every enabled mode
   (mirrors AREV-004), or mode-ladder it (WARN Standard / FAIL Strict)?
3. **Is M3 done for v.2.0?** With the output contract enforced, the remaining
   M3-shaped candidate is the L4-style aggregate envelope (findings currently
   surface as per-finding diagnostics; there is no aggregate "L3 verdict"
   object). Flagged as the next increment only if the reviewer wants it.

### Verification run (real numbers, run this session)

- `tests/helpers/adversarial-review-tests.ps1` → **PASS=39 FAIL=0**
  (27 pre-existing + 12 new AREV-007 assertions)
- `scripts/pmo-doctor.ps1` → **PASS=59 WARN=0 FAIL=0** (DOCTOR-007
  catalog⇄emitter reconcile includes AREV-007 both ways; DOCTOR-008
  suggestion present; DOCTOR-009 doc page resolves)
- `scripts/check-public-hygiene.ps1` → **PASS=1 FAIL=0**
- `scripts/run-validation-tests.ps1` → **PASS=158 FAIL=0**
- `tests/helpers/execution-contract-tests.ps1` → **PASS=127 FAIL=0**
- `tests/helpers/clean-room-tests.ps1` → **PASS=63 FAIL=0** ·
  `tests/helpers/plugin-install-spike-tests.ps1` → **PASS=17 FAIL=0**
  (both exercise `verify-execution-result.ps1` end-to-end as subprocesses)
- `grep "recommendation"` across both validators → zero code references
  (item 2b above).

Working-protocol notes for the reviewer: `feeback.md` Round 5 read first. All
changes confined to the work list: `pmo-config/adversarial-review-policy.json`,
`pmo-config/validation-rules.json`, `templates/EXECUTION-REVIEW.json`,
`scripts/lib/execution-contract-validator.ps1`,
`scripts/lib/adversarial-review-validator.ps1`, new
`docs/rules/AREV-007.md`, and `tests/helpers/adversarial-review-tests.ps1`.
`scripts/` and `pmo-config/` were touched, so
`docs/architecture/powershell-portability.md` was required reading (§7.5);
the new code invokes no native commands (Get-Content/ConvertFrom-Json/table
parsing only), so DOCTOR-010/011 stay green. Branch `Axiom-PMO-v.2.0`,
nothing committed; new files: `docs/rules/AREV-007.md` (untracked).

---

## 2026-08-13 — Round 6 feedback executed: M3 CLOSED (per-finding `owner` added to AREV-007, completing the five-field output contract)

### Done

**1. `owner` added to the contract (feeback Round 6 decision 1, work list items 1–3).**
- `pmo-config/adversarial-review-policy.json` `output_contract.fields` — new
  `owner` entry: `required: true`, `conditional: false`, `n_a_allowed: false`,
  description pointing at `handoff-policy.json owner_policy.generic_tokens`
  as the token source. `_note` updated to include owner in the contract list.
- `templates/EXECUTION-REVIEW.json` — the finding example now carries
  `"owner": "<Named human accountable for this finding -- a group name or TBD
  is not a name>"`, and the `$comment` M3 paragraph names owner as a fourth
  required element.
- `scripts/lib/adversarial-review-validator.ps1` AREV-007 — owner check added,
  same envelope shape as the other three fields (`-ItemId <finding_id> -Field
  "owner"`), with two distinct diagnostics: **missing** (blank/absent) vs.
  **generic** (a token the owner policy flags), the same missing-vs-invalid
  split the `requirement_ref` check already used. The check is
  `Test-GenericOwner`, the **shared helper** the handoff family already uses
  (HANDOFF-003 / APPROVAL-005), not a copy: `adversarial-review-validator.ps1`
  now dot-sources `handoff-validator.ps1` (the same lib→lib dot-source
  convention `handoff-validator.ps1` itself uses for `ordinal-sort.ps1`) and
  reads `owner_policy` from `pmo-config/handoff-policy.json` (missing config
  = hard error, same no-silent-fallback rule `Read-AdversarialReviewPolicy`
  applies). PASS message updated to name owner.

**2. Severity unchanged (decision 2): FAIL at every enabled mode.** No
mode-ladder machinery was introduced — AREV-007 stays FAIL at Standard and
Strict exactly as before, consistent with the reviewer's structural finding
that the EXEC/AREV pipeline has never emitted a WARN.

**3. No aggregate envelope (decision 3): M3 is closed once this lands.** The
work list's item 6 says it plainly — no Round 8 question needed for M3. This
entry reports completion and asks what's next (remaining plan scope vs.
v.2.0 close-out) rather than opening a new sub-track.

**4. Tests (work list item 4).** `tests/helpers/adversarial-review-tests.ps1`:
- Every existing finding across the suite gained `owner = "Alice Chen"` (a
  real person, not a token) so the AREV-004/005/006 and recommendation
  invariant cases still measure only what they claim to measure.
- 3 new cases / 8 new assertions: **missing owner** → AREV-007 raised with
  `field: owner`, `item_id: AF-001`, blocks the verdict on its own; **generic
  group owner** (`"Dev Team"`) → raised, message names the token; **valid
  named owner** (`"Alicia Wu"`) → not raised, verdict pass. Same rigor as the
  other three fields' cases.

**5. `docs/rules/AREV-007.md` extended** — owner field documented in "What
this rule checks" and "How to fix", the Round 6 decision 1 reference added to
"Why it exists", and the scope section now states owner reuses the handoff
family's check rather than a parallel list.

### Not done (and why)

- **No commit** — standing instruction; all changes stay in the working tree.
- **HANDOFF family** — untouched (Round 5 decision 1; no diff this round).
- **M1/M2** — closed (DEC-024).
- **Aggregate "L3 verdict" envelope** — deliberately NOT built (Round 6
  decision 3: L4 is declined, there is no L4 envelope to match; AREV-007
  already emits through the standard Add-Result envelope with
  rule_id/level/artifact/item_id/field).
- **Deferred items** (action.yml release-diff inputs; TEST-RESULT-001
  skipped-row reconciliation) — untouched, still deferred.

### Found that contradicts the plan / observations (report only, not changed)

- None this round. One design note worth recording: `Test-GenericOwner` treats
  blank as generic (`$trimmed.Length -eq 0 → true`), so the AREV-007 owner
  check tests the blank branch first to keep "missing" and "generic" as two
  distinguishable messages rather than folding blank into the generic message.
  Also: `"N/A"` is itself a `generic_tokens` entry, so an owner of `"N/A"` is
  rejected as generic — correct, since `owner` is the one contract field where
  the N/A marker is never allowed (`n_a_allowed: false`).

### Verification run (real numbers, run this session)

- `tests/helpers/adversarial-review-tests.ps1` → **PASS=47 FAIL=0**
  (39 pre-existing + 8 new owner assertions)
- `scripts/pmo-doctor.ps1` → **PASS=59 WARN=0 FAIL=0**
- `scripts/check-public-hygiene.ps1` → **PASS=1 FAIL=0**
- `scripts/run-validation-tests.ps1` → **PASS=158 FAIL=0**
- `tests/helpers/execution-contract-tests.ps1` → **PASS=127 FAIL=0**
- `tests/helpers/clean-room-tests.ps1` → **PASS=63 FAIL=0**
  (exercises verify-execution-result.ps1 end-to-end with the modified
  validator)
- `tests/golden/capture-examples.ps1 -Verify` → all example golden outputs
  match
- `grep "recommendation"` across both validators → exactly one hit, the
  explanatory comment inside the AREV-007 block; zero code references (exit
  code still never influenced by a verdict).

Working-protocol notes for the reviewer: `feeback.md` Round 6 read first.
Changes confined to the work list: `pmo-config/adversarial-review-policy.json`,
`templates/EXECUTION-REVIEW.json`,
`scripts/lib/adversarial-review-validator.ps1`, `docs/rules/AREV-007.md`,
`tests/helpers/adversarial-review-tests.ps1`. `scripts/` was touched, so
`docs/architecture/powershell-portability.md` was required reading (§7.5);
the new code invokes no native commands (Get-Content/ConvertFrom-Json only),
so DOCTOR-010/011 stay green. Branch `Axiom-PMO-v.2.0`, nothing committed.

**M3 is closed.** Next step per work list item 6: awaiting direction on the
plan's remaining scope (e.g. M5/M6/M8 or the deferred action.yml /
skipped-row items) or v.2.0 close-out — no new sub-track opened unprompted.
