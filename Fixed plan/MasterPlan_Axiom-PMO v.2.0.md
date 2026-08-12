# MasterPlan — Axiom-PMO v.2.0 (Revised)

> **Status:** REVISED DRAFT — accepted in direction by the Human Owner on
> 2026-08-13; not yet ratified by a `DEC` entry.
> **Branch:** `Axiom-PMO-v.2.0` — the only branch this work happens on.
> **Date:** 2026-08-13
> **Supersedes:** the first draft of this document (commit `12e7c9f`) **in full.**
> That draft contained capability assumptions that do not hold against the real
> AxiomGuard code. §1 records exactly what changed and why. Do not work from the
> old version.

---

## 0. Working Protocol — READ THIS FIRST

**This section is binding on any agent doing work under this plan.**

### 0.1 Who does what

| Role | Who | Does |
|---|---|---|
| **Human Owner** | the repository owner | decides, approves, ratifies, releases. Nothing else may. |
| **Reviewing agent** | a separate Claude session | reviews work, writes `Fixed plan/feeback.md` |
| **Implementing agent** | you, if you are reading this to do work | implements, writes `Fixed plan/update_fixed.md` |

The implementing agent **never** reviews its own work as final, and **never**
moves an approval row from `pending` to `approved`. That is the same rule
`AGENTS.md` §11 already enforces; v.2.0 does not soften it.

### 0.2 The hard boundary — AxiomGuard is READ-ONLY

> **AxiomGuard — the separate `AxiomGuard` repository, checked out as a sibling
> of this one — will not be touched.**
> Read it. Study it. Whether it is right or wrong is irrelevant to this project.
> Do not edit, patch, fork, branch, commit, open an issue, or open a PR against
> it — not even to fix an obvious bug, not even a typo, not even if a limitation
> blocks you.

Consequences, in order of how often they will come up:

1. **Consume it as a pinned PyPI package only** — `axiomguard==0.7.2`. Never a
   git checkout, never a path dependency, never a vendored copy.
2. **If AxiomGuard cannot do something you need**, you have exactly two moves:
   work around it inside Axiom-PMO, or record it as **deferred** in
   `decision-log.md` and in `update_fixed.md`. There is no third move.
3. **All work happens in the `Axiom-PMO` repository, on branch
   `Axiom-PMO-v.2.0`.** No other branch, no other repository.

### 0.3 `update_fixed.md` — the implementing agent's report (REQUIRED)

Write and maintain `Fixed plan/update_fixed.md`. **Append-only** — never rewrite
or delete an earlier entry; add a new dated entry instead. One entry per work
session, in this shape:

```markdown
## <YYYY-MM-DD> — <session summary in one line>

### Done
- <what changed> — `<file path>` — evidence: `<command run>` → `<result>`

### Not done (and why)
- <item> — <blocked by / out of scope / needs a human decision>

### Found that contradicts the plan
- <what the plan assumed> → <what is actually true> → <evidence>

### Needs a Human Owner decision
- <question, with the options and your recommendation>

### Verification run
- `scripts/pmo-doctor.ps1` → <pass/warn/fail counts>
- `scripts/run-validation-tests.ps1` → <result>
- <any other command, with real output — never a summary you did not run>
```

Rules for this file:

- **Report faithfully.** If a test fails, say so and paste the output. If you
  skipped a step, say you skipped it. "Done" means done and verified.
- **Push back with evidence, do not silently deviate.** If the plan asks for
  something that turns out to be wrong or impossible, write it under *"Found
  that contradicts the plan"* and stop that item — do not improvise a different
  design and do not quietly narrow the scope.
- Never mark an item complete because it "should work". Run it.

### 0.4 `feeback.md` — the review channel (READ BEFORE EVERY SESSION)

`Fixed plan/feeback.md` is written by the **reviewing agent and the Human
Owner**. It does not exist until the first review round.

