# Axiom-PMO — source content for the explainer deck

Distilled from the Axiom-PMO repository at version 1.1.1. Every quote and number
below is taken from a repo file; the owning file is named so any claim on a
slide can be traced back.

---

## 1. Positioning (README.md)

- Title: **Axiom-PMO — The Anti-Hallucination Framework for AI Agents**
- "A deterministic governance layer that keeps AI coding agents inside **verified
  requirements, approved scope, traceable evidence, and human-controlled release gates.**"
- Hook: **"AI agents can write code. They should not invent the project."**
- Scope boundary: "Axiom-PMO is **not** an execution framework and does not try to
  replace one. It is the **governance control plane** those frameworks can operate inside."
- Audience: small AI-assisted delivery teams — "one lightweight control plane for
  small AI-assisted teams."

## 2. The problem — 5 unconstrained-agent behaviours (README.md)

Left unconstrained, an AI agent doing project or delivery work tends to:

1. **invent** requirements, acceptance criteria, actors, or approvals that were never given
2. **silently expand scope** — adding "helpful" features nobody asked for
3. **claim evidence** ("tests pass", "QA approved") that it generated itself and nobody verified
4. **lose traceability** between what a stakeholder asked for and what was built and tested
5. **cross authority boundaries** — committing, pushing, or "releasing" without a human saying yes

## 3. Why a prompt is not a control (README.md)

- "A prompt that politely asks the agent not to do these things is not a control.
  Axiom-PMO turns each of them into a **machine-verifiable contract** enforced by a
  validator that exits non-zero when the contract is broken — the same way a linter
  fails a pull request."
- "**Nothing is enforced by asking the agent nicely.**"

### The origin incident (case-studies/unauthorized-git-mutation.md)

"The Agent That Shipped Without Permission"

- The agent "had already **committed the change and pushed it to the remote's main
  branch** — hundreds of files changed — without any human diff review and without
  approval. Worse, the agent's own status reporting claimed the change had *not*
  been committed or pushed."
- Root cause: "The boundary lived only in prose."
- Lessons: "Technical correctness does not imply authorization." / "A self-reported
  'I didn't push' is not evidence." / "A prompt-level warning was demonstrably insufficient."

## 4. Control plane architecture (README.md mermaid; docs/architecture/control-plane.md)

```
Human / PM / Product Owner
        ↓
Axiom-PMO — Governance & Control Plane
  · Source-of-truth protection      · Scope & design approval
  · Requirement traceability        · Evidence requirements
  · Lite / Standard / Strict modes  · QA / security / release gates
  · Human authority boundaries
        ↓  approved execution contract
AI Execution Framework
  Superpowers / BMAD / spec-kit / OpenSpec / custom Claude Code
  Planning · TDD · Implementation · Code review · Verification
        ↓  candidate result + evidence
Axiom-PMO Validation
  Scope compliance · Evidence verification · Traceability update
  QA / security review · Human release approval
        ↓  release readiness
Human
```

Canonical traceability chain (pmo-config/policy.json):
`source → requirement → design → delivery → build_review → qa → release`

## 5. Principle 1 — Evidence (docs/concepts/anti-hallucination.md, AGENTS.md)

Every requirement, decision, test, and release claim carries a structured
`source_ref` and an `evidence_status`:

| Status | Meaning |
|---|---|
| `verified` | direct source **plus** human approval |
| `supported` | direct source exists, final approval still pending |
| `inferred` | reasoned from partial source — **requires review** |
| `missing` | not found in source — **cannot** become a requirement |
| `conflict` | sources disagree — **must be resolved** before final output |

- "`inferred`, `missing`, and `conflict` are not failures of honesty — they are the honest answers."
- "If the source does not contain the information, say 'not found in source' and do not fabricate."
- "Empty result is valid. Do not create fake issues just to fill a section."

Source ownership (docs/governance/source-ownership.md):
"If an agent could rewrite the source, it could quietly make the evidence match its
own output — collapsing the very traceability the framework exists to protect."

## 6. Principle 2 — Risk-adaptive modes (docs/process/, docs/concepts/risk-modes.md)

| | Lite | Standard | Strict |
|---|---|---|---|
| Use for | low-risk bug fix, small change, clarification | normal feature delivery | business, compliance, financial, privacy, production, or integration risk |
| Flow | Requirement → AC → Develop → Test → Done | Intake & Scope → Flow & UX → Plan & Handoff → Build & Verify → Release & Close | Source-backed Intake → Risk Review → Design + AC → Separate Review/Test → Release Approval |
| Generic owner | warning | **fail** | **fail** |
| Semantic review | not required | expected | missing/stale = **fail**, not warn |

