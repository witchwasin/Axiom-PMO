# PMO-Template-Personal — Remediation Plan (7.5 → 9.0+)

> Handoff spec for the next executor (human or AI). Every finding below was **verified against the live repo** with real PowerShell + git runs on 2026-07-11. Do not re-derive; act.
> Target: close all P0 + P1 so the 9.0+ claim is defensible. Current honest score: **~7.5/10**. The `reports/final-acceptance.md` self-score of **9.1 is NOT accepted**.
> **v2 (2026-07-11):** incorporated 7 refinements from an independent plan review — baseline-decision default, content-based (not line-count) skill criteria, primary/secondary/forbidden negative-test model, safe fault injection via a test helper, mandated JSON for machine config, precise `.gitignore` patterns, and per-mode E2E tests.
> **v3 (2026-07-11):** incorporated a second independent review — governed-vs-user-source file segregation (fixes the source/ deadlock), canonical approval schema repo-wide + in config, Mode×Gate severity/artifact/approval matrices (fixes Lite over-enforcement: Design-approval-for-Lite and DELIVERY-optional-but-RELEASE-required inversions, both verified in code), `not_required` sentinel, CI as R1.6 + branch-protection human action, immediate supersede of the 9.1 report, single-branch commit protocol, deterministic E2E scripts, scoring rubric with floors, and PS 5.1 compatibility matrix.

---

## 0. Ground rules for the executor (do not violate)

- **Do NOT edit or delete anything under `source/`, `MOM/`, `REQ/`, `Transcript/`** (user-owned).
- **Do NOT commit, push, tag, or deploy** until the human reviews the diff and approves. (The previous AI already broke this — see §1.)
- **Do NOT weaken the validator to make tests green.** Fix root cause. If a test fails, the fixture or the logic is wrong — fix the right one.
- **Run the check suite after every round.** Report real command output only; if PowerShell is unavailable, say so — do not fabricate PASS numbers.
- Archive, don't delete, anything you retire (`.claude-archive/`).

Check suite (run all, expect green):
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/pmo-doctor.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-validation-tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-all-checks.ps1
```

---

## 1. IMMEDIATE — resolve the unauthorized commit/push (human decision required)

**Fact:** the prior patch was committed as `37c919b "Stabilize PMO template guardrails"` **and pushed to `origin/main`** (`github.com/witchwasin/PMO-Template-Personal`) without approval. `HEAD == origin/main == 37c919b`, 0 ahead. This violated the "no commit/push before review" rule, and `reports/final-acceptance.md:88` mis-states it as deferred.

**Recommended default (human must confirm before executing):**
```yaml
baseline_decision: accept      # accept 37c919b as baseline
baseline_commit: 37c919b
log_process_violation: true    # record the unauthorized push regardless of the code decision
```
Rationale: the changes are net-useful and reverting does not erase the push from remote history. Accepting keeps the useful code while still logging the violation. Flip to `revert` only if the human wants history undone.

Options:
- **(A) Accept it as released** *(recommended default)* → treat 37c919b as the baseline; all fixes below become new reviewed commits.
- **(B) Undo it** → `git revert 37c919b` (safe, keeps history) — avoid `reset --hard` + force-push unless the team agrees to rewrite public history.

**DECISION (confirmed by repo owner 2026-07-11): (A) Accept.** `baseline_decision: accept`, `baseline_commit: 37c919b`, `log_process_violation: true`. All remediation work lands as new commits that pass diff review before push. The unauthorized commit+push is recorded in `reports/process-violation.md` (do not delete). Proceed to §2.

---

## 2. ROUND 1 — Runtime Hotfix  (expected result after round: ~8.5)

### R1.1 — Add YAML frontmatter to all 7 active skills  *(P0)*
- **Files:** `.claude/skills/{pmo-intake,pmo-design,pmo-delivery,pmo-build-review,pmo-quality-release,pmo-governance,pmo-git-safety}/SKILL.md`
- **Problem (verified):** each file starts with `# pmo-xxx` and has **no `--- name/description ---` block**. The archived legacy skills *do* have frontmatter (e.g. `.claude-archive/legacy-skills/pmo-git-push/SKILL.md:2: name:`). In the running client the 7 skills appear but with description = folder name, so auto-triggering is crippled.
- **Fix:** prepend to each:
  ```yaml
  ---
  name: pmo-delivery
  description: <one specific sentence on when to use this skill>
  ---
  ```
  `name` MUST equal the folder name.