- **Read it at the start of every work session, before touching anything.**
- Where `feeback.md` and this plan disagree, **`feeback.md` wins** — it is newer.
- Do not edit `feeback.md`. It is not yours. Respond to it in `update_fixed.md`.

*(Spelling note: the file is `feeback.md`, as the Human Owner named it. Keep that
exact spelling so every path matches.)*

### 0.5 The cycle

```text
implementing agent works
   → writes Fixed plan/update_fixed.md
      → Human Owner brings it to the reviewing agent
         → reviewing agent writes Fixed plan/feeback.md
            → implementing agent reads feeback.md
               → next session
```

### 0.6 Rules that do not change in v.2.0

Everything in `AGENTS.md` still applies, unchanged. Especially:

- No human approval is created, moved, or implied by any output of this work.
- No `source/` file is edited, created, or deleted.
- No existing governance rule is weakened to make a new test pass.
- No commit without explicit user instruction; no push without confirmation.
- Read `docs/architecture/powershell-portability.md` before changing anything
  under `scripts/`. This is not optional — see §7.5.

---

## สรุปสำหรับ Human Owner (ภาษาไทย)

แผนฉบับแรกตั้งเป้าให้ AxiomGuard พิสูจน์ว่า **implementation ของโปรเจกต์ผู้ใช้ถูกต้อง**
ซึ่งตรวจโค้ดจริงแล้วพบว่า **ทำไม่ได้** — AxiomGuard ตรวจ "ชุด claim ที่มีคนป้อนให้"
ไม่ได้อ่านโค้ด ไม่ได้ทำ static analysis และ artifact ของเราเก็บกฎไว้เป็นประโยคภาษาคน
ซึ่ง validator ที่เป็น PowerShell แปลงเป็น claim แบบ deterministic ไม่ได้

ฉบับแก้นี้จึงหด L4 ลงมาเหลือสิ่งที่ **มีคุณค่าจริงและทำได้จริงวันนี้**:

> ใช้ Z3 พิสูจน์ว่า **ชุด policy ของ Axiom-PMO เองไม่ขัดกันเอง**
> ไม่ใช่ไปพิสูจน์ธุรกิจของลูกค้า

เหตุผล: ผู้ใช้ไม่ต้องเขียนอะไรเพิ่มเลย, Python ไม่ตกถึงมือผู้ใช้ (เป็น maintainer
check), ป้องกันความเจ็บที่เคยเกิดจริงมาแล้ว (`LL-20260811-05` / `DEC-023`), และ
ไม่ข้ามเส้น "ห้ามตีความ domain ของลูกค้า" ที่เป็นหลักการหลักของ framework

และมี **ด่านตัดสินเดียว: M0 spike** — ถ้า spike ไม่เจอข้อขัดแย้งที่ 114 rules
เดิมมองไม่เห็น ให้ **ปิดเรื่อง L4 บันทึกเป็น declined** แล้วเอาแรงไปลง M4 แทน
นี่คือทางที่ถูกที่สุดในการทดสอบว่าไอเดียนี้คุ้มหรือไม่ ก่อนลงทุนหลายเดือน

---

## 1. What changed from the first draft, and why

Every row below was verified against the real code, not assumed.

