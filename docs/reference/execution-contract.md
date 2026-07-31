# Execution contract and result (Milestone 5)

Axiom-PMO can hand an approved work item to an AI execution workflow as a
**contract**, then check what came back against the contract and against what
the repository can be observed to show actually happened.

It answers one question:

> **Did this agent run stay inside the contract it was given?**

It does not answer "is the code good," "does it satisfy the requirement," or
"should this ship." Those are human judgements this check makes no attempt at.

## The one idea worth reading first

> **An execution result is written by the actor being verified. It is a claim,
> not evidence, until Axiom-PMO confirms it independently.**

Everything below follows from that. A result saying "tests passed" is a
sentence the agent wrote about itself. A result saying "I changed three files"
is checked against `git diff`, not believed. A result claiming an approval is
rejected on the strength of *who is claiming*, not the wording.

```text
Agent claim  ->  Axiom-observed evidence  ->  Human authority
```

| Data | Status |
|---|---|
| Agent states a test ran | Claim |
| A checksummed artifact or checked CI run exists | Observed evidence |
| A CI check tied to the exact commit SHA passed | Stronger observed evidence |
| A human states the work is accepted | Human authority |

## Why this shape, and not a plugin integration

Milestone 5.0 inspected the reference execution workflow (`superpowers`) directly
rather than assuming. It registers exactly one hook — `SessionStart` — which
injects a static skill file as context. There is no contract-ingestion or
result-emission surface to bridge to, and its own porting guide says so:
"the bootstrap is the entire integration."

So Milestone 5 verifies against **git ground truth** instead of a native
protocol handshake. An agent writes `EXECUTION-RESULT.json` into the repository
the same way it writes code; Axiom-PMO checks that file against the contract and
against the commits, diffs, and refs the repository actually contains. No change
to any execution workflow is required. Full reasoning:
[`docs/architecture/execution-contract-verification.md`](../architecture/execution-contract-verification.md).

## Flow

```text
approved DELIVERY.md work item
  -> axiom export     -> .execution/D-001/EXECUTION-CONTRACT.json  (+ .sha256)
  -> agent executes   -> .execution/D-001/EXECUTION-RESULT.json
  -> axiom verify     -> structured diagnostics, EXEC-001..008
  -> human decides
```

### Export

```bash
node cli/axiom.mjs export --project projects/P02-MYPROJECT --work-item D-001
node cli/axiom.mjs export --project projects/P02-MYPROJECT --work-item D-001 --grant commit
```

The contract is **derived from already-approved artifacts**, never authored
fresh:

| Contract field | Comes from |
|---|---|
| `objective`, `requirement_refs`, `acceptance_criteria`, `required_tests` | the `DELIVERY.md` work-item row |
| `allowed_paths`, `prohibited_paths` | `SCOPE.json`'s `implementation_scope` |
| `base_sha` | the repository's current `HEAD`, resolved to an exact commit |
| `git_authority` | denied by default; widened only by `--grant` |

A project without `SCOPE.json` cannot be exported from. There is no approved
scope to hand over, and defaulting to "anywhere" would make the contract
meaningless — so export fails closed.

### Verify

```bash
node cli/axiom.mjs verify --project projects/P02-MYPROJECT \
  --result projects/P02-MYPROJECT/.execution/D-001/EXECUTION-RESULT.json
```

Output uses the same diagnostic contract as every other check
([`diagnostics-contract.md`](diagnostics-contract.md)), so an existing consumer
parses it with no new code. `--json` adds an `execution_verification` envelope
field alongside `results`.

## The result document

```json
{
  "contract_version": "1.0",
  "work_item_id": "D-001",
  "contract_sha256": "<digest printed by axiom export>",
  "base_sha": "<the contract's base_sha>",
  "head_sha": "<commit the work ended at>",
  "execution_status": "completed",
  "changed_files": ["src/payments/checkout.ts"],
  "requirement_refs": ["REQ-001"],
  "git_actions_performed": ["commit"],
  "test_evidence": [
    { "type": "runner-exit-record", "name": "unit tests",
      "run_record_path": ".execution/D-001/runs/<run-id>.json" }
  ],
  "authority_claims": [
    { "type": "implementation-complete", "actor": "agent", "claim": "done" }
  ]
}
```