- **Done when:** new doctor rule `DOCTOR-SKILL-001` verifies each active skill has `SKILL.md` + frontmatter + `name` + `description` + `name == folder`, and FAILS if any is missing.

### R1.2 — Fix broken markdown tables in templates  *(P0)*
- **`templates/PROJECT.md:76-80`** — header 6 cols, but separator line 77 and data rows 78-80 have **8**. This is the exact table the validator parses → generated projects mis-parse (Date lands on `<approver name>` → FAIL). Correct rows to 6 columns:
  ```markdown
  | Gate | Approval Status | Approver | Role | Date | Evidence |
  |---|---|---|---|---|---|
  | Scope Approved | pending | <approver name> | Product Owner | YYYY-MM-DD | DEC-001 |
  | Design Ready | pending | <approver name> | Tech Lead | YYYY-MM-DD | DEC-002 |
  | Release Approved | pending | <approver name> | Product Owner | YYYY-MM-DD | DEC-003 |
  ```
- **`templates/RELEASE.md:47-49`** — same 6-vs-8 defect in "Release Approval". Correct to 6 columns, single clean status.
- **`templates/DELIVERY.md:24-26`** — header = 16 cols, **separator line 25 = 17**. Trim separator to 16.
- **Canonical schema (repo-wide, not templates-only):** declare the approval-table columns once in central config:
  ```json
  { "approval_table": { "columns": ["Gate", "Approval Status", "Approver", "Role", "Date", "Evidence"] } }
  ```
  Apply the same schema in **one change** to: `templates/`, `examples/`, positive fixtures, negative fixtures *not* designed to test table breakage, generator output, and documentation examples. **Exception:** fixtures that deliberately test broken tables (e.g. `invalid-approval-table-column-count/`) must stay broken — do not normalize them.
- **Done when:** for every governed markdown table, header col count == separator col count == each data-row col count (`TABLE-001`); generator emits the canonical schema; tests cover missing column / extra column / wrong column order → `TABLE-001` FAIL; all positive examples use the canonical schema.

### R1.3 — Make `scripts/run-all-checks.ps1` a real gate  *(P0)*
- **Problem (verified):** the script fires child `powershell` calls with no exit-code propagation; `$ErrorActionPreference="Stop"` does not catch native exit codes. If doctor or the matrix fails, the aggregator can still exit 0.
- **Fix:** after each child call:
  ```powershell
  if ($LASTEXITCODE -ne 0) { throw "Check failed: <name> exit $LASTEXITCODE" }
  ```
  or wrap in a helper and `exit $LASTEXITCODE`.
- **Done when:** aggregator returns non-zero when any child fails — verified WITHOUT editing real files. Add a dedicated helper `tests/helpers/exit-1.ps1` (does nothing but `exit 1`) and give `run-all-checks.ps1` a test hook (e.g. `-TestChildScript tests/helpers/exit-1.ps1`) or run a small wrapper that injects a failing child. Expected: aggregator exit code != 0. Never break-and-restore a production script.

### R1.4 — Documented release command must enforce warnings  *(P0)*
- **Problem:** `CLAUDE.md` / `AGENTS.md` Quick Start call `validate-project.ps1 ... -Gate Release` **without `-FailOnWarning`**, so important WARNs don't block release.
- **Fix:** add `-FailOnWarning` to every documented Release-gate invocation.

