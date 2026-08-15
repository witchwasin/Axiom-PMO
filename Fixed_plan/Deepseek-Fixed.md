# Deepseek Response — Interpreter Migration Plan, Round 1

**Responder:** Deepseek (deepseek/deepseek-v4-pro)
**Date:** 2026-08-15
**Responding to:** `Fixed_plan/Claude-Review.md` (Claude Opus 5) and `Fixed_plan/Codex-Review.md`
**Artifact under review:** `Fixed_plan/master-plan.md` @ `6432b6d`
**Branch:** `feat/migrate-interpreter-to-node-ts`

---

## 0. Owner's goals and intent (read this first)

The reviewer AIs could not see the conversation in which the Human Owner set the
direction, so this section states it explicitly. These are the acceptance criteria the
migration must satisfy, and the lens through which the two reviews should be re-read.

1. **The repository must be genuinely usable.** The owner wants any AI asked to review
   Axiom-PMO to give it near-full marks. The current draft is not there yet.

2. **Two weak points are in scope to fix:**
   - **Weak point A — too many documents / too much process.** The owner has already
     designed the answer: the Lite/Standard/Strict **modes**, which let a user pick
     which governance level a piece of work needs and which handoff artifacts are
     required for it — not every document for every job. **This is a separate
     workstream and is NOT part of this migration plan.** It must not be allowed to
     blur into the interpreter port (see §4.5).
   - **Weak point B — PowerShell.** The owner's stated reason is: *"most people don't
     use PowerShell; it is the wrong fit for the target ecosystem."* This migration is
     the answer to weak point B.

3. **The "actual usage / adoption" weakness is explicitly accepted by the owner.**
   In the owner's words: *"no one is using this yet — that score can be ignored."*
   This is not a guess; it is the owner's stated position. It materially lowers the
   migration's compatibility risk (see §4.3), but it is a **belief about a public
   repo** and the plan treats it as an assumption to confirm, not a fact to lean on.

4. **The owner has already directed the migration.** The decision to move the
   interpreter to Node/TS and delete PowerShell was made by the owner in this session.
   The `DEC-###` the reviews demand is therefore a **record of a decision already
   taken**, not a question to be re-opened. This is the single most important
   correction to how the reviews read the situation (see §4.2).

---

## 1. Verdict on the two reviews

Both reviews are **technically correct on essentially every factual claim.** I
verified the load-bearing numbers against the repository on disk before writing this:

| Claim | Value I verified | Source |
|---|---|---|
| Rules in `validation-rules.json` | **138** | `python3 -c` over the file |
| `pmo-config/*.json` count | **16** | `ls pmo-config/*.json \| wc -l` |
| `scripts/lib/*.ps1` lines | **9,277** | `cat scripts/lib/*.ps1 \| wc -l` |
| top-level `scripts/*.ps1` lines | **5,268** | `cat scripts/*.ps1 \| wc -l` |
| `tests/*.ps1` lines | **9,636** | `find tests -name '*.ps1'` |
| Tracked `.ps1` files (excl `.git`) | **89** | `git ls-files '*.ps1'` |
| Diagnostic row fields | `level, rule_id, message, blocking, artifact, item_id, field, suggestion, documentation_url` | `pmo-config/diagnostics-schema.json` |
| Digest canonicalization | strip one BOM, CRLF/CR→LF, re-encode no-BOM, extension allowlist | `scripts/lib/artifact-hash.ps1` |

**I accept the reviews as the correct engineering specification for the rewrite.**
My disagreements are narrow, strategic, and all trace back to one cause: the reviews
were asked to judge the plan *in isolation*, so they could not see the owner's intent
that changes the weighting of three specific findings.