Required: `contract_version`, `work_item_id`, `contract_sha256`, `base_sha`,
`execution_status` (`completed` | `partial` | `blocked` | `failed`).
`head_sha` is required in practice — without it nothing can be verified.

### Test evidence adapters

Two independent questions get asked of every entry, and keeping them apart is
the whole design:

> **Does the artifact check out?** — the file exists, its bytes hash to the
> declared digest, its contents report success.
>
> **Does anything establish who produced it?** — a different question, and
> the one that decides whether a required test is satisfied.

| Adapter | Requires | What is actually checked | Provenance |
|---|---|---|---|
| `ci-check` | `name`, `commit_sha` | Live GitHub API query for a check run matching `name` on that commit. The **observed** conclusion must be `success`; the entry's own `conclusion` field is never read. No `gh`, no auth, or no resolvable remote all mean *unverified*. | `externally-observed` |
| `junit-artifact` | `path`, `sha256` | `path` resolved inside the project root, the real file hashed and compared to the claimed digest, XML parsed with DTD processing prohibited, `failures + errors` summing to zero. | `artifact-observed` |
| `runner-exit-record` | `run_record_path` | The sealed file `axiom run` produced, reopened, its digest recomputed against the `.sha256` sidecar, its work-item and contract bindings confirmed, sealed exit code `0`. | `artifact-observed` |
| `agent-assertion` | `name` | Nothing. Recorded for context only. | `agent-claimed` |

**Only `externally-observed` evidence satisfies a required test on its own.**

`artifact-observed` evidence is real and tamper-evident, but both the artifact
and its digest live where the actor being verified can write them — so it
proves the artifact is internally consistent, not that a test ran. A code
review demonstrated a fully hand-forged run record with a genuinely matching
sidecar passing an earlier version of this check, without `axiom run` ever
being invoked. Computing a SHA-256 is exactly as easy as writing the JSON it
summarises.

