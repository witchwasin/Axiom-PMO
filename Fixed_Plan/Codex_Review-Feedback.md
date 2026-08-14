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
| Latest commit reviewed | `a6fbca8` (`05f04b5` implementation, `14d86a8` handoff record, and FreeBuff candidate pre-review) |
| Open findings | 22 — 8 High, 12 Medium, 2 Low (`CR-001`..`CR-022`) |
| Human Owner decisions needed | 1 — define the default Human-review behavior for Internal externalization when no provider-specific policy exists (`CR-005`) |
| Overall review state | **Changes required. FB-001 is not ready for Human acceptance or merge.** FreeBuff should complete FB-002 in the repair order recorded in Review CR-002. |

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

### Review CR-002 — 2026-08-15

**Executor:** Codex — formal independent review of FB-001. FreeBuff's Review
CR-001 above was treated as candidate input only; every candidate behavior was
reproduced independently in temporary project copies before disposition.

**Review scope**

| Field | Value |
|---|---|
| FreeBuff iteration | FB-001 (M4–M8) |
| Commit SHA(s) reviewed | `05f04b5`, `14d86a8`, `a6fbca8` |
| Comparison base | `4893691` (Codex M0–M3 handoff) |
| Plan references reviewed | `master-plan.md` §M4–M8, §12 test strategy/growth budget, §14 Definition of Done |
| Evidence inspected | Full diff; policy/templates/validators; generator/CLI/status; docs and canonical example; skills mirror; targeted suites; independent negative mutations; branch/CI trigger state |

**Disposition of FreeBuff candidate findings**

| ID | Severity | Codex disposition | Required correction |
|---|---|---|---|
| CR-001 | Medium | Confirmed / Open | `scripts/lib/design-provider-validator.ps1:172-187` never validates `preflight.manifest_digest`. Require a SHA-256 value equal to the current `INPUT-MANIFEST.json.combined_digest`, including missing/stale/input-revision mutations. |
| CR-002 | Medium | Confirmed / Open | `scripts/lib/externalization-validator.ps1:104-124` treats `network_transfer_occurred` as optional and accepts a JSON string. Make it a required JSON boolean and add omission/type mutations. |
| CR-003 | Medium | Confirmed / Open | `scripts/lib/research-validator.ps1:105-119` treats any substring matching a source pattern as resolved. Anchor references and resolve MOM/REQ/TR against Source Snapshot or project artifacts and DEC against the decision registry. |
| CR-004 | Medium | Confirmed / Open | `scripts/lib/research-validator.ps1:150-155` treats `rejected` as unresolved. Block only genuinely unresolved (`proposed`) proposals, while also applying CR-012 so a rejected proposal still needs a Human decision. |
| CR-005 | Medium | Confirmed / Open / partial Human decision | `scripts/lib/externalization-validator.ps1:157-175` forces Human evidence for every approved transfer. The plan resolves Public as policy-allowed, so remove blanket approval from the trigger. Define Internal's missing provider-policy default with the Human Owner; retain Human evidence for Confidential/Restricted, non-clean scans, and an explicit review-required declaration. |
| CR-006 | Low | Confirmed / Open, proposed remedy corrected | Add explicit `complete | stopped` research state, stop reason, and next action; require provider booleans. A stopped active-research track must remain blocking/actionable at Scope or be explicitly turned off by a Human—it must not silently pass as completed research. |

**Additional Codex findings**