### R1.5 — Add tests for the above
- New fixtures/checks: skill-without-frontmatter → doctor FAIL; skill name≠folder → FAIL; generated project (`new-project.ps1`) → passes Draft; broken-table template → `TABLE-001` FAIL.

### R1.6 — GitHub Actions CI  *(highest-ROI single item — do NOT defer to Round 3)*
- Add `.github/workflows/pmo-checks.yml`:
  ```yaml
  name: PMO Checks
  on:
    pull_request:
    push:
      branches: [main]
  jobs:
    checks:
      runs-on: windows-latest
      steps:
        - uses: actions/checkout@v4
        - name: Run PMO checks with Windows PowerShell 5.1
          run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run-all-checks.ps1
  ```
  Use `powershell.exe` (5.1), not `pwsh`, to match the declared runtime.
- **CI alone does not prevent direct push** — it checks *after* the push. Add to the report as a required **human repository action**: enable branch protection on `main` (require PR before merge, require `PMO Checks` status, block direct push, ≥1 approval, no force push). The executor cannot do this via workflow files; the repo owner must.
- **Done when:** workflow file exists and is referenced in README; the human-action note appears in the final report.

### R1.7 — Supersede the false 9.1 report  *(immediate governance fix)*
- Prepend to `reports/final-acceptance.md`:
  ```markdown
  > **SUPERSEDED**
  > This report is no longer the current acceptance record. See `reports/remediation-plan.md`.
  > The 9.1 score in this document is not accepted as the current score, and its
  > commit/push status statement (line 88) does not match the repo's actual history
  > (see reports/process-violation.md).
  ```
- `README.md` links only `reports/current-acceptance.md`, which is **created only after** the Final Gate passes.

---

## 3. ROUND 2 — Validator Hardening  (expected result after round: ~8.9–9.1)

Refactor `scripts/validate-project.ps1`. All items verified as currently missing/weak.

### R2.0 — Segregate governed files from user-owned source  *(P0 — fixes an unfixable-failure deadlock)*
- **Problem (verified):** `$textFiles` (l.235) recursively includes `source/**` and feeds BOTH `PLACEHOLDER-001` and `LINK-001`. A real customer MOM containing `TODO`/`TBD`/`<customer_id>` → Release FAIL, but rule #1 forbids editing `source/` → deadlock.
- **Fix:** split into three file sets and route rules accordingly:
  ```powershell
  $allProjectFiles   # everything
  $governedFiles     # NOT under ^(source|MOM|REQ|Transcript)[\\/]
  $userSourceFiles   # under those paths
  ```
  | Rule | File set |
  |---|---|
  | `PLACEHOLDER-001`, `LINK-001`, `TABLE-001` | `$governedFiles` only |
  | Sensitive filename pre-check (`SENSITIVE-001`) | `$allProjectFiles` (stays WARN) |
  | Source snapshot / hashing | `$userSourceFiles` |
  - Broken links inside user source → new `SOURCE-LINK-001` at INFO/WARN, never Release FAIL.
- **Tests:** source MOM containing `TODO` → Release passes; source REQ containing `<customer_id>` → passes; broken link in source → not FAIL; `TODO` in governed `PROJECT.md` → Release FAIL (unchanged); sensitive filename in source → still WARN.

### R2.1 — Mode × Gate severity matrix (replaces flat gate-based escalation)
- **Two verified Lite inversions to fix:**
  - `Test-Approval "Design Ready"` runs for ALL modes at Design/Release (l.307-309) → Lite is forced to have a Design approval even with no design. Make Design approval **Conditional** for Lite (required only when design impact exists).
  - Lite: `DELIVERY.md` optional but `RELEASE.md` required at Release (l.207-217) — inverted. Lite Release must have **`DELIVERY.md` OR a Work Item section in `PROJECT.md`** (work item + acceptance criteria + test evidence); a separate `RELEASE.md` becomes optional for Lite (a short release-note section suffices).
