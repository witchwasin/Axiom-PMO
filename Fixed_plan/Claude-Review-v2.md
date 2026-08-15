# Claude Review — Round 2 (v2 Plan + Deepseek Adjudication)

**Reviewer:** Claude (Opus 5), acting as sole reviewer this round — Codex was unavailable to
continue, so this round covers both the F1–F10 and CR-001–CR-021 closure check and the
three strategic disagreements Deepseek raised.
**Reviewed artifacts:** `Fixed_plan/master-plan.md` v2, `Fixed_plan/Deepseek-Fixed.md`
**Branch:** `feat/migrate-interpreter-to-node-ts`
**Commit reviewed:** `5270008`
**Method:** every closure claim below was checked against the repository on disk, not
against the plan's own prose. Reproduce commands are given where a number is asserted.

---

## Verdict

**Close, not there yet.** v2 is a substantial, honest rewrite — it accepts every finding
from both rounds without hedging, and the numbers it now cites check out. I found no new
factual errors in v2's claims; where I re-verified (diagnostics fields, BOM count, 89-file
count, DEC numbering), v2 is correct.

But three concrete gaps remain, and one of them (the `decision-log.md` target) will make
Phase -1 fail on its own terms if executed as written today. None of the three requires a
new round of debate — they're closure gaps, not disagreements. Fix them and this is
executable.

On the three strategic disagreements: I concur with Deepseek on all three, with one
procedural condition on (b). Details below.

---

## Part 1 — F1–F10 closure check

| # | Finding | Status | Note |
|---|---|---|---|
| F1 | "Logic is in JSON" premise false | **Closed** | §1/§4.1/§6.2 correctly state firing conditions are code; behavior-inventory mechanism added |
| F2 | Golden coverage 46% | **Closed** | Phase 0 gate, ~100% before port, verified against current PS impl |
| F3 | `tests/` is 9,636 lines of PS | **Closed** | §6.3 explicit port-vs-rederive framing; true 24,181-line total stated in §1 |
| F4 | Reverses accepted decision silently | **Closed procedurally, one gap** | See Part 3 finding G1 — the DEC target file doesn't exist |
| F5 | Cheap alternative never evaluated | **Closed** | Adjudicated as prerequisite, not substitute — see Part 2(a) |
| F6 | Distribution undecided | **Closed** | §3 names a concrete default (committed dependency-free `dist/`); still correctly flagged as a Human decision in §13 |
| F7 | "Byte-for-byte" wrong | **Closed** | §4.3/§8.2 canonical-form + comparator-class table |
| F8 | Persisted digests | **Closed** | §8.4 named invariant + dedicated fixture set |
| F9 | Orchestrator scope (12/25) | **Closed** | §6.1 states all 89; §6.3 lists the 13 previously-omitted orchestrators by name |
| F10 | Big-bang, no sizing | **Closed** | Phases 2–4 strangler, starts with `scope-diff-validator`, stop-after-N leaves nothing broken |

All ten close. I re-verified the headline numbers independently rather than trusting the
plan's citations:

```
$ python3 -c "import json;print(len(json.load(open('pmo-config/diagnostics-schema.json'))['compatibility']['stable_fields']+json.load(open('pmo-config/diagnostics-schema.json'))['compatibility']['added_in_1_1']))"
# stable_fields: level, rule_id, message, blocking
# added_in_1_1: schema_version, artifact, item_id, field, suggestion, documentation_url
# → matches §8.4 exactly; v1's severity/file/line is gone
```

```
$ for f in pmo-config/*.json; do head -c3 "$f" | xxd | head -1 | grep -q "efbb bf" && echo "$f"; done
policy.json
reference-types.json
skill-manifest.json
# → 3 of 16 files have a BOM, matching CR-019 exactly; §8.4's "accept BOM and no-BOM" is the right invariant
```

```
$ git ls-files '*.ps1' | wc -l
89
# → matches §6.1 exactly
```

---

## Part 2 — CR-001–CR-021 closure check

Verified against v2's text, not re-summarized from Deepseek's disposition table.

