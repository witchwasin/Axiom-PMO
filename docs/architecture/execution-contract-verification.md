# Execution Contract Verification — Milestone 5.0 research

> Status: **research complete, decision recorded.** This document is
> Milestone 5.0's required output: a threat model, a target schema design,
> and an explicit GO / GO WITH REFRAME / NO-GO decision. It is design, not
> shipped code — nothing in `scripts/` or `pmo-config/` reads the schemas
> described here yet. Implementation is Milestone 5.1 onward, and per
> `ROADMAP.md`'s Roadmap Governance, opening planning issues for it is
> allowed; starting it is a separate step.

## 1. Objective

Milestone 5 asks whether Axiom-PMO can verify that an AI agent's execution
output stayed inside an approved contract, using observable ground truth
instead of trusting the agent's own report of what it did. Milestone 5.0's
job is narrower: decide whether a *native, verifiable integration surface*
exists in a real execution framework, or whether the milestone has to be
reframed around git-ground-truth verification instead.

## 2. What was inspected, and how

This research was done against **primary sources actually present on this
machine**, not general background knowledge, per the standing rule that a
memory or assumption is a claim about the past until re-verified:

- `integrations/superpowers/` (this repo) — the existing experimental
  `EXECUTION-CONTRACT.template.json`, `EXECUTION-RESULT.schema.json`, and
  `integration-policy.json`.
- `SCOPE.json` and Milestone 4.5's diagnostic contract
  (`docs/reference/scope-declaration.md`, `docs/reference/diagnostics-contract.md`)
  — the closest existing precedent for a deterministic, git-grounded check.
- **A real, current local clone of the `superpowers` plugin** at
  `/Users/arm/Documents/GitHub/superpowers`, commit `44c9b2d6e889982ac18c27d05a19fefe335194e1`
  (2026-07-27), `.claude-plugin/plugin.json` version `6.2.0`. This is the
  actual upstream project (`https://github.com/obra/superpowers`), inspected
  directly rather than assumed from the earlier experimental schemas'
  own commentary.

### 2.1 The real hook/event surface

`hooks/hooks.json` in that clone registers exactly one hook:

```json
{
  "hooks": {
    "SessionStart": [
      { "matcher": "startup|clear|compact",
        "hooks": [{ "type": "command",
          "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start",
          "shell": "bash", "async": false }] }
    ]
  }
}
```

No `PostToolUse`, `Stop`, `SubagentStop`, or any other hook type is
registered anywhere in the repository (verified by grep across the full
tree, not just the hooks directory).

`hooks/session-start` (the script that hook invokes) does exactly one
thing: it reads `skills/using-superpowers/SKILL.md` as a static file,
JSON-escapes it, and emits it as injected context
(`hookSpecificOutput.additionalContext` on Claude Code). It does not read
any execution-contract input, does not write any execution-result output,
and does not touch the filesystem beyond that one read.

The project's own `docs/porting-to-a-new-harness.md` states this
architecture explicitly, as an intentional design, not a gap:

> "The bootstrap is the entire integration. Without it, the skill files are
> inert — present on disk, never invoked."