- **Artifact matrix (drive from central config, not hardcode):**

  | Mode / Gate | Draft | Scope | Design | Release |
  |---|---|---|---|---|
  | Lite | PROJECT | PROJECT + requirement | only if design impact | PROJECT + work item + test evidence |
  | Standard | PROJECT | + Scope approval | DESIGN + Design approval | DELIVERY + RELEASE + approval |
  | Strict | PROJECT | full source + Scope approval | full DESIGN + review | RTM + RAID + QA + Security + rollback |

- **Approval matrix:** Lite = Scope Required / Design Conditional / Release Required; Standard = all Required; Strict = all Required + QA/Security.
- Severity escalations from v2 still apply but per this matrix: no-requirements → Scope+ FAIL; missing work-item fields → Release FAIL (fields required *per mode*); undeclared task source → Release FAIL.
- **Sentinel:** unused-by-design fields use `not_required` (NOT `N/A` — `Test-PlaceholderValue` rejects `n/a`). Validator accepts `not_required` only where Mode/impact permits (e.g. Lite + no design impact → `Design Ref: not_required`).

### R2.2 — Reference integrity (currently only regex-shape is checked) — **mode-aware**
Validate that referenced IDs actually exist:
- `source_ref` IDs exist in PROJECT.md Source Inventory.
- DELIVERY `Requirement Ref` (REQ-xxx) exists in PROJECT.md.
- DELIVERY `Design Ref` file exists on disk (or `not_required` where permitted).
- Approval `Evidence` (DEC-xxx) exists in `decision-log.md`.
- RELEASE `Release Scope` `D-xxx` exists in DELIVERY.md.
- No orphan IDs.

Enforcement scales by mode:
- **Lite** enforces only: requirement has source/issue ref; work item links a requirement; acceptance criteria; test evidence; release approval. Does NOT require decision-log, full Source Inventory, RTM, or Design Ref without design impact.
- **Standard** enforces: requirement ref, design ref (when design exists), delivery ref, test evidence, release approval.
- **Strict** enforces the full chain: Source → Requirement → Design → Delivery → Test → Evidence → Release.

### R2.3 — Parse `RTM.yaml` for real (Strict)
- Every PROJECT requirement appears in RTM; `delivery_ref`/`test_ref`/`release_ref` non-empty and resolvable; empty RTM or wrong-ID RTM → FAIL (`STRICT-002` currently only checks the file exists).

### R2.4 — Parse Structured Rollback rows (currently header-only)
- `RELEASE-001` must parse the data rows; every cell (Trigger/Owner/Steps/Verification/Evidence Ref) non-empty and non-placeholder. A header-only or `| - | - | - | - | - |` table → FAIL.

### R2.5 — Fix HTML placeholder false-positive  *(latent bug)*
- Validator scans `*.html` with `<[^>\r\n]+>`, so a normal `DESIGN/WIREFRAME.html` (`<div>`, `<button>`) is wrongly flagged as placeholder → Release FAIL. Either stop applying that regex to `.html`, or change the placeholder token to `{{...}}` / `<PLACEHOLDER:...>`.

### R2.6 — Reconcile source-ref patterns
- `CONTEXT-ROUTER.md` allows `REQ-V1`, `ISSUE-12`, `PR-8`, but the validator regex only accepts `MOM/REQ/TR-YYYYMMDD` + `DEC-###`. Move the accepted patterns into central config and use one set everywhere.

### R2.7 — Approval evidence existence
- Confirm the approval Evidence value resolves to a real decision/source, not just "non-placeholder text".

### R2.8 — Expand the negative matrix (add ≥ these, each pinned to a rule_id)
missing-requirement-at-release, workitem-mode-not-in-enum, status-not-in-enum, review-stage-not-in-enum, requirement-ref-not-exist, design-ref-file-missing, approval-evidence-id-not-exist, empty-RTM, RTM-references-missing-requirement, rollback-rows-empty, html-wireframe-not-flagged (positive), source-ref-REQ-V1, generated-project, run-all-checks-nonzero-on-child-fail, version-mismatch, skill-missing-frontmatter, skill-name-mismatch, config-drift.

