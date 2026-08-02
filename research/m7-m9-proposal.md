# Proposal — Milestones 7, 8, 9

> **Status: revision 3, ACCEPTED. M7 authorized for implementation; M8.0
> authorized for research only; M9's boundary confirmed, implementation not
> authorized.**
>
> Revisions 1 and 2 were each reviewed by Independent AI Reviewer; revision 3 received Independent AI Reviewer's
> verdict ACCEPT. The Human Owner then authorized this proposal on 2026-08-03:
> `DEC-011` (Milestone 7 implementation), `DEC-012` (Milestone 8.0 research
> only, plus the Strict/human-attested confirmation), `DEC-013` (Milestone 9's
> local/opt-in boundary, plus the Permanent Non-Goals section in
> `ROADMAP.md`). §0 records the disposition of every review finding across all
> three rounds; §7 is now a record of what was decided, not an open list.
>
> Implementation work for Milestone 7 proceeds on branch
> `m7-onboarding-execution-paths`, off `main`.
>
> Each milestone section is written in the roadmap's own planning shape so it
> was pasted into `ROADMAP.md` largely unedited.
>
> Author: AI (Claude Opus 5), 2026-08-03. Sources: the Human Owner's two written
> proposals of 2026-08-03; Independent AI Reviewer's reviews of revisions 1-3; the Human Owner's
> authorization of 2026-08-03.

| | Milestone | One line | Size | Depends on |
|---|---|---|---|---|
| **M7** | Onboarding and the Two Execution Paths | Stop making the user interpret where to start | Small–Medium | Nothing new |
| **M8.0** | Adversarial Review — research and go/no-go | Answer whether an independent review can be *proven*, before building one | Medium (research) | M5, M5.5 |
| **M9** | Failure Pattern Registry and Governed Improvement Proposals | Organizational memory over diagnostics already emitted | Small–Medium | M2 diagnostics |
| **M8.1** | Adversarial Review Evidence — implementation | Only on a GO from M8.0 | Large | M8.0 |
| **—** | Autonomous policy mutation | **Permanent Non-Goal.** Not deferred work | — | — |

---

## 0. Disposition of both review rounds

Recorded rather than silently absorbed, because "the reviewer said so" is not a
reason and this framework does not accept it as one anywhere else. Four findings
across the two rounds were accepted in substance and implemented differently
from the way they were proposed; each says why.

### Round 1 (against revision 1)

| Independent AI Reviewer's point | Disposition | Reason |
|---|---|---|
| No full `Mode × Gate × Path` matrix; use additive deltas | **Accepted, taken further** | The delta turned out to be *empty*, so revision 2 stopped restructuring `artifact-policy.json` at all |
| Path rules must not demand execution artifacts before execution | **Accepted; fixed differently** | Right problem, wrong fix. `validate-project.ps1` contains **zero** references to `EXEC-*` or execution artifacts — no gate *can* demand them. Independent AI Reviewer's example also keyed off an `"Execution"` gate absent from `policy.json enums.gates`. The offending rule was deleted |
| The path must be changeable | **Accepted in substance, rejected in form** | Real scenario, missed in revision 1. `axiom path set` rejected: a command surface to edit one line, printing what `axiom status` shows anyway |
| A human's onboarding answer is not `evidence_status: inferred` | **Accepted — revision 1 was wrong** | Correct. Revision 2's replacement was itself wrong; see round 2 below |
| Don't show raw trigger enum ids as questions | **Accepted** | Cheap; drift closed by a doctor check |
| Backward compatibility for projects with no path declared | **Accepted — revision 1 missed it** | Six examples, the demo, and every fixture predate the field |
| `check_run_id` proves CI ran, not that a review happened | **Accepted; promoted to M8.0's primary question** | The M5 round-2 defect one level up, with an honest ceiling added |
| Deterministic preflight before the AI review | **Accepted, scoped down** | A flag on an existing command, not a verb, never a gate |
| Human reviewer independence is unprovable offline | **Accepted** | Matches what `handoff-policy.json` already says about `reviewer_kind` |
| Finding status must distinguish actor authority | **Accepted in substance, reduced in form** | ~12 statuses across 3 actors rejected as over-modelled; existing 4-status + `closure_policy` pattern extended instead |
| Append-only single JSON is the wrong storage model | **Accepted in full** | Concurrency, merges, torn writes, history mixed with derived summary |
| Metadata can itself be sensitive | **Accepted, with a concrete rule** | Paths leak; "metadata-only" is not a guarantee |
| Don't threshold on raw occurrence counts | **Accepted** | 20 reruns of one unfixed defect is one problem |
| Candidates must not default to proposing new rules | **Accepted** | Ties to an existing roadmap `Not Now` |
| Sequence M7 → M8.0 → M9 → M8.1 | **Accepted** | Independently supported: M8.0's output sets M9's event schema |
| `v1.3.0` is governance sequencing, not a dependency | **Accepted** | Sharper wording |
| `Permanent Non-Goal`, not `Not Now` | **Accepted** | A safety boundary is a different statement from effort allocation |

