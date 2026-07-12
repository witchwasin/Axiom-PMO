# Upgrade Plan v2 (Unified): 8.3 → 9+

> Merges my verified-findings plan with GPT-5.6's engineering plan. Every P0 was
> **reproduced live** on this machine (real PowerShell) before entering this plan.
> Baseline honest score: **8.3/10** (GPT-5.6's published independent verdict — its later
> "7.8" figure was unexplained and is not used). Target: **≥9.0 on the rubric in §9,
> with no floor violated.**
>
> Owner decisions already made (2026-07-12):
> - **Phase 4 full modular refactor: APPROVED** (11 lib modules; regression risk accepted,
>   mitigated by the golden-master control in Phase 4).
> - **Branch protection (§7.4): owner DEFERRED the (A)/(B)/(C) decision (2026-07-12)
>   after learning it is 403-blocked on free-plan private repos. Until resolved, score
>   claims are stated per option (C): "9.x (branch protection unavailable on current
>   GitHub plan; compensating controls documented)". Phases 0–6 proceed regardless.**

---

## 1. Objective

Take `PMO-Template-Personal` from Strong Stable Candidate (8.3) to a provable 9+:
no known validator bypasses, real reference integrity, per-row traceability,
release-completeness enforcement, modular maintainable validator, and CI-enforced gates.

Workflow unchanged: Source → Requirement → Design → Delivery → Build Review → QA → Release.
Principles unchanged: ≤10-person teams; Lite stays genuinely light; humans approve
Scope/Design/Release; AI never commits/pushes/deploys/approves production on its own;
no documents forced without a mode/risk trigger.

## 2. Executor rules

**Never:**
- Edit/delete anything under `source/`, `MOM/`, `REQ/`, `Transcript/`, `Others/`.
- Weaken the validator to make a test pass.
- Hardcode values that belong in central config.
- Force extra mandatory artifacts onto Lite without a trigger.
- Commit or push before human review. **Push requires explicit per-push human
  confirmation — approval to start a phase is NOT push permission** (two prior
  violations on record in `reports/process-violation.md`).
- Claim 9+ from test counts alone.
- Use PS7-only features (`??`, `ConvertFrom-Yaml`, ternary) — runtime is Windows
  PowerShell 5.1. CI-only tooling (PSScriptAnalyzer) may be installed pinned in CI.

**Per-phase loop:** fix → run tests → show diff → human review → human approve →
local commit → no push. After Final Gate: combined human review → push branch
`remediation/9plus-v2` → open PR → remote CI green → merge after approval.