| Area | My position |
|---|---|
| F1 / CR-003 — "logic is in JSON" is overstated | **Accept fully.** My §4.1/§6.2 were wrong. Firing conditions are code, ~24k lines total. |
| F2 — golden coverage 46% | **Accept fully.** Raise to ~100% as a Phase 0 prerequisite. |
| F3 — `tests/` is PowerShell | **Accept fully.** Decide port vs re-derive explicitly. |
| F4 / CR-001 — reverses an accepted decision | **Accept the *procedure*, reject the *re-decision*.** The owner already decided (see §4.2). Draft the DEC, don't re-open it. |
| F5 — cheap alternative (drop 5.1) never evaluated | **Partially reject.** Drop-5.1 is a correct *prerequisite*, not a *substitute* (see §4.1). |
| F6 / CR-007 — distribution undecided | **Accept fully.** Adopt a concrete default (committed, dependency-free bundle). |
| F7 / CR-005 — "byte-for-byte" wrong | **Accept fully.** Correct to "canonical-form equivalence." |
| F8 — persisted digests | **Accept fully.** Add as a named invariant. |
| F9 / CR-002 — orchestrator scope | **Accept fully.** Complete 89-file disposition inventory. |
| F10 — big-bang, no sizing | **Accept fully.** Strangler, value-ordered. |
| CR-004 — diagnostics fields | **Accept fully.** Fix to the real contract. |
| CR-006 — invocation-aware corpus | **Accept fully.** |
| CR-008 — exit codes not one map | **Accept fully.** |
| CR-009 — final-tree ≠ proven-tree | **Accept fully.** |
| CR-010 — CI classifier | **Accept fully.** |
| CR-011 — no autonomous commit | **Accept fully.** |
| CR-012..CR-018 | **Accept fully** (each is a correct, implementable constraint). |
| CR-019 / CR-020 / CR-021 | **Accept fully** (factual corrections; "no PowerShell mention" → "no active runtime invokes PowerShell"). |

---

## 2. Point-by-point acceptances (for the record)

I am not going to re-argue what is correct. The following is the disposition map that
drives the revised plan; every "accept" below becomes a concrete requirement in
`master-plan.md` v2.

### Claude's findings

| # | Finding | Disposition |
|---|---|---|
| F1 | Premise "logic in JSON" false; ~14.5k lines of behavioral code | **Accept.** Rewrite §1/§3/§4.1/§6.2: rule *identity/severity/remediation* is data; rule *firing conditions* are code, ported line-by-line. Add a behavior inventory classifying each rule `config-driven / code-driven / hybrid`. |
| F2 | Golden covers 63/138 (46%); 75 uncovered | **Accept.** Golden-coverage expansion becomes a Phase 0 gate, against the *current* PS implementation, before any port. |
| F3 | `tests/` = 9,636 lines PS; can't be "unchanged" + PS-free | **Accept.** State true total 24,181 lines; add a dedicated "port `tests/`" phase with its own risk entry; decide which tests are ported vs re-derived from goldens. |
| F4 | Reverses ROADMAP Milestone 3.5 non-goal silently | **Accept the procedure; see §4.2.** Draft `DEC-###` to supersede; do not block on re-deciding. |
| F5 | Cheap alternative (drop 5.1) never evaluated | **Partially reject; see §4.1.** Adopt drop-5.1 as a cheap *first step*, but it does not satisfy the owner's goal and does not replace the migration. |
| F6 | Distribution/build undecided; no `package.json` | **Accept.** Make distribution a §13 decision #1; default = committed, dependency-free bundled `dist/`. |
| F7 | "Byte-for-byte" is not what the oracle checks | **Accept.** Replace with "canonical-form equivalence"; state the normalizer's exact ignores. |
| F8 | Persisted digests are a frozen contract | **Accept.** Add digest canonicalization as a named invariant + dedicated fixture set. |
| F9 | §6.4 covers 12/25 orchestrators | **Accept.** Complete the inventory to all 89 `.ps1` with a disposition. |
| F10 | No sizing; big-bang shape | **Accept.** Strangler, value-ordered; each leaf lands green with both impls live. |

### Codex's findings (P0/P1)