| First draft claimed | Verified reality | Correction |
|---|---|---|
| L4 answers *"does the implementation satisfy the constraints"* (§3 table, §5 worked example) | AxiomGuard verifies a list of `subject/relation/object` claims that **someone else supplies**. It never reads code, does no static analysis, no symbolic execution. | L4 answers *"do the **declared** constraints contradict each other"*. The order-cancellation worked example is removed. |
| The validator encodes claims itself, no LLM (M2) | The constraints in governed artifacts are **prose**. `templates/BUILD-SPEC.md:72` "State Machine and Transition Guards" is free text; `PROJECT.md` Business Rules is a table with a free-text rule column. PowerShell cannot deterministically turn *"the transition into Done is guarded by `review_notes`"* into a triple. | L4 is applied **only to inputs that are already structured** — `pmo-config/*.json`. No prose is parsed. No LLM enters the encoding path. |
| AxiomGuard "produces a counterexample" (§5) | It returns `unsat_core()` → `contradicted_claims` (claim indices) + `violated_rules` (metadata). UNSAT means *no model exists*; there is no satisfying model to hand back. | Correct term throughout: **unsat core / contradicting claims**. Never "counterexample". |
| "L1 and L2 are already shipped (deterministic, 100%)" (§3) | M4 of the same document exists precisely to close L2 gaps. | Claim removed. This repository's convention is evidence, not self-report. |
| Solver absent ⇒ "fails closed" (§9) **and** "degrades to today's behavior / skips cleanly" (§9, M1) | Two mutually exclusive behaviours in one document. | Resolved: **not opted in ⇒ skip silently. Opted in but solver absent ⇒ fail.** |
| M6 ships an npm package | The Human Owner **declined npm on 2026-08-11** (commit `7d2393b`), recording: *"Nothing may describe Axiom-PMO as having an npm distribution."* | npm removed from M6 entirely. It is a separate optional track — §10. |
| M5 Formal Studio (dashboard) | AxiomGuard's Studio is inside the read-only repo, so this means writing a whole new web application in Axiom-PMO. Unrelated to the core thesis and a scope-creep magnet. | Deferred to v2.1. Not in v.2.0. |
| M1/M2 first | M3 and M4 need nothing from AxiomGuard, carry no new dependency, and deliver value regardless of whether L4 survives. | Reordered — see §6. |

---

## 2. Core thesis (kept — but narrower)

Unchanged in principle:

> We are not trying to build an LLM that obeys the rules 100% of the time.
> We are building a system that does not have to trust the LLM in the first place.

```text
Policy → Contract → LLM → Candidate →
    Verification
      ├── L1  Deterministic policy rules   (shipped)
      ├── L2  Repository ground truth      (shipped, partial → M4)
      ├── L3  Semantic audit               (shipped as candidate evidence → M3)
      └── L4  Formal proof (Z3)            (NEW — scope narrowed, see §5)
```

What is **narrower** than the first draft: L4 does not claim to verify anyone's
implementation. It proves internal consistency of a **declared, already
structured** rule set. That is a smaller claim, and it is a true one.

---

## 3. AxiomGuard — verified facts (do not re-derive, do not assume)

Checked on 2026-08-13 against the real repository and PyPI. Recorded here so no
agent has to open that repository again to work on this plan.

| Fact | Value |
|---|---|
| Published package | `axiomguard` on PyPI, latest **0.7.2** — released versions: 0.5.0 → 0.7.2 |
| Runtime | `requires-python >=3.9` |
| Dependencies | `z3-solver>=4.12.0`, `pydantic>=2.0`, `pyyaml>=6.0` |
| CLI | **None.** `pyproject.toml` has no `[project.scripts]`. It is a library only. |
| Local HEAD vs release | HEAD (`3bce198`, "Studio v2") is **ahead of** tag `v0.7.2`. Unreleased work exists. **This is why we pin PyPI `==0.7.2`, not a git ref.** |
| Deterministic entry point | `verify_structured(response_claims, axiom_claims=None, kb=None, system_time=None) -> VerificationResult` — bypasses the LLM extractor entirely. **This is the only entry point we use.** |
| Claim shape | `Claim(subject: str, relation: str, object: str, negated: bool = False, confidence: float = 1.0)` |
| Result shape | `VerificationResult(is_hallucinating, reason, confidence, extraction_warnings, contradicted_claims, violated_rules)` — `contradicted_claims` is the unsat core as claim indices |
| Rule types that exist | `unique`, `exclusion`, `dependency` (incl. conditional chains), `range`, `negation`, `temporal`, `comparison`, `cardinality`, `composition` |
| Rule types that do **not** exist | anything state-machine / transition-table shaped |
| Rule file format | `.axiom.yml` — see `examples/loan_rules.axiom.yml` in that repository for the canonical shape |