### Round 2 (against revision 2)

| # | Independent AI Reviewer's point | Disposition | Reason |
|---|---|---|---|
| **B1** | **Blocking.** The wizard must not create `source/REQ/onboarding-declaration.md` — `source/` is user-owned and this collapses stakeholder input and framework-generated artifacts into one trust class | **Finding accepted in full. Both proposed remedies rejected — a third option exists that needs no new artifact** | The finding is correct and cites a non-negotiable (`AGENTS.md` rule 9, `docs/governance/source-ownership.md`). But `.axiom/onboarding/declaration.json` and `ONBOARDING-DECLARATION.md` both add an artifact, and one of them adds a reference type, to solve a problem the schema already solves: `policy.json table_schemas.delivery_work_items` **already defines `Strict Trigger`, `Mode Reason`, and `Mode Approved By`** columns, and `templates/DELIVERY.md` already ships them. See §2(b) |
| **B2** | **Blocking.** The finding lifecycle says the executor may set `disputed` *and* may never move a finding out of `open` | **Accepted in full — a straight contradiction in revision 2's own text** | Fixed with Independent AI Reviewer's wording, plus the missing property: `disputed` is not a closure and remains blocking |
| 3 | `PATH-002` must distinguish an active execution package from archived history, or a legitimate switch warns forever | **Accepted, with a concrete definition** | Correct. "The file exists" is the wrong predicate. Defined against an *unresolved* contract for a work item that is not `Done` |
| 4 | One immutable event file per validation run, not concurrent appenders on one file | **Accepted** | Revision 2's `events/*.jsonl` was ambiguous and would have reintroduced the concurrency problem it claimed to fix |
| 5 | Rename M9's retained `path` field so it is not read as a filesystem path | **Accepted, and applied wider** | Revision 2 was inconsistent with itself: the concept was headed "Delivery Paths" while the field was `execution_path`. Unified on **Execution Path / `execution_path`** everywhere — "delivery" is already taken in this repo by `DELIVERY.md`, delivery planning, and the `pmo-delivery` skill, so reusing it for a different axis is a worse collision than the one Independent AI Reviewer flagged |

### Found while revising, raised by neither review

| Issue | Fix |
|---|---|
| Revision 2 assigned **`DOCTOR-013` twice** — to the M7 onboarding-question check and to the M9 rule-lifecycle check | M7 keeps `DOCTOR-013`; M9's becomes `DOCTOR-014` |
| Revision 2 never said whether M9's event files are committed or ignored | Stated in §4: ignored by default, sharing is opt-in |

---

## 1. What already exists (so none of it gets rebuilt)

| Proposed | Already in the repo | Gap |
|---|---|---|
| Choose a governance mode | `Lite`/`Standard`/`Strict`; `policy.json`; per-work-item mode | Nothing *asks*; `axiom init --mode` requires the user to already know |
| "Override a wrong Lite choice" | **The effective-mode resolver already does this.** `MODE-001`, `MODE-003`, `STRICT-001` force Strict from a declared trigger | It runs on triggers declared in `DELIVERY.md`, which do not exist yet at init time |
| Record *why* a mode was chosen, and who said so | **`Strict Trigger`, `Mode Reason`, `Mode Approved By` columns already exist** in `policy.json table_schemas` and `templates/DELIVERY.md` | Nothing populates them at init |
| Two execution paths | Both engines exist — Handoff (`HANDOFF-001..014`, `assess-handoff.ps1`) and Governed AI Execution (`export` → `run` → `verify`, `EXEC-001..008`) | Neither is **named**, neither is **selectable**, nothing records which one a project is on |
| `axiom init` | Exists, flag-driven | No interactive mode, no risk questionnaire, no summary |
| AI review as candidate evidence | `HANDOFF-REVIEW.json` + `semantic_review` — dual-digest freshness, severity enums, closure policy, human-only lenses, attestation caveat | No equivalent *after* execution |
| Claim vs. evidence | `EXEC-005`; `structurally_checkable` vs `provenance`; `ci-check` bound to `check_run_id` | Not applied to a *review* artifact |
| Diagnostics to learn from | `diagnostics-schema.json` 1.1 with `rule_id`, `level`, `blocking`, `artifact`, `item_id`, and a `sensitive_data_policy` | Nothing aggregates them across runs |