Superpowers is a **prompt-injection skill library**: skills are markdown
files describing actions in harness-neutral language ("dispatch a
subagent", "invoke a skill"); the harness's own native tools execute those
actions. There is no JSON contract the plugin ingests and no JSON result it
emits — an agent using Superpowers is just a Claude Code (or other harness)
agent reading instructions and using its normal tools.

### 2.2 What this confirms and what it changes

This confirms the finding the earlier experimental schemas' own README
already assumed ("not wired into the validator runtime"), now backed by
primary evidence instead of assumption. It also confirms the renaming this
repo already did on 2026-07-29 (Milestone 5: "Superpowers Runtime Bridge" →
"Execution Contract Verification MVP") was the right call before this
research even ran — there is no runtime to bridge to.

## 3. Threat model

Reproduced from `ROADMAP.md` (this is that document's authoritative copy;
if the two ever disagree, treat that as a bug and reconcile them):

```text
Untrusted:
  Agent-generated execution result, agent-authored summaries, agent-declared
  test outcomes, agent-declared approval state.

Observed but context-limited:
  Local Git repository, available remote refs, CI artifacts, workflow check
  conclusions.

Trusted only under explicit policy:
  Framework configuration, the approved execution contract, human authority
  records.
```

The core principle this threat model enforces: **an agent-authored
`EXECUTION-RESULT.json` is written by the same actor being verified.** It
cannot be evidence by default. Every field needs explicit provenance:

```text
Agent claim -> Axiom-observed evidence -> Human authority
```

| Data | Status |
|---|---|
| Agent states a test ran | Claim |
| A test tool produced a real artifact (JUnit XML, checked CI run) | Observed evidence |
| A CI check tied to the exact commit SHA passed | Stronger observed evidence |
| A human states the work is accepted | Human authority |

## 4. Target schema design

This section is design intent for Milestone 5.1+, not a shipped schema.
Field names may change during implementation; the shapes and invariants
below should not.

### 4.1 Contract immutability

A contract and result editable by the same actor prove nothing. The result
must reference the contract it claims to satisfy **by content digest**, and
the base/head commits it claims to have worked from **by exact SHA, never
a branch name** (branch names move; the exact commit a contract was
approved against does not — this is the same time-of-check/time-of-use
discipline Milestone 4.5 already applies to pull-request base/head
resolution, reused directly rather than re-invented):

```json
{
  "contract_sha256": "...",
  "base_sha": "...",
  "head_sha": "..."
}
```

Axiom-PMO validates the result against the contract version that was
actually approved — never a version the agent could have modified
afterward by editing both files together.

### 4.2 Evidence provenance, attached per field

Extending the experimental `EXECUTION-RESULT.schema.json`'s flat
`tests[].result` with explicit provenance:

```json
{
  "evidence_origin": "agent-claimed",
  "verification_status": "unverified"
}
```

enriched, where Axiom-PMO can independently confirm something, to:

```json
{
  "evidence_origin": "git-observed",
  "verification_status": "verified",
  "observed_head_sha": "abc123..."
}
```

An unverified claim may be recorded; it must never satisfy a required check
by itself.

### 4.3 Test evidence: three machine-verifiable adapters, not one

The experimental schema's `tests[].result` enum (`passed`/`failed`/`skipped`)
stays, but MVP scope is deliberately capped at three *evidence sources*, not
locked to one test framework's output format:

1. A JUnit XML artifact, with a checksum (so it can't be edited after the
   fact without detection).
2. A GitHub Actions check tied to the exact commit SHA (verifiable via the
   GitHub API, the same trust boundary Milestone 4's own Action already
   operates inside).
3. An exit record **Axiom's own runner produces**, not the agent — the
   single strongest evidence source available in the MVP, because Axiom
   itself observed the command run.

A free-text agent claim (`{"name": "unit tests", "result": "passed"}`) may
still be recorded, but is always `evidence_origin: agent-claimed` /
`verification_status: unverified`, and can never alone satisfy a
`required_tests` entry.

### 4.4 Authority claims, not a boolean

The experimental `integration-policy.json`'s `git_authority_defaults`
(commit/push/merge/deploy default `false`) stays as the default posture, but
approval itself becomes a **typed authority-claim record**, not a single
boolean an agent could flip:

```json
{
  "authority_claims": [
    { "type": "release-approval", "actor": "agent", "claim": "approved" }
  ]
}
```

The validator rejects any claim whose `actor` type lacks authority to grant
it — regardless of what the claim text says. Commit author alone is
insufficient proof of a human actor (it can be spoofed); acceptance must
cite an authority record the framework independently recognizes.

### 4.5 Known, stated limitation — not a promise to prove a negative

The MVP verifies observable Git claims within the available repository and
remote context: SHA resolvability, whether a commit descends from the
claimed base, whether the head tree matches what was reported, whether
changed paths match the diff, whether the contract permitted a claimed
`commit`/`push`, whether a claimed remote ref actually contains that commit
(when remote context is available). It does **not** prove the absence of
every possible external Git side effect — a push to a remote the current
checkout doesn't know about, or a force-moved remote ref, cannot be
disproven from local state alone. This limitation is stated in the
product-facing docs when 5.1+ ships, not discovered by a user the hard way.

## 5. Decision

**GO WITH REFRAME.**

No native, verifiable contract-ingestion or result-emission surface exists
in the reference execution workflow (Superpowers) — confirmed directly
against its current source, not assumed. `NO-GO` is rejected because a
meaningful verification boundary *does* exist: git state itself (commits,
diffs, remote refs) is real, observable, and already how Milestone 4.5
verifies scope. Plain `GO` (a native runtime bridge) is rejected because
there is nothing on the other end to bridge to, and forcing a runtime
integration that doesn't exist would mean either fabricating one inside
Superpowers (out of scope, not this repo's to change) or lying about the
integration's depth.

The reframed shape: Axiom-PMO defines and validates an **execution
contract and result schema that any execution workflow can produce**,
verified primarily against **git ground truth** (commits, diffs, checked
CI runs) rather than against a native protocol handshake. Superpowers
remains the reference workflow used to design and test this — an agent
using Superpowers' skills (or any other workflow) can write an
`EXECUTION-RESULT.json` file into the repo by hand/by instruction, exactly
the way it already writes code and commits; Axiom-PMO's validator then
checks that file against the contract and against what git actually shows
happened. No change to Superpowers itself is required or proposed.

This keeps the MVP's promise honest: **"Axiom-PMO controls execution
output with real validation, not only architecture documentation"** (the
Milestone 5 success signal already recorded in `ROADMAP.md`) — validation
against git ground truth is real; a claimed native bridge to a plugin that
has no ingestion surface would not have been.

## 6. What this does not change

- `ROADMAP.md`'s Milestone 5 deliverables list (export/import commands,
  schema validation, allowed-path validation reusing Milestone 4.5's glob
  engine, required-test validation against the three evidence adapters
  above, scope-deviation checks, contract-to-result git-authority
  validation, self-approval blocking via typed authority claims,
  integration tests) already assumed this shape when it was written on
  2026-07-30 — this document is the evidence trail for why that shape is
  right, not a new plan.
- `integrations/superpowers/*.json` are **not modified by this document**.
  They stay experimental until Milestone 5.1 actually implements against
  the refined shapes in §4 — updating them now would blur "designed" with
  "shipped," which Milestone 5.0 is explicitly not authorized to do.
- Milestones 5.1–5.4 remain separate, sequenced steps. This decision
  unblocks planning them; it is not itself their implementation.