**Entry points we must never use** (they put an LLM back into the proof path and
break the whole thesis): `verify()`, `extract_claims()`, `translate_to_logic()`,
`generate_with_guard()`, any `axiomguard.backends.*`, `Tournament`, the
self-correction loop, the RAG/vector integrations, LangChain/LlamaIndex adapters,
document ingestion, and Axiom Studio.

---

## 4. Axiom-PMO — verified facts about the target

| Fact | Value |
|---|---|
| Validation rules today | **114 entries** in `pmo-config/validation-rules.json` |
| What they check | almost entirely **existence and shape** — file present, field non-empty, `source_ref` resolves, digest current, git diff matches the claim |
| What nothing checks | whether the **declared policy set contradicts itself** |
| Policy files | 15 JSON files in `pmo-config/` — `policy.json`, `artifact-policy.json`, `handoff-policy.json`, `validation-rules.json`, and others |
| ⚠️ Encoding gotcha | `pmo-config/policy.json` is **UTF-8 with BOM**. Python `json.load()` fails on it unless opened with `encoding="utf-8-sig"`. Expect this across the config set; handle it once, centrally. |
| CLI | `cli/axiom.mjs`, 817 LOC, imports **only `node:` builtins** — zero npm dependencies. Exits `127` when no PowerShell host is found. |
| Packaging boundary | **already exists** — `scripts/lib/framework-checkout.ps1` splits user-facing scripts (work from a packaged install) from maintainer scripts (require a real checkout, and correctly refuse otherwise). |
| CI | 4 legs in `.github/workflows/pmo-checks.yml`, `timeout-minutes: 30`, and a run has previously finished with ~13s of margin under the older 15-minute budget. **The existing legs have no headroom to spare.** |

### 4.1 The gap, with evidence

Two findings from the current `pmo-config/policy.json` that the 114 rules cannot
see, because no rule checks declared facts against each other:

1. **`"Project Owner"` appears exactly once in the entire repository** —
   `pmo-config/policy.json:16`, as an allowed role for `Scope Approved`.
   Everywhere else the repository uses `"Project Manager"`. There is no closed
   `roles` enum, so nothing catches an orphan role string. Typo or deliberate,
   **nothing in the system can tell you which.**

2. **Waiver asymmetry** — `test_waiver.allowed_modes = ["Standard"]` but
   `rollback_waiver.allowed_modes = ["Lite"]`. Lite, the lightest mode, cannot
   waive tests while Standard can. This may well be deliberate (a test note is
   one of the few artifacts Lite requires at all), but **nothing declares the
   intent**, so nothing can confirm it.

This is not hypothetical damage. `docs/architecture/lessons-learned.md`
`LL-20260811-05` records a role-matrix mismatch discovered **mid-flow in a real
project**, which required `DEC-023` to resolve.

**Honest counterpoint, stated up front:** finding #1 took three minutes with
`grep`. A closed `roles` enum plus three PowerShell rules would catch it without
any solver. So the value of Z3 is **not** "it finds orphan strings". It is the
one class of question hand-written rules cannot answer by construction:

> Is there any combination of (mode, gate, role, waiver, strict trigger) that
> lets a project reach `Release` without a valid human approval?

That is a reachability question over a product space — 3 modes × 5 gates ×
5 approval checkpoints × waivers × 11 strict triggers, growing every milestone.
Each hand-written rule looks at one thing; none looks at the whole space.

**M0 exists to test whether that class of question yields anything real.**

---

## 5. Where L4 actually applies

### 5.1 In scope

**L4 verifies Axiom-PMO's own policy configuration for internal consistency.**

- **Input:** `pmo-config/*.json` — already structured, already machine-readable,
  authored by the maintainer.
- **Encoding:** compiled to `.axiom.yml` by Axiom-PMO code. Deterministic. No
  LLM anywhere in the path.