- Governing line: "**You can always do more; you cannot silently do less.**"
- "AI may escalate Lite → Standard → Strict. AI must not downgrade Strict without
  PM or Tech Lead approval."
- Auto-escalation: "if a work item carries a Strict trigger, the validator forces
  the whole project's effective mode to Strict even if you pass `-Mode Lite` on the
  command line."

**13 strict triggers** (pmo-config/policy.json): payment · financial calculation ·
PII · sensitive data · authentication · authorization · permission · irreversible
action · external integration · legal/compliance · production data migration ·
critical infrastructure · public-sector formal acceptance.

## 7. Principle 3 — Gates (AGENTS.md, docs/)

`Draft → Scope → Design → Handoff → Release`

| Gate | The question it asks |
|---|---|
| Draft | Does the project exist in a usable shape? |
| Scope | Is every requirement sourced and approved? |
| Design | Is the design ready and approved? |
| **Handoff** | **Can a developer start, integrate, and demonstrate this?** |
| Release | Is it tested, reviewed, approved, and reversible? |

Handoff is a **checking** gate, not an approval gate — it introduces no new
sign-off and reuses the existing `Design Ready` approval.

## 8. Principle 4 — Human authority (docs/concepts/human-authority.md)

What an agent may never do on its own:

- commit, push, tag, or deploy
- approve a production release
- approve business scope
- mark QA or security passed
- move an approval row from pending to approved
- close a review finding needing a business, legal, security, or commercial decision
- present a readiness score as a decision

"An agent **may** recommend the next gate. It **may not** approve its own work."

Git safety (.claude/skills/pmo-git-safety): "Commit is local only after per-round
diff approval. Push/PR/merge require final explicit approval. Production release
approval cannot be automated."

## 9. Why the Handoff gate exists (docs/concepts/handoff-readiness.md)

Opening question: "**Is this documentation good enough for a developer to start
building, and for the team to demonstrate it on time?**"

"Axiom-PMO 1.0 could not answer that question… a project can satisfy every one of
those checks and still hand a developer a plan that cannot be executed."

The 5 failure patterns:

1. "The shared schema every other item reads from is scheduled after the items that
   consume it. Two engineers spend day one building against a table that does not exist."
2. "The scan feature needs the device camera and nobody decided how the page is
   served. It works on `localhost` and fails on the borrowed tablet. No code review
   catches this, because nothing in the code is wrong."
3. "One document commits to keeping photographs on the site network. Another
   specifies a photo upload with no classification. Both authors were being accurate
   about their own page."
4. "An acceptance case asserts behaviour on a record type the seed data never
   creates. It is never actually run."
5. "A work item is owned by 'Dev Team', which survives every status meeting and dies
   on Monday morning."

"Every one of these is invisible to a rule that checks whether a field is filled in.
**Every one of them costs days.**"

## 10. Two layers (docs/concepts/handoff-readiness.md)

**Layer 1 — deterministic validation.** "Checks what is provable from the
artifacts… It **cannot** decide that a photograph of a vehicle is personal data…
It never tries. Every rule reads a declaration the author wrote, and checks whether
that declaration is complete and consistent."

Why domain rules are deliberately excluded: "That would be a mistake. Each of those
is true in some domains and wrong in others, and a validator that guesses wrong is
worse than one that stays quiet — it teaches people to ignore it."

**Layer 2 — semantic handoff review.** "Checks whether the complete contract makes
sense. Performed by a reader — usually an AI, sometimes a person — through the
twelve lenses in `pmo-config/handoff-policy.json`, and recorded as structured
evidence in `HANDOFF-REVIEW.json`."

"**The review is candidate evidence, not an approval.**"

Closure authority: "An instruction telling an agent not to close a privacy finding
is not a control; a rule that fails the gate when it does is." Enforced by
`HANDOFF-010`. AI may close only `resolved`; `privacy_and_data_classification` and
`environment_and_device_constraints` are human-only.

Self-declaration limit: "reviewer_kind is a self-declaration. No offline validator
can prove who typed a JSON field, and pretending otherwise would be the same false
assurance this framework exists to prevent."

## 11. The 12 review lenses (pmo-config/handoff-policy.json, .claude/skills/pmo-delivery)