Three structural facts shape everything below:

1. **The execution loop is not part of the gate system.** `validate-project.ps1`
   never mentions `EXEC-*` or any execution artifact. Gates check governed
   documents; `verify-execution-result.ps1` checks what an agent did.
2. **Work items already carry mode provenance.** The columns exist, ship in the
   template, and are validated. A mode declaration does not need a new home.
3. **M9 aggregates JSON the validator already emits**, which is why it is small;
   **M8 is the `HANDOFF-REVIEW` pattern one stage later**, which is why it is
   tractable. Neither needs a new engine.

---

## 2. Milestone 7 — Onboarding and the Two Execution Paths

### Why this milestone exists

Capability is not the bottleneck; the first ten minutes are. A new user must
read `README.md`, infer a mental model, guess a workflow, and only then start.
Two independent decisions are never asked:

```text
Axis 1 — who builds it?   Development Handoff  |  Governed AI Execution
Axis 2 — how hard is it governed?   Lite | Standard | Strict
```

They must stay independent. A vendor handoff can be Strict; a governed AI
execution can be Lite.

### Naming

The field and the concept are both **Execution Path** (`execution_path`).
Revision 2 used "Delivery Path" in prose and `execution_path` in the schema.
"Delivery" is already this repo's word for something else — `DELIVERY.md`,
delivery planning, the `pmo-delivery` skill — so the axis takes the other name,
and no field anywhere is called bare `path`.

### Three things this milestone must not get wrong

**(a) The questionnaire declares; it does not detect.**

At `init` there is no source, no requirement, no work item — nothing to detect
*from*. The output is a **human declaration**:

```text
GOOD   You declared that this work handles personal data.
       Strict triggers are non-downgradable, so the effective mode is Strict.

BAD    The system detected personal data.
       (Nothing was read. This would be a fabricated evidence claim of exactly
        the kind the framework exists to prevent.)
```

**(b) Where that declaration is recorded — resolved, on evidence.**

Revision 1 said `evidence_status: inferred`, which was wrong: `inferred` means an
AI reasoned from partial source. Revision 2 replaced it with a generated file
under `source/REQ/`, which was worse: `source/` is user-owned, and
`AGENTS.md` rule 9 and `docs/governance/source-ownership.md` both say the agent
must not create files there. Independent AI Reviewer's finding is accepted in full.

Independent AI Reviewer proposed two remedies — `.axiom/onboarding/declaration.json`, or
`ONBOARDING-DECLARATION.md` plus a new `Declaration:` reference type. **Neither
is needed.** The work-item schema already has the columns for exactly this:

```json
"delivery_work_items": { "columns": [
  "ID", "Mode", "Strict Trigger", "Mode Reason", "Mode Approved By", ... ] }
```

They are in `pmo-config/policy.json`, they ship in `templates/DELIVERY.md`, and
`MODE-003` / `STRICT-001` already read them. So the wizard writes:

```text
| D-001 | Strict | pii | declared at interactive init, 2026-08-05 | <name> | ... |
```

and `PROJECT.md` front matter records the mode and the execution path. That is
the whole mechanism.

Three consequences worth stating, because they are why this is better than any
of the three artifacts previously proposed:

- **No `evidence_status` problem exists.** A strict trigger is not a requirement.
  Evidence statuses live on requirement rows in `PROJECT.md`; work-item mode
  provenance lives in `Mode Approved By`. Revision 1 and revision 2 both went
  looking for a source reference that the schema never asked for.
- **Nothing is written to `source/`, and no artifact, reference type, hidden
  directory, or field is added.**
- **`Mode Approved By` is attested, not proven** — the same standing as
  `reviewer_kind` in `handoff-policy.json`. The wizard prefills it from
  `git config user.name` and requires confirmation; the value is a claim a named
  person makes, and the docs say so rather than implying identity was verified.

At init there is one generated work item, so one row carries the declaration.
When the user later splits the work, each item declares its own trigger — which
is the framework's intended per-item mode selection, not a special case.

**(c) Decision logic never enters the CLI.** `cli/axiom.mjs` states at the top
that it contains zero validation logic and must keep containing zero, because a
second implementation in JavaScript would drift from the PowerShell reference.