| ID | Severity | Status | Plan reference | Evidence / affected path | Required action |
|---|---|---|---|---|---|
| CR-007 | High | Open | §M5 Tests/Done, §14 | `scripts/lib/design-provider-validator.ps1:81-84,255-259`: a `claude_design` project at Handoff/Release reports DPROV-005/006 PASS when `DESIGN/CLAUDE-DESIGN/REVIEW.json` is absent. | At Handoff/Release require a current passed preflight, non-empty current output, `acceptance.decision=accepted`, `reviewer_kind=human`, resolvable Human decision, and no open blocking provider finding. |
| CR-008 | High | Open | §M5 flow/tests | `scripts/lib/design-provider-validator.ps1:176-205`: empty output plus the empty-set digest passes; the outside-folder walk is tautological because it walks only `OUTPUT/**`; templates contain no output inventory/screens/states/scope refs. | Add a declared output inventory and required screens/states/scope references, require non-empty current output when reviewed, validate every declared output is under `OUTPUT/**`, and reject undeclared/outside output. |
| CR-009 | High | Open | §M5 step 8, §14 | `scripts/lib/design-provider-validator.ps1:207-245`: an open technical finding with `routes_to_change_control=false` passes DPROV-006/007 and can coexist with accepted output. | Validate finding schema and derive routing from impact/lens rather than a self-asserted boolean; block accepted baseline while technical/scope findings or their governed changes remain unresolved/stale. |
| CR-010 | High | Open | §M4 item 6, §M5 input manifest, §M6 guided flow | `scripts/lib/design-provider-validator.ps1:98-159` and `scripts/lib/research-validator.ps1:181-199` accept any approved EXT ID without binding provider, purpose, and outgoing path+digest. A manifest containing only raw `source/MOM/**` passed while citing an unrelated EXT entry. | Bind each provider package/brief to the same provider/purpose and exact outgoing path+digest set in its approved EXT entry; enforce canonical minimum inputs and require explicit governed justification/evidence before a specific raw source input is included. |
| CR-011 | High | Open | §M6 required sections/guided flow/Done | `scripts/lib/research-validator.ps1:122-157` never parses Impact Assessment. Accepted impact rows with no Change Proposal, owner, or DEC pass Scope. | Validate Impact Assessment rows, their REQ/scope/AC/risk mappings, and require every proposed/accepted product impact to resolve through a governed proposal and Human disposition. |
| CR-012 | High | Open | §M6 Guided step 7, §14 Authority | `scripts/lib/research-validator.ps1:138-154` requires a DEC only for `accepted`; Human-rejected proposals with no decision pass RESEARCH-004/005. | Require a named Human owner and resolvable DEC for both accepted and rejected dispositions; keep proposed as unresolved. |
| CR-013 | Medium | Open | §M6 provenance/tests, §14 Engineering quality | `scripts/lib/research-validator.ps1:91-120,159-178` ignores `retrieved_at`, source title/issuer/date/primary/verification, freshness/unresolved verification, actual report-section existence, provider enum/declaration agreement, and missing provider booleans. | Enforce the declared provenance/provider contract and deterministic freshness model; add missing/wrong-type/nonexistent-section/provider mutations without claiming web truth verification. |
| CR-014 | Medium | Open | §M5 inactive/scaffolding tests, §M8 generator E2E | `scripts/new-project.ps1:141-145,192-210` creates placeholder provider manifests, while `design-provider-validator.ps1:79-84` enforces them at Draft. A real `claude_design` generation produced five DPROV FAILs and exit 1. | Make Draft scaffolding placeholder-tolerant or delay materialization/activation appropriately; add generator and CLI E2E for `claude_design`. |
| CR-015 | Medium | Open | §M4 item 2, §12 Config mutation | `scripts/lib/externalization-validator.ps1:42-47,99-102` reads nonexistent `$policyEnums.sensitive_paths` instead of `policy.permissions.sensitive_paths`, always uses a hardcoded fallback, and misses nested `.env`/`id_rsa`. | Load the real policy value, match basename/nested paths safely, fail closed on malformed patterns, and prove the config is load-bearing with nested-path mutations. |
| CR-016 | Medium | Open | §M8 host verification, portability guide §7 | UTF-8-sensitive reads omit `-Encoding UTF8` in `externalization-validator.ps1:83`, `design-provider-validator.ps1:91,152,168,226`, and `research-validator.ps1:52,76,128,191`. | Use explicit UTF-8 for every digest/path/heading/reference-bearing read and add a non-ASCII Windows PowerShell 5.1 regression fixture. |
| CR-017 | High | Open | §M4 governed boundary, §M5 input containment, §14 Security | Lexical `GetFullPath().StartsWith(root)` checks in `externalization-validator.ps1:143-152`, `design-provider-validator.ps1:125-134`, and `research-validator.ps1:111-116` follow symlinks/junctions outside the project. A repo-relative symlink to `/etc/hosts` passed EXT-001..004. | Resolve and compare physical targets (including Windows reparse points), reject boundary escapes, and add symlink/junction regression coverage without echoing external content. |
| CR-018 | High | Open | §M8 line-ending tests, §14 DoD | New input/output digests use raw `Get-FileHash` (`design-provider-validator.ps1:55-66,120-140`; `externalization-validator.ps1:149-153`). LF→CRLF conversion changed every provider digest and made current evidence stale. | Define one shared canonical hashing convention: normalize governed text extensions while hashing binary bytes; cover LF/CRLF, UTF-8/BOM, non-ASCII, input, output, and externalization artifacts. |
| CR-019 | Medium | Open | §M7 status | `scripts/pmo-status.ps1:72-90` reports the accepted canonical review as `preparing`, treats file existence as review state, calls completed research merely `active`, and counts only `proposed` changes (approved/unimplemented changes disappear). | Derive validated lifecycle/freshness from artifacts and diagnostics, count every nonterminal governed change, and expose the next Human gate or automated action explicitly; add Text/JSON status tests. |
| CR-020 | Medium | Open | §M8 canonical example | `examples/OPTIONAL-TRACKS/HANDOFF.md:1,6` and `HANDOFF-REVIEW.json:3` still say `HANDOFF-DEMO`; the review digest is stale. Handoff result: 55 PASS, 1 blocking WARN, 2 FAIL. | Correct project identity, recompute review digests, and make the canonical example pass Handoff with `-FailOnWarning`; register that gate in the suite. |
| CR-021 | Medium | Open | §M8 Full verification, §12, §14 | Coverage lacks optional generator E2E, active-track Handoff/Release, status tests, M4–M6 nested policy mutations, new digest line-ending/UTF-8 tests, and cross-host CI. `V2.1` push has no run because workflow push triggers only `main`; `gh run list --branch V2.1` returned none. | Add the missing layers, dispatch/PR the existing Windows PS5.1/Windows pwsh/Linux/macOS matrix under Human direction, and record actual results. A green existing `run-all-checks` is necessary but not sufficient because these paths are absent. |
| CR-022 | Low | Open | §M8 README/report accuracy | README labels all three tracks **Shipped** despite open High findings; Quick Start remains far below the mental model; `FreeBuff_fixed-update.md` inaccurately describes M4 enums/mode/scope and omits explicit Feyman outcome/limits. The example implies provider/Human events without a synthetic-fixture banner. | Keep status claims experimental/in-review until closure, move Quick Start as planned, correct FB-001 evidence, mark example evidence explicitly synthetic, and record Feyman as integrated/unavailable/deferred—never implied. |

