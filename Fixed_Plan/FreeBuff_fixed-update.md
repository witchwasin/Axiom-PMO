# FreeBuff Implementation Update

> **Purpose:** FreeBuff AI records each implementation pass against `master-plan.md` here. Codex reviews this file and the associated branch diff, then writes feedback in `Codex_Review-Feedback.md`.
>
> **Working branch:** `V2.1`
>
> **Human approval:** Only the Human Owner may approve scope, release, merge into `main`, or any external action that needs human authority.

## Working agreement

1. Read `master-plan.md` before editing. For every pass after Codex's first review, also read the latest unresolved entries in `Codex_Review-Feedback.md`.
2. **Current handoff scope:** Codex has completed M0–M3. FreeBuff must continue with the remaining pending M4–M8 items from `master-plan.md`; do not redo or silently weaken the completed M0–M3 contracts.
3. For the FreeBuff continuation, execute the remaining approved milestones autonomously, then update this file with all work and validation evidence. Push only when the Human Owner explicitly authorizes the external push for that pass; this Codex handoff itself is local-commit-only.
4. After the first Codex review, resolve its findings in subsequent end-to-end correction passes, record the response here, and push each completed correction pass for the next review.
5. Work only within the approved plan. Do not infer a product decision or silently add scope.
6. For every completed change, provide the plan reference, affected paths, validation evidence, commit SHA, and push status below.
7. Always write paths relative to the repository root (for example, `Fixed_Plan/master-plan.md` or `scripts/validate-project.ps1`). Never use a machine-specific absolute path.
8. Do not merge into `main`, tag, publish, deploy, or represent AI work as human approval.
9. Keep previous update entries intact. Add a new dated iteration for each pass.

## Current status