- **Engine:** `axiomguard==0.7.2` → `verify_structured()` → Z3.
- **Output:** contradictions in the policy set, as candidate evidence for the
  maintainer.
- **Audience:** the framework maintainer, via `pmo-doctor`. **Not** an end user.
- **Distribution:** Python never becomes a dependency of using Axiom-PMO. The
  check is maintainer/CI-only and skips silently when Python or `axiomguard` is
  absent.

Why this shape wins on every axis: users write nothing new; the "who can author
`.axiom.yml`" adoption problem disappears because the maintainer is the author;
it prevents a failure that has already happened once; and it never crosses the
framework's own boundary against interpreting a customer's domain.

### 5.2 Explicitly NOT in scope

- Verifying a **user project's** business rules, state machines, or requirements.
- Parsing prose out of `BUILD-SPEC.md` or `PROJECT.md`.
- Any claim that L4 verifies an implementation, or code, or tests.
- Any LLM step in the encoding path.
- Requiring users to author `.axiom.yml`.

The user-project version of L4 is **v2.1 at the earliest**, and it must first
clear one gate: **one person who is not the author successfully writes a correct
constraint set on their own.** Until that happens, there is nothing to build.

---

## 6. Milestones (reordered)

```text
M0 spike  ──► decision point ──► if PASS: M1 → M2
   │                             if FAIL: record declined, stop L4
   ▼
M4 (repo ground truth)  ──►  M3 (semantic contract)     [independent of L4]
```

### M0 — Spike (THE DECISION GATE) · timebox 1–2 days

**Nothing else in the L4 track starts until M0 reports.**

- Hand-write a `.axiom.yml` encoding of `pmo-config/policy.json` +
  `pmo-config/artifact-policy.json`. **By hand. Throwaway. Not production code.**
- Feed it to `verify_structured()` with `axiomguard==0.7.2` in a local venv.
- Answer one question, with evidence: **does it surface any contradiction that
  the 114 existing rules do not already catch?**
- Try specifically to express the reachability question from §4.1.

**Output:** a section in `update_fixed.md` — what was encoded, what the solver
said, what (if anything) was new, and a recommendation of PASS or FAIL.

**PASS** = at least one contradiction, or one reachability answer, that is real
and that the current rules miss.
**FAIL** = it only restates what the 114 rules already check.

**On FAIL:** stop. Record `L4 — declined` in `decision-log.md` with the evidence,
the same way npm and marketplace were recorded as declined. This is a legitimate,
successful outcome of M0 — not a failure of the work. Then go to M4.

### M1 — Policy Consistency Check *(only if M0 passes)*

- `scripts/lib/formal-policy-*.ps1` — compiles `pmo-config/*.json` → `.axiom.yml`.
- An adapter **owned by Axiom-PMO** that shells out to Python and calls
  `verify_structured()`. Versioned input/output schema, defined in this repo.
- Absent-dependency behaviour: **not opted in ⇒ skip silently; opted in but
  Python/`axiomguard` missing ⇒ fail with a clear message.**
- Conformance fixtures that pin the behaviour of `axiomguard 0.7.2` we rely on,
  so the frozen dependency cannot change under us unnoticed.

**Done when:** the check runs, the fixtures pass, and every existing project,
fixture, and invocation validates exactly as it did in v1.5.0.

### M2 — Wire into `pmo-doctor` *(only if M1 lands)*

- New `DOCTOR-0xx`, maintainer-only, opt-in, skips cleanly.
- Positive **and** negative fixtures with goldens — a deliberately contradictory
  policy set must be caught.
- Documentation: `docs/concepts/formal-verification.md`, stating plainly that
  this verifies **our own policy**, not customer code.

**Done when:** an intentionally broken policy fixture fails the check, a correct
one passes, and `run-validation-tests.ps1` is green on all existing hosts.

### M3 — Semantic Audit Contract (L3 hardening) · *independent of AxiomGuard*