| Layer | Lives in | May contain |
|---|---|---|
| Prompting, TTY handling, selection UI | `cli/axiom.mjs` | Presentation only |
| Trigger list, question wording, mode resolution, generated text | `pmo-config/*.json` + `scripts/` | All decision logic |

And **non-interactive stays the default when stdin is not a TTY.** Flags always
win; a missing flag prompts only on a TTY. CI, `make demo`, and every existing
script call `axiom init --code ...` today and must not hang.

### Scope

1. **`execution_path` as a declared field.**
   - Enum in `policy.json`: `development_handoff` | `governed_ai_execution`.
   - Declared in `PROJECT.md` front matter beside `Default mode` and
     `Task source` — the existing precedent for a project-level declaration
     that changes validation.
   - **Default when absent: `development_handoff`**, the core product's own
     default. Every existing example, fixture, and the demo keeps passing.
   - `PATH-001` — declaration missing or unrecognized. `info` when absent
     (backward compatibility), `warn` when present but not in the enum.
   - `PATH-002` — the declaration contradicts an **active** execution, defined
     precisely so a legitimate switch does not warn forever: an execution
     contract exists whose work item is not `Done` and which has no verified
     result, while the path says `development_handoff`. Archived or completed
     execution evidence never triggers it — a project that ran an AI execution,
     finished it, and moved to a vendor handoff is in a valid state, and its
     audit history must stay on disk without nagging. `warn`, worded as a
     question about currency rather than an accusation:

     ```text
     PATH-002  This project declares Development Handoff, but an active
               execution package is present. Confirm the execution-path
               declaration is current.
     ```

2. **The path is a current strategy, not project identity.** Documented
   explicitly, because the switch happens in real life (a vendor withdraws; an
   AI-built item is handed outward; a verified handoff is continued by an
   execution framework). Properties:
   - changing it is an ordinary edit to `PROJECT.md`, picked up on the next run;
   - a path may **add** required artifacts and may **never remove** them, so a
     switch can never reduce governance — asserted by a test, not by prose;
   - `axiom status` shows the declared path so a stale declaration is visible.

   No `axiom path set` verb.

3. **`artifact-policy.json` is not restructured in M7.** The path delta is empty
   today, and shipping an empty mechanism to be filled later is speculative
   structure. The `⊇` invariant is specified and tested in M7; the file gains a
   `path_deltas` key when M8 produces the first real entry
   (`EXECUTION-REVIEW.json`, required only on the AI path in Strict).

4. **Interactive `axiom init`.** Two questions plus `Help me decide`:
   - Q1 execution path — asked as *"Who will build this?"*, which is the axis;
   - Q2 governance mode, or `Help me decide`;
   - `Help me decide` asks one question per entry in
     `policy.json enums.strict_triggers`, with wording read from a new
     `pmo-config/onboarding-questions.json` keyed by trigger id:

     ```json
     { "pii": {
         "question": "Will this work collect, process, or store personal information?",
         "help_text": "Names, phone numbers, email addresses, ID numbers, health data, location.",
         "recommended_mode": "Strict" } }
     ```

     `DOCTOR-013` fails when any enum trigger has no question, so the wording
     file cannot drift behind the enum.
   - A pre-creation summary — path, effective mode, *why* the mode is what it
     is, expected flow, files about to be created — then confirm.

5. **`axiom status`.** A read-only verb answering "where am I, what is next":

   ```text
   Execution Path:  Governed AI Execution   (declared 2026-08-05)
   Governance Mode: Standard (effective: Strict — D-003 declares `pii`)
   Current Gate:    Design
   Next required:   PROJECT.md has no approved Scope row  [STRUCT-001]
   ```

   `Next required` is **derived from the validator's own diagnostics** — the
   first blocking finding at the next gate, with its rule id and its catalog
   `suggestion`. A second, prettier source of "what to do next" that could
   disagree with the validator is a defect, not a feature.

6. **README restructure.** Both paths above the fold, with the statement that
   both support all three modes.

### Non-goals

- No new approval, gate, or authority.
- No detection of risk from source material. Declaration only.
- **No file created, edited, or deleted under `source/`, by the wizard or by
  anything else in this milestone.**
- No new artifact, reference type, or work-item field.
- No new required artifact for either path.
- No `artifact-policy.json` restructure. No web UI.

### Risks