**Independent reproduction and validation evidence**

| Check | Result | Notes |
|---|---|---|
| Clean control | Pass | `examples/OPTIONAL-TRACKS`, Standard/Design: 40 PASS, 0 WARN, 0 FAIL |
| FreeBuff CR-001..006 mutations | Reproduced | All six behaviors matched the candidate report; mutations lived only in temporary copies |
| Missing design review at Handoff | Defect reproduced | DPROV-002..007 all PASS despite absent provider `REVIEW.json` |
| Empty/outside provider output | Defect reproduced | DPROV-005/006 PASS after empty-set digest and output moved outside `OUTPUT/**` |
| Research authority mutations | Defect reproduced | Accepted Impact without proposals and rejected proposals without DEC both passed Scope |
| Boundary escape | Defect reproduced | Repo-relative symlink to an external file passed EXT-001..004 |
| Optional generator | Defect reproduced | Standard + guided/feyman + `claude_design` creation exited 1 at Draft with five DPROV failures |
| Canonical example Handoff | Failed | 55 PASS, 1 blocking WARN, 2 FAIL (`HANDOFF-014` x2; stale `HANDOFF-010`) |
| Line-ending mutation | Defect reproduced | Input combined digest and output digest changed after LF→CRLF only |
| M4–M6 helper | Pass | Current committed helper assertions pass; they do not cover the failing paths above |
| Doctor / public hygiene / plugin mirror | Pass | Doctor 61/61; hygiene pass; generated skill mirror 1/1 |
| Git/CI state | Incomplete | Worktree was clean at `a6fbca8`; no GitHub Actions run exists for branch `V2.1` |

**Required FB-002 repair order**

1. **P0 authority/security:** CR-007 through CR-012 and CR-017. Close the
   Human-acceptance, output, Change Control, externalization binding, Research
   authority, and physical-containment bypasses first.
2. **P1 integrity/portability:** CR-001 through CR-005, CR-013 through CR-016,
   and CR-018. Add each negative mutation before declaring the rule closed.
3. **P1 workflow truthfulness:** CR-019 through CR-021. Make the generator,
   status, canonical Handoff, and missing verification layers prove the actual
   workflow.
4. **P2 truthful presentation:** CR-006 and CR-022, plus corrections to every
   affected concept/rule page, skill, README row, and FB-001 claim.
5. Run targeted suites after each group, then the full local suite. Cross-host
   CI remains pending until Human-directed dispatch/PR evidence exists.

**Review summary**

- Status: **Changes required; return to FreeBuff for FB-002.**
- Existing passing suites are credible for the paths they exercise, but they
  do not establish M4–M8 Definition of Done.
- Growth budget itself is respected: four new-domain validator modules total,
  one canonical example, one M4–M6 helper, no new skill, and the generated
  skill mirror is current.
- No implementation fix, Human approval, merge, tag, release, or deployment
  was performed during this Codex review.

**Closure evidence**

All `CR-001`..`CR-022` findings remain open pending FB-002 evidence. Codex will
close a finding only after the corresponding mutation and applicable full-suite
evidence pass on the reviewed commit. CR-005 additionally awaits the Human
Owner's Internal-provider default decision.

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