- Formalize the L3 output contract: every semantic finding carries
  `requirement_ref`, `implementation_claim`, `test_claim`, severity, and a named
  human decision owner.
- An AI's semantic verdict must never change a validator exit code on its own —
  same closure authority `HANDOFF-010` already enforces.

### M4 — Repository Ground Truth (L2 completion) · *independent of AxiomGuard*

- Extend SCOPE-DIFF semantics to **tests** and **artifacts**: claimed test files
  actually changed, actually ran.
- Reconcile EXEC-* evidence so a contradiction surfaces even when the agent's own
  report claims success.

**Done when:** an agent report claiming *"all tests pass / scope respected"*
cannot pass the gate against contradicting git ground truth.

### Deferred to v2.1 — not in v.2.0

- **Formal Studio / dashboard** (old M5) — a whole new web application; unrelated
  to the thesis.
- **L4 on user projects** — gated on §5.2.
- **External pilot** — meaningful only once there is something to pilot.

---

## 7. Concrete work list

Ordered. Do not skip ahead. Tick items in `update_fixed.md`, not here.

### 7.1 Plan hygiene (already applied in this revision — verify only)

- [x] Worked example removed; L4 wording corrected to "declared constraints"
- [x] "counterexample" → "unsat core / contradicting claims"
- [x] fail-closed vs skip-clean contradiction resolved
- [x] "L1/L2 shipped 100%" removed
- [x] npm removed from the milestone track
- [x] `axiomguard==0.7.2` pin recorded

### 7.2 Repository work — do in this order

- [ ] **M0 spike** (§6). Throwaway code, local venv, do not commit the venv.
      Report in `update_fixed.md`. **Then stop and wait for review.**
- [ ] Add a closed `enums.roles` to `pmo-config/policy.json` and resolve the
      orphan `"Project Owner"` (§4.1 finding 1). **This needs a Human Owner
      decision** — is it a typo for `"Project Manager"` or a real distinct role?
      Do not guess. Ask, via `update_fixed.md`.
- [ ] Record the waiver asymmetry (§4.1 finding 2) as either intentional (with a
      one-line reason in the config or its doc) or a defect. Again: ask.
- [ ] *(M0 PASS only)* adapter + compiler + conformance fixtures
- [ ] *(M0 PASS only)* `DOCTOR-0xx` + positive/negative fixtures + goldens
- [ ] *(M0 PASS only)* `docs/concepts/formal-verification.md`

### 7.3 CI

- [ ] Any L4 job is a **new, separate job**. The 4 existing legs are not to be
      modified — they already run close to their timeout.
- [ ] The L4 job is non-blocking until it has been green twice on this branch.

### 7.4 Governance records

- [ ] `decision-log.md` — a `DEC` ratifying this revised plan **and** recording
      the AxiomGuard read-only boundary (§0.2) as binding.
- [ ] `RAID-log.md` — two risks, at minimum:
      *(a)* the formal engine is frozen at `0.7.2` and its bugs cannot be fixed
      by us, mitigated by conformance fixtures;
      *(b)* Python enters the maintainer toolchain.
- [ ] `CHANGELOG.md` — **not yet.** Only when something ships.

### 7.5 PowerShell portability — mandatory reading before `scripts/`

Read `docs/architecture/powershell-portability.md` **before** editing anything
under `scripts/`. The specific trap this work will hit:

> Under `$ErrorActionPreference = "Stop"`, **Windows PowerShell 5.1 turns any
> native command's stderr into a terminating error** — including harmless
> informational output, and despite `2>$null`.

Python, pydantic and z3 write deprecation warnings to stderr as a matter of
routine. `DOCTOR-010` enforces the guard for `scripts/`. Follow the existing
pattern in `scripts/lib/execution-contract-git.ps1`, which already solves this
shape for `git`.