| Risk | Mitigation |
|---|---|
| A path becomes an escape hatch from governance | The `⊇` invariant, asserted by a test |
| The wizard hangs CI | TTY-only prompting; flags win; a fixture runs `init` with stdin closed |
| Decision logic drifts into the JS CLI | Questions and triggers read from `pmo-config/`; a check asserts the JS file contains no trigger literals |
| "The system detected PII" wording leaks out | Text fixture on the generated summary |
| The wizard writes into `source/` by regression | A test asserts `init` creates nothing under `source/` beyond the three empty directories it already creates |
| `Mode Approved By` reads as verified identity | Docs and the summary state it is attested; wizard requires explicit confirmation of the prefilled name |
| Existing projects break | Default `development_handoff`; `PATH-001` is `info` when absent; all six examples and the demo run in CI unchanged |

### Planning shape

```text
Owner:              Human Owner
Dependencies:       none new
Primary artifacts:  pmo-config/policy.json (enum), pmo-config/onboarding-questions.json (new),
                    cli/axiom.mjs (prompting only), scripts/new-project.ps1,
                    scripts/pmo-status.ps1 (new), templates/PROJECT.md, README.md,
                    docs/concepts/execution-paths.md (new), docs/rules/PATH-00*.md
Test artifacts:     positive/negative fixtures for PATH-001..002, including an archived
                    execution package that must NOT warn; non-TTY init test;
                    text fixture for summary wording; DOCTOR-013 fixture;
                    a source/ write-barrier test; a superset assertion for the path
                    delta contract; a regression run of all six examples with no
                    execution_path declared
Risks:              table above
Non-goals:          listed above
Release decision:   1.4.0 candidate; independently releasable
```

---

## 3. Milestone 8.0 — Adversarial Review: research and go/no-go

**Research only.** No implementation is proposed for authorization. The reason
is specific: M8's central artifact sits on the same self-attestation surface
that cost Milestone 5 five review rounds, and revision 1 of this proposal got it
wrong once already. The M5.0 and M6.0 precedent — research, threat model,
explicit GO/NO-GO — is the right shape.

### What the capability is for

Deterministic rules reach what can be defined in advance. They structurally
cannot reach: behaviour changed inside an approved file; a test that passes
while testing the wrong thing; an implementation that satisfies the letter of an
acceptance criterion and not its intent; a behaviour change hidden in a
refactor. That gap is real and worth closing.

### Naming and placement (settled going into research)

**Adversarial Review *Evidence*** — artifact `EXECUTION-REVIEW.json`, rule
prefix `AREV-*`. Not a "gate": it produces candidate evidence whose *presence
and integrity* a mode may require. Calling it a gate is how, six months later,
"the AI reviewer passed it" gets read as "it is approved".

Not per-commit. Cost, latency, and review noise all argue against it, and a
control users route around is worse than none.

```text
axiom export → agent implements → axiom run (sealed test evidence)
   → axiom verify --preflight        contract integrity, base/head resolvable,
   │                                  diff available, identity binding
   → ADVERSARIAL REVIEW              independent context; no executor reasoning
   → executor fixes, or disputes with evidence
   → axiom verify                    full EXEC-* and AREV-*
   → human approval
```

The preflight is a flag selecting an existing subset of checks — not a new verb,
never a new gate. Its purpose is correctness before cost: a review of a diff
whose base does not resolve produces findings about the wrong code.

### The primary research question

> **A `check_run_id` proves a CI job ran. It does not prove that an independent
> adversarial review produced this artifact.**

A CI job can copy a file the executor wrote, call a script that never invokes a
reviewer, use a modified prompt, or upload a placeholder. Revision 1 called
`ci-observed` the strongest tier and stopped there; that is the M5 round-2
defect one level up.

M8.0 must determine what binding set makes `ci-observed` mean something —
candidates: `check_run_id`, workflow identity and path, the workflow file's
commit, reviewer adapter/command identity, review-policy version,
prompt/config digest, `contract_sha256`, `base_sha`, `head_sha`, and a digest of
the review artifact itself.

And it must state the **honest ceiling** in its output: even with every binding
above, what is proven is *"a named workflow, at a known commit, produced this
file"* — never what happened inside the model call. If the research concludes
the achievable assurance does not justify the machinery, **NO-GO is a correct
outcome** and the milestone should not be built.

### Other questions M8.0 must answer

1. **Provenance tiers.** Whether the three-tier model holds up:

   | Tier | What it would prove | Provisional standing |
   |---|---|---|
   | `ci-observed` | A workflow outside the executor's control produced this | Strongest, *subject to the binding set above* |
   | `human-attested` | A named person is accountable | Sufficient alone |
   | `artifact-observed` | The file is internally consistent — **not** that a review happened | Requires human acceptance, exactly as `EXEC-005` already requires for artifact-observed test evidence |

