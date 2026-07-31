# EXEC-005 - Required test not backed by evidence that proves execution

| | |
|---|---|
| Level | FAIL |
| Runs when | `scripts/verify-execution-result.ps1` is invoked |
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

…and the cited decision row must itself name that digest:

```text
| 2026-07-31 | DEC-014 | Accept unit tests evidence for D-001 | ... | accepted |
  reviewed reports/junit.xml by hand; sha256 <digest> | ... |
```

### Why the digest has to appear in the decision row

**This rule was wrong a third time**, and the correction is worth stating
because the near-miss is instructive.

Round 3 found the vouch was a single global boolean: any resolvable
`test-evidence-accepted` claim promoted *every* artifact-observed entry in the
execution. Demonstrated with a fabricated JUnit report claiming 99 passing
tests, vouched by a real decision record about **which logging library to
use**. The claim named no test, no artifact and no digest, so there was
nothing for it to be wrong about.

Binding the claim to the evidence is necessary — but on its own it does not
close the hole, and it is worth being precise about why. **The result document
is written by the actor being verified.** If the binding lived only in the
claim, the same attack survives: forge the artifact, hash it, copy that hash
into your own `evidence_sha256`, cite the same unrelated decision, and every
field "matches". Self-consistent forgery is still forgery.

So the anchor is the decision row, which the actor cannot author inside the
verified range (`decision-log.md` must not change within `base..head`). A row
naming the artifact's digest had to exist *before the work began* — which
means predicting the exact bytes of an artifact not yet produced.

Requirements, in full:

| Field | Must match |
|---|---|
| `actor` | `human` — an agent vouching for itself is rejected on authority |
| `test_name` | the required test being satisfied |
| `evidence_sha256` | the digest the adapter actually computed |
| `decision_ref` | a `DEC-###` resolving to exactly one row, not written in-range |
| the decision row | must contain that same digest |
| `evidence_type`, `work_item_id`, `contract_sha256` | optional; checked when present |

A vouch with no bindings fails closed.

This is deliberately not a config flag. A weakening that is per-execution,
attributable, and recorded in a governed artifact is reviewable; a boolean in
a config file is not.

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
