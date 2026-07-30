# EXEC-005 - Required test has no verifiable evidence

| | |
|---|---|
| Level | FAIL |
| Runs when | `scripts/verify-execution-result.ps1` is invoked |
| Artifacts | `EXECUTION-RESULT.json` |

## What this rule checks

Every entry in the contract's `required_tests` has a matching entry in the result's `test_evidence` whose adapter type is **machine-verifiable** and which carries the fields that make it so.

## Why it exists

> An agent stating that a test passed is a claim, not evidence.

The result is authored by the actor being verified. `{"name": "unit tests", "result": "passed"}` is a sentence that agent wrote about itself; treating it as proof that tests ran would make required-test validation ceremonial.

So the MVP recognizes three evidence sources it can independently check, and one it explicitly cannot:

| Adapter | Verifiable | Requires |
|---|---|---|
| `runner-exit-record` | yes | `command`, `exit_code`, `recorded_by` |
| `ci-check` | yes | `name`, `commit_sha`, `conclusion` |
| `junit-artifact` | yes | `path`, `sha256` |
| `agent-assertion` | **no** | `name` |

`runner-exit-record` is the strongest of the three in the MVP, because Axiom-PMO's own runner produced it — it is the one case where the framework observed the command run rather than being told about it.

An `agent-assertion` may still be recorded. It is kept for context and always carries `evidence_origin: agent-claimed`; it simply never satisfies a required test on its own.

### Naming an adapter is not carrying evidence

`{"type": "ci-check", "name": "unit tests"}` fails this rule despite naming a verifiable adapter, because it omits `commit_sha` and `conclusion` — the fields that would let anyone check it. A verifiable adapter missing the fields that make it verifiable is not verifiable.

### Unknown adapter types

An adapter type the policy does not recognize degrades to *not verifiable* rather than failing the run outright. A result produced by a newer toolchain should be reported as "this does not satisfy a required test" — which is safe — instead of crashing verification, which would make adding an adapter a breaking change.

## How to fix

Attach real evidence per required test:

```json
{
  "test_evidence": [
    { "type": "runner-exit-record", "name": "unit tests",
      "command": "npm test", "exit_code": 0, "recorded_by": "axiom-runner" },
    { "type": "ci-check", "name": "integration tests",
      "commit_sha": "abc123...", "conclusion": "success" }
  ]
}
```

The `name` must match the `required_tests` entry it satisfies.

## Related

`EXEC-007` (claiming an approval rather than evidence), `EXEC-008` (git-observable claims), `RTM-003` (requirement with no linked test evidence, the documentation-side equivalent).
