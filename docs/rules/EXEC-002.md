# EXEC-002 - Contract missing, invalid, or not the one that was approved

| | |
|---|---|
| Level | FAIL |
| Runs when | `scripts/verify-execution-result.ps1` is invoked |
| Artifacts | `EXECUTION-CONTRACT.json`, `EXECUTION-CONTRACT.json.sha256`, `EXECUTION-RESULT.json` |

## What this rule checks

Four related things, in order:

1. **The contract exists and is valid** — parseable, with `contract_version`, `project_id`, `work_item_id`, `mode`, `base_sha`, a non-empty `allowed_paths`, and `git_authority`.
2. **The digest sidecar exists and is well-formed.** `EXECUTION-CONTRACT.json.sha256` is **mandatory, not best-effort**. A missing sidecar means there is no approved digest to check against, and is treated exactly like a missing contract -- verdict `contract_digest_missing` -- never as an unverified pass. A present-but-malformed sidecar (not a 64-character hex digest) is verdict `contract_digest_malformed`.
3. **The contract still matches its digest sidecar.** `axiom export` writes the sidecar at export time. If the contract's bytes no longer hash to that value, the contract was edited after approval. Verdict: `contract_tampered`.
4. **The result answers this contract.** The result's `contract_sha256` must equal the contract's actual digest. Verdict: `contract_mismatch`.

**This rule was corrected.** An earlier version only ran check 3 `if (Test-Path $sidecarPath)` -- deleting the sidecar skipped the tamper check entirely, which is a strictly easier bypass than editing the contract and hoping nobody compares digests. A code review found this before it was accepted.

## Why it exists

**A contract and a result that the same actor can edit together prove nothing.** An agent that widens `allowed_paths` (or flips `git_authority.push` to `true`) in the contract, then writes a result that conforms to the edited version, would otherwise verify cleanly — the check would be validating the agent's work against the agent's own rules.

Pinning the contract's identity by content digest at approval time is what makes the later comparison mean anything. The digest is over the file's **raw bytes**, not a canonical re-serialization of its parsed JSON, because `ConvertTo-Json`'s ordering and escaping differ between Windows PowerShell 5.1 and PowerShell 7 — both required hosts. A digest that disagreed across hosts would fail runs for reasons unrelated to tampering.

### What this does not catch

An actor that rewrites the contract, the sidecar, **and** the result consistently defeats this check. Only git history shows that, which is why the `.execution/` directory is meant to be committed. This limitation is stated rather than papered over — see [`docs/reference/execution-contract.md`](../reference/execution-contract.md).

## How to fix

Verify the result against the contract it was exported from, unmodified.

If the contract genuinely needs to change (the approved scope was wrong, or the work legitimately needs commit authority), **re-export it** — which mints a new digest and makes the change visible in review — and run the work against the new version:

```bash
axiom export --project <path> --work-item D-001 --grant commit --force
```

Do not hand-edit an approved contract; that is precisely what this rule reports.

## Related

`EXEC-001` (the result side), `EXEC-003` (contract intact, but the result is about different work), `EXEC-006` (git authority the contract withheld).
