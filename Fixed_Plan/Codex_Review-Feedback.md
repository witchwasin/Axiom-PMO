# Codex Review Feedback

> **Purpose:** Codex records its review of FreeBuff's implementation updates and branch changes against `master-plan.md`. FreeBuff responds in `FreeBuff_fixed-update.md`; the loop continues until the Human Owner approves the outcome.
>
> **Working branch:** `V2.1`
>
> **Authority boundary:** This document is candidate review evidence only. It is not scope, design, release, merge, or production approval. Only the Human Owner may authorize merge into `main`.

## Review protocol

1. FreeBuff first completes one autonomous, end-to-end implementation pass across the approved plan and pushes it to `V2.1`. Codex then reviews that complete first handoff; Codex does not interrupt it with milestone-by-milestone review.
2. Codex reviews the latest pushed `V2.1` commit(s), the matching FreeBuff iteration, and the applicable parts of `master-plan.md`.
3. Every finding must state a plan reference, affected path or evidence inspected, severity, and clear next action.
4. If the plan or evidence cannot resolve a material question, Codex records it as **Needs Human Owner Decision** and asks the Human Owner rather than guessing.
5. FreeBuff addresses open findings in a new iteration in `FreeBuff_fixed-update.md`, pushes the work, and records the resulting commit SHA.
6. A finding may be closed only when repository evidence demonstrates it is addressed. Human-decision findings remain pending until the Human Owner decides.
7. All paths in updates and findings must be relative to the repository root; machine-specific absolute paths are not allowed.

## Review status

| Field | Value |
|---|---|
| Latest FreeBuff iteration reviewed | FB-001 (M4–M8) |
| Latest commit reviewed | `05f04b5` + `14d86a8` (FB-001, pushed to `origin/V2.1`) |
| Open findings | 6 (CR-001..CR-006) — recorded by FreeBuff's independent pre-review of FB-001; Codex verifies next |
| Human Owner decisions needed | Possibly for CR-005 (policy-vs-validator authority scope) if the plan cannot resolve it |
| Overall review state | FB-001 implementation complete and pushed; FreeBuff independent pre-review recorded below; Codex formal review next |

### Review CR-001 — 2026-08-14

**Executor:** FreeBuff — independent pre-review of the FB-001 (M4–M8) pass,
recorded here as candidate input for the Codex review loop. It is not a Codex
review and carries no approval authority; every finding was reproduced on a
temporary copy of the repository (never the working tree) and is verifiable
by re-running the stated mutation.

**Review scope**

| Field | Value |
|---|---|
| FreeBuff iteration | FB-001 (M4–M8) |
| Commit SHA(s) reviewed | `05f04b5` (implementation) + `14d86a8` (update record) |
| Plan references reviewed | `master-plan.md` §M4, §M5, §M6, §M7, §M8 |
| Evidence inspected | Diff vs `4893691`; `scripts/lib/externalization-validator.ps1`, `scripts/lib/design-provider-validator.ps1`, `scripts/lib/research-validator.ps1`; templates; `examples/OPTIONAL-TRACKS`; `scripts/pmo-status.ps1`; `CONTEXT-ROUTER.md`; `README.md`; live forge mutations |

**Findings**

