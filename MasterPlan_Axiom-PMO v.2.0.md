# MasterPlan — Axiom-PMO v.2.0

> **Status:** DRAFT — for Human Owner review and ratification (a future DEC).
> **Branch:** `Axiom-PMO-v.2.0`
> **Date:** 2026-08-13
> **Scope of this document:** the v.2.0 architecture direction and milestone plan.
> It changes no shipped behavior. Nothing here is authorized until the Human Owner
> accepts it and a decision-log entry records that acceptance.

---

## สรุปผู้บริหาร (Executive Summary — ภาษาไทย)

Axiom-PMO v.2.0 ไม่ใช่การเขียนระบบตรวจสอบใหม่จากศูนย์ และไม่ใช่การเอา LLM
อีกตัวมารีวิวให้

มันคือการนำ **AxiomGuard** (repo ที่ทำไว้ก่อนหน้า — Z3/SMT formal verification
engine) กลับมาเป็น **ชั้นพิสูจน์ความจริง (Formal Assurance Layer)** ที่อยู่
**ใต้** Axiom-PMO:

- **Axiom-PMO = กำหนดว่า "อะไรคือสิ่งที่ต้องเป็นจริง"** (Governance Truth)
- **AxiomGuard = พิสูจน์ว่า "สิ่งนั้นเป็นจริงหรือไม่"** (Logical Truth)

**Core thesis ของ v.2.0:**

> เราไม่ได้พยายามสร้าง LLM ที่เชื่อฟัง Rule 100%
> เราสร้างระบบที่ไม่จำเป็นต้องเชื่อ LLM ตั้งแต่แรก

LLM เป็น **untrusted worker** — ผิดได้ แต่ระบบต้อง**จับความผิดให้ได้ก่อนผ่าน gate**
โดยใช้การตรวจ 4 ระดับ: policy → repository ground truth → semantic audit →
formal proof (SAT/UNSAT + counterexample)

Z3 ไม่ได้มาแทน Axiom-PMO — มันถูก Axiom-PMO เรียกใช้เป็น solver layer
ผลลัพธ์ทุกอย่างเป็น **candidate evidence** มนุษย์ยังเป็นผู้ปล่อย release เสมอ

---

## 1. Core Thesis

### 1.1 The one-sentence version

Axiom-PMO v.2.0 makes the AI execution path **verification-first instead of
trust-first**: the system does not try to make the LLM obey rules 100% of the
time; it makes the gates *catch* violations before anything passes them.

### 1.2 Old thinking vs Axiom model

```text
OLD THINKING
  Prompt → LLM → "Please follow rules" → hope nothing slips

AXIOM MODEL
  Policy → Contract → LLM → Candidate →
      Verification
        ├── Deterministic rules        (Level 1)
        ├── Repository ground truth    (Level 2)
        ├── Semantic audit             (Level 3)
        └── Formal proof (Z3)          (Level 4)
            → PASS / FAIL
```