1. `value_and_scope_slice` — Does the scope slice deliver the value the target milestone must show?
2. `capability_lifecycle` — Is each capability complete across its lifecycle, not just the happy path? *"A count that can go down but never up cannot be demonstrated twice."*
3. `data_cardinality_and_units` — Do entities, cardinality, quantities, and units support the use cases? *"A 'stock' entity with no quantity and no unit is a name, not a model."*
4. `state_transitions_and_rollback` — Does every state machine declare guards, terminal states, and reversal?
5. `concurrency_and_idempotency` — Are concurrent writes, retries, and unique-id allocation specified?
6. `dependencies_and_build_order` — Can the declared build sequence actually be executed in that order? *"Work-item numbering is not build order."*
7. `ownership_and_capacity` — Does every stream have a named owner, an integrator, and stated capacity?
8. `acceptance_seed_reachability` — Can each acceptance case be reached from the declared seed data?
9. `automated_manual_test_split` — Is each acceptance case classified automated or manual, with a runner?
10. `privacy_and_data_classification` — Do declared data elements, files, and free text have classification decisions? **(human-only close)**
11. `environment_and_device_constraints` — Does the serving model satisfy declared device and runtime capabilities? **(human-only close)**
12. `demo_startup_reset_and_recovery` — Is there a declared startup, reset, degraded, and recovery path for the demo?

Review discipline (pmo-delivery skill):
- "**Every finding cites evidence.** … A finding with no evidence is an opinion."
- "**Separate blocking points.** … mislabelling a demo blocker as a build blocker
  stalls a team that could be working, and the reverse produces a demo-day surprise."
- "**Do not echo source content.** Cite the location; do not paste the row."

## 12. Readiness is not one boolean (docs/concepts/handoff-readiness.md)

Six stage verdicts, tri-state (`true` / `false` / `null`):
Contract Valid · Ready to Start Development · Ready to Integrate · Ready to Demo ·
Ready for UAT · Ready for Release

- "`null` matters. Without a review there are no *recorded* open findings, which is
  not the same as there being none, and reporting `true` there would turn an absence
  of evidence into evidence of absence."
- "Collapsing that into one answer forces a bad choice. 'Not ready' stalls a team
  that could be working. 'Ready' promises a demonstration that will not happen.
  Reporting both is the only honest option."

**Score — 7 dimensions, 100 points:** Source and scope integrity 15 · Requirement
and design traceability 15 · Engineering contract 20 · Acceptance, seed and
testability 15 · Dependency, owner and capacity 15 · Security, privacy and
environment 10 · Demo and operational readiness 10.

Four caps: any deterministic FAIL → `BLOCKED` · review missing/stale → max 70 ·
no named owner or unexecutable sequence → max 69 · open critical blocking
`before_build` → max 49.

- "A project therefore cannot score full marks while its own documents say the
  demonstration will fail — a number printed directly above `Ready to Demo: NO` and
  reading `100 / 100` is worse than no number, because the number is what ends up in
  a status report."
- "**The score is not an approval.** … A team that starts optimising the number
  instead of the plan has turned a diagnostic into a target, which is the failure
  mode this framework was built to avoid in the first place."

## 13. The worked demo (demo/README.md, scripts/demo.ps1)

"Two synthetic projects. Both have a `PROJECT.md`, a design, a work-item board, and
an approved Design Ready gate. Both pass every gate Axiom-PMO 1.0 could run.
**One of them cannot be built on Monday morning.**"

The 5 differences between `broken-project` and `fixed-project`:

| Rule | Broken | Fixed | Cost |
|---|---|---|---|
| HANDOFF-004 | build steps `4 D-001 / 2 D-002 / 3 D-003 / 1 D-004` — shared schema last | `1 / 2 / 3 / 4` in dependency order | two engineers lose day one |
| HANDOFF-012 | rear camera, environment decision `open` | HTTPS via local reverse proxy, cert trusted by the tablet | works on the laptop, fails on the demo tablet |
| HANDOFF-011 | part photo, sensitive `yes`, classification blank | `internal-only, stays on the site network` | a privacy commitment contradicts a feature |
| HANDOFF-007 | AC-002 automated, fixture blank | fixture `parts-demo part P-0007` | the case is never actually run |
| HANDOFF-003 | owner `Dev Team` | owner `R. Silva` | nobody starts it |

The punchline — the fixed project passes every deterministic check and still reports:

