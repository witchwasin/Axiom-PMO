# EXEC-005 - Required test not backed by evidence that proves execution

| | |
|---|---|
| Level | FAIL |
| Runs when | `node cli/axiom.mjs verify` is invoked |
| Artifacts | `EXECUTION-RESULT.json` |

## What this rule checks

Each entry in the contract's `required_tests` must have a matching
`test_evidence` entry that clears **two separate bars**:

1. **The artifact checks out.** The file exists inside the project, its bytes
   hash to the declared digest, its contents report success.
   (`Test-EvidenceEntryVerified`)
2. **Something establishes who produced it.** The entry's *provenance tier*
   must be one that can satisfy a required test — or a human must have
   accepted it on the record.

Passing (1) and failing (2) is a FAIL, and that is the point of this rule.

## Why it exists — and why it was wrong twice

> A digest proves a file has not changed since it was hashed.
> It proves nothing about who hashed it.

**Round 1 of review** found the check was pure theatre: it only confirmed an
entry's *fields were present*. `{"type": "runner-exit-record", "command":
"npm test", "exit_code": 0, "recorded_by": "axiom-runner"}` passed with no
file ever opened.

**Round 2 found the fix was still wrong.** The replacement opened the run
record, verified a `.sha256` sidecar, checked its contract and work-item
bindings, and confirmed the sealed exit code — real work. But the record and
its sidecar both live under `.execution/**`, which the verified actor can
write and which is deliberately exempt from scope analysis. A reviewer
demonstrated a **fully hand-forged record with a genuinely matching
sidecar passing verification, with the runner never invoked.** Computing a
SHA-256 is exactly as easy as writing the JSON it summarises.

The mistake both times was the same: conflating *"Axiom-PMO can check this"*
with *"this proves a test ran."* Those are different questions, and no
amount of additional checking on a file the actor controls answers the
second one. `sealed_by: "axiom-runner"` is a string the forger types.

## Provenance tiers

| Tier | Adapters | Satisfies a required test alone? |
|---|---|---|
| `agent-claimed` | `agent-assertion` | Never |
| `artifact-observed` | `junit-artifact`, `runner-exit-record` | **No** |
| `externally-observed` | `ci-check` | Yes |

`artifact-observed` is not worthless — it is structured, digest-checked, and
tamper-evident *after* it is written. It simply is not proof of execution,
so it cannot carry a required test by itself.

`ci-check` is the only tier that clears the bar today, because a GitHub check
run is asserted by a third party the executing actor cannot impersonate.

## The two ways through

**1. External evidence.** Attach a `ci-check` bound to the exact commit SHA.
Its conclusion is queried live; the result's own `conclusion` field is never
read.

**2. A human accepts *that specific artifact* on the record.** Add a
`test-evidence-accepted` authority claim, bound to the test and the artifact:

```json
{
  "test_evidence": [
    { "type": "junit-artifact", "name": "unit tests",
      "path": "reports/junit.xml", "sha256": "<real digest>" }
  ],
  "authority_claims": [
    { "type": "test-evidence-accepted", "actor": "human", "claim": "accepted",
      "decision_ref": "DEC-014",
      "test_name": "unit tests",
      "evidence_sha256": "<the same real digest>" }
  ]
}
```

…and the cited decision row must itself say what it authorizes, in a form
that can be checked field by field:

```text
| 2026-07-31 | DEC-014 | Accept unit tests evidence for D-001 | ... | accepted |
  reviewed reports/junit.xml by hand.
  axiom-authority: type=test-evidence-accepted; work_item=D-001;
  contract=<contract sha256>; test=unit tests; evidence=<artifact sha256> | ... |
```

A token has no closing delimiter — a test name may contain spaces, and the
semicolon is the field separator — so each one runs until the next
`axiom-authority:` or the end of its cell. One row may carry several tokens,
in the same cell or different ones; each is matched independently, and a row
authorizes a claim when *some* token on it matches in full. Parsing is per
cell, never across the concatenated row.

| Field | Required for | Meaning |
|---|---|---|
| `type` | every human-only claim | the claim type this row authorizes |
| `work_item` | every human-only claim | the work item it authorizes it for |
| `contract` | every human-only claim | the contract digest it was written against |
| `test` | a test vouch | the required test being satisfied |
| `evidence` | a test vouch | the artifact digest being accepted |

### Why the decision row has to carry a structured binding

**This rule was wrong three times**, and each correction is worth stating
because the near-misses are instructive.

**Round 3** found the vouch was a single global boolean: any resolvable
`test-evidence-accepted` claim promoted *every* artifact-observed entry in the
execution. Demonstrated with a fabricated JUnit report claiming 99 passing
tests, vouched by a real decision record about **which logging library to
use**. The claim named no test, no artifact and no digest, so there was
nothing for it to be wrong about.

Binding the claim to the evidence is necessary — but on its own it does not
close the hole. **The result document is written by the actor being verified.**
If the binding lived only in the claim, the same attack survives: forge the
artifact, hash it, copy that hash into your own `evidence_sha256`, cite the
same unrelated decision, and every field "matches". Self-consistent forgery is
still forgery. So the anchor is the decision row, which the actor cannot author
inside the verified range (`decision-log.md` must not change within
`base..head`).

**Round 4 found that anchor was still too weak.** It searched the decision row
for the digest as a *substring*. That answers "does this row mention these
bytes" — not "did a human approve *this artifact* for *this test*". A row
approving a JUnit report for `unit tests` was reusable for `integration tests`
by relabelling the evidence entry and the claim, both of which the actor
writes. Reproduced, verdict `pass`, no rule raised.

A substring is not a statement. The row now has to make one, and it is parsed
field by field.

Requirements, in full:

| Field | Must match |
|---|---|
| `actor` | `human` — an agent vouching for itself is rejected on authority |
| `test_name` | the required test being satisfied |
| `evidence_sha256` | the digest the adapter actually computed |
| `decision_ref` | a `DEC-###` resolving to exactly one row, not written in-range |
| the decision row's `axiom-authority:` token | every field above, plus type, work item, and contract digest |
| `evidence_type`, `work_item_id`, `contract_sha256` | optional on the claim; checked when present |

A vouch with no bindings fails closed. So does a decision row with no token.

### This applies to every human-only claim

Round 4's second finding: the binding check ran only for
`test-evidence-accepted`. Every other human-only claim — `release-approval`,
`qa-approval`, `security-approval`, `scope-change`, `risk-mode-downgrade` —
still resolved on `decision_ref` alone, so any `DEC-###` in the log satisfied
them. They now all require a binding token naming at least `type`,
`work_item`, and `contract`. See `EXEC-007`.

## What this still does not prove

Even a correctly bound vouch only means *a human said they accepted this
artifact*. If they did not actually inspect it, the framework cannot tell. The
guarantee is accountability, not certainty — the same one every human approval
gate here offers.

**Residual limit, stated rather than papered over:** an actor could plant a
digest in a decision row during an *earlier* execution, for an artifact it
intends to forge later. That requires the earlier execution to have passed
review carrying an unexplained digest — narrower and more visible, but not
closed.

## Git reconciliation: stale evidence (M4 / L2 completion)

A `junit-artifact` is the *output of a test run*. Git ground truth can
therefore say one necessary thing about it that no amount of hashing or XML
parsing can: **if the artifact file was not changed within the verified
`base..head` commit range, it predates the work — it cannot be the output of
a run of the code under verification.** The diagnostic says so explicitly
when the artifact is verified but out-of-range and no human vouch applies:

> The evidence file `<path>` was not changed within the verified commit
> range, so it cannot be the output of a test run of the code under
> verification — a report that predates the work cannot prove the changed
> code passes.

This is the same both-directions discipline as `EXEC-008`'s `changed_files`
reconciliation, applied to the evidence file itself: the claim "this test
passed" is checked against what the repository shows actually happened.

**A valid human vouch still wins.** The vouch is the documented escape hatch
for evidence that legitimately lives outside the diff — a gitignored CI
artifact, for example — so a vouched, out-of-range artifact is unchanged.
The stale-evidence note sharpens *why* unpromoted evidence cannot be
trusted; it does not add a second gate on top of the vouch. (Whether a vouch
*should* be able to override staleness is an open question for a future
round — closing it would move the remaining "stale report accepted by
vouch" case from accountability to enforcement.)

## How to fix

- Attach a `ci-check` for the required test, **or**
- record a decision in `decision-log.md` and cite it from a
  `test-evidence-accepted` claim, **or**
- if the test genuinely did not run, say so: `execution_status: "partial"`
  and leave the required test unsatisfied rather than manufacturing evidence.

## Related

`EXEC-007` (the authority rules the vouch is held to), `EXEC-002` (the same
digest-is-not-provenance limit applied to the contract itself), `EXEC-008`
(git-observable claims), `RTM-003` (the documentation-side equivalent).
