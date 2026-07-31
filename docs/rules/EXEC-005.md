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

**2. A human accepts the artifact on the record.** Add a
`test-evidence-accepted` authority claim citing a decision record:

```json
{
  "test_evidence": [
    { "type": "junit-artifact", "name": "unit tests",
      "path": "reports/junit.xml", "sha256": "<real digest>" }
  ],
  "authority_claims": [
    { "type": "test-evidence-accepted", "actor": "human",
      "claim": "accepted", "decision_ref": "DEC-014" }
  ]
}
```

The vouch is held to the same standard as every other human-only claim
(`EXEC-007`): `actor` must be `human` (an agent vouching for itself is
rejected), the `DEC-###` must resolve to exactly one row in
`decision-log.md`, and that row must **not** have been added or edited within
the commit range under verification.

This is deliberately not a config flag. A weakening that is per-execution,
attributable, and recorded in a governed artifact is reviewable; a boolean in
a config file is not.

## What this still does not prove

Even a vouched artifact only means *a human said they accepted it*. If that
human did not actually inspect the artifact, the framework cannot tell. The
guarantee is accountability, not certainty — the same guarantee every human
approval gate in this framework offers.

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