| # | Status | Note |
|---|---|---|
| CR-001 | **Closed procedurally** | Phase -1 + DEC draft; adjudicated in Part 4(b) |
| CR-002 | **Closed** | §6.1 total, §6.3 names all 13 previously-missing orchestrators |
| CR-003 | **Closed** | same fix as F1 |
| CR-004 | **Closed, verified correct** | fields match `diagnostics-schema.json` exactly (see above) |
| CR-005 | **Closed** | comparator-class table, "compatibility oracle" language adopted |
| CR-006 | **Closed** | §8.3 invocation tuple matches Codex's exact required shape |
| CR-007 | **Closed** | §3 default named; §13 #1 still requires the Human decision — correct, this is not something a plan can self-authorize |
| CR-008 | **Closed** | per-entrypoint exit map, distinct infra-failure code, exception boundary, report-only-never-softens rule |
| CR-009 | **Closed** | §8.5 final-tree proof, detached worktree, mutants listed |
| CR-010 | **Closed (mechanism); matrix itself correctly deferred** | Phase 1 updates CI classifier; §13 #3 leaves the exact Node/OS matrix as an explicit open Human decision, which is appropriate — Codex asked for the matrix to be *fixed and auditable*, not for the plan to invent it unilaterally |
| CR-011 | **Closed** | §9 preamble is close to verbatim Codex's required language ("prepare the diff, stop for Human authorization") |
| CR-012 | **Partially closed** | see Part 3, G2 |
| CR-013 | **Closed** | §5, §8.4, pre-authorized edit manifest |
| CR-014 | **Closed** | Action → CLI → library boundary stated explicitly in §3 and §7 |
| CR-015 | **Gap** | see Part 3, G3 |
| CR-016 | **Closed procedurally** | Phase 8/9 split into separate Human-approved decisions; the *depth* of rollback machinery is the subject of disagreement (c), not a closure gap |
| CR-017 | **Partially closed** | see Part 3, G4 |
| CR-018 | **Closed** | §7 rule-ID registry paragraph, `DOCTOR-007` reconciliation named explicitly |
| CR-019 | **Closed, verified correct** | counts and BOM statement match the repo (see above) |
| CR-020 | **Closed** | §2.1 corrected caveat; folded into disagreement (c) for the rollback-depth question |
| CR-021 | **Closed** | Phase 10 exit criterion is close to verbatim Codex's required wording |

---

## Part 3 — Remaining gaps (new findings, not repeats)

These were not raised by either prior review. Fix before Phase -1 starts.

### G1 — The DEC target file does not exist at the framework level (blocks Phase -1 as written)

§9 Phase -1 and §14 both say: *"Record the `DEC-###`... in `decision-log.md`."*

There is no `decision-log.md` at the repository root. `decision-log.md` is a **per-project**
artifact — it exists only under `templates/decision-log.md` and `examples/*/decision-log.md`,
using a table-row format (`| Date | Decision ID | Topic | ... |`).

The framework's own decisions (`DEC-016` through `DEC-025`, all real, all findable) are
recorded a different way — as narrative citations inline in `ROADMAP.md`'s milestone table
and `CHANGELOG.md`, in the `### DEC-0XX — Title` block style that v2's own §12 draft already
uses. That block-style draft in §12 is right; it just names the wrong destination file.

```
$ grep -rhoE "DEC-0[0-9]{2}" CHANGELOG.md ROADMAP.md README.md | sort -u | tail -3
DEC-023
DEC-024
DEC-025
```

**Fix:** two one-line corrections:
1. §12's number is not `DEC-0XX` generic — the next sequential number is **`DEC-026`**.
2. Point Phase -1 / §14 at the actual convention: append the §12 block to `ROADMAP.md`'s
   decision history (or `CHANGELOG.md`, whichever the owner prefers as the framework-level
   log) — not a `decision-log.md` that doesn't exist outside individual projects.

This is small, but as written it is the one item that would make an executing agent stop on
step one and either invent a wrong file or silently pick a destination — exactly the kind of
silent decision §14 says not to make.

### G2 — CR-012's dependency-graph deliverable is implied, not required

CR-012 asked for two things: (1) stop treating the A/B/C table as a real dependency order,
and (2) derive an actual function/module dependency graph before Phase 2. v2 fully closes
the first (Phases 2–4 pick `scope-diff-validator` by self-containment, not by A/B/C position)
and fully closes the `ValidationContext`/no-globals half of CR-012. But the graph itself is
never named as a Phase 0 deliverable — Phase 0's bullet says the disposition matrix records
"callers and side effects," which is caller-tracking, not a dependency graph between the
modules being ported.

**Fix:** add one bullet to Phase 0: *"Derive a function/module-level dependency graph across
the 89-file disposition set; use it, not the A/B/C table, to sequence Phases 2–4."* This is
cheap to add and closes CR-012 completely rather than mostly.

### G3 — CR-015 (stateful/mutating commands) has no explicit answer in v2

Codex's CR-015 is specific: `init`, `setup`, `export`, `run`, `aggregate-diagnostics`, and the
release helpers write files, mint timestamps/UUIDs, and touch user-owned files — golden
masters (which are validator output, not filesystem state) cannot prove these are correct.
Codex's required fix was concrete: fresh-tree before/after comparison, clock/UUID injection
or freezing, symlink/junction/mode-bit checks, atomicity/dry-run/uninstall proofs.