| # | Finding | Disposition |
|---|---|---|
| CR-001 | Migration not authorized as a framework decision | **Accept procedure; see §4.2.** Phase -1 requires the named Human decision, but it is a *record*, and the owner has already made it. |
| CR-002 | Phase 9 deletes more than plan replaces (89 files) | **Accept.** Machine-checked disposition inventory: `port / replace / temporary-oracle / retire-with-evidence`. |
| CR-003 | "Logic in JSON" inaccurate | **Accept** (same as F1). |
| CR-004 | Diagnostics invariant names wrong fields | **Accept.** Replace with per-command contract matrix sourced from `diagnostics-schema.json`. |
| CR-005 | "Byte-for-byte" conflicts with golden contract | **Accept.** Comparator-class table; call PS the *compatibility oracle*, not correctness oracle. |
| CR-006 | Corpus not invocation-aware | **Accept.** Versioned compatibility-case manifest (entrypoint + project + mode + gate + format + flags + cwd + env + git + platform). |
| CR-007 | TS runtime/distribution unresolved | **Accept.** Node range, ESM target, committed bundle, zero-runtime-dep default. |
| CR-008 | Exit codes not one global 0/1/2 | **Accept.** Per-entrypoint exit-code map; reserve an infra-failure code. |
| CR-009 | Final tree ≠ proven tree | **Accept.** Run final differential after cutover + deletion; keep reference in detached worktree. |
| CR-010 | CI doesn't prove Node/OS matrix | **Accept.** Update classifier before code lands; numeric N with reset rules. |
| CR-011 | Plan grants git authority policy withholds | **Accept.** Replace "commit per phase" with "prepare diff → stop for Human authorization." |
| CR-012 | A/B/C grouping not a real dependency graph | **Accept.** Derive a real graph; typed per-run `ValidationContext`; no `$script:` globals. |
| CR-013 | Freezing all config bytes impossible | **Accept.** Freeze *semantics*; pre-authorized manifest of runtime-reference/version edits. |
| CR-014 | Preserve Action→CLI→library boundary | **Accept.** |
| CR-015 | Stateful commands need command-specific proof | **Accept.** Fresh-tree before/after comparison; inject/freeze clocks/UUIDs. |
| CR-016 | Rollback/deletion inconsistent | **Accept.** Separate cutover and deletion into distinct PR/release decisions. |
| CR-017 | New supply-chain/security surface | **Accept.** Security gate: zero runtime deps, `private:true`, lockfile, containment tests, named security reviewer. |
| CR-018 | `pmo-doctor` needs rule-registry replacement | **Accept.** Typed rule-ID registry/generated manifest. |
| CR-019 | Counts + BOM stale | **Accept.** Derive counts from baseline SHA, not hardcoded. BOM invariant: accept BOM/no-BOM, strip exactly one U+FEFF. |
| CR-020 | "Every user has Node" is an assumption | **Accept.** Present as a deliberate breaking-support trade-off in the DEC. |
| CR-021 | "No PowerShell mention anywhere" wrong | **Accept.** Exit criterion: no *active* runtime/CI/skill/hook/template/config/support doc invokes PowerShell; historical records preserved. |

---

## 3. What the reviews got right, stated so it survives the rewrite

1. **The migration must end with one permanent implementation.** Dual-state is bounded.
2. **Never edit a golden master to make the port pass.**
3. **Governance changes must be separated from the interpreter migration and approved independently.**
4. **Differential comparison is a hard gate, not a confidence check.**
5. **Human decisions are required for toolchain, compatibility, cutover, deletion, release.**
6. **PowerShell remains a frozen compatibility oracle until the final Node tree is proven.**

These six are now load-bearing principles of the revised plan.

---

## 4. Where I disagree — my own independent opinion

These are the points where the reviews, judging the plan without the owner's intent,
reach conclusions I believe are mis-weighted. I am flagging them explicitly so that
Claude and Codex can adjudicate the *disagreement* rather than re-review the parts we
all agree on.

### 4.1 "Drop Windows PowerShell 5.1" is a prerequisite, not a substitute (vs F5)

Claude's F5 recommends: *"Drop 5.1, keep PowerShell 7 → the DOCTOR-010/011 class
disappears at ~1 day cost, so re-decide whether a 24k-line rewrite is justified."*

That is technically true, and I accept it **as a cheap first step** — but it does not
satisfy the owner's stated weak point B. The owner did not say "the bug is 5.1/7
portability." The owner said: **"most people don't use PowerShell."** Keeping
PowerShell 7 means macOS/Linux users still run `brew install --cask powershell`,
contributors still write PowerShell, and the exact review criticism the owner is trying
to remove ("AI's see it as not answering the need") persists unchanged.

- Drop-5.1 fixes a **defect class** (a real, worth-doing thing — I keep it in the plan).
- It does **not** fix the **ecosystem-fit** problem, which is the owner's actual goal.

So the honest framing is: drop-5.1 *now* (cheap, correct, shrinks the port surface by
removing `pwsh-host.ps1` and the `$IsWindows` branching), and migrate to Node *because
that is what the owner asked for* — not because the numbers alone force it. This is a
goal-alignment argument, not a line-count argument. The reviews asked "show why (c)
beats (a) on the numbers"; the answer is "the numbers were never the owner's reason."

### 4.2 The `DEC-###` is a record of a decision already made, not a re-decision (vs F4/CR-001)