2. **Finding lifecycle and authority.** Three actors must not share statuses.
   Proposed starting point — the existing four statuses plus two, with a
   `settable_by` map, rather than a parallel 12-status model:

   | Status | Settable by | Means | Blocking |
   |---|---|---|---|
   | `open` | reviewer | Raised, unresolved | yes |
   | `disputed` | executor | Contested with evidence. **Not a closure** | yes |
   | `resolved` | reviewer only, on re-review | The reviewer re-checked and agrees | no |
   | `false_positive` | human | The finding was wrong | no |
   | `accepted_risk` | human | Understood and accepted | no |
   | `deferred` | human | Deliberately later | no |

   Authority attaches to the **role** (reviewer / executor / human), not the
   *kind* (ai / human) — revision 1 conflated them. The rule, stated without the
   contradiction revision 2 contained:

   > The executor may transition an open finding only to `disputed`, with
   > evidence. `disputed` is not a closure and remains blocking until a reviewer
   > re-review or a human disposition. The executor may never set `resolved`,
   > `false_positive`, `accepted_risk`, `deferred`, or any other closure or
   > acceptance state.

   Security, legal, business, and privacy categories stay human-only to close,
   mirroring `HANDOFF-010`.

3. **Strict must not become pay-to-pass.** Requiring an independent AI review in
   Strict creates a procurement dependency: an organization without a second
   model, or with a policy against sending diffs to one, could not pass Strict.
   Independence is about context and authority, not vendor — a `human-attested`
   review by someone other than the executor must satisfy Strict identically.
   With the honest caveat, in the policy file itself:

   > Axiom-PMO records and validates the declared reviewer identity and its
   > decision reference. It does not independently prove organizational identity
   > separation without an external identity system.

4. **Enforcement levels**, mapping onto the existing `severity_when_missing`
   pattern: Lite disabled, Standard `warn`, Strict `fail`.

5. **Evaluator isolation.** The evaluator sees the approved requirement, scope,
   acceptance criteria, contract, diff, test artifacts, and architecture
   constraints. It does not see the executor's chain of thought, its persuasion,
   a prior reviewer's verdict, or the narrative fields of
   `EXECUTION-RESULT.json`, which are written by the actor under review and are
   by definition a claim.

### Non-goals

- Not a gate, not an approval, never authority. A verdict must never change an
  exit code.
- Not the enforcement mode for the M6.5 advisory hook, which is separately
  **Blocked** in the roadmap. M8 must not become it by another route.
- Not a code-quality linter.
- **Not an implementation authorization.**

### Planning shape

```text
Owner:              Human Owner
Dependencies:       M5 (execution contract), M5.5 (check_run_id binding)
Primary artifacts:  docs/architecture/adversarial-review.md (research + threat model),
                    a GO/NO-GO recommendation, a draft policy and artifact schema
Test artifacts:     none in 8.0 -- research produces a threat model, not code.
                    One demonstration is required in the report: that an
                    executor-authored review does NOT satisfy Strict alone,
                    shown the way the M5 round-2 defect was shown -- demonstrated,
                    not asserted
Risks:              the achievable assurance may not justify the machinery; NO-GO is
                    a legitimate and cheap outcome at this stage
Non-goals:          listed above
Release decision:   research only. Implementation (M8.1) is a separate decision on
                    the report's recommendation
```

---

## 4. Milestone 9 — Failure Pattern Registry and Governed Improvement Proposals

### Why it is small

The validator already emits everything needed. M9 aggregates existing JSON and
adds a proposal artifact. No new instrumentation, no new engine, no ML —
counting and clustering by `rule_id` is the whole algorithm.

### Boundaries set before any code

1. **Local and opt-in. No network transmission, by default or implicitly.** Any
   future external aggregation requires its own milestone and its own Human
   Owner decision.
2. **"Metadata-only" is not a privacy guarantee.** Paths leak:
   `customers/acme/fraud-investigation.md` discloses the subject without a byte
   of content. Every field carries an explicit disposition:

   | Field | Disposition |
   |---|---|
   | `rule_id`, `level`, `blocking`, `mode`, `gate`, `execution_path` | retain — closed enums |
   | `artifact` | retain **only** if it matches the closed set of governed artifact names in `artifact-policy.json` (`PROJECT.md`, `DELIVERY.md`, `DESIGN/BUILD-SPEC.md`, …); anything else → `other` |
   | `item_id` | normalize to its pattern (`D-###`, `REQ-###`), never the literal |
   | project name, branch name | hash with a per-repository salt |
   | free text, `message`, `suggestion`, source paths | drop |

   No field in the registry is named bare `path`; the execution-path axis is
   `execution_path`, and filesystem artifact names are governed by the
   `artifact` row above.