To satisfy a required test with `artifact-observed` evidence, a human must
accept it on the record — see [Authority claims](#authority-claims) below.

Produce `runner-exit-record` evidence with:

```bash
axiom run --project <path> --work-item D-001 --name "unit tests" --command "npm test"
```

### Authority claims

| Actor | May grant |
|---|---|
| `agent` | `implementation-complete` |
| `human` | everything, **with a `decision_ref` citing a `DEC-###`** |

`"actor": "human"` inside an agent-authored file is not self-proving, and commit
authorship is not proof either — `user.name` is an arbitrary string. The claim
must resolve to exactly one row in `decision-log.md` -- not merely name one;
`DEC-999-NOT-REAL` is rejected the same as an empty `decision_ref`. It must
also not have been added or edited **within the commit range under
verification**: a row the execution's own commits could have introduced is
not independent authority for that same execution.

Resolving is not enough. The row must also **state what it authorizes**, via
an `axiom-authority:` binding token — otherwise any decision in the log
satisfies any claim:

```text
| 2026-07-31 | DEC-014 | Approve release of D-001 | ship / hold | ship |
  axiom-authority: type=release-approval; work_item=D-001;
  contract=<contract sha256> | none | approved |
```

`type`, `work_item` and `contract` are required on every human-only claim. The
token is parsed field by field, per table cell, and runs until the next
`axiom-authority:` or the end of its cell — so one row may carry several
bindings, sharing a cell or not. See
[`EXEC-007`](../rules/EXEC-007.md).

#### Vouching for artifact evidence

`test-evidence-accepted` is the claim type that promotes `artifact-observed`
evidence so it can satisfy a required test. It is bound on both sides — the
claim names the test and the artifact digest, and the decision row's token
names the same pair:

```json
{
  "test_evidence": [
    { "type": "junit-artifact", "name": "unit tests",
      "path": "reports/junit.xml", "sha256": "<real digest>" }
  ],
  "authority_claims": [
    { "type": "test-evidence-accepted", "actor": "human",
      "claim": "accepted", "decision_ref": "DEC-014",
      "test_name": "unit tests", "evidence_sha256": "<the same real digest>" }
  ]
}
```

```text
| 2026-07-31 | DEC-014 | Accept unit test evidence for D-001 | ... | accepted |
  axiom-authority: type=test-evidence-accepted; work_item=D-001;
  contract=<contract sha256>; test=unit tests; evidence=<the same real digest> | ... |
```

Both sides are necessary. The claim is written by the actor being verified, so
claim-side binding alone lets a forger hash their own artifact and copy the
result into their own claim; the decision row is the one input the actor cannot
author inside `base..head`. Promotion is per evidence entry, never global: a
vouch for `unit tests` does nothing for `integration tests`, and a row
approving one artifact does not carry over to another.

An agent vouching for its own evidence is rejected on actor authority, and a
`DEC-###` that does not resolve, is ambiguous, was written by this execution's
own commits, or carries no matching token, promotes nothing.

Deliberately a claim rather than a config flag: a weakening that is
per-execution, attributable, and recorded in a governed artifact can be
reviewed later. A boolean in a config file cannot.

**What it proves:** that a named human accepted responsibility for the
artifact. Not that they inspected it. The guarantee here is accountability,
the same one every human approval gate in this framework offers — not
certainty.

## Contract immutability

`axiom export` writes the contract **and** `EXECUTION-CONTRACT.json.sha256`, a
digest of the contract file's exact bytes. Verification requires all three to
agree: the contract's current hash, the sidecar, and the result's
`contract_sha256`. The sidecar is **mandatory** -- deleting it fails
verification (`EXEC-002`, verdict `contract_digest_missing`) rather than
skipping the tamper check.

This is what stops an agent widening `allowed_paths` or flipping
`git_authority.push` in the approved contract and then conforming to its own
edit. To change a contract legitimately, re-export it — which mints a new digest
and makes the change visible in review.

The digest is over raw file bytes rather than canonicalized JSON because
`ConvertTo-Json`'s ordering and escaping differ between Windows PowerShell 5.1
and PowerShell 7, both required hosts.

## What this does not verify

Stated plainly rather than left to be discovered:

- **It does not prove the absence of git side effects.** A push to a remote this
  checkout does not know about, a force-moved remote ref, or a branch pushed then
  deleted cannot be disproven from local state. Push detection is tri-state:
  only a positive observation raises `EXEC-006`.
- **No local artifact proves its own provenance.** This is the general form of
  the point above about `artifact-observed` evidence, and it applies to the
  contract too: an actor that rewrites contract, sidecar, and result
  consistently defeats the digest check. A digest establishes integrity from
  the moment it was taken; it never establishes who took it. Closing that
  would need either a secret the actor cannot read, or an observer outside
  the actor's reach — neither of which exists inside a working tree the actor
  controls. What remains is git history (which is why `.execution/` is meant
  to be committed), external observation (`ci-check`), and human
  accountability.
- **A human vouch proves accountability, not inspection.** A
  `test-evidence-accepted` claim records that a named person accepted an
  artifact. Whether they actually looked at it is outside what any validator
  can see.
- **It does not judge code quality, requirement satisfaction, or whether the
  work should ship.** Those remain human decisions.
- **`--format` is accepted but does not change the output.** The schema is
  workflow-neutral by design; per-workflow dialects would be the "normalized
  intermediate representation" Milestone 5's scope explicitly rejects until a
  second real consumer exists.

## Rules

| Rule | Fails when |
|---|---|
| [`EXEC-001`](../rules/EXEC-001.md) | result missing or malformed |
| [`EXEC-002`](../rules/EXEC-002.md) | contract missing, invalid, tampered, or a different version |
| [`EXEC-003`](../rules/EXEC-003.md) | different work item, base, or an uncovered requirement |
| [`EXEC-004`](../rules/EXEC-004.md) | changed file outside approved paths |
| [`EXEC-005`](../rules/EXEC-005.md) | required test lacks verifiable evidence |
| [`EXEC-006`](../rules/EXEC-006.md) | git authority exceeded |
| [`EXEC-007`](../rules/EXEC-007.md) | authority claim the actor cannot grant |
| [`EXEC-008`](../rules/EXEC-008.md) | claims irreconcilable with observed git state |

## Related

- [`docs/architecture/execution-contract-verification.md`](../architecture/execution-contract-verification.md) — threat model and the Milestone 5.0 decision
- [`docs/reference/scope-declaration.md`](scope-declaration.md) — `SCOPE.json`, whose glob engine and precedence rules this reuses
- [`docs/reference/diagnostics-contract.md`](diagnostics-contract.md) — the shared output shape
- `pmo-config/execution-contract-policy.json` — adapters, actor authority, exempt paths, stated limits