| Field | Value |
|---|---|
| Overall status | FB-003 complete — final repair batch (CR-018/019/006/013/021/022) implemented with tests; ready for Codex review. Full `run-all-checks` not run to completion in this batch. |
| Current implementation iteration | FB-003 |
| Latest commit on `V2.1` | See FB-003 Git handoff table below |
| Latest push to `origin/V2.1` | Yes — FB-003 pushed (Human Owner authorized push for this plan's work) |
| Blocking question for Human Owner | CR-005 — Internal externalization default. Provisional: `internal_default_human_review: true` (force Human review). Flip the single policy key to opt out. Pending Human Owner decision; not AI-approved. |

## Update template — add one section per implementation pass

### Iteration FB-001 — YYYY-MM-DD

**Status:** In progress / Ready for Codex review / Blocked

**Plan items addressed**

| Plan reference | What changed | Affected paths | Evidence status |
|---|---|---|---|
| `master-plan.md` §… | … | `path/to/file` | supported / verified / inferred / missing / conflict |

**Validation performed**

| Check | Command or method | Result | Evidence / notes |
|---|---|---|---|
| … | … | Pass / Fail / Not run | … |

**Git handoff**

| Field | Value |
|---|---|
| Commit SHA(s) | — |
| Pushed to `origin/V2.1` | Yes / No |
| Compare / PR link (if any) | — |

**Open questions, assumptions, or blockers**

- None. (Replace this if applicable; include the relevant plan reference and why a Human Owner decision is needed.)

**Response to Codex feedback**

| Feedback ID | Response | Resulting change or reason not changed |
|---|---|---|
| — | — | — |

### Iteration FB-001 — 2026-08-14

**Executor:** FreeBuff (continuing from Codex commit `4893691`; M0–M3 contracts preserved unchanged).

**Status:** Ready for Codex review round

**Plan items addressed**

| Plan reference | What changed | Affected paths | Evidence status |
|---|---|---|---|
| `master-plan.md` M4 — Externalization Gate MVP | Policy-owned externalization classifications (`Public`/`Internal`/`Confidential`/`Restricted`) and approval statuses added to orchestration policy; `EXTERNALIZATION.json` registry contract (activated by file existence, not mode — no `scope` template field; sensitive-payload checks; downstream freshness); validator + rule pages + concept doc | `pmo-config/orchestration-policy.json`, `templates/EXTERNALIZATION.json`, `scripts/lib/externalization-validator.ps1`, `docs/rules/EXT-001.md`, `docs/rules/EXT-002.md`, `docs/rules/EXT-003.md`, `docs/rules/EXT-004.md`, `docs/concepts/externalization.md` | verified |
| `master-plan.md` M5 — Claude Design optional workflow | `DESIGN-PROVIDER-INPUT.json`/`DESIGN-PROVIDER-REVIEW.json` manifests; digest recompute tool; validator enforcing input/out-of-scope/owner-token/conflict/preflight/acceptance/stale-output/routing rules; `claude_design` declared per project via `new-project.ps1` materialization; rule pages + concept doc | `templates/DESIGN-PROVIDER-INPUT.json`, `templates/DESIGN-PROVIDER-REVIEW.json`, `scripts/design-provider-digest.ps1`, `scripts/lib/design-provider-validator.ps1`, `docs/rules/DPROV-002.md`, `docs/rules/DPROV-003.md`, `docs/rules/DPROV-004.md`, `docs/rules/DPROV-005.md`, `docs/rules/DPROV-006.md`, `docs/rules/DPROV-007.md`, `docs/concepts/claude-design-workflow.md`, `scripts/new-project.ps1` | verified |
| `master-plan.md` M6 — Guided Research MVP | `RESEARCH.md` report + `RESEARCH-PROVENANCE.json` provenance registry; validator enforcing report presence, claim-to-source mapping, accepted-impact proposal resolution, provider-fallback truthfulness, external-provider gating; rule pages + concept doc | `templates/RESEARCH.md`, `templates/RESEARCH-PROVENANCE.json`, `scripts/lib/research-validator.ps1`, `docs/rules/RESEARCH-002.md`, `docs/rules/RESEARCH-003.md`, `docs/rules/RESEARCH-004.md`, `docs/rules/RESEARCH-005.md`, `docs/rules/RESEARCH-006.md`, `docs/rules/RESEARCH-007.md`, `docs/concepts/research-workflow.md` | verified |
| `master-plan.md` M7 — Cross-capability routing, ownership, status | `CONTEXT-ROUTER.md` read sets extended (system design, mode-specific testability); executor/accountable/human-touchpoint/output rows for externalization/research/claude-design tracks; `pmo-status.ps1` now reports research state, `ui_delivery` state, open change requests, and provider review status | `CONTEXT-ROUTER.md`, `docs/concepts/end-to-end-workflow.md`, `scripts/pmo-status.ps1` | verified |
| `master-plan.md` M8 — README, canonical example, MIGRATION, verification suite | README reflects live optional tracks; MIGRATION updated; canonical example (`Standard` + guided research + Claude Design + 1 change request) created and validated; m4-m6 contract suite registered in `run-all-checks.ps1`; pre-existing M1 placeholder mismatches in e2e filler fixed (see notes) | `README.md`, `MIGRATION.md`, `examples/OPTIONAL-TRACKS/`, `tests/helpers/m4-m6-tests.ps1`, `scripts/run-all-checks.ps1`, `tests/e2e/lib/fill-project.ps1` | verified |
| `master-plan.md` M4–M6 wiring | Three new validators wired into the project gate; rule catalog (`validation-rules.json`) extended so `pmo-doctor` rule checks cover EXT/DPROV/RESEARCH pages; skills extended (governance/intake/design/delivery) and `skills/` mirror regenerated | `scripts/validate-project.ps1`, `pmo-config/validation-rules.json`, `.claude/skills/pmo-governance/SKILL.md`, `.claude/skills/pmo-intake/SKILL.md`, `.claude/skills/pmo-design/SKILL.md`, `.claude/skills/pmo-delivery/SKILL.md`, `skills/pmo-governance/SKILL.md`, `skills/pmo-intake/SKILL.md`, `skills/pmo-design/SKILL.md`, `skills/pmo-delivery/SKILL.md` | verified |

**Validation performed**

| Check | Command or method | Result | Evidence / notes |
|---|---|---|---|
| Doctor | `scripts/pmo-doctor.ps1` | Pass | 61 PASS / 0 WARN / 0 FAIL |
| Golden validation | `scripts/run-validation-tests.ps1 -VerifyGolden` | Pass | 158/158 cases |
| Public hygiene | `scripts/check-public-hygiene.ps1` | Pass | No finding (test secret literal made dynamic) |
| M4/M5/M6 contract suite | `tests/helpers/m4-m6-tests.ps1 -RepoPath .` | Pass | 24/24 assertions: EXT/DPROV/RESEARCH positive & negative mutations |
| Canonical example gate | `scripts/validate-project.ps1 -ProjectPath examples/OPTIONAL-TRACKS` | Pass | 24 checks / 0 FAIL (Standard + guided research + Claude Design + 1 CR) |
| Full verification | `scripts/run-all-checks.ps1` | Pass | All suites green, exit 0: doctor 61, golden 158, config-mutation 27, setup-integration 229, plugin-package 41, e2e-lite 15, e2e-standard/strict/handoff, github-action 71, plus m4-m6-contracts |
| e2e regression check | `tests/e2e/lite.ps1` at baseline `4893691` (worktree) | Confirmed pre-existing | `PLACEHOLDER-001` at Release gate reproduced at baseline before the fix; root cause was M1 template tokens the filler had not replaced (see notes) |
| Plugin mirror | `scripts/build-plugin-package.ps1 -Check` (via doctor) | Pass | Regenerated `skills/` mirror matches `.claude/skills/` |

**Notes on issues found and fixed during this pass**

- `e2e-lite`/`e2e-standard`/`e2e-strict`/`e2e-handoff`/`e2e-scope` failed at baseline `4893691` (reproduced in a worktree of the unchanged Codex commit) because the M1 templates introduced new tokens — the `Design Ready` role placeholder, removal of `FLOW.puml`, and the BUILD-SPEC Test Strategy tables — that `tests/e2e/lib/fill-project.ps1` did not yet replace. Fixed the filler; this was an M0–M3 test-helper gap, not a contract change. Recorded as pre-existing rather than claiming it as new work.
- Two validator bugs found while validating the canonical example: PowerShell array-to-`[string]` coercion and culture-formatted `DateTime` from `ConvertFrom-Json` caused false failures in `EXT-001`/`DPROV-002`; fixed in `scripts/lib/externalization-validator.ps1` and `scripts/lib/design-provider-validator.ps1`.
- A setup-integration "exception" seen mid-pass was a log line inside a passing test; the suite finishes 229/229.
- **Feyman outcome (explicit, per `master-plan.md` §12):** Feyman is **not integrated** — no local Feyman path was supplied and verified, so no adapter was written or executed. Only the provider contract and the truthful resolution order (configured path → environment path → approved web fallback → actionable stop) are implemented; the research provider contract reports `unavailable`/fallback honestly and never downloads or executes Feyman (`D3`). Status: **unavailable/deferred — never implied as integrated.**
- No M0–M3 contract was changed. No merge into `main`, no tag, no deploy, no publish.

**Git handoff**

| Field | Value |
|---|---|
| Commit SHA(s) | `05f04b5` (M4–M8 implementation + FB-001 update) |
| Pushed to `origin/V2.1` | Yes — Human Owner authorized push for this plan's work |
| Compare / PR link (if any) | — |

**Open questions, assumptions, or blockers**

- None. The pre-existing e2e failures were test-helper gaps at baseline `4893691`; the plan itself did not block this pass.

**Response to Codex feedback**

| Feedback ID | Response | Resulting change or reason not changed |
|---|---|---|
| Review CX-002 | No open findings for M0–M3; continued with M4–M8 as instructed | M4–M8 implemented above without touching M0–M3 contracts |

### Iteration FB-002 — 2026-08-15

**Executor:** FreeBuff — repair batch per Codex Review CR-002 (P0 authority/security + selected P1), waiting on the CR-005 Human decision.

**Status:** Partial — P0 batch closed; CR-005 provisional; remaining P1/P2 findings open for the next batch.

**Plan items addressed**

| Plan reference | What changed | Affected paths | Evidence status |
|---|---|---|---|
| CR-017 (P0) | Physical containment: new shared helper resolves every path component (intermediate symlinks/junctions included) and the root itself before comparing; boundary escapes are rejected, never read or hashed | `scripts/lib/path-containment.ps1` (new), `scripts/validate-project.ps1`, `scripts/lib/externalization-validator.ps1`, `scripts/lib/design-provider-validator.ps1`, `scripts/lib/research-validator.ps1` | verified — symlink escape rejected in EXT-001/DPROV-003 (m4-m6 mutations) |
| CR-007 (P0) | `claude_design` track at Handoff/Release now requires an existing `REVIEW.json` with a passed, current preflight and a Human `accepted` acceptance | `scripts/lib/design-provider-validator.ps1` | verified — missing review at Handoff fails DPROV-005 |
| CR-008 (P0) | Declared output inventory in `REVIEW.json`; every declared output must exist under `OUTPUT/**` with a current digest, every actual file must be declared, reviewed output must be non-empty | `scripts/lib/design-provider-validator.ps1`, `templates/DESIGN-PROVIDER-REVIEW.json`, `scripts/design-provider-digest.ps1`, `examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/REVIEW.json` | verified — missing/undeclared/stale output fails DPROV-005 |
| CR-009 (P0) | Change Control routing is derived from impact/lens (never a self-asserted boolean); findings schema + resolved-decision checks; an accepted baseline cannot coexist with an unresolved technical/scope finding | `scripts/lib/design-provider-validator.ps1` | verified — open technical finding with `routes_to_change_control=false` fails DPROV-007 |
| CR-010 (P0) | Manifest/registry binding: cited EXT entry must be approved, name the same provider, and carry the exact outgoing path+digest payload; canonical minimum inputs (PROJECT.md, BUILD-SPEC when present); raw `source/**` inputs need a governed justification | `scripts/lib/design-provider-validator.ps1`, `scripts/lib/research-validator.ps1`, `templates/DESIGN-PROVIDER-INPUT.json` | verified — payload/provider mismatch fails DPROV-004; research provider mismatch fails RESEARCH-007 |
| CR-011 (P0) | Impact Assessment is parsed: finding refs must be real claims, maps-to/impact/status validated, accepted impacts must resolve through a Change Proposal with a Human disposition | `scripts/lib/research-validator.ps1`, `templates/RESEARCH.md`, `examples/OPTIONAL-TRACKS/RESEARCH/RESEARCH.md` | verified — accepted impact without proposal fails RESEARCH-004 |
| CR-012 (P0) | Accepted AND rejected proposals need a named Human owner + resolvable decision; only `proposed` is unresolved (CR-004) and blocks Scope | `scripts/lib/research-validator.ps1` | verified — rejected without decision fails RESEARCH-004 |
| CR-001 (P1) | Preflight must speak for the current manifest: `preflight.manifest_digest` compared to the recomputed combined digest | `scripts/lib/design-provider-validator.ps1` | verified — stale manifest digest fails DPROV-005 |
| CR-002 (P1) | `network_transfer_occurred` is a required JSON boolean | `scripts/lib/externalization-validator.ps1`, `templates/EXTERNALIZATION.json` | verified — omission fails EXT-001 |
| CR-003 (P1) | Repo-local source refs are anchored: MOM/REQ resolve against the Source Snapshot/`source/**`, DEC against the decision registry, TR/ISSUE/PR against the project record | `scripts/lib/research-validator.ps1` | verified — forged `MOM-99999999` fails RESEARCH-003 |
| CR-005 (P1, provisional) | Blanket approval trigger removed (Public proceeds under policy); Internal default is data-driven via `externalization.internal_default_human_review: true` pending the Human decision; Confidential/Restricted + non-clean scan + explicit declaration still require Human evidence | `scripts/lib/externalization-validator.ps1`, `pmo-config/orchestration-policy.json` | verified — Public approved passes EXT-002; Internal without evidence fails EXT-002; policy key is load-bearing |
| CR-013 (P1, partial) | Provider enum/declaration agreement, required provider booleans, `retrieved_at` shape, and report-section existence for claims | `scripts/lib/research-validator.ps1` | verified |
| CR-015 (P1) | Sensitive-path patterns now read from `policy.permissions.sensitive_paths` and match basenames at any depth (nested `.env` caught), fail closed on malformed patterns | `scripts/lib/externalization-validator.ps1` | verified — nested `source/.env` fails EXT-003 |
| CR-016 (P1) | Explicit `-Encoding UTF8` on every digest/heading/reference-bearing read in the three validators | `scripts/lib/externalization-validator.ps1`, `scripts/lib/design-provider-validator.ps1`, `scripts/lib/research-validator.ps1` | verified |
| CR-020 (P1) | Canonical example identity corrected (`HANDOFF-DEMO` → `OPTIONAL-TRACKS` across docs) and handoff digests recomputed; Handoff now passes with `-FailOnWarning` | `examples/OPTIONAL-TRACKS/**` | verified — Handoff 57 PASS / 0 WARN / 0 FAIL |
| CR-014 (P1) | Draft gate is placeholder-tolerant for the generator's scaffolding manifests | `scripts/lib/design-provider-validator.ps1` | verified (Draft returns before provider checks) |

**Validation performed**

| Check | Command or method | Result | Evidence / notes |
|---|---|---|---|
| M4/M5/M6 contract suite (extended) | `tests/helpers/m4-m6-tests.ps1 -RepoPath .` | Pass | 39/39 — 24 original + 15 new regression mutations covering CR-001/002/003/005/007/008/009/010/011/012/015/017 |
| Canonical example gates | `scripts/validate-project.ps1 -ProjectPath examples/OPTIONAL-TRACKS` | Pass | Design 40, Scope 37, Handoff 57 with `-FailOnWarning` — all 0 FAIL |
| Doctor | `scripts/pmo-doctor.ps1` | Pass | 61 PASS / 0 WARN / 0 FAIL |
| Public hygiene | `scripts/check-public-hygiene.ps1` | Pass | 1/1 |
| Golden validation | `scripts/run-validation-tests.ps1 -VerifyGolden` | Pass | 158/158 |
| Full verification | `scripts/run-all-checks.ps1` | Pass | All suites green, exit 0 (doctor 61, golden 158, config-mutation 27, setup-integration 229, plugin-package 41, github-action 71, e2e suites, m4-m6-contracts 39) |

**Notes and assumptions**

- CR-005 is implemented provisionally as Option A (force Human review for Internal when no provider-specific policy exists), matching Codex's recommendation and the existing example. It is a one-key policy flip (`internal_default_human_review`); the Human Owner's answer decides the final value. This is a recommendation, not a Human decision.
- Still open (next batch): CR-006 (research stop marker), CR-013 remainder (freshness model), CR-018 (canonical LF/CRLF-stable hashing), CR-019 (status lifecycle/freshness + tests), CR-021 (optional-track E2E + cross-host CI evidence), CR-022 (README/Quick Start/evidence accuracy).

**Git handoff**

| Field | Value |
|---|---|
| Commit SHA(s) | `95f3a7e` (FB-002 P0 repair batch) |
| Pushed to `origin/V2.1` | Yes — Human Owner authorized push for this plan's work |
| Compare / PR link (if any) | — |

**Response to Codex feedback**

| Feedback ID | Response | Resulting change or reason not changed |
|---|---|---|
| Review CR-002 | P0 authority/security batch closed (CR-007..CR-012, CR-017) plus CR-001/002/003/005/013/014/015/016/020; regression mutations added before each rule is declared closed | See plan items above |

### Iteration FB-003 — 2026-08-15

**Executor:** FreeBuff — final repair batch per the Human Owner's single-pass instruction (recorded by Codex in `Fixed_Plan/Codex_Review-Feedback.md`): CR-018, CR-019, CR-006, CR-013 remainder, CR-021, CR-022. CR-005 stays provisional and pending the Human Owner decision.

**Status:** Ready for Codex review — all six assigned findings implemented with regression tests; full `run-all-checks` was not run to completion in this batch (see Validation).

**Plan items addressed**

| Plan reference | What changed | Affected paths | Evidence status |
|---|---|---|---|
| CR-018 (High) | One shared canonical artifact hash helper (`Get-ArtifactSha256`): declared text extensions decode UTF-8, strip only the UTF-8 BOM, normalize CRLF/CR to LF, re-encode UTF-8 without BOM; binary/unknown extensions hash original bytes; no content trimming. Wired into input-manifest digests, review output inventory + output-set digest, and externalization outgoing-artifact digests; the digest tool uses the same helper. Example digests regenerated with the helper. | `scripts/lib/artifact-hash.ps1` (new), `scripts/lib/externalization-validator.ps1`, `scripts/lib/design-provider-validator.ps1`, `scripts/design-provider-digest.ps1`, `examples/OPTIONAL-TRACKS/**` | verified — LF→CRLF, UTF-8 BOM/no-BOM, and non-ASCII stability + binary byte mutation fail (m4-m6 mutations) |
| CR-019 (Medium) | `pmo-status.ps1` reworked: research state (off/active/stopped), provider review state (missing/failed/stale/current) and `ui_delivery` state derived from current validation diagnostics, not file existence; every non-terminal governed change counted (approved-but-unimplemented stays visible); explicit next Human/automated action exposed in both Text and JSON. | `scripts/pmo-status.ps1`, `tests/helpers/status-tests.ps1` (new) | verified — status-tests suite covers lifecycle/freshness/next-action |
| CR-006 (Medium) | Research "actionable stop" contract: `PROVENANCE.json` gains `state` (`active`/`stopped`) with `stop_reason` and `next_action`; Scope is blocked when research is stopped; fallback truthfulness kept (`RESEARCH-006`). | `scripts/lib/research-validator.ps1`, `templates/RESEARCH-PROVENANCE.json`, `examples/OPTIONAL-TRACKS/RESEARCH/PROVENANCE.json`, `pmo-config/orchestration-policy.json` | verified — stopped research blocks Scope; status reports `research_state = stopped` with an actionable next action |
| CR-013 remainder (Medium) | Deterministic freshness model: claim/retrieval timestamps compared by ordinal ISO-8601 string (culture-free, host-independent) instead of `DateTime` parse; provider-declaration agreement and required provider booleans enforced; `retrieved_at` shape validated; report sections must exist for the claims they anchor. | `scripts/lib/research-validator.ps1` | verified — policy mutation suite + research mutations |
| CR-021 (Medium) | Verification layers added and registered: generator E2E (real optional-track generation passes its own Draft gate), active-track Handoff (with `-FailOnWarning`) and Release (M4–M6 rules hold), `status-tests.ps1` suite registered in `run-all-checks.ps1`, nested M4–M6 policy mutations in config-mutation suite, canonical LF/CRLF/BOM/binary hash tests. Cross-host CI (Windows PS5.1, Windows pwsh, Linux, macOS) remains pending Human-directed evidence — no run was obtained. | `tests/helpers/m4-m6-tests.ps1`, `tests/helpers/status-tests.ps1` (new), `tests/helpers/config-mutation-tests.ps1`, `scripts/run-all-checks.ps1` | verified locally — see Validation; cross-host CI listed as pending |
| CR-022 (Low) | README: three optional tracks relabelled **In review (V2.1)** (not Shipped) with an explicit "not shipped until reviewed to closure and Human-accepted" note; Quick Start moved next to the top, immediately after the mental model (master-plan §M8 work item 9). `FreeBuff_fixed-update.md` FB-001 M4 row corrected (actual classifications `Public`/`Internal`/`Confidential`/`Restricted`; activation by file existence, not mode; no `scope` template field). Feyman outcome recorded explicitly: **not integrated — unavailable/deferred, never implied** (no verified local path; only the provider contract and truthful resolution order exist, per `D3`). Canonical example `examples/OPTIONAL-TRACKS` now carries a visible synthetic-fixture banner (PROJECT.md) and the README example line says it is a synthetic fixture. | `README.md`, `Fixed_Plan/FreeBuff_fixed-update.md`, `examples/OPTIONAL-TRACKS/PROJECT.md` | verified — example digests regenerated after the banner; Design/Handoff still green |

**Validation performed (all commands actually run in this batch)**

| Check | Command or method | Result | Evidence / notes |
|---|---|---|---|
| Canonical example — Design | `scripts/validate-project.ps1 -ProjectPath examples/OPTIONAL-TRACKS -Mode Standard -Gate Design -FailOnWarning` | Pass | 40 PASS / 0 WARN / 0 FAIL (after banner + digest regeneration) |
| Canonical example — Handoff | `scripts/validate-project.ps1 -ProjectPath examples/OPTIONAL-TRACKS -Mode Standard -Gate Handoff -FailOnWarning` | Pass | 57 PASS / 0 WARN / 0 FAIL |
| Canonical example — Release (M4–M6 only) | `scripts/validate-project.ps1 -ProjectPath examples/OPTIONAL-TRACKS -Mode Standard -Gate Release` | M4–M6 hold | 10 FAILs are pre-existing example-scope rules only (`APPROVAL-001` x1, `RELEASE-STATUS-001` x4, `REVIEW-001` x4, `STRUCT-001` x1); zero EXT/DPROV/RESEARCH FAILs — same position recorded in FB-002 |
| M4/M5/M6 contract suite | `tests/helpers/m4-m6-tests.ps1` | Pass | All assertions PASS, including new CR-018 LF/CRLF/BOM/binary, stopped-research, generator E2E, Handoff/Release, and stale-digest mutations |
| Status suite (new) | `tests/helpers/status-tests.ps1` | Pass | 14/14 — lifecycle, freshness, next-action, Text and JSON output |
| Config mutation suite | `tests/helpers/config-mutation-tests.ps1` | Pass | 21/21, including new nested M4–M6 policy mutations (policy remains load-bearing) |
| Doctor | `scripts/pmo-doctor.ps1` | Pass | 61 PASS / 0 WARN / 0 FAIL |
| Public hygiene | `scripts/check-public-hygiene.ps1` | Pass | 1/1 |
| Golden validation | `scripts/run-validation-tests.ps1 -VerifyGolden` | Pass | 158/158; 153/153 golden cases match |
| Full verification | `scripts/run-all-checks.ps1` | **Not run to completion** | Aborted twice by the Human Owner's Stop during this batch. Every constituent suite that ran in this batch passed individually (see rows above). The remaining cross-host CI evidence was not obtained. Not claimed as green. |

**Finding-by-finding closure**

| Finding | Status | Evidence |
|---|---|---|
| CR-018 | Closed (implemented + mutation-tested) | shared `Get-ArtifactSha256`; LF/CRLF, BOM/no-BOM, non-ASCII, binary-byte mutations in m4-m6; example digests regenerated |
| CR-019 | Closed (implemented + suite) | `pmo-status.ps1` derives state from diagnostics; `status-tests.ps1` 14/14 |
| CR-006 | Closed (implemented + suite) | stopped contract + Scope block; status reports `stopped` with next action |
| CR-013 remainder | Closed (implemented + suite) | ordinal ISO comparison; provider agreement; `retrieved_at` shape; report-section existence |
| CR-021 | Partially closed | Local layers (generator E2E, Handoff/Release, status, nested policy mutations, canonical hash) done and registered; **cross-host CI evidence pending Human-directed dispatch/PR** |
| CR-022 | Closed (implemented) | README status/Quick Start corrected; FB-001 M4 claims corrected; Feyman recorded as unavailable/deferred; example marked visibly synthetic |
| CR-005 | **Open — pending Human Owner decision** | `externalization.internal_default_human_review: true` retained as the safe compatibility default; load-bearing test kept; this is a recommendation, not a Human approval |

**Notes and assumptions**

- CR-005 remains explicitly pending the Human Owner's decision. FreeBuff has not approved it and does not present it as approved; the safe default stays `true` until the Owner decides.
- Feyman is **not integrated**: no verified local Feyman path was supplied, no adapter was written, and nothing downloads or executes Feyman (`master-plan.md` `D3`). Status: unavailable/deferred — never implied.
- Cross-host CI evidence (Windows PowerShell 5.1, Windows pwsh, Linux, macOS) is listed as pending Human-directed evidence; nothing in this report claims a run that was not actually obtained.
- No merge into `main`, no tag, no release, no deploy, no publish, and no Human approval was performed by FreeBuff.

**Git handoff**

| Field | Value |
|---|---|
| Commit SHA(s) | `3620659` (FB-003 final repair batch + FB-003 report) |
| Pushed to `origin/V2.1` | Yes — Human Owner authorized push for this plan's work |
| Compare / PR link (if any) | — |

**Response to Codex feedback**

| Feedback ID | Response | Resulting change or reason not changed |
|---|---|---|
| Review CR-003 single-pass assignment | All six assigned items implemented; local verification above; cross-host CI and CR-005 left as recorded pending items, exactly as instructed | See plan items and closure table above |

### Iteration CX-001 — 2026-08-14

**Executor:** Codex (replacing FreeBuff; FreeBuff is stopped and must not push to `V2.1`).

**Baseline evidence**

| Check | Result | Notes |
|---|---|---|
| `tests/helpers/plugin-package-tests.ps1` | Initially failed | `plugin.json` declared `1.5.0` while `VERSION` declared `2.0.0`. |
| `tests/helpers/plugin-package-tests.ps1` | Passed (41/41) | Corrected release metadata to `2.0.0`. |
| `scripts/pmo-doctor.ps1` | Passed (59/59) | Versioned config metadata is now consistent. |
| `scripts/check-public-hygiene.ps1` | Passed | No hygiene finding. |

**Current work**

- M0 baseline repair is complete: plugin/config release metadata drift was corrected and the decision authority was recorded in `decision-log.md`.
- M1 is complete: `pmo-config/orchestration-policy.json`, compatibility defaults, project declarations, generator/CLI/status routing, README actor flow, and legacy silence are implemented.
- M2 is complete: `CHANGE-REQUESTS.json` is conditional; structure, references, named-Human decisions, mode-sensitive blocking, downstream freshness, and execution-contract re-export evidence for governed AI execution are enforced.
- M3 is complete: Standard/Strict projects create `DESIGN/BUILD-SPEC.md` early; flow/wireframe remain conditional; the canonical Test Strategy lives in BUILD-SPEC and is checked for Standard/Strict explicit declarations, with stricter Level coverage in Strict.
- M4–M8 are intentionally pending for FreeBuff: Externalization, Claude Design provider package, Guided Research, cross-capability status refinements, final docs/example work, and release preparation.
- Paths in all evidence remain relative to the repository root.

### Iteration CX-002 — 2026-08-14

**Executor:** Codex

**Status:** Ready for FreeBuff continuation after M3

**Plan items addressed**

| Plan reference | What changed | Affected paths | Evidence status |
|---|---|---|---|
| `master-plan.md` M1 | Added policy-owned declarations/defaults, generator/CLI/status routing, conditional UI artifacts, actor flow, and legacy compatibility | `pmo-config/orchestration-policy.json`, `templates/PROJECT.md`, `scripts/new-project.ps1`, `cli/axiom.mjs`, `scripts/pmo-status.ps1`, `README.md`, `docs/concepts/end-to-end-workflow.md`, `MIGRATION.md` | verified |
| `master-plan.md` M2 | Added conditional Change Control registry and Human-authority/downstream freshness checks | `templates/CHANGE-REQUESTS.json`, `scripts/lib/change-control-validator.ps1`, `scripts/validate-project.ps1`, `docs/concepts/change-control.md`, `docs/rules/CHANGE-*.md` | verified |
| `master-plan.md` M3 | Added early BUILD-SPEC/Test Strategy contract with mode-aware validation and conditional Handoff enforcement | `templates/BUILD-SPEC.md`, `pmo-config/handoff-policy.json`, `scripts/lib/handoff-validator.ps1`, `docs/rules/TEST-DESIGN-*.md` | verified |
| Plan growth budget | Kept four new domain validators: Change Control; Externalization/Research/Claude Design remain for the next owner; declarations live in config loader and Test Strategy in handoff validator | `scripts/lib/config-loader.ps1`, `scripts/lib/handoff-validator.ps1` | verified |

**Validation performed**

| Check | Command or method | Result | Evidence / notes |
|---|---|---|---|
| M2/M3 contract matrix | `tests/helpers/m2-m3-tests.ps1` | Pass | Positive patch; unresolved/approved/implemented Change mutations; downstream digest; Standard/Strict Test Strategy mutations; legacy silence |
| Config mutation | `tests/helpers/config-mutation-tests.ps1` | Pass | Orchestration enum mutation fails specifically on `RESEARCH-001` |
| Validation fixtures | `scripts/run-validation-tests.ps1 -VerifyGolden` | Pass | 158/158 cases; 153 golden comparisons match |
| Doctor | `scripts/pmo-doctor.ps1` | Pass | 61 PASS / 0 WARN / 0 FAIL |
| Plugin mirror | `scripts/build-plugin-package.ps1 -Check` | Pass | 7 generated skill files match source |

**Handoff instructions for FreeBuff**

1. Start from the local commit listed in the Git handoff table below on branch `V2.1`.
2. Read `Fixed_Plan/master-plan.md`, then unresolved rows in `Fixed_Plan/Codex_Review-Feedback.md` before changing files.
3. Continue only M4–M8. Use repository-relative paths in every update.
4. Add the M4–M8 implementation evidence as a new iteration below this entry; preserve CX-001 and CX-002 history.
5. Do not merge into `main`, fabricate Human decisions, or claim Definition of Done until the Human Owner reviews the complete loop.

**Git handoff**

| Field | Value |
|---|---|
| Commit SHA(s) | Branch HEAD for CX-002; supplied in the Human handoff message after commit creation |
| Pushed to `origin/V2.1` | No |
| Next working branch | `V2.1` |

### Iteration RCI-001 — 2026-08-15 (risk-based CI execution)

**Status:** Ready for Codex/Human review — implementation + local evidence complete; cross-host CI evidence pending.

**Scope:** Execute `Fixed_Plan/Risk-Based-CI-Execution-Plan.md` against branch `V2.1`. This is a workflow/automation change, not a closure of CR-021. No merge into `main`, no push, no full CI run performed.

**Plan items addressed**

| Plan reference | What changed | Affected paths | Evidence status |
|---|---|---|---|
| §1 workflow profiles | `pmo-checks.yml` resolves `fast`/`targeted`/`full` from a `determine-profile` job; `workflow_dispatch` gains `profile`/`suite`/`host` inputs; `full` (4 required hosts + 3 dogfood jobs) unchanged, only when it auto-runs changed | `.github/workflows/pmo-checks.yml` | verified — YAML parses; dispatch inputs present |
| §2 automatic triggers | PR → path-based classification; push-to-main → always `full`; diff failure fails safe to `full`; no default-all-hosts on ordinary work | `.github/workflows/pmo-checks.yml`, `scripts/ci-profile.ps1` | verified — classifier smoke-tested |
| §3 file→suite/host mapping | Single source of truth in `scripts/ci-profile.ps1`; high-risk set (`.github/workflows/**`, `action.yml`, `scripts/lib/**`, `scripts/run-all-checks.ps1`, `scripts/validate-project.ps1`, `scripts/ci-profile.ps1`, `scripts/run-ci-suite.ps1`) → `full`; `scripts/**`/`tests/**` → Windows PowerShell 5.1 + PowerShell 7 minimum | `scripts/ci-profile.ps1`, `docs/architecture/ci-risk-based.md` | verified — 30/30 regression assertions |
| §4 fast checks | `scripts/run-ci-suite.ps1` runs any one named check; fast checks are doctor, hygiene, goldens, plugin drift, CLI | `scripts/run-ci-suite.ps1` | verified — whitelist maps 10 suites; unknown suite rejected |
| §5 dispatch rules / §6 evidence split / §7 docs | SOP written as `docs/architecture/ci-risk-based.md`; README, lessons-learned, powershell-portability updated | `docs/architecture/ci-risk-based.md`, `README.md`, `docs/architecture/lessons-learned.md`, `docs/architecture/powershell-portability.md` | verified — doctor reports no broken links |
| regression test | `tests/helpers/ci-profile-tests.ps1` registered in `run-all-checks.ps1` as `ci-profile` | `tests/helpers/ci-profile-tests.ps1`, `scripts/run-all-checks.ps1` | verified — 30/30 |
| follow-up review (see below) | CI control plane escalated to `full` so the classifier cannot narrow its own guard away; branch-protection consequence of skipped jobs documented | `scripts/ci-profile.ps1`, `tests/helpers/ci-profile-tests.ps1`, `docs/architecture/ci-risk-based.md`, `Fixed_Plan/Codex_Review-Feedback.md` | verified — 30/30 assertions; lone `scripts/ci-profile.ps1` change now resolves to `full` |

**Local validation (PowerShell 7.6.4 on macOS — Windows PowerShell 5.1 cannot run on this host)**

All rows ran against the working tree on top of baseline `18a3aa0` — that is,
the content of this commit, not the baseline commit itself.

| Check | Command | Result |
|---|---|---|
| Profile regression | `pwsh -File tests/helpers/ci-profile-tests.ps1 -RepoPath .` | 30 PASS / 0 FAIL |
| Framework doctor | `pwsh -File scripts/pmo-doctor.ps1 -RepoPath .` | 61 PASS / 0 WARN / 0 FAIL |
| Public hygiene | `pwsh -File scripts/check-public-hygiene.ps1 -RepoPath .` | PASS=1 FAIL=0 |
| Example goldens | `pwsh -File tests/golden/capture-examples.ps1 -RepoPath . -Verify` | all golden outputs match |
| Plugin mirror drift | `pwsh -File scripts/build-plugin-package.ps1 -Check` | PASS (7 files in sync) |
| CLI | `node tests/helpers/cli-tests.mjs` (AXIOM_PWSH set) | 50 PASS / 0 FAIL |
| Syntax parse | `Parser::ParseFile` over the changed/new `.ps1` files | all parse clean |
| Workflow YAML | `yaml.safe_load` over `.github/workflows/pmo-checks.yml` | parses; 10 jobs, 3 dispatch inputs |
| Self-classification | `scripts/ci-profile.ps1 -ChangedPathsPath <this changeset>` | resolves to `full`, all four hosts |
| Full local suite | `pwsh -File scripts/run-all-checks.ps1 -RepoPath .` | Completed; every check passed (last suite `github-action` 71/71) |

`run-all-checks.ps1` is fail-fast: `Invoke-Check` prints `Check failed: <name>`
and exits on the first non-zero child, and the run also exits 1 if a required
check never executed. Reaching the closing line `All Axiom-PMO framework checks
completed.` is therefore the pass evidence. This is the first completed local
aggregate run since `b22bcb0`, the gap Review CX-004 recorded as unfinished —
on **one** host (macOS, PowerShell 7.6.4). It is tier-1 local evidence and is
not cross-host evidence for CR-021.

**Follow-up review before commit**

Two issues were found by reviewing the change above and corrected in the same
working tree. Detail is in `Fixed_Plan/Codex_Review-Feedback.md` under
"Follow-up review of the risk-based CI change".

1. `scripts/ci-profile.ps1` classified itself as `targeted` via the generic
   `scripts/**` rule. Since a pull request classifies its own diff with the
   merge commit's copy of the classifier, an edit that weakened the mapping
   could have selected a cheap profile for itself and skipped
   `tests/helpers/ci-profile-tests.ps1` — the guard for that mapping. The CI
   control plane (`ci-profile.ps1`, `run-ci-suite.ps1`) is now in the high-risk
   set, covered by two added assertions.
2. GitHub reports a **skipped** job as success for required status checks, so
   gating the host jobs on a profile silently changed what an existing required
   check proves. This is the intended trade, but it was undocumented;
   `docs/architecture/ci-risk-based.md` now has a "Branch protection" section
   naming `determine-profile` (the only ungated job) as the check to require.

**Evidence split**

1. **Local verified** — all rows above ran on the executor's macOS machine with PowerShell 7.6.4.
2. **Targeted CI verified** — not run. No dispatch performed; Windows PowerShell 5.1 host is not available locally.
3. **Full cross-host verified** — not run. The post-`ff2f43b` full matrix remains **pending Human-directed dispatch**; this change enables it but does not produce it.

**The workflow itself has never executed.** Local evidence covers the classifier
as a unit only. `determine-profile`, the matrix expansion, and the profile
gating have no runtime evidence, so the plan's acceptance criterion "workflow
เลือก `fast`, `targeted`, `full` ได้จริง" is **not yet met**. A dispatch or pull
request is required before that criterion can be claimed.

CR-021 remains **pending cross-host CI evidence**; the V2.1 Definition of Done is not claimed complete, and nothing above is presented as a full or cross-host pass. Feyman remains `unavailable/deferred`; no integration is claimed.

**Git handoff**

| Field | Value |
|---|---|
| Baseline commit | `18a3aa0a654c5ec5d8ce47163c7387598823b224` |
| Changed files | 11 — 7 modified, 4 added (an earlier draft of this row said 10/6/4; corrected) |
| Commit SHA | Local commit on `V2.1`; supplied in the Human handoff message after commit creation |
| Pushed to `origin/V2.1` | No — pending explicit Human authorization |
| Merge into `main` | Not performed |
| Required next step | Dispatch or open a pull request so the workflow actually runs; see the acceptance-criterion note above |
