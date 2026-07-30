# EXEC-005 - Required test has no verified evidence

| | |
|---|---|
| Level | FAIL |
| Runs when | `scripts/verify-execution-result.ps1` is invoked |
| Artifacts | `EXECUTION-RESULT.json` |

## What this rule checks

Every entry in the contract's `required_tests` has a matching entry in the result's `test_evidence` that **actually verifies** — not merely one that names a verifiable-looking adapter type and fills in the right field names. `scripts/lib/execution-contract-evidence.ps1`'s `Test-EvidenceEntryVerified` opens the file, recomputes the hash, queries the live API, or reopens the sealed record, per adapter.

## Why it exists

> An agent stating that a test passed is a claim, not evidence.

The result is authored by the actor being verified. `{"name": "unit tests", "result": "passed"}` is a sentence that agent wrote about itself; treating it as proof that tests ran would make required-test validation ceremonial.

**This is a corrected rule.** An earlier version of this check only confirmed that a `test_evidence` entry's *fields were present* — `{"type": "runner-exit-record", "command": "npm test", "exit_code": 0, "recorded_by": "axiom-runner"}` passed outright, because nothing ever opened a file, queried an API, or checked a hash. A code review found this before it was accepted; the real checks below are what replaced it.

### The three real adapters

| Adapter | Requires | What is actually checked |
|---|---|---|
| `junit-artifact` | `path`, `sha256` | `path` resolves inside the project root (same containment check as a `FILE:` reference, `REF-002`); the file exists; its real SHA-256 equals the claimed `sha256`; its XML parses safely (DTD processing prohibited); `failures + errors` across every `<testsuite>` sum to zero; `tests` is greater than zero. |
| `ci-check` | `name`, `commit_sha` | A live query via `gh api repos/<owner>/<repo>/commits/<sha>/check-runs`, matched by `name`. The **observed** conclusion must be `success`. The result's own `conclusion` field, if present, is never read — see below. No `gh` CLI, no auth, or no resolvable GitHub remote all mean *unverified*, never a silent pass. |
| `runner-exit-record` | `run_record_path` | A relative path (containment-checked) to a file `scripts/run-execution-command.ps1` produced: a JSON record plus a `.sha256` sidecar of its exact bytes. The sidecar's digest must match the file's real hash; the record's `work_item_id` and `contract_sha256` must bind to the contract under verification; its sealed `exit_code` must be `0`. `command`/`exit_code` fields on the `test_evidence` entry itself, if present, are informational only. |

`agent-assertion` (`name` only) is recorded for context and always carries `evidence_origin: agent-claimed`; it never satisfies a required test on its own.

### Never trust the result's own claimed conclusion

A `ci-check` entry may carry a `conclusion` field. It is **never read as authoritative** — only the live API response is. An agent writing `"conclusion": "success"` into its own result proves nothing about what actually happened; the whole point of this adapter is to check independently.

### The runner is the strongest evidence in the MVP, and how it is sealed

`runner-exit-record` evidence comes from `axiom run` (`scripts/run-execution-command.ps1`), which actually executes the command as a real child process and captures the real exit code — Axiom-PMO observed it, rather than being told about it. The record and its `.sha256` sidecar use the same file+sidecar pattern `EXECUTION-CONTRACT.json` does, deliberately: a digest self-embedded via `ConvertTo-Json` re-serialization would differ between Windows PowerShell 5.1 and PowerShell 7, for reasons unrelated to tampering — hashing the file's stored bytes has no such dependency.

This is not cryptographic proof against an actor with unrestricted filesystem access who edits both the record and its sidecar together. What it defeats is an agent hand-typing a plausible JSON object with no script ever having run the command — the actual gap the review found.

### Unknown adapter types

An adapter type the policy does not recognize degrades to *not verifiable* rather than failing the run outright. A result produced by a newer toolchain should be reported as "this does not satisfy a required test" — which is safe — instead of crashing verification, which would make adding an adapter a breaking change.

## How to fix

Produce real evidence, then reference it:

```bash
axiom run --project <path> --work-item D-001 --name "unit tests" --command "npm test"
# prints the run_record_path to put in EXECUTION-RESULT.json
```

```json
{
  "test_evidence": [
    { "type": "runner-exit-record", "name": "unit tests",
      "run_record_path": ".execution/D-001/runs/<run-id>.json" },
    { "type": "ci-check", "name": "integration tests", "commit_sha": "abc123..." },
    { "type": "junit-artifact", "name": "e2e tests",
      "path": "reports/junit.xml", "sha256": "<real sha256 of that file>" }
  ]
}
```

The `name` must match the `required_tests` entry it satisfies.

## Related

`EXEC-007` (claiming an approval rather than evidence), `EXEC-008` (git-observable claims), `RTM-003` (requirement with no linked test evidence, the documentation-side equivalent).