3. **Aggregation is not evidence.** "This rule fired 14 times" is an observation
   about the registry, not a finding about any project.

### Scope

1. **Immutable per-run event files + a rebuildable derived registry.** A single
   append-only document is the wrong shape: concurrent CI writers collide, git
   merges conflict, a torn write corrupts the file, and raw history ends up
   mixed with derived summary. The fix is not "append carefully" — it is that
   **nothing is ever appended to a closed file**:

   ```text
   .axiom/learning/events/<utc-timestamp>-<run-id>.jsonl
        one file per validation run, written once, never reopened
        one diagnostic event per line
             │
             └── aggregate ──> FAILURE-PATTERNS.json   derived, disposable
                                      │
                                      └──> IMPROVEMENT-CANDIDATE.json
   ```

   Two writers cannot collide because two runs never share a file. The registry
   must be **fully rebuildable from the events** — asserted by a test that
   rebuilds and compares — so a corrupted registry is never a data-loss event.

   **Events are git-ignored by default.** They are local observations, and
   committing them by default would push per-run metadata into shared history
   without anyone choosing to. A team that wants shared organizational memory
   opts in, and the derived registry is the file to share, not the raw events.

2. **Clustering thresholds are multi-dimensional.** Twenty reruns against one
   unfixed defect is one problem. A cluster is scored on distinct run ids,
   distinct commits, distinct work items, distinct projects, the time window,
   and the disposition distribution — never a raw count.

3. **Disposition per cluster:** `true_defect` | `false_positive` | `user_error`
   | `undetermined`. The false-positive path is the half usually forgotten and
   the half that keeps the framework usable: a rule that annoys people is a
   defect in the rule.

4. **`IMPROVEMENT-CANDIDATE.json`** — generated when a cluster crosses its
   threshold. Constraints:
   - a candidate must consider remedies from the full set — documentation,
     onboarding, error-message wording, a changed default, a validator defect,
     false-positive reduction, review-prompt wording, *and* a new deterministic
     rule — with "add a rule" never the default. This ties directly to the
     roadmap's existing `Not Now`: "adding validation rules only to increase
     perceived coverage";
   - when written by an AI, `status` may only ever be `proposed`. Any other
     value requires a `DEC-###`.

5. **Rule lifecycle in the catalog.** `validation-rules.json` gains an optional
   `lifecycle`: `experimental` | `enforced` | `deprecated`, with one hard
   invariant:

   ```text
   An experimental rule may be `info` or `warn`.
   It may never be `fail`, `fail_release`, or blocking.
   Promotion experimental -> enforced requires a DEC-### and a roadmap entry.
   ```

   Enforced by `DOCTOR-014`, in the same style as `DOCTOR-008` requiring a
   suggestion on every failable rule. This is what makes the lifecycle real
   rather than a diagram.

### The honest limit on preventing self-modification

> **Nothing offline can prevent an agent with write access from editing
> `pmo-config/*.json`.** Claiming otherwise would be the same false assurance
> this framework exists to prevent — the M6 round-1 finding (ownership decided
> by a self-declared digest) is the local precedent.

What is achievable is detection and visibility, stated as such the way Milestone
6 states it about out-of-scope edits:

- a rule flagging any change to a severity, authority, or lifecycle field under
  `pmo-config/**` inside a verified commit range as requiring a human decision
  reference — the mechanism `EXEC-007` already uses to catch a decision record
  edited inside the range under verification;
- `CODEOWNERS` on `pmo-config/**`;
- a `SCOPE-DIFF`-style prohibited-path default, so an execution contract does
  not grant `pmo-config/**` without a deliberate grant.

### Non-goals

- No telemetry, no external service, no cross-organization data.
- No automatic rule creation, editing, or promotion.
- No automatic closure of a recurring finding.
- No ML.

### Planning shape