**Check suite after every phase:**
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-all-checks.ps1
```

## 3. Target architecture

Runtime config (JSON only; markdown stays human-facing):
```text
pmo-config/
├── policy.json              (enums, sentinel rules, evidence/reference types)
├── artifact-policy.json     (Mode × Gate artifact matrix — NEW)
├── validation-rules.json    (rule catalog + operative severities)
├── skill-manifest.json
├── reference-types.json     (typed reference regexes — NEW)
└── context-map.json         (converted from .yaml, Mode × Intent structure)
```
Artifacts: `PROJECT.md`, `DELIVERY.md`, `RELEASE.md`, `RAID-log.md`, `decision-log.md`,
**`RTM.json`** (canonical, replaces RTM.yaml — see P2.1), `DESIGN/`, `source/`.
Lite may keep delivery + release notes inside `PROJECT.md` when artifact-policy allows.

---

## Phase 0 — Baseline & safety

1. Record current SHA/branch/working-tree status; create branch `remediation/9plus-v2`.
2. Run doctor + matrix + run-all-checks; record exit codes, PASS/WARN/FAIL counts,
   test-case count (currently 53), active skills (7), file count (428).
3. Write `reports/upgrade-baseline.md` + `reports/upgrade-manifest.md`.
4. Baseline honest score recorded as **8.3**.

**DoD:** baseline from real runs; no user files touched; pre-change diff recorded.

---

## Phase 1 — Validator integrity hotfix

### P1.1 Contain `not_required` (universal bypass — most severe)
**Evidence (live):** approval rows with `Approver/Role/Evidence = not_required` and a
work item with `Owner/AC/Test/Evidence Ref = not_required` passed
`-Gate Release -FailOnWarning` at **PASS=13/0/0 exit 0**.
- Remove the `not_required` whitelist from `Test-PlaceholderValue` (validate-project.ps1 ~l.207).
- New context-aware check `Test-FieldValue -FieldName -Value -Mode -Gate -DesignImpact`.
- Config: `policy.json → sentinel_rules.not_required = { allowed_fields: ["Design Ref"],
  allowed_modes: ["Lite"], conditions: ["design_impact_false"] }`.
- Must-FAIL fixtures: not_required in Approver / Owner / Acceptance Criteria /
  Test Checklist / Evidence Ref / Rollback cells. Must-PASS: Lite + no design impact +
  `Design Ref = not_required`. Reproduce my exact live fixture → must FAIL.
- Rule IDs: `FIELD-001`, `SENTINEL-001`.

### P1.2 Complete user-source segregation + non-blocking warnings
**Evidence:** `Test-UserSourcePath` (l.68) omits `Others/` though AGENTS.md:98 declares
it user-owned; and WARN + `-FailOnWarning` lets `SOURCE-LINK-001`/`SENSITIVE-001` on
un-editable client files block Release.
- Add `Others` to the user-source regex.
- Adopt warning taxonomy: `WARN_BLOCKING` vs `WARN_NON_BLOCKING`
  (config: `warning_behavior.blocking_warning_levels`). `-FailOnWarning` fails only on
  `WARN_BLOCKING`. `SOURCE-LINK-001` → INFO; `SENSITIVE-001` on user source →
  `WARN_NON_BLOCKING` (visible, never blocks); on governed files → `WARN_BLOCKING`.
- Tests: `source/MOM` TODO → Release passes; `Others/` `<customer_id>` → passes;
  `Quotation.pdf` in source → warns, doesn't block; governed TODO → still FAILs.

### P1.3 Effective mode (kill CLI downgrade)
**Evidence (live):** `examples/STRICT-HIGH-RISK` with `-Mode Lite` → PASS 20/0/0,
all Strict checks silently skipped.
- `effective_mode = MAX(cli, project_default, highest_work_item, strict_trigger)`
  with Lite=1 < Standard=2 < Strict=3. CLI may upgrade, never downgrade.
- Output must show: Requested / Detected / Effective / Reason.
- Rules: `MODE-001` (downgrade attempt), `MODE-002` (project conflict),
  `MODE-003` (strict-trigger escalation).
- Tests: strict trigger + `-Mode Lite` → effective Strict; default Strict +
  `-Mode Standard` → Strict; Lite project + `-Mode Strict` → Strict (upgrade OK);
  mixed work items → max.

### P1.4 Mode × Gate artifact matrix (config-driven)
**Evidence (live):** Standard at `-Gate Draft` → FAIL Missing DELIVERY.md/RELEASE.md.
- Move the matrix to `artifact-policy.json` (schema per GPT plan §P1.4: per mode ×
  gate `required` / `required_any` / `conditional` / `optional`; Lite Release =
  `required_any: [[DELIVERY.md],[PROJECT.md#Work Items]]`, RELEASE.md optional;
  Strict Release = DELIVERY + RELEASE + RAID + decision-log + RTM.json +
  qa_approval + security_approval + rollback).
- `task_source: github` at Release: DELIVERY.md may be absent when PROJECT.md declares
  github + repo name; emit `TASK-003` WARN_NON_BLOCKING ("GitHub state not verifiable offline").
- Tests: Standard Draft no RELEASE → pass; Strict Scope no RTM → pass; Standard
  Release no RELEASE → fail; Lite Release with work item + evidence, no RELEASE.md → pass.

---

## Phase 2 — Traceability & artifact contract

### P2.1 Canonical `RTM.json` (supersedes the keep-YAML decision)
Rationale: every RTM artifact must be rewritten for schema unification anyway
(template uses `requirements:/id:/deliverable_ref`, **no release_ref**; validator wants
`requirement_id/delivery_ref/test_ref/release_ref` — a generated Strict project fails
RTM-001 even when filled correctly). Since blast radius is paid regardless, move to
JSON: native `ConvertFrom-Json`, no regex parsing, `schema_version`.
- Schema: `{ "schema_version":"1.0", "traceability":[ { requirement_id, source_ref,
  design_ref, delivery_ref, test_ref, evidence_ref, release_ref, status } ] }`.
- Update in the SAME change: templates, examples, strict fixtures, validator,
  context-map, skills, generator, README, MIGRATION.
- **Row-by-row validation** (not global regex): every project requirement covered;
  each row's refs resolve; no duplicates; no orphans.
- Rules: `RTM-001` invalid schema … `RTM-007` orphan row (per GPT list).
- **Registry definitions (gap fixed — GPT's plan referenced TEST-/REL- IDs with no
  home):**
  - `TEST-###` — declared in RELEASE.md "Test Summary" table, which gains an `ID`
    column. `test_ref` must resolve to a TEST row (or a `FILE:` evidence path).
  - `REL-###` — RELEASE.md header gains `Release ID: REL-001`; `release_ref` must
    match a declared Release ID.

### P2.2 Typed reference resolver
- New `scripts/lib/reference-resolver.ps1`; types in `reference-types.json`:
  `DEC-### / REQ-### / D-### / TEST-### / REL-### / FILE:path / URL:https… /
  ISSUE:n / CI:https…`.
- Local IDs and `FILE:` must resolve for real; external types (`URL/ISSUE/CI`) get
  shape-validation + marked `externally_unverified` (Strict Release: external evidence
  requires human acknowledgement). Free text ("approved-by-email") → FAIL at
  Standard/Strict Release; WARN_BLOCKING at Lite.

### P2.3 Approval evidence integrity + role matrix
- Approval requires: status=approved, approver, role, date, **resolvable Evidence Ref**.
- Role matrix in config (Scope→PO; Design→Tech Lead/Architect; Release→PO/Release
  Manager; QA→QA Lead; Security→Security Reviewer/Tech Lead). Severity nuance for
  small teams: wrong role = **WARN_BLOCKING at Standard, FAIL at Strict**, not checked
  at Lite.
- Tests: DEC-999 → fail; `approved-by-email` → fail; wrong role → per severity above;
  valid Lite approval → pass.

---

## Phase 3 — Release enforcement

### P3.1 Work-item completion
At Release, every work item in scope must be `Status = Done`, review passed, AC and
Test Checklist non-empty, Evidence Ref resolvable, no open blocker. Exclusion:
`release_scope: false` + reason. Rules: `RELEASE-STATUS-001`, `RELEASE-SCOPE-001`,
`TEST-EVIDENCE-001`, `REVIEW-001`.

### P3.2 Structured QA/Security review
Real table contract (`| Review Type | Status | Reviewer | Role | Date | Evidence |`),
parsed row-by-row — replaces the current "the word qa appears somewhere" regex.
Strict: QA + Security approved. Standard: QA approved. Lite: test evidence only,
no separate QA role.

### P3.3 Structured rollback
Every row: Trigger/Owner/Steps/Verification/Evidence Ref real (no `-`, `not_required`,
TBD/TODO/N/A). Lite alternative: `rollback_required: false` + reason + approver, valid
only when the change type is in the config allowlist (e.g. content-only).

---

## Phase 4 — Modular validator refactor *(owner-approved, full)*

Structure per GPT plan: `scripts/lib/{config-loader, markdown-table-parser,
artifact-policy, mode-resolver, reference-resolver, approval-validator,
workitem-validator, rtm-validator, release-validator, source-validator,
result-writer}.ps1`; `validate-project.ps1` = parse params → load config → resolve
mode → invoke modules → aggregate → write Text/JSON → exit code.
Rule results carry `{level, rule_id, artifact, field, item_id, message}`.

**Mandatory regression control (my addition — non-negotiable given the risk):**
1. **Golden master:** AFTER Phase 3 passes (behavior finalized in the monolith),
   run the validator with `-Format Json` across the ENTIRE fixture matrix + examples
   and store outputs under `tests/golden/`.
2. Refactor.
3. Re-run everything; refactored output must match the golden master **exactly**
   (rule ids, levels, per-item results). Any diff = refactor bug, not a chance to
   "improve" behavior. Behavior changes in the same commit as the refactor are forbidden.
4. All modules PS 5.1-compatible; no unnecessary global state.

---

## Phase 5 — Testing upgrade

### P5.1 New negative tests (≥20, each pinned to rule id)
The GPT list verbatim: not_required in approver/AC/test-evidence/rollback; strict
project via `-Mode Lite`; Standard Draft no RELEASE (positive); Strict Scope no RTM
(positive); RTM row-2 missing test; RTM delivery ref missing; free-text approval
evidence; work item In Progress at Release; QA table header-only; security review
pending; evidence file missing; source broken link non-blocking (positive); governed
broken link blocking; `Others/` TODO passing (positive); malformed external evidence;
duplicate release ref; artifact-matrix config mutation.

### P5.2 Generator-to-Release E2E (no example copy-over)
**Evidence:** current E2E copies `examples/STANDARD-FEATURE/*` over the generated
project — which is exactly how the template/validator RTM schema mismatch stayed
invisible. Rebuild: `new-project.ps1` → deterministic fill-in of the **generated
templates** → validate Draft → Scope → Design → Release → cleanup. All 3 modes,
plus: path with spaces, Thai filename, source TODO, mixed work-item modes, strict
escalation, external evidence. Standard/Strict use `-FailOnWarning`.
`new-project.ps1` itself must check `$LASTEXITCODE` and propagate.

### P5.3 Static analysis
CI step: `Invoke-ScriptAnalyzer -Path scripts -Recurse -Severity Error`, PSScriptAnalyzer
version pinned. Runtime keeps zero external dependencies.

### P5.4 CI gate = run-all-checks calls all of:
doctor, matrix, config mutation (must assert expected rule ids, not just non-zero),
fault injection, 3× E2E, generator-to-release, static analysis, version consistency.
Any child failure → master non-zero (already fixed; keep covered by fault injection).

---

## Phase 6 — Context & skills alignment

- Convert `context-map.yaml` → `context-map.json`, Mode × Intent structure (Lite
  qa_release requires PROJECT only; DELIVERY conditional; RELEASE optional — fixes the
  standing Lite conflict).
- 7 skills must reference the same config contracts as the validator. Forbidden in
  skills: hardcoded matrices/enums, read-all-source-by-default, log-every-action,
  RTM/RELEASE.md creation for Lite without trigger, approving releases for humans.

---

## Phase 7 — Governance, versioning, hygiene

### 7.1 CHANGELOG factual error — already fixed in working tree
("main was never affected by either" → violation #1 DID push `37c919b` to main).
Include in this round's first commit.

### 7.2 Versioning
After Final Gate: `VERSION = 0.5.0` (**plain — no `-stable` suffix**; the suffix
pattern was deliberately retired at 0.4.0). Must match CHANGELOG top entry, README,
all `pmo-config/*.json` (`DOCTOR-005`), and current-acceptance. Tag `v0.5.0` after
merge; delete or supersede the stale `v0.4.0-stable-candidate` tag.

### 7.3 Schema versions
Every machine artifact (`RTM.json`, configs) carries `schema_version`; validator
warns/fails on unsupported versions.

### 7.4 Branch protection — **BLOCKED BY PLATFORM PLAN; owner decision required**
Verified 2026-07-12: `gh api .../branches/main/protection` → **403 "Upgrade to GitHub
Pro or make this repository public to enable this feature."** Free-plan private repos
cannot enable branch protection (or rulesets). The owner's earlier choice "(ก) enable"
is not executable as-is. Options:
- **(A) Make the repo public** → protection available free. Requires a privacy
  decision (this repo's docs are synthetic; confirm nothing sensitive) + add LICENSE.
- **(B) Upgrade to GitHub Pro** → protection available on private repo (paid).
- **(C) Stay free+private** → protection impossible; record as a **platform
  constraint** (stronger basis than a waiver): compensating controls = PR-based
  workflow + CI on every PR + the per-push human-confirmation rule. Score is then
  stated as `9.x (branch protection unavailable on current GitHub plan; compensating
  controls documented)`.
When protection becomes available (A/B), apply solo-maintainer settings — **NOT the
generic spec**, which would deadlock a single-owner repo (you cannot approve your own
PR): require PR before merge; required status check `pmo-checks` (verified real
context name); `enforce_admins: true`; **required approvals: 0**; no force push;
no deletions.

### 7.5 LICENSE
Owner decision still open: MIT / proprietary note / none-but-documented. Default if
unanswered: add a "Proprietary — all rights reserved" line to README so the absence
is a decision, not an omission.

---

## Phase 8 — Final Acceptance Gate (no 9+ claim before ALL pass via real runs)

**Validator:** not_required only where config allows · CLI cannot downgrade mode ·
effective mode shows reason · artifacts match Mode×Gate · source warnings never block
unreasonably · RTM per-row chain complete · evidence + approval refs resolve ·
release scope all Done · QA/Security parsed from real rows · rollback rows real.

**Reproduce-my-bypasses (must now FAIL):** the all-`not_required` fixture ·
STRICT-HIGH-RISK via `-Mode Lite` · free-text evidence · non-Done release scope.
**(must now PASS):** Standard at Draft with PROJECT.md only · generated Strict project
with filled templates · `Others/` TODO + `Quotation.xlsx` in source with `-FailOnWarning`.

**Templates/contract:** template=generator=examples=validator on one schema ·
RTM.json canonical · schema_version everywhere · Lite has no artifacts beyond policy.

**Tests:** doctor 0/0 · full positive+negative matrix · config mutation (rule-id
asserted) · fault injection · 3× E2E + generator-to-release E2E · PSScriptAnalyzer
0 errors · everything verified on Windows PowerShell 5.1 · golden-master diff = empty.

**CI/governance:** remote CI green on the exact merge SHA · §7.4 decision recorded
and applied · PR human-approved · working tree clean · current-acceptance cites real
SHA · both process violations resolved · no push happened without explicit per-push
confirmation.

---

## 9. Scoring rubric (final score is computed, with anchors)

| Dimension | Weight |
|---|---:|
| PM Lifecycle & Architecture | 15% |
| Mode Adaptability | 10% |
| AI Runtime & Context | 10% |
| Templates & Artifact Contracts | 10% |
| Validator Correctness | 20% |
| Traceability & Governance | 12% |
| Tests, Tooling & CI | 13% |
| Maintainability & Extensibility | 10% |

**Anchors:** 9.0–9.4 = no open P0, reference integrity real, no known bypass,
one schema everywhere, CI enforces critical tests, governance gate per §7.4 decision.
8.0–8.9 = strong architecture but known bypass/enforcement gap remains.
<8 = shape/keyword-level validation only.

**Floors (no 9+ if any holds):** open P0 · Validator Correctness < 9.0 ·
Tests/CI < 8.8 · reference integrity bypassable · mode downgrade possible ·
RTM not per-row · release passes with non-Done items · templates/validator schema
mismatch · §7.4 unresolved (either protection enabled per (A)/(B), or constraint
formally recorded per (C)).

**Expected progression:** Phase 1 → 8.5–8.7 · Phase 2–3 → 8.8–9.0 ·
Phase 4–5 → 9.0–9.2 · Phase 6–8 → **9.1–9.3**.

---

## 10. Final executor report

Baseline+final SHA · version before/after · files created/modified/moved · rule ids
added/changed · real commands + exit codes · positive/negative/E2E summary · config
mutation results · golden-master result · before/after metrics · known limitations ·
remaining risks · computed score per §9 · git status + diff summary · CI URL/status ·
§7.4 status. No commit/push of final changes before human diff review + approval.

---

## Executor prompt (copy-paste)

```text
คุณคือ Executor ของ repo PMO-Template-Personal
ภารกิจ: ทำตาม reports/upgrade-plan-9plus.md (v2 unified) ทุก Phase (0→8) เพื่อยกคะแนน 8.3 → 9+
อ่านก่อน: reports/upgrade-plan-9plus.md, reports/remediation-plan.md (บริบทรอบก่อน),
  reports/process-violation.md (กฎ push), scripts/validate-project.ps1, scripts/pmo-doctor.ps1
กฎ: ห้ามแตะ source/MOM/REQ/Transcript/Others; ทำบน branch remediation/9plus-v2;
  ทุก Phase: แก้ → test → แสดง diff → มนุษย์ approve → commit local; ห้าม push
  โดยไม่มีคำสั่ง push ตรง ๆ ต่อครั้ง; ห้ามลดความเข้ม validator; ห้ามใช้ PS7-only features;
  Phase 4 ต้องทำ golden-master ก่อน refactor และ output หลัง refactor ต้องตรง 100%
ลำดับ: Phase 0 → 1 → (ตรวจ) → 2 → (ตรวจ) → 3 → (ตรวจ) → 4 → (ตรวจ golden-master) →
  5 → (ตรวจ) → 6 → 7 → (ตรวจ) → Phase 8 Final Gate
หมายเหตุ §7.4: branch protection ติด 403 บน Free plan — ต้องได้คำตอบ (A)/(B)/(C)
  จากเจ้าของ repo ก่อนปิด Phase 7
ห้ามเคลม 9+ จนกว่า Final Acceptance Gate จะผ่านครบด้วยการรันจริง
```
