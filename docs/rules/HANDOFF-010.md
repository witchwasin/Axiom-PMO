# HANDOFF-010 - Semantic review missing, incomplete, or stale

| | |
|---|---|
| Level | FAIL (Strict) / WARN (Lite, Standard) |
| Gate | Handoff |
| Applies to | Standard, Strict |
| Artifacts | `HANDOFF-REVIEW.json` |

## What this rule checks

1. `HANDOFF-REVIEW.json` exists when the mode requires it.
2. It parses, and its `schema_version` matches the policy.
3. `reviewer_kind` is `ai` or `human`.
4. **Every lens in the policy was reviewed**, and no unknown lens is claimed.
5. Every finding has an id, a lens the policy knows, a valid severity, a valid status, a valid blocking point, a **named** owner, at least one evidence reference, and a suggestion.
6. **Closure has authority behind it** (see below).
7. **The review is current** against *both* digests: `source_snapshot.digest` and `review_inputs.digest`.

When all of that holds and open critical findings exist, the rule additionally emits a WARN listing them with their blocking points.

## Why it blocks

The deterministic rules in this gate prove that the contract is *complete*. They cannot prove it is *sensible*. A build sequence can be perfectly ordered and still omit the receive-stock operation that makes the consume-stock operation reachable. Only a reader can catch that, so the framework requires that a reader looked - and records what they found in a form the validator can check.

Staleness matters because a review is evidence about the sources it actually saw. When a new MOM lands, the previous review's clean bill of health no longer refers to the current scope.

## Who may close a finding

Any status other than `open` is a claim that somebody decided something. That claim is checked, not trusted:

| Rule | Enforced as |
|---|---|
| A closed finding names a decision | `resolved`, `accepted_risk`, and `deferred` all require a `decision_ref` that resolves |
| An AI may only mark `resolved` | `accepted_risk` and `deferred` are human judgements in every mode |
| An AI may never close a human-only lens | `privacy_and_data_classification` and `environment_and_device_constraints`, whatever the decision reference says |

Configured in `pmo-config/handoff-policy.json` under `semantic_review.closure_policy`.

The intended workflow is that an AI drafts the review and a human signs it. When a human has closed the findings only they could close, the file's `reviewer_kind` is `human` and `reviewer` names them — see `examples/HANDOFF-DEMO/HANDOFF-REVIEW.json`. An AI-authored review that closes a privacy finding on its own authority fails this rule, which is the point: a rule an agent can talk its way past is not a control.

### `reviewer_kind` is an attestation, not proof

No offline validator can prove who typed a JSON field. Claiming otherwise would be exactly the false assurance this framework exists to prevent, so the check does not rest on that word alone.

What is actually enforced: a finding closed under a **human-only lens** must cite a `DEC-###` that exists in `decision-log.md` **with a named decider**. That anchors the closure to a governed artifact a person is accountable for. Writing `"reviewer_kind": "human"` in a file buys nothing on its own — the decision row has to exist, and its `Decided By` cannot be `TBD` or a team name.

This is a real limit, stated plainly: the control makes an unattributed closure *traceable to a document*, not *provably human*. Signed commits or a reviewed pull request are what make it provable, and both live outside this validator.

## Two digests, not one

A review goes stale two different ways:

| Digest | Covers | Goes stale when |
|---|---|---|
| `source_snapshot.digest` | `PROJECT.md`'s Source Snapshot table | new source material lands |
| `review_inputs.digest` | the governed artifacts the reviewer read | someone edits `HANDOFF.md`, `DESIGN/BUILD-SPEC.md`, `DELIVERY.md`, the design, RAID, or the decision log |

The second matters more often than it sounds. Rewriting the build sequence after a review leaves the source snapshot untouched, so with one digest the review would keep reporting as current while no longer describing the plan in front of it.

`HANDOFF-REVIEW.json` is deliberately excluded from `review_inputs`: a review cannot invalidate itself by being written.

## This is not an approval

`HANDOFF-REVIEW.json` is candidate evidence. An AI reviewer may record findings, recommend readiness, and close a finding when the documents show it was fixed. It may not close a finding that needs a business, legal, security, or human decision, and it may never move an approval row from pending to approved. See `docs/concepts/human-authority.md`.

## How to fix

Run the `pmo-delivery` skill with the `handoff_review` intent, or write the file by hand from `templates/HANDOFF-REVIEW.json`. Recompute both digests whenever anything the review read changes:

```bash
node -e "import('./dist/tools/digest-tools.js').then(m=>process.stdout.write(m.handoffDigest('.', '<project>').output))"
```

## Related

`SOURCE-002` (snapshot freshness), `docs/concepts/handoff-readiness.md`.