| ID | Severity | Status | Plan reference | Evidence / affected path | Required action |
|---|---|---|---|---|---|
| CR-001 | Medium | Open | `master-plan.md` §M5 flow step 4 ("Deterministic preflight checks … manifest …") and §M5 Tests ("revision invalidates prior digest/review") | `scripts/lib/design-provider-validator.ps1`, `templates/DESIGN-PROVIDER-REVIEW.json` — `preflight.manifest_digest` is declared and carried everywhere but never compared to the current `INPUT-MANIFEST.json` `combined_digest`. Forge: set `preflight.manifest_digest` to 64 zeroes on a valid manifest → validation exit 0, no FAIL. A preflight/acceptance recorded against a stale manifest passes; only output-set changes invalidate acceptance, input changes do not | Add a freshness check in `DPROV-005`: recompute the combined digest of the current input manifest and fail when `preflight.manifest_digest` differs; add a regression mutation to `tests/helpers/m4-m6-tests.ps1` |
| CR-002 | Medium | Open | `master-plan.md` §M4 Work item 7 ("whether network transfer occurs must be recorded truthfully") | `scripts/lib/externalization-validator.ps1`, `templates/EXTERNALIZATION.json` — `network_transfer_occurred` is in the template and example but only format-checked when present; it is not a required field. Forge: removed the property from an entry → validation exit 0, no FAIL | Add `network_transfer_occurred` to the `EXT-001` required-field list (boolean check), and cover the omission in `tests/helpers/m4-m6-tests.ps1` |
| CR-003 | Medium | Open | `master-plan.md` §M6 Tests ("unresolvable material claim") and §M6 `PROVENANCE.json` spec ("source URL/file reference") | `scripts/lib/research-validator.ps1` — pattern references (`MOM-YYYYMMDD`, `REQ-…`, `TR-…`, `DEC-###`, `ISSUE-…`, `PR-…`) count as resolvable without verifying the referenced artifact exists in the project (only `FILE:` paths and URLs are checked). Forge: claim source `MOM-99999999` with no such file or Source Snapshot row → validation exit 0, no FAIL | Verify pattern references against the project's Source Snapshot table / `source/**` artifacts before treating them as resolved, or fail with an explicit unresolved-source diagnostic; the concept doc's web-existence disclaimer does not cover repo-local references |
| CR-004 | Medium | Open | `master-plan.md` §M6 Tests ("Scope cannot be approved with an **unresolved** accepted-impact proposal") | `scripts/lib/research-validator.ps1` — `$status -ne "accepted"` treats a **rejected** proposal as unresolved. Forge: `Impact=scope`, `Accepted Impact=yes`, `Status=rejected`, `Decision Ref=DEC-004` at the Scope gate → `RESEARCH-005` FAIL. A human-rejected proposal is resolved and should not block Scope | Block Scope only for proposals still unresolved (`proposed`), or handle `rejected` explicitly; add the rejected-with-scope-impact mutation to `tests/helpers/m4-m6-tests.ps1` |
| CR-005 | Medium | Open (may need Human Owner decision if the plan cannot resolve) | `master-plan.md` §M4 Work item 4 ("Public may proceed under policy") vs `pmo-config/orchestration-policy.json` `externalization.human_review_required` (only `Confidential`, `Restricted`) | `scripts/lib/externalization-validator.ps1` — the `status == "approved"` clause forces named-Human reviewer + decision on **every** approved entry regardless of classification, contradicting the declared policy list; the `elseif` "approval" branch is dead code. Forge: `Public` + `approved` + `human_review_required=false` + no reviewer/decision → `EXT-002` FAIL | Decide and align one way: either relax `EXT-002` so Public/Internal approved entries may proceed under policy without Human evidence, or extend `human_review_required` to all classifications so policy matches the validator. Record the choice in `FreeBuff_fixed-update.md`; escalate to Human Owner if Codex cannot resolve from the plan |
| CR-006 | Low | Open | `master-plan.md` §M6 Auto provider behavior order item 5 ("actionable stop") and §M6 Tests ("provider unavailable has truthful fallback/**stop** behavior") | `scripts/lib/research-validator.ps1`, `templates/RESEARCH-PROVENANCE.json` — there is no stop marker, so `provider_available=false` + `fallback_used=false` always fails `RESEARCH-006`; a truthful stop cannot pass any gate while research is active | Add an explicit stop/status marker to the provenance contract (e.g. `research_status: complete \| stopped`) and let `RESEARCH-006` accept unavailable+stopped as truthful; update the template, docs, and tests |

**Review summary**

- Status: Ready for next pass — findings CR-001..CR-006 are candidate defects for the Codex review loop; none blocks the FB-001 merge (no merge exists yet) and the shipped suites still pass (doctor 61/61, golden 158/158, m4-m6 24/24, full `run-all-checks` exit 0).
- Notes: The apparent delay during the pre-review was the local PowerShell runtime (~20 s per validator invocation), not a repository hang; `scripts/design-provider-digest.ps1` runs to completion with correct output. Verified correct (no finding): `context-map.json` already carries the M7 read sets from the M0–M3 pass; `axiom status` delegates to `pmo-status.ps1`; README §10 flow block and the limitation sections in the concept docs are present; example digests are current.

**Closure evidence**

| Finding ID | Verified in FreeBuff iteration | Commit SHA | Evidence | Closure status |
|---|---|---|---|---|
| CR-001 | — | — | — | Open |
| CR-002 | — | — | — | Open |
| CR-003 | — | — | — | Open |
| CR-004 | — | — | — | Open |
| CR-005 | — | — | — | Open |
| CR-006 | — | — | — | Open |

### Review CX-002 — 2026-08-14

**Review scope:** Codex's own M0–M3 implementation handoff, checked against
`master-plan.md` §§M0–M3 and the user's narrowed execution instruction.

**Result:** No open findings for M0–M3. The targeted contract suite passed
Change Control positive/negative mutations, Human decision enforcement,
downstream digest freshness, Standard/Strict Test Strategy coverage, Strict
test-level mutation, and legacy compatibility. Full fixture/golden validation
also passed. This is candidate evidence, not Human approval of scope, design,
release, merge, or Definition of Done.

**Next action for FreeBuff:** implement only pending M4–M8, add a new iteration
to `FreeBuff_fixed-update.md`, and leave this review entry intact. If FreeBuff
finds a conflict in the completed M0–M3 contracts, record it as a new finding
with the exact repository-relative path and wait for Human Owner direction when
the plan cannot resolve it.

## Review template — add one section per review pass

### Review CR-001 — YYYY-MM-DD

**Review scope**

| Field | Value |
|---|---|
| FreeBuff iteration | FB-… |
| Commit SHA(s) reviewed | — |
| Plan references reviewed | `master-plan.md` §… |
| Evidence inspected | Diff, tests, documentation, configuration, etc. |

**Findings**

| ID | Severity | Status | Plan reference | Evidence / affected path | Required action |
|---|---|---|---|---|---|
| CR-001 | Blocker / High / Medium / Low / Question | Open / Closed / Needs Human Owner Decision | `master-plan.md` §… | … | … |

**Review summary**

- Status: Ready for next FreeBuff pass / Needs Human Owner Decision / No new findings in this pass.
- Notes: …

**Closure evidence**

| Finding ID | Verified in FreeBuff iteration | Commit SHA | Evidence | Closure status |
|---|---|---|---|---|
| — | — | — | — | — |
