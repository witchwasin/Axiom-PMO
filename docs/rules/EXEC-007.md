# EXEC-007 - Authority claim the actor cannot grant

| | |
|---|---|
| Level | FAIL |
| Runs when | `scripts/verify-execution-result.ps1` is invoked |
| Artifacts | `EXECUTION-RESULT.json` |

## What this rule checks

Each entry in the result's `authority_claims` is checked against `pmo-config/execution-contract-policy.json`:

1. The `actor` is a recognized type. An unknown actor is rejected, never defaulted to permitted.
2. The `type` is one that actor `may_grant`.
3. A `human_only` claim type cites a `decision_ref`.

## Why it exists

This is the rule that stops an agent approving its own work.

**Why a typed claim rather than a boolean.** An earlier design had the result carry `approval_claimed: false`. That is worthless: the field is set by the same actor it constrains, and an agent inclined to claim an approval is equally inclined to write `false`. Modelling approval as a *typed authority event* lets the validator reject the claim on the strength of who is making it, regardless of what the claim text says:

```json
{ "authority_claims": [
    { "type": "release-approval", "actor": "agent", "claim": "approved" }
] }
```

is rejected because `agent` is not authorized to grant `release-approval` — not because the word "approved" was noticed.

| Actor | May grant |
|---|---|
| `agent` | `implementation-complete` only |
| `human` | all claim types, **with a decision record** |

An execution agent may report that it finished implementing. It may never grant an approval, change approved scope, or downgrade a risk mode.

### Why `actor: "human"` is not self-proving

The result is an agent-authored file. Writing `"actor": "human"` in it does not make a human the author, and **commit authorship is not proof either** — `user.name` and `user.email` are arbitrary strings anyone can set.

So a human-only claim must cite a `decision_ref` pointing at a `DEC-###` in `decision-log.md`: a governed artifact a named person is accountable for, that exists outside the document making the claim.

This mirrors the framework's standing rule that a semantic review is candidate evidence, never an approval (`AGENTS.md` rule 11).

## How to fix

Have the agent report only what it can:

```json
{ "authority_claims": [
    { "type": "implementation-complete", "actor": "agent", "claim": "done" }
] }
```

For a real human approval, record the decision in `decision-log.md` first, then cite it:

```json
{ "type": "release-approval", "actor": "human",
  "claim": "approved", "decision_ref": "DEC-014" }
```

## Related

`EXEC-005` (evidence rather than approval), `EXEC-006` (git authority), `APPROVAL-004` / `APPROVAL-005` (approval authenticity in project artifacts).