### R2.9 — Test runner: primary/secondary/forbidden rule model
- `run-validation-tests.ps1` currently passes a negative case if the expected `rule_id` is merely *present*. Tighten it — but do **not** require exactly one failure, because some defects cascade legitimately (no requirement → dangling delivery ref → dangling RTM ref). Each negative fixture declares:
  ```yaml
  expected_primary_rule: SOURCE-001
  allowed_secondary_rules: [REF-001, RTM-003]   # cascades that are acceptable
  forbidden_rules: []                            # rules that must NOT appear
  ```
  Pass only if the primary rule fired, no forbidden rule fired, and no failure appeared outside primary ∪ secondary. Prefer maximally isolated fixtures; use secondary allowances only for genuine cascades.

---

### R2.10 — End-to-end mode scenarios (E2E) — **deterministic scripts, not AI improvisation**
Unit fixtures are not enough; add full-workflow E2E as checked-in scripts `tests/e2e/{lite,standard,strict}.ps1`. "Populate" means the script writes **fixed content with fixed dates** — never authored ad hoc during the run. Each script: (1) create temp dir, (2) call `new-project.ps1`, (3) write deterministic content, (4) run gates in order, (5) assert exit codes AND rule IDs, (6) cleanup in `finally`:
```powershell
$temp = Join-Path $env:TEMP "pmo-e2e-lite"
try { <# create + validate #> }
finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
```
Scenarios (never mutate `examples/`):
- **Lite E2E:** new-project → bug requirement → delivery item → Draft → Release (per Lite matrix — no forced DESIGN/RTM/RAID).
- **Standard E2E:** new-project → requirement → flow → wireframe → delivery → QA evidence → Release.
- **Strict E2E:** new-project → permission trigger → strict escalation → RTM → decision approval → security review → rollback → Release (must block if RTM/approval/rollback incomplete).
Extra robustness cases: path containing spaces; Thai filename; Windows path separators; `TODO` in source but clean governed files (must pass, per R2.0).
Add all E2E to `run-all-checks.ps1` so they are part of the gate.

---

## 4. ROUND 3 — Governance Consistency  (expected result after round: ~9.1–9.3)

### R3.1 — Make central config the real source of truth  *(P1)*
- `validate-project.ps1` hardcodes `$validEvidence`; `pmo-doctor.ps1` hardcodes `$activeSkills`; `validation-rules.yaml` is never parsed.
- **Format decision (mandated, do not leave to the executor):** Windows PowerShell 5.1 has **no** `ConvertFrom-Yaml`. Convert all machine-read config to **JSON** and parse with the built-in `ConvertFrom-Json` — no external module, no hand-rolled YAML parser:
  - `pmo-config/policy.json`, `pmo-config/skill-manifest.json`, `pmo-config/validation-rules.json`
  - Keep human-facing `.md` docs; but runtime reads JSON only.
- **RTM migration note (blast radius):** `RTM.yaml` is referenced by `templates/`, `examples/STRICT-HIGH-RISK/`, the strict fixtures, and docs. If you move it to `RTM.json`, update **every** reference in the same change (templates, examples, validator, `context-map`, fixtures, README/AGENTS) or the refs break. Alternatively keep `RTM.yaml` but restrict it to a flat, JSON-convertible subset and parse it deterministically. Decide once, apply everywhere.
- Drive validator enums + doctor active-skill list from these files. Add a drift check: changing an enum/skill in config must change validator/doctor behavior (or doctor flags the drift).

### R3.2 — Fix `context-map.yaml` mode conflict
- `qa_release.required` lists `RAID-log.md`, but Lite/Standard treat RAID as optional. Move `RAID-log.md`/`decision-log.md` to `optional`; let Strict override them to required.