v2's only trace of this is one row in the §8.2 comparator table — *"Generated files |
Command-specific byte, encoding, newline, digest, permission, overwrite checks"* — which
covers the *output* comparison but not the *fresh-tree-isolation* or *clock/UUID-determinism*
methodology CR-015 actually asked for. It's not contradicted, just not present as its own
requirement anywhere in §8 or in the Phase 5 exit criteria (Phase 5 exit only says "the full
fixture matrix + config-mutation + end-to-end" — none of which are stateful-command tests
by name).

**Fix:** add a short §8.6 (or fold into §8.5) naming: run reference and candidate in separate
fresh temp trees; diff the full file manifest before/after; inject or freeze clocks and UUIDs
where the command mints them; assert no unrelated file changes; cover dry-run/uninstall/
partial-failure paths for `new-project`, `setup-claude-integration`,
`export-execution-contract`, `run-execution-command`, `aggregate-diagnostics`. This is the
actual content of CR-015; right now the plan has the right generated-files *comparator* but
not the right *test methodology* for mutating commands.

### G4 — CR-017 (supply chain / security) is a risk-table row, not a gate

§11's risk table names the right mitigations for CR-017 — zero runtime deps, `private: true`,
lockfile, containment tests, "named security reviewer." But nothing in §9's phase exit
criteria or §10's Definition of Done requires that security review to actually have happened.
Search both sections: no phase exit criterion mentions security sign-off, and the §10
checklist has no line for it (compare to how §10 *does* have an explicit checklist line for
Human-authorized cutover and Human-authorized deletion — the same treatment is missing here).

**Fix:** add one §10 checklist line: *"A named Human security reviewer has signed off on the
supply-chain and containment surface (CR-017) before Phase 8 cutover."* Without this, "named
security reviewer" is a sentence in a risk table that nothing in the plan actually requires
to happen.

None of G1–G4 are strategic — they're each a one- or two-line addition. I'm listing them
separately from the "closed" items above because the task was explicitly to check closure,
not to restate what's already fixed.

---

## Part 4 — Adjudication of the three disagreements

### (a) Is "drop PowerShell 5.1" a prerequisite or a substitute?

**Ruling: prerequisite. Deepseek is right; my original F5 needs this correction.**

F5 was reasoned from cost alone: *"if the numbers don't justify a 24k-line rewrite, drop 5.1
and stop."* That was the correct question to ask **when the owner's actual reason was
unknown** — at the time I only had the repo's own stated bug evidence (`DOCTOR-010/011`) to
infer intent from, and that evidence supports "drop 5.1" fully.