Both reviews correctly state that reversing ROADMAP Milestone 3.5's non-goal requires a
`DEC-###` with `source_ref` and `evidence_status`, per the repo's own rules. They are
right about the *mechanism*.

But both reviews then assume the decision is still **open**, and structure their
recommendation around "if the Human Owner declines, the plan stops cheaply." The owner
has **already declined to decline** — in this session the owner directed: *create a
branch, migrate the interpreter to Node/TS, prove equivalence with golden master, then
delete PowerShell.* The decision is made; what is missing is the **record**.

My revision therefore:
- **Does not** block Phase 0 on "re-deciding."
- **Does** include a fully-drafted `DEC-###` (see §6) that the owner signs/records as a
  formality, with F1's cost figures and F2's coverage figures as the `evidence_status`
  payload. This satisfies the governance requirement without re-litigating a settled
  call.

If a reviewer wants to dispute this, the dispute is with the owner's direction, not
with the plan's compliance — the plan records the direction correctly.

### 4.3 "No active users" changes the risk calculus (vs CR-016 / CR-020)

The reviews' compatibility concerns — "breaking-support trade-off," "installed plugin
caches," "Action consumers pinned to tags/SHAs," "publish a corrected reference" — are
all correct **for a repo with live consumers**. The owner has stated there are none.

I am not using this to wave away correctness: the golden-master gate stands unchanged.
I am using it to resolve two over-cautious dead ends:

- **CR-020's "breaking support"** — there is no active user to break; the trade-off is
  real but costs nothing today. The plan still *documents* it in the DEC so a future
  user is warned.
- **CR-016's rollback-to-pinned-tag machinery** — with zero consumers, the correct
  rollback is "revert the branch to the baseline SHA," which Phase 0 snapshots. I keep
  a lightweight version of Codex's requirement (separate cutover/deletion gates) but do
  not build a multi-version support matrix for a user base that does not exist.

**Caveat I am recording honestly:** "no users" is the owner's belief about a public
repo (it has release tags, `marketplace.json`, and a published GitHub Action). The plan
treats it as an **assumption to confirm** in Phase 0 (a quick check of forks/stars/Action
consumers), not as a settled fact. If the check finds even one external consumer, the
fuller CR-016/CR-020 machinery comes back into scope.

### 4.4 Golden-coverage expansion should be the strangler's backbone (synthesis of F2 + F10)

The two reviews separately demand (a) raise golden coverage to ~100% and (b) reorder
the port as a value-delivering strangler. I am merging them into a single mechanism,
which neither review stated but both logically require:

**Expand goldens rule-group by rule-group, and port in the same order.**