The maintainer machine is macOS and **cannot run Windows PowerShell 5.1 at all.**
When a check fails only on a host you cannot run, **read the CI log — do not
guess a fix.** A wrong guess costs a full CI round-trip; this repository has
already lost three that way.

---

## 8. Non-negotiables

1. **Human release authority is unchanged.** No output of this work approves,
   promotes, or releases anything. Everything is candidate evidence.
2. **AxiomGuard is read-only** (§0.2). No exceptions.
3. **No LLM in the encoding path.** If a step needs an LLM to produce claims,
   that step is out of scope — not a design problem to solve.
4. **No weakening of existing governance to make a new test pass.**
5. **One implementation per layer.** No second validator, no second solver.
6. **No source mutation.** Nothing under `source/` is read-write.
7. **Backward compatibility.** Every existing project, fixture and invocation
   validates exactly as in v1.5.0. L4 is opt-in and default off.
8. **Python never becomes a requirement for using Axiom-PMO.**

---

## 9. Deliberately out of scope for v.2.0

- Replacing the PowerShell validator.
- Making formal verification mandatory anywhere.
- Any new approval gate, or any change to human authority.
- Moving AxiomGuard code into Axiom-PMO.
- **Any modification to AxiomGuard.**
- Parsing prose constraints out of governed artifacts.
- A dashboard or web UI.
- Publishing to npm (§10).

---

## 10. npm — separate optional track, not part of v.2.0

**Recommendation: create the package manifest, do not publish.**

Background the implementing agent needs: the Human Owner **declined npm on
2026-08-11** (commit `7d2393b`), on two grounds — there was no `package.json`, and
npm's unpublish window is 72 hours, after which a name can be deprecated but never
withdrawn. `ROADMAP.md` records: *"Nothing may describe Axiom-PMO as having an npm
distribution."*

Why publishing is still the wrong move right now:

- npm does not remove a runtime dependency, it adds one. Today: git + PowerShell.
  With npm: **Node** + PowerShell. After L4: + **Python**.
- Axiom-PMO is repo-native. Its actual first step is *"copy `templates/` into
  `projects/P01-ABC/`"* and read `examples/`. Inside `node_modules/`, nobody does.
- Two distribution channels already work: the GitHub Action
  (`uses: witchwasin/Axiom-PMO@<sha>`, no local PowerShell needed) and plugin
  install from URL.
- Publishing freezes a public install contract **in the same cycle the dependency
  structure is changing.**

The reversible 80%:

- [ ] Add `package.json` + `bin` → `npx github:witchwasin/Axiom-PMO` works today.
      `"dependencies": {}` — the CLI imports only `node:` builtins.
- [ ] Optionally map `npm run check` → `scripts/check.sh`.
- [ ] Fix the `ROADMAP.md` line that says *"there is no package.json in the
      repository"*, which is used as a reason for the decline.
- [ ] **Do not run `npm publish`.** It is irreversible and outward-facing. Only
      the Human Owner does that, and only after a `DEC` openly reverses the
      2026-08-11 decision — never by a silent `ROADMAP.md` edit.

Publish only when all three hold: the dependency story is settled; a
`npm i -g` user can get templates/examples without opening the repository; and
someone who is not the author has asked for it. **Currently 0 of 3.**

---

## 11. Open decisions for the Human Owner

1. Ratify this revised plan as a `DEC`, recording the AxiomGuard read-only
   boundary (§0.2) as binding.
2. `"Project Owner"` in `policy.json:16` — typo for `"Project Manager"`, or a
   real distinct role? (§4.1)
3. Waiver asymmetry — intentional or defect? (§4.1)
4. npm: manifest-without-publish (recommended), or leave it entirely alone? (§10)
5. If M0 reports FAIL — confirm that recording `L4 — declined` and moving to M4
   is the accepted outcome.

---

*End of MasterPlan. This document defines direction, not permission. Ratification
by the Human Owner is required before implementation begins, and `feeback.md`
overrides this document wherever the two disagree.*