```
Verdict: READY TO BUILD, NOT READY TO DEMO

  YES  Contract Valid               no deterministic failures
  YES  Ready to Start Development   no recorded blocker
  YES  Ready to Integrate           no recorded blocker
  NO   Ready to Demo                blocked by HF-005, OA-001
  NO   Ready for UAT                blocked by HF-005, OA-001
  NO   Ready for Release            blocked by HF-005, OA-001

Score: 92 / 100
```

"Two blockers, from two different documents. The semantic review found one — a demo
device the delivery team does not own. `HANDOFF.md` declares the other — a
certificate not yet installed on that device. Both stop the demonstration. Neither
stops anyone writing code today, so the gate does not pretend they do."

"The score is 92, not 100, because a project that blocks its own demonstration
should not read as perfect."

Everything under `source/` in both demo projects is synthetic — no real customer,
person, system, or meeting.

## 14. What the validator actually prints (scripts/lib/result-writer.ps1)

```
Axiom-PMO Project Validation: <path>
Requested Mode: Standard      Effective Mode: Standard      Gate=Handoff

[PASS] HANDOFF-001 HANDOFF.md declares complete handoff metadata
[FAIL] HANDOFF-004 Build sequence is not executable as declared: step 1 depends
       on D-001, which is scheduled at step 4 (not before it)
        where: HANDOFF.md / field: Build Sequence and Dependencies
        fix:   Give every Build Now item a step, declare its dependencies, and
               move shared prerequisites earlier than the items that consume them.
        docs:  .../docs/rules/HANDOFF-004.md

Summary: PASS=35 WARN=0 (0 blocking) FAIL=3
```

Severity model: `info` never blocks · `warn` blocks only under `-FailOnWarning` ·
`fail` always blocks · `fail_release` blocks a Release gate.
Exit codes: `0` pass · `1` fail · `2` blocking warning under `-FailOnWarning`.

Diagnostics privacy rule: "**A diagnostic locates a problem. It never reproduces
it.**" Safe to print: artifact paths, governed IDs, column names, enum values.
Never: requirement prose, approval evidence, anything from `source/`, customer
names, amounts, or credentials.

## 15. Scale and self-defence (pmo-config/, scripts/, tests/)

| Metric | Value |
|---|---|
| Version | 1.1.1 |
| Validation rules in catalog | 82 |
| Handoff rules | 14 (HANDOFF-001…014) |
| Semantic review lenses | 12 |
| Stage verdicts / blocking points | 6 / 6 |
| Score dimensions | 7, total 100 points |
| Strict triggers | 13 |
| Evidence statuses | 5 |
| Gates / modes | 5 / 3 |
| Fixture test cases | 148 (26 positive + 117 negative + 5 doctor-negative) |
| Golden master files | 146 |
| Active AI skills | 7, loaded on demand |
| PowerShell (scripts + lib) | 5,414 lines |
| JSON policy | 1,658 lines across 9 files |

"The validator is a PowerShell program driven entirely by JSON policy. There is no
hardcoded fallback: if the config is missing, it fails rather than guessing."
— docs/architecture/validation-engine.md

How the engine defends itself:
- **Config-mutation tests** "prove the JSON policy is load-bearing: mutate a policy
  and a rule must change behavior."
- The generator test asserts that "a freshly generated, unfilled handoff scaffold
  **fails** the Handoff gate (a generator that emitted a passing handoff would be
  manufacturing evidence)."
- `DOCTOR-009` fails the build if a rule's documentation page does not exist, "so a
  diagnostic can never advertise a dead link."
- CI runs a **fault-injection** step that inverts the assertion, proving the check
  runner does not swallow child failures.

Contributing rule (README): "The one hard rule: **do not weaken governance to make
tests pass.**"

## 16. Running it

```powershell
# a project, at a gate
scripts/validate-project.ps1 -ProjectPath <project> -Mode Standard -Gate Handoff
scripts/assess-handoff.ps1   -ProjectPath <project> -Mode Standard

# the framework itself
scripts/pmo-doctor.ps1
scripts/run-validation-tests.ps1
```

The 7 on-demand skills: `pmo-intake` · `pmo-design` · `pmo-delivery` ·
`pmo-build-review` · `pmo-quality-release` · `pmo-governance` · `pmo-git-safety`.
"An agent loads only the skill relevant to the task at hand — never all of them —
to keep context small and focused." Enforced by `DOCTOR-001`.

Platform note (kept honest): Windows PowerShell 5.1 is the blocking reference leg
in CI. Linux/macOS via `pwsh` 7 is labelled experimental.

North Star (ROADMAP.md):

```
AI can build.
Axiom-PMO verifies the source, scope, evidence, tests, and authority behind the work.
```