- Pick a self-contained leaf validator (start: `scope-diff-validator`, ~5 rules,
  git-backed — Claude's own suggestion).
- **First** capture goldens for *that group's* currently-uncovered rules against the
  current PS implementation.
- **Then** port that group to Node and run the differential harness for just that group.
- Land green with both implementations live for that group. Repeat.

This means coverage and porting advance in lock-step, no rule is ever ported without a
golden, and value (a working Node validator) ships incrementally. It also converts
rollback from "revert everything" to "stop after N groups, nothing is broken."

### 4.5 Two workstreams must not blur (a point neither review could see)

The owner has **two** goals. Goal A (modes / fewer mandatory documents) is a *separate*
change to governance semantics. Goal B (this migration) is an *equivalence-preserving*
runtime change. Codex's principle #3 ("governance improvements and compatibility changes
must be separated") is exactly right — so I am making it explicit in the plan:

- **This migration changes no rule, no gate, no mode, no artifact requirement.**
- The modes redesign (Goal A) is deferred to a **separate branch, separate `DEC-###`,
  separate plan.** It is not a hidden rider on this migration.

This prevents the exact failure both reviews are guarding against — governance drift
during a rewrite — while keeping the owner's Goal A queued and visible rather than lost.

---

## 5. Draft `DEC-###` (for the owner to record — content, not yet the number)

The executing agent should not invent the decision number; the owner or the next
governance pass assigns it. The content follows the repo's `DEC-###` format.

```markdown
### DEC-0XX — Supersede Milestone 3.5 non-goal: authorize Node/TypeScript validator

- **Status:** Approved
- **Approved by:** WITCHWASIN K. (Human Owner)
- **Date:** 2026-08-15
- **source_ref:** ROADMAP.md (Milestone 3.5 non-goals); Fixed_plan/master-plan.md v2
- **evidence_status:** supported

**Decision:** The ROADMAP Milestone 3.5 non-goal "Rewriting the validator in TypeScript
or another language" is superseded. A Node.js/TypeScript reimplementation of the
validation interpreter is authorized, proven equivalent to the current PowerShell
implementation by golden-master differential comparison, after which PowerShell is
retired. Milestone 3.5's second non-goal "Dropping Windows PowerShell 5.1 before
compatibility evidence supports it" is addressed separately: 5.1 is dropped as an
independent, cheap prerequisite step (its own evidence: the existing 5.1/7 portability
defect record), not as part of the TypeScript decision.

**Scope:** interpreter (runtime) migration only. No governance rule, gate, mode, or
artifact requirement changes in this work. The Lite/Standard/Strict modes redesign is a
separate decision and is not part of this migration.

**Evidence:** port surface 24,181 lines PowerShell (9,277 lib + 5,268 scripts + 9,636
tests); golden coverage 63/138 rules (46%) to be raised to ~100% before port;
distribution target = committed, dependency-free Node bundle.
```

The owner should assign the `DEC-0XX` number and record this in `decision-log.md` at
Phase -1. Nothing in this plan proceeds past Phase 0 without it.

---

## 6. How `master-plan.md` v2 changes

The revised plan (next file) restructures the original ten phases into the sequence both
reviews converge on, with the following headline changes:

1. **Phase -1 — Authorization.** The `DEC-###` above is recorded. (Not a re-decision.)
2. **Phase 0 — Complete inventory + immutable baseline + golden-coverage gap.**
   89-file disposition matrix; versioned compatibility-case manifest; baseline SHA +
   goldens + config + env fingerprint; raise golden coverage to ~100% **before** any port.
3. **Phase 1 — Build/distribution contract + harness skeleton + CI routing.** Committed
   dependency-free bundle decision; differential harness with mutant self-tests; CI
   classifier recognizes `src/`, `dist/`, `package*.json`, `tsconfig*`.
4. **Phases 2–4 — Strangler port, golden-coverage-anchored** (per §4.4): port one
   leaf validator group at a time, each with goldens captured first, each landing green.
5. **Phase 5 — Complete executable + test surface.** Every entrypoint from the
   disposition inventory (port/replace/retire), including `tests/` and the CI/hook/
   digest/release tooling; preserve Action→CLI→library.
6. **Phase 6 — Final-tree differential gate.** Direct reference vs direct candidate,
   full compatibility-case manifest, zero unexplained skips/diffs; archive a report
   binding both SHAs.
7. **Phase 7 — Node-default canary** with a fixed numeric N and reset rules.
8. **Phase 8 — Human-approved cutover** (separate PR/release decision).
9. **Phase 9 — Human-approved PowerShell deletion** (separate PR/release decision),
   re-run final-tree proof after deletion.
10. **Phase 10 — Documentation reconciliation.** Remove active PowerShell instructions;
    preserve historical records under a reviewed allowlist.

Every accepted finding (F1–F10, CR-001–CR-021) maps to a concrete line in the revised
plan; nothing is "noted but not acted on."

---

## 7. What I still need Claude and Codex to adjudicate

I am not asking for a full re-review of the parts we agree on. I need a verdict on the
**three disagreements**, because they are where the plan's shape is decided:

1. **§4.1 — Is "drop 5.1" a substitute or a prerequisite?** I assert prerequisite; the
   migration proceeds because the owner asked for ecosystem fit, not because line counts
   force it. If either reviewer holds that drop-5.1 alone satisfies the owner's goal,
   say so and why — that is a claim about the owner's intent I can act on.

2. **§4.2 — Is the `DEC-###` a record or a re-decision?** I assert record (owner already
   decided). If the reviewers require the owner to *re-affirm* rather than merely record,
   the revised plan still passes — it just adds one human confirmation step at Phase -1.

3. **§4.3 — Does "no active users" justify the lighter rollback/compat machinery?**
   I assert yes, subject to a Phase-0 verification. If the reviewers insist on the full
   multi-version support matrix regardless, the cost is containment, not correctness.

Everything else in both reviews has been accepted and is already incorporated into
`master-plan.md` v2.

---

## 8. Next steps

1. Owner (or the next governance pass) assigns the `DEC-0XX` number and records §5 in
   `decision-log.md`.
2. Owner sends this response + `master-plan.md` v2 back to Claude and Codex for the
   focused second pass on §7's three disagreements.
3. On approval of all three, the plan is `final-plan.md` and Phase -1 begins.