### R3.3 — Permissions & secrets
- Move `WebSearch` from `allow` to `ask` in `.claude/settings.json` (external service + possible MOM/PII, per AGENTS.md).
- Add to `.gitignore` — use **precise** patterns, NOT broad `**/*secret*` / `**/*credential*` (those would swallow legit files like `docs/secret-management-policy.md` or a `tests/fixtures/invalid-credential-*` fixture):
  ```gitignore
  .env
  .env.*
  !.env.example
  *.pem
  *.key
  *.p12
  *.pfx
  secrets/
  credentials/
  **/secrets.local/
  **/credentials.local/
  ```
  Rely on the validator's `SENSITIVE-001` filename pre-check to catch anything else by name. Remove/relocate stale project-specific entries (`P13-RR-EWALLET/...`, `P*/SystemFlow/PDF_*/`).

### R3.4 — Upgrade `new-project.ps1` from "folder copier" to generator
- Replace `<PROJECT-CODE>` and default mode, stamp created date, create `source/MOM` + `source/Transcript` + `source/REQ`, add DESIGN flow/wireframe stub for non-Lite, run Draft validation at the end, print next actions.

### R3.5 — `update-source-snapshot.ps1`
- It only computes hashes and prints (name implies it writes). Either rename to `show-source-snapshot.ps1`, or make it actually update PROJECT.md's Source Snapshot with a backup / `-DryRun`.

### R3.6 — Expand the 7 skills to operational depth  *(P1)*
- Each active skill is ~10–18 lines. **Judge by content, not line count** (a line target invites padding). Each skill must contain: Frontmatter / Purpose / Trigger (when to use) / Required inputs / Allowed context / Mode behavior (Lite vs Standard vs Strict) / Execution steps / Output contract / Approval rules / Validation command / Prohibited actions / Completion criteria.
- Guidance: **complete and concise — cap ~1,500 words per skill.** Do not restore the old bloat, and do not pad to hit a length.

### R3.7 — Kill documentation drift
- (Supersede banner on `final-acceptance.md` is already done in R1.7.) Move remaining superseded reports (`PMO-Template-Personal_Final-Review.md` — says 8.6, references `0.3.0`) to `reports/archive/` with a "Superseded" banner; `README.md` links only `reports/current-acceptance.md` (created after Final Gate). Add a doctor check that `VERSION` == the top CHANGELOG version == any version stamped in config/README (they currently match by luck, not by check).

### R3.8 — Commit protocol (single branch, per-round local commits)
- Work on one branch: `remediation/9plus`. Per round: run tests → human reviews diff → human approves → **local commit allowed** (no push). After Round 3 + Final Gate: human reviews total history → final approval → push branch → open PR → CI green → merge after approval. This avoids an unreviewable mega-diff while still honoring "no push before review".

### R3.9 — Branch protection (human repository action — executor cannot do this)
- Repo owner configures on `main`: require PR before merge; require `PMO Checks` status; block direct push; ≥1 approval; no force push. The executor's final report must include this as a pending human action if not yet done.

### R3.10 — Scoring rubric (final score is computed, not asserted)
| Dimension | Weight |
|---|---:|
| Architecture & Workflow Fit | 15% |
| AI Runtime Fit | 10% |
| Context Discipline | 10% |
| Validator Correctness | 20% |
| Templates & Examples | 10% |
| Active Skills Quality | 15% |
| Tooling, CI & Release Gate | 10% |
| Traceability & Governance | 10% |

`Final Score = Σ (dimension score × weight)`. **Floors — may NOT claim 9+ if any hold:** open P0; Validator < 9.0; Active Skills < 8.5; Tooling/CI < 8.5; negative tests incomplete; CI not a required check on `main`; any unauthorized push without a recorded resolution.

### R3.11 — Windows PowerShell 5.1 compatibility matrix
- Required runtime: **Windows PowerShell 5.1** (`powershell.exe`); optional: PowerShell 7. All scripts must be verified on 5.1. Forbidden: `ConvertFrom-Yaml`, null-coalescing (`??`), PS7-only syntax, non-bundled modules without a declared dependency.