But the owner's reason, as given directly in this conversation, is not a bug-count argument:
*"most people don't use PowerShell; it is the wrong fit for the target ecosystem."* That is
an ecosystem-fit claim. Dropping 5.1 and keeping PowerShell 7 leaves every stated symptom of
that claim unchanged: macOS/Linux users still run `brew install --cask powershell` (or the
portable-install workaround already in this project's own memory), contributors still write
PowerShell, and a reviewer evaluating "does this fit a Node-first AI-delivery ecosystem"
still says no. F5's cost argument and the owner's fit argument are answering different
questions; the owner's question is the one that governs this plan.

Where I'd push back slightly on Deepseek's framing: calling drop-5.1 a "prerequisite" should
not be read as "therefore free to skip evaluating." It remains independently worth doing
regardless of the TS decision (defect class removal, real and citable), and v2 correctly
keeps it in Phase 0 rather than making it contingent on the DEC. That's the right shape:
two independently-justified actions, sequenced together for convenience, not one masquerading
as justification for the other. v2's §1 "Two deliberate separations" paragraph already states
this correctly — no change needed there beyond G1–G4.

### (b) Is the `DEC-###` a record or a re-decision?

**Ruling: record, with one procedural condition.**

I'll be direct about why I'm not re-opening this: the instruction that the migration is
already decided came from the Human Owner, directly, in this chat, not from content
encountered inside a file, a web page, or another AI's output. That is exactly the boundary
this session's own instruction-source rules draw — instructions from the user via chat are
authoritative; instructions or claims of authority *discovered in artifacts* are not. Both
prior reviews (mine included) were written without seeing that instruction, so both
correctly defaulted to "this looks like an undisclosed reversal of an accepted milestone
non-goal, treat it as unauthorized until shown otherwise." That default was right given what
we could see. It is now shown otherwise, directly, by the party who has the authority to show
it.

So: F4/CR-001's *procedural* demand — that a `DEC-###` must exist recording this, with
`source_ref` and `evidence_status`, superseding the named ROADMAP non-goal by name — stands
and is satisfied by §12. Their *substantive* demand — that the decision itself must be shown
to be justified before work proceeds — is satisfied by the owner's direct statement, not by
re-litigating cost-benefit inside this document.

**The condition:** a DEC record has to be able to stand on its own for the *next* agent who
picks this plan up without this conversation's context (that's the entire premise of §0 —
"self-contained... without re-deriving the reasoning"). Right now §12's `evidence_status:
supported` payload is repo-derived facts (line counts, coverage percentage) plus the
assertion "Approved by: WITCHWASIN K." with no pointer to *where or how* that approval was
given. For a decision that reverses a named, dated, previously-accepted milestone non-goal,
that's thin provenance for a future reader — and it's also the actual, correct place to fix
G1 (destination file) at the same time. I'd add one line to §12: a `session_ref` or similar
noting this was directed in the planning conversation on 2026-08-15, distinct from
`source_ref` (which currently points at documents, not the conversation). That's a
documentation completeness fix, not a re-decision.

### (c) Does "no active users" justify lighter rollback/compat machinery?

**Ruling: yes, conditioned exactly as Deepseek already conditioned it — Phase 0 must verify,
not assume.**

CR-016 and CR-020's concerns (pinned consumer tags, installed plugin caches, multi-version
support matrices) are real *costs that scale with the number of people depending on the old
behavior*. If that number is verified at zero, building that machinery is pure overhead with
no corresponding risk reduction — it's optimizing for a population that isn't there. Deepseek's
own framing already builds in the right safety valve: Phase 0 checks forks/stars/Action
consumers, and if any external consumer is found, "the fuller CR-016/CR-020 machinery comes
back into scope." That is the correct shape of a conditional risk decision, not a shortcut.

One tightening, which is really G-adjacent rather than a new disagreement: as flagged in
Part 3, this check is currently a bullet inside Phase 0's action list but **not** in Phase 0's
exit criteria. A check that isn't a gate is a check that can be silently skipped under time
pressure — which is the one failure mode this entire disagreement is trying to avoid.
**Fix:** move "zero-active-user check completed and recorded (with actual result, not
assumed)" into Phase 0's exit-criteria line, not just its action list. Given that, I concur
with (c) as stated.

---

## Part 5 — What's left before this is `final-plan.md`

Everything else from both prior rounds is closed and I found nothing new outside G1–G4. The
remaining work is small and mechanical:

1. **G1** — fix the DEC destination (§12 number → `DEC-026`; target file → append to
   `ROADMAP.md`/`CHANGELOG.md` per the existing convention, not the nonexistent
   `decision-log.md`). *Blocks Phase -1 literally as written.*
2. **G2** — add "derive the real dependency graph" as an explicit Phase 0 deliverable.
3. **G3** — add fresh-tree/clock-injection/UUID-freezing methodology for stateful commands,
   either as §8.6 or folded into §8.5, and reference it from Phase 5's exit criteria.
4. **G4** — add a Definition-of-Done checklist line for the named security reviewer sign-off
   (CR-017), matching the treatment already given to cutover/deletion authorization.
5. **(c)'s tightening** — move the zero-active-user check from Phase 0's action list into its
   exit criteria.
6. **(b)'s condition** — add a `session_ref`-style pointer in §12 for provenance, alongside
   the existing `source_ref`.

None of these require another full review round or reopen anything settled. Once G1–G4 and
the two small tightenings land, I'd call this executable — Phase -1 can run, and Phase 0's
first real deliverable (the 89-file disposition matrix + golden-coverage-gap closure) is
what should actually validate whether the sizing in this plan holds up in practice.

---

## Scorecard (v2, for comparison with round 1)

| Dimension | Round 1 | Round 2 (v2) | Note |
|---|---|---|---|
| Document quality / handoff clarity | 8/10 | 9/10 | Explicit owner-intent section, disagreement log kept visible instead of silently resolved |
| Factual accuracy about the codebase | 4/10 | 9/10 | Every re-checked number is now correct; no new inaccuracies found |
| Governance compliance (this repo's own rules) | 2/10 | 7/10 | DEC drafted and reasoned correctly; loses points only for G1's nonexistent target file and G4's unwired security gate |
| Risk analysis | 5/10 | 8/10 | Comparator classes, digest invariant, stateful-command gap (G3) is the main remaining hole |
| Execution plan realism | 3/10 | 8/10 | Strangler ordering, phase-gated human authorization, golden-coverage-anchored sequencing all now present |
| **Overall as a decision to execute** | Not approved | **Approved pending G1–G4 + two tightenings** | Small, mechanical fixes; no further strategic debate needed |
