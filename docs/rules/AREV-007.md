# AREV-007 - Semantic finding output contract

| | |
|---|---|
| Level | FAIL (whenever the adversarial review check is enabled at all: Standard and Strict; Lite disables the whole AREV family) |
| Runs when | `node cli/axiom.mjs verify` is invoked without `--preflight` and `EXECUTION-REVIEW.json` is present and valid |
| Artifacts | `EXECUTION-REVIEW.json` (each finding), `PROJECT.md` (In Scope table) |

## What this rule checks

Every semantic finding of an adversarial review must carry the M3 output
contract, defined in `pmo-config/adversarial-review-policy.json`
`output_contract` and checked by AREV-007:

- **`requirement_ref`** — mandatory, and must resolve: it names the `REQ-###`
  this finding speaks about, declared in `PROJECT.md`'s In Scope table (parsed
  the same way RTM does — `Get-IdsFromRows` on the `### In Scope` rows).
  Missing and unresolvable are two distinct diagnostics, and both name the
  finding id and field, so a review author can tell "forgot to fill it in"
  from "cited a requirement that does not exist".
- **`implementation_claim` / `test_claim`** — non-empty, **or** the explicit
  N/A marker (`output_contract.n_a_marker`, `"N/A"` by default). The claims
  are conditional by design: a finding about a build order or an
  acceptance-seed reachability gap has no natural test claim, and forcing one
  would fabricate content. But "no natural claim" must be *stated* with the
  marker, never left blank — a blank field is "forgot to fill in", and this
  rule treats it as a violation.
- **`owner`** — mandatory, never conditional, and never a group. It names
  the human accountable for the finding, checked with `Test-GenericOwner`
  against the same `owner_policy` that governs handoff owners
  (`pmo-config/handoff-policy.json` `owner_policy.generic_tokens`) — the
  exact check HANDOFF-003 and APPROVAL-005 reuse, not a parallel copy.
  Blank and "a generic group name" ("Dev Team", "Engineering", "TBD") are
  two distinct diagnostics, and a generic token is never accepted as an
  owner even where an N/A marker would be allowed on a claim field.

Each violation is emitted through the standard diagnostic envelope with
`-ItemId <finding_id>` and `-Field <field>`, the same shape as the rest of
the AREV family.

## Why it exists

MasterPlan M3 ("Semantic Audit Contract" / L3 hardening): an AI's semantic
verdict must never change a validator exit code on its own — the closure
authority already enforced by `HANDOFF-010` and the AREV family's own
`core_principle`. What the framework *can* check deterministically is the
**shape** of a semantic finding: whether it says which requirement it speaks
about, and whether its claims are actually present rather than silently
absent. Without this contract, a review that agrees with the code but names
no requirement and makes no claims is indistinguishable from a review that
forgot to do its job — the two failures look identical in the artifact, so a
validator cannot tell them apart.

The N/A marker design follows feeback.md Round 5 decision 3: conditional
fields with an explicit, checkable marker, so "not applicable" and "forgot to
fill in" are distinguishable states. `owner` completes the five-field list
(severity — already AREV-004's — plus requirement_ref, implementation_claim,
test_claim, owner) per feeback.md Round 6 decision 1, closing the M3 contract.

## Scope and limits (decided in feeback.md Round 5)

- **Anchored on `EXECUTION-REVIEW.json` (adversarial) only.** The handoff
  family (`HANDOFF-REVIEW.json`, `HANDOFF-010`) is deliberately untouched —
  its findings review completeness before code exists, so
  `implementation_claim`/`test_claim` do not fit them naturally. (`owner` was
  already present on handoff findings; it is the one field M3 adds here.)
- **`owner` reuses the handoff family's own check** (`Test-GenericOwner` +
  `handoff-policy.json` `owner_policy`), rather than inventing a parallel
  token list — feeback.md Round 6 decision 1.
- **`requirement_ref` resolves against `PROJECT.md` In Scope only**, not
  `DELIVERY.md` — `item_id` already covers the work-item link, and resolving
  two different kinds of reference through one field would blur them.
- **Shape only, never judgment.** AREV-007 checks presence and resolvability,
  not whether the review's content is thorough, correct, or intelligent —
  the same line AREV-004/005/006 draw.
- **Never reads `recommendation`.** A review whose `recommendation.verdict`
  is `request_changes` passes every AREV check unchanged; the verdict is a
  recommendation to a human, never an input to a validator's pass/fail.
- **Fails closed when the project has no In Scope table**: the requirement id
  set is empty, so any `requirement_ref` fails to resolve. A review cannot
  cite a requirement that does not exist.

## How to fix

- Fill `requirement_ref` with a `REQ-###` that actually appears in
  `PROJECT.md`'s In Scope table.
- Give every finding an `implementation_claim` and `test_claim` — one
  sentence each — or the explicit N/A marker from
  `pmo-config/adversarial-review-policy.json` (`output_contract.n_a_marker`)
  when the finding has no natural claim to make. Never leave the field blank.
- Name a real person in `owner` — the human accountable for the finding.
  A team name, "TBD", or any token listed in
  `pmo-config/handoff-policy.json` `owner_policy.generic_tokens` is a
  violation.

## See also

`AREV-004` (finding schema — presence of the *other* required fields),
`AREV-001` (the review artifact's presence/validity), `HANDOFF-010` (the
same "semantic verdict is not authority" rule on the handoff family), and
[`docs/architecture/adversarial-review.md`](../architecture/adversarial-review.md).