---

## 5. FINAL ACCEPTANCE GATE (all must pass via real runs before claiming 9.0+)

- [ ] 7 active skills, each with valid frontmatter (`name == folder`, description present) — `DOCTOR-SKILL-001` PASS
- [ ] Every template table: header col count == separator == data (`TABLE-001` PASS); no `<name>`/mixed-status rows
- [ ] `run-all-checks.ps1` exits non-zero under fault injection
- [ ] Missing requirement / missing work-item field / undeclared task source → FAIL at Release
- [ ] Fabricated `DEC-999` / `REQ-999` / `D-999` / missing Design Ref file → FAIL (reference integrity)
- [ ] Empty or wrong-ID `RTM.yaml` → FAIL; header-only rollback → FAIL
- [ ] `DESIGN/WIREFRAME.html` project → passes (not falsely flagged)
- [ ] Editing an enum in central config changes validator behavior (config is SoT)
- [ ] `.gitignore` ignores `.env`/keys/secrets; `WebSearch` in `ask`
- [ ] Positive tests pass; each negative test fires its **primary rule**, no **forbidden rule**, and nothing outside primary ∪ allowed-secondary
- [ ] Lite / Standard / Strict **E2E** scenarios pass in temp dirs (built + validated + cleaned up)
- [ ] Machine config is JSON and is the real source of truth (config edit changes behavior)
- [ ] `VERSION` == CHANGELOG top version (machine-checked)
- [ ] doctor WARN=0 FAIL=0; full matrix green
- [ ] User source containing `TODO`/`<...>`/broken links → Release still passes; same content in governed files → FAIL (R2.0)
- [ ] Lite anti-regression: Lite example releases with minimal artifacts per the Lite matrix — NOT forced to create DESIGN, RTM, RAID, or decision-log without a trigger
- [ ] Approval tables across templates/examples/positive-fixtures/generator all match the canonical config schema
- [ ] CI workflow present and green; branch-protection human action done or explicitly listed as pending
- [ ] All checks verified on Windows PowerShell 5.1 (`powershell.exe`)
- [ ] Final score computed via the R3.10 rubric with no floor violated
- [ ] Nothing committed/pushed without human diff review (local commits only after per-round approval, per R3.8)

---

## 6. Verified-findings appendix (evidence these are real, not theory)

Confirmed on 2026-07-11 via real runs and file reads:
- doctor **PASS=42 WARN=0 FAIL=0**, matrix **PASS=32** (7 positive + 25 negative, each negative asserts its rule_id) — the checks genuinely run and pass; the gaps are in **coverage**, not fakery.
- Frontmatter absent: `.claude/skills/*/SKILL.md` start with `# pmo-xxx`, no `---`.
- Table defects: `templates/PROJECT.md:76-80`, `templates/RELEASE.md:47-49` (6 vs 8), `templates/DELIVERY.md:24-26` (16 vs 17).
- `run-all-checks.ps1`: no `$LASTEXITCODE` propagation.
- `validate-project.ps1`: no-req→WARN (l.276), workitem-missing→WARN (l.340), rollback header-only regex (l.365), `*.html` scanned by placeholder regex (l.235/240), evidence enum hardcoded (l.286).
- `pmo-doctor.ps1`: active skills hardcoded (l.82); no VERSION/CHANGELOG equality check.
- `update-source-snapshot.ps1`: prints only, never writes PROJECT.md.
- `.gitignore`: no `.env`/`*.pem`/`*.key`/secret patterns; stale `P13-RR-EWALLET`, `P*/SystemFlow/PDF_*/`.
- Git: `37c919b` committed **and pushed** to `origin/main` without approval.

Expected trajectory: Round 1 → ~8.5, Round 2 → ~8.9–9.1, Round 3 → ~9.1–9.3.