```text
Owner:              Human Owner
Dependencies:       M2 structured diagnostics (delivered).
                    Sequenced after M8.0 so the research can specify what review
                    disposition data the event schema must carry
Primary artifacts:  pmo-config/learning-policy.json (new, incl. the field disposition
                    table), templates/IMPROVEMENT-CANDIDATE.json (new),
                    scripts/aggregate-diagnostics.ps1 (new),
                    validation-rules.json lifecycle field + DOCTOR-014,
                    docs/concepts/governed-learning.md
Test artifacts:     rebuild-from-events equality test; a concurrent-run test proving two
                    runs never write the same file; a fixture proving no artifact content
                    or unlisted path reaches the registry; a fixture proving an
                    experimental rule cannot be blocking; a fixture proving an
                    AI-written candidate cannot leave `proposed`; a clustering fixture
                    where 20 reruns of one defect do not cross a threshold
Risks:              privacy leakage through paths and names; candidates that only ever
                    propose more rules; thresholds tuned to noise
Non-goals:          listed above
Release decision:   1.5.0 or later; smallest of the three, safe to slip
```

---

## 5. Permanent Non-Goals

A new heading in `ROADMAP.md`, separate from `Not Now`. `Not Now` reads as
near-term effort allocation and implies "later, perhaps". This does not.

> ### Permanent Non-Goals
>
> Excluded by design, not deferred. Revisiting any of these is a change to what
> Axiom-PMO is, not a scheduling decision.
>
> - **Autonomous policy mutation.** An AI may not change a rule's severity,
>   promote an experimental rule to enforced, alter authority policy, reduce a
>   Strict requirement, change a schema so its own output passes, or approve a
>   rule it proposed. An AI that can change the rule it is judged by is the
>   exact failure mode this framework exists to prevent. `AGENTS.md` rule 11
>   already says this for handoff findings; this generalizes it.
>
>   What an AI may do: **observe → aggregate → propose → supply evidence.**
>   What only a human may do: **review → authorize → promote → accept risk.**

The Human Owner's own scoring should be kept as written: autonomous
self-improvement at 0/10 is a **safety boundary, not a capability gap**. One
refinement — today's automated recurring-pattern detection is nearer 0 than 3,
because no aggregation exists at all. The 8.5 for the manual governed loop is
well supported by the git history: defect → reproduce → fix → regression test →
threat-model update → independent re-review → human closure, repeated across
M4.5, M5, M5.5, and M6.

---

## 6. Sequencing

```text
v1.3.0 release-state decision (outstanding, separate)
   │
   └── M7   Onboarding + Execution Paths ........... 1.4.0   independently releasable
          │
          └── M8.0  Adversarial review research ..... research output + GO/NO-GO
                 │
                 ├── M9   Failure Pattern Registry ... 1.5.0
                 │
                 └── M8.1 Adversarial Review Evidence  only on GO; 1.5.0+
```

Milestone numbers are kept; execution order is not forced to follow them.
M8.0 runs before M9 for a concrete reason beyond risk-sequencing: its output
determines what review-disposition data M9's event schema must carry, and
running M9 first would mean changing that schema afterwards.

On the tag:

```text
M7 does not technically depend on the v1.3.0 tag. The Human Owner should settle
the outstanding release-state decision before authorizing implementation, to
keep release scope and milestone scope separate.
```

Governance sequencing, not a code dependency.

## 7. Decisions from the Human Owner (recorded 2026-08-03)

All seven items below were decided, not defaulted by an AI. Independent AI Reviewer's reviews
recommended; they did not authorize.

1. **M7 implementation authorized**, as revised. Recorded as `DEC-011`.
2. **Execution-path contract confirmed**: `execution_path` is a governed
   declaration and a *current strategy, not project identity*; a path may add
   required artifacts and may never remove them; the default when absent is
   `development_handoff`.
3. **Declaration mechanism confirmed**: onboarding answers are recorded in the
   existing `Strict Trigger` / `Mode Reason` / `Mode Approved By` work-item
   columns; nothing is written under `source/`; no new artifact or reference
   type is created; `Mode Approved By` is attested, not proven.
4. **M8.0 research authorized, research only** — threat model plus GO/NO-GO,
   with the `ci-observed` provenance question as its primary subject. NO-GO is
   an acceptable outcome. Recorded as `DEC-012`.
5. **Confirmed that a `human-attested` review satisfies Strict**, so Strict
   never requires purchasing a second model — with the stated caveat that the
   framework records attested accountability, not proven identity separation.
6. **Confirmed M9 is local and opt-in**, with no network transmission by
   default or implicitly, events git-ignored by default, and any future
   external aggregation a separate milestone and decision. Recorded as
   `DEC-013`, alongside item 7.
7. **`Permanent Non-Goals` section added** to `ROADMAP.md` (§5 here).

Items 1–7 are decided. Everything else here is design detail that may be
revised during implementation without a further decision.
