# Anti-Hallucination Controls

"Anti-hallucination" here does not mean the underlying model stops making things
up. It means the **process refuses to accept unsupported claims** as if they were
true. Axiom-PMO turns each common failure mode into a machine-verifiable
condition.

| Failure mode | Control |
|---|---|
| Inventing requirements or acceptance criteria | Every requirement needs a `source_ref` and an `evidence_status`; "not found in source" is a valid, non-fabricating answer. |
| Silently expanding scope | Scope is approved at a gate; work items declare mode and triggers; out-of-scope is explicit. |
| Claiming unverified test/QA evidence | Test and review claims must resolve to typed references; unresolvable evidence blocks the gate. |
| Fabricating approvals | Approvals are validated against declared roles and gates; a bare "approved-by-chat" string does not pass. |
| Losing traceability | Source → requirement → design → delivery → test → evidence → release is checked row by row (RTM in Strict). |
| Crossing authority boundaries | Git mutations and release approval require explicit human confirmation. |

## The evidence status vocabulary

Every important claim carries one of:

- `verified` — direct source **plus** human approval.
- `supported` — direct source exists, final approval still pending.
- `inferred` — reasoned from partial source; **requires review**.
- `missing` — not found in source; **cannot** become a requirement.
- `conflict` — sources disagree; **must be resolved** before final output.

`inferred`, `missing`, and `conflict` are not failures of honesty — they are the
honest answers, and the framework is built to make them visible rather than
papered over.

## Why a prompt is not enough

An instruction in a prompt is advisory: the agent can ignore or misreport it. A
control is enforced by a script that exits non-zero. Axiom-PMO deliberately puts
the important boundaries in the second category — see
[the validation engine](../architecture/validation-engine.md) and
[human authority](human-authority.md).

Related: [evidence-based execution](evidence-based-execution.md),
[risk modes](risk-modes.md).