The LLM is an **untrusted worker**, not a trusted component. This is the
security/verification mindset the current product already leans toward
(candidate evidence, human authority boundaries, "nothing enforced by asking
the agent nicely") — v.2.0 completes it with a formal layer.

---

## 2. The AXIOM Two-Layer Architecture

Two sibling products, one architecture:

```text
                          AXIOM
             ┌──────────────┴──────────────┐
             │                             │
        AXIOM-PMO                     AXIOMGUARD
             │                             │
     Governance Control Plane     Formal Verification Engine
             │                             │
   "What must be true?"          "Is it true?"
             │                             │
             └──────────────┬──────────────┘
                            │
                       AI Execution
                            │
                      Human Release
```

Full pipeline:

```text
┌───────────────────────┐
│       HUMAN / PM      │
└───────────┬───────────┘
            ▼
┌───────────────────────┐
│      AXIOM-PMO        │   Governance Control Plane
│  Requirements · Scope │
│  Risk · Approval      │
│  Evidence Policy      │
│  Traceability         │
│  Release Gates        │
└───────────┬───────────┘
            │  Execution Contract
            ▼
┌───────────────────────┐
│       AI / LLM        │   Claude / Codex / etc.
└───────────┬───────────┘
            │  Candidate Result
            ▼
┌───────────────────────┐
│      AXIOMGUARD       │   Formal Assurance Layer
│  Logical Constraints  │
│  Invariants           │
│  SMT / Z3             │
│  Counterexamples      │
│  Deterministic Proof  │
└───────────┬───────────┘
            │  VERIFIED / REFUTED
            ▼
┌───────────────────────┐
│      AXIOM-PMO        │   Verification Gate (v.2.0)
└───────────┬───────────┘
            ▼
        HUMAN RELEASE
```

### 2.1 Responsibility split (target state)

| Capability | Axiom-PMO | AxiomGuard |
|---|---|---|
| Requirement governance | ✅ | |
| Scope governance | ✅ | |
| PM process / risk modes | ✅ | |
| Evidence policy | ✅ | |
| Human approval | ✅ | |
| Traceability (RTM) | ✅ | |
| Release gate | ✅ | |
| Logical constraints | | ✅ |
| Formal verification (SMT/Z3) | | ✅ |
| Counterexample generation | | ✅ |
| Proof obligations | | ✅ |

AxiomGuard is **not** a feature buried inside Axiom-PMO. It is the **Formal
Assurance Layer** that Axiom-PMO calls — a separate engine, a separate repo,
a separate release train.

---

## 3. The Four Verification Levels

| Level | Name | What it answers | Engine | Authority |
|---|---|---|---|---|
| **L1** | Policy Verification | "Does the required artifact, source ref, approval, evidence exist and pass the policy rules?" | Axiom-PMO deterministic validator (PowerShell) | Blocking (today) |
| **L2** | Repository Verification | "Did the actual git diff, tests, and artifacts match what was claimed?" | git ground truth (SCOPE-DIFF, EXEC-* today; extended in v.2.0) | Blocking (today, partial) |
| **L3** | Semantic Verification | "Does the implementation semantically match the requirement and its tests?" | LLM-assisted audit | **Candidate evidence only — never final authority** |
| **L4** | Formal Verification | "Does the implementation satisfy the formalized constraints — is there a counterexample?" | AxiomGuard (Z3) | Proof result = candidate evidence feeding the gate |

- L1 and L2 are **already shipped** (deterministic, 100%).
- L3 is partially shipped (semantic handoff review as candidate evidence).
- L4 is **new in v.2.0** — the formal layer.

### 3.1 Governance Truth vs Logical Truth

- **Governance Truth** (Axiom-PMO): a requirement exists, is sourced, is
  approved by an allowed role, is traced through RTM, has test evidence, and
  cleared QA/security/release reviews. Machine-readable today
  (`pmo-config/*.json`, `validation-rules.json`).
- **Logical Truth** (AxiomGuard): a set of formalizable constraints is
  *provably* satisfied (SAT) or violated (UNSAT + counterexample) — decided by
  math, not by opinion.

They are different kinds of truth and neither replaces the other. v.2.0 makes
the gate consume both.

---

## 4. AxiomGuard as the Formal Assurance Layer

### 4.1 Architectural rule

AxiomGuard must be callable from the Axiom-PMO validator the same way git is
called today: a **sidecar CLI** with a stable, versioned input/output contract.
No validator logic moves into AxiomGuard; no solver logic moves into the
validator.

- Keeps the **"one implementation"** principle: the PowerShell validator remains
  the single governance implementation; Z3 remains the single formal engine.
  They verify different layers, so they cannot drift against each other.
- Keeps determinism: Z3 with the same constraints and same claims returns the
  same result every time. This does not violate the existing doctrine.
- Keeps the trust model: extraction/encoding of claims is **untrusted** and must
  be **exposed for human review** (the same discipline AxiomGuard already
  documents: "Extraction transparency — every claim is visible before Z3
  processes it").

### 4.2 Where it plugs in

```text
Gate (Handoff / Release)
   │
   ├── L1  Axiom-PMO deterministic rules        → FAIL/WARN (blocking)
   ├── L2  git ground truth (SCOPE-DIFF, EXEC)  → FAIL/WARN (blocking)
   ├── L3  semantic audit (LLM-assisted)        → candidate evidence
   └── L4  axiomguard verify                    → VERIFIED / REFUTED
             (formalizable constraints extracted from governed artifacts,
              compiled to .axiom.yml or equivalent, solved by Z3)
                  │
                  ▼
        FORMAL-REVIEW.json (new candidate-evidence artifact)
                  │
                  ▼
        Gate consumes it: REFUTED + counterexample ⇒ blocking WARN/FAIL
        (severity policy decides, human remains the approver)
```

---

## 5. Worked Example — Order Cancellation

The requirement (governance layer):

> REQ-001 — User must be able to cancel an order before shipment.

Axiom-PMO turns it into a governed contract (state machine declared in the
design/build-spec):

```text
Order cancellation
  Allowed:  CREATED, PAID, PROCESSING
  Forbidden: SHIPPED, DELIVERED, CANCELLED
```

AxiomGuard receives the formalized constraint:

```text
cancel(order) ⇒ order.status ∈ {CREATED, PAID, PROCESSING}
```

The solver answers **SAT / UNSAT**. If the implementation (or its claimed
state model) contains a path:

```text
SHIPPED → cancel() → CANCELLED
```

AxiomGuard proves the constraint is violated and **produces a counterexample** —
not an opinion that something "seems wrong", but a model of the violation that
a human or a developer can inspect and reproduce.

---

## 6. Non-Negotiables (Trust Model)

1. **Human release authority is unchanged.** No verification result, formal or
   semantic, may approve, promote, or release anything. All v.2.0 outputs are
   candidate evidence consumed by the existing gates.
2. **Extraction is untrusted and transparent.** Every claim that AxiomGuard
   verifies must be visible for human review before the solver runs
   (AxiomGuard's existing doctrine).
3. **Determinism is preserved.** L4 uses a theorem prover with fixed inputs;
   it is reproducible, auditable, and fails closed.
4. **No weakening of existing governance to make tests pass.** Same hard rule
   as CONTRIBUTING.md — applies to the new layer too.
5. **One implementation per layer.** No second validator, no second solver.
6. **No source mutation.** Nothing in v.2.0 edits, creates, or deletes files
   under `source/` or any governed artifact. It reads and reports.
7. **Backward compatibility.** Every existing project, fixture, and invocation
   validates exactly as in v1.x unless it opts into formal verification
   (opt-in per project/mode, default off).

---

## 7. Milestones

### M1 — Contract Bridge (foundation)

**Goal:** define how governed artifacts become formalizable constraints, and how
the validator calls the engine.

- New `pmo-config/formal-policy.json` (or extension of `execution-contract-policy.json`):
  severity by mode, opt-in declaration, artifact naming, claim-encoding rules.
- Declared **formalizable elements** in governed artifacts:
  - state machines (from `BUILD-SPEC.md` "State Machine and Transition Guards"),
  - business rules (from `PROJECT.md` Business Rules — e.g. `BR-001`),
  - environment/capability constraints (HANDOFF-012 data),
  - acceptance-case preconditions (HANDOFF-006),
  - temporal orderings (approval dates, horizon, demo date).
- Stable **sidecar CLI contract**: `axiomguard verify --input claims.json
  --rules rules.yml --output proof.json` with versioned schema.
- New candidate-evidence artifact template: `FORMAL-REVIEW.json`.

**Done when:** a project can declare opt-in, the validator shells out to
`axiomguard` (or skips cleanly when absent), and output lands in
`FORMAL-REVIEW.json` with a freshness digest consistent with the existing
dual-digest model.

### M2 — Level 4 Core: Formal Verification at the Gate

**Goal:** the first real proof results feed the Handoff/Release gates.

- Encode state-machine and business-rule constraints from governed artifacts as
  `.axiom.yml` (AxiomGuard format) or a verified-equivalent schema.
- New rules `FORMAL-001` … (result present/current, REFUTED handling,
  counterexample surfaced, claim list auditable).
- Severity: opt-in, `Lite=warn / Standard=warn / Strict=fail` default
  (mirrors existing pattern); blocking behavior per policy, never an approval.
- AxiomGuard engine work (in the AxiomGuard repo): state-machine rule type,
  counterexample humanization (render the violating path in text),
  temporal-rule reuse, `verify_structured()` path (no LLM needed for claims the
  validator itself encodes).

**Done when:** the `demo` broken/fixed pair demonstrates an L4 catch —
a constraint violation the deterministic rules cannot see — and the suite has
positive + negative fixtures with goldens.

### M3 — Level 3 Hardening: Semantic Audit Contract

**Goal:** make the existing LLM-assisted review a first-class, gated candidate
evidence stream (it exists today as HANDOFF-REVIEW.json).

- Formalize the L3 output contract: semantic mismatch findings must carry
  `requirement_ref`, `implementation_claim`, `test_claim`, severity, and a
  human decision owner — nothing new approves anything.
- Wire L3 findings into the same gate envelope as L4 (single evidence model).
- Anti-pattern: an AI's semantic verdict must never change a validator exit
  code on its own (matches existing closure-authority rules).

**Done when:** a semantic mismatch found by the LLM flows to the gate as
candidate evidence, with the same closure/decision rules HANDOFF-010 enforces.

### M4 — Level 2 Completion: Repository Ground Truth

**Goal:** close the remaining "claimed vs actual" gaps at the repo layer.

- Extend SCOPE-DIFF semantics to *tests* and *artifacts*: claimed test files
  actually changed / actually ran (CI check-run binding exists for
  `externally-observed`; extend coverage).
- Reconcile EXEC-* evidence with L4 results: a formal REFUTED must surface
  even when the agent's own report claims success.

**Done when:** an agent report claiming "all tests pass / scope respected"
cannot pass the gate against contradicting git ground truth.

### M5 — Formal Studio (read-only dashboard)

**Goal:** a read-only view of governance + proof state across projects —
the "Portfolio dashboard" gap from the v1.x roadmap, without touching authority.

- Model: Axiom Studio (Streamlit) pattern from AxiomGuard; **read-only by
  construction** (no endpoint that mutates approvals or artifacts).
- Shows: gate status, approval rows, digests, L3/L4 findings, counterexamples.

**Done when:** a dashboard renders the demo projects' state, and a review
confirms no write path exists.

### M6 — Adoption & Evidence

**Goal:** prove v.2.0 outside the author's own machine.

- npm package for the CLI (Milestone 3 Phase B from v1.x roadmap, now
  prerequisite for the sidecar story), Python packaging for `axiomguard`
  already exists on PyPI.
- One real pilot project with the Human Owner's team; recorded case study
  (repo convention: evidence, not self-report).
- Docs: `docs/concepts/formal-verification.md`, `docs/reference/formal-contract.md`,
  updated `docs/integrations/overview.md` showing AxiomGuard at Level 4.

**Done when:** an external (non-author) user has run the L4 path and the result
is recorded in the repo.

---

## 8. What is Deliberately Out of Scope (v.2.0)

- Replacing the PowerShell validator.
- Making formal verification mandatory for any existing mode/project.
- Any new approval gate or change to human authority.
- LLM-written formal constraints without human/validator review of the claims.
- Moving AxiomGuard's codebase into Axiom-PMO (they stay separate repos).
- Committing generated proof artifacts as *proof* of anything — they are
  candidate evidence like every other review record.

---

## 9. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Claim encoding is wrong (extraction error) | Expose every encoded claim for human review before solving; AxiomGuard's extraction transparency discipline; `verify_structured()` path so the validator can encode claims itself without an LLM |
| Z3 becomes a new trust dependency | Z3 is deterministic and auditable; inputs and outputs are recorded as candidate evidence; failing closed on solver absence |
| Scope creep into "smart verification" | Levels and done-criteria are explicit; non-goals section above is binding |
| Python runtime dependency in CI | Opt-in per project; validator degrades to today's behavior when `axiomguard` is absent; CI legs for L4 are separate jobs |
| The two repos drift (engine vs governance) | Versioned sidecar contract (M1) + golden fixtures that pin the interface |
| Team tries to ship without pilot evidence | M6 gates release-readiness on a recorded external pilot |

---

## 10. Open Decisions for the Human Owner

1. Ratify the architecture and this plan (record as a DEC in `decision-log.md`).
2. Choose the formal-contract schema: AxiomGuard `.axiom.yml` directly vs a
   governance-side schema compiled to `.axiom.yml`.
3. Default severity of L4 REFUTED per mode (`Lite=warn / Standard=warn /
   Strict=fail` is the proposal).
4. Opt-in mechanism: per-project declaration in `PROJECT.md` vs per-gate flag.
5. Whether M6 (pilot + npm packaging) blocks a v.2.0 release or runs in
   parallel with M2–M4.
6. Branch/versioning convention for v.2.0 (this plan lives on
   `Axiom-PMO-v.2.0`; nothing is merged until ratified).

---

*End of MasterPlan. This document defines direction, not permission. A
decision-log entry, Human Owner acceptance, and implementation milestones are
required before any code changes.*
