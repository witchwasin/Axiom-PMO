# Handoff readiness

> "Is this documentation good enough for a developer to start building, and for the team to demonstrate it on time?"

Axiom-PMO 1.0 could not answer that question. It could answer a narrower one — is the governance complete, is every claim sourced, has a human approved each gate — and it answered it well. But a project can satisfy every one of those checks and still hand a developer a plan that cannot be executed.

The Handoff gate exists to close that gap.

```text
Draft → Scope → Design → Handoff → Build/QA → Release
```

---

## The failure this prevents

A green validator that produces a stalled team.

Consider a plan that passes every 1.0 check. Requirements are sourced. Design is approved by a Tech Lead. Work items have modes, statuses, and evidence references. Nothing is a placeholder. And then:

- The shared schema every other item reads from is scheduled after the items that consume it. Two engineers spend day one building against a table that does not exist.
- The scan feature needs the device camera and nobody decided how the page is served. It works on `localhost` and fails on the borrowed tablet. No code review catches this, because nothing in the code is wrong.
- One document commits to keeping photographs on the site network. Another specifies a photo upload with no classification. Both authors were being accurate about their own page.
- An acceptance case asserts behaviour on a record type the seed data never creates. It is never actually run.
- A work item is owned by "Dev Team", which survives every status meeting and dies on Monday morning.

Every one of these is invisible to a rule that checks whether a field is filled in. Every one of them costs days.

---

## Two layers, deliberately separate

The temptation is to encode the failures above as validator rules: *stock features must have a receive operation*, *photos are PII*, *QR scanning requires HTTPS*. That would be a mistake. Each of those is true in some domains and wrong in others, and a validator that guesses wrong is worse than one that stays quiet — it teaches people to ignore it.

So the work splits:

### Layer 1 — deterministic validation

Checks what is provable from the artifacts. `scripts/validate-project.ps1 -Gate Handoff`, rules `HANDOFF-001` to `HANDOFF-014`.

It can prove that a build sequence declares a dependency scheduled after its consumer. It can prove that a row the author marked "contains sensitive data" has no classification decision. It can prove that an acceptance case has no seed strategy, that a work item has no named owner, that a declared capability has no serving model.

It **cannot** decide that a photograph of a vehicle is personal data, or that a stock feature is incomplete without a receive operation. It never tries. Every rule reads a declaration the author wrote, and checks whether that declaration is complete and consistent.

### Layer 2 — semantic handoff review

Checks whether the complete contract makes sense. Performed by a reader — usually an AI, sometimes a person — through the twelve lenses in `pmo-config/handoff-policy.json`, and recorded as structured evidence in `HANDOFF-REVIEW.json`.

This is where "stock can be consumed but never received" gets caught. A reader notices that the demonstration requires running the flow twice and the count only moves one way.

**The review is candidate evidence, not an approval.** Layer 1's interest in Layer 2 is narrow and mechanical: did a review happen, did it cover every lens, does every finding have an owner and a blocking point, and is it still current? `HANDOFF-010` checks exactly that and nothing more. It never evaluates whether the findings were any good.

---

## Freshness

A review speaks only for the sources it actually read.

`HANDOFF-REVIEW.json` records **two** digests, because a review goes stale two different ways:

| Digest | Goes stale when |
|---|---|
| `source_snapshot` | new source material lands |
| `review_inputs` | someone edits a governed artifact the reviewer read — `HANDOFF.md`, `DESIGN/BUILD-SPEC.md`, `DELIVERY.md`, the design, RAID, or the decision log |

The second is the one people forget. Rewriting the build sequence after a review leaves the source snapshot untouched; with one digest the review would keep reporting as current while no longer describing the plan in front of it.

Get both with:

```bash
pwsh -File scripts/handoff-digest.ps1 -ProjectPath <project>
```

## Who may close a finding

Recording a review is only half the control. The other half is that closing a finding is checked rather than trusted: `resolved`, `accepted_risk`, and `deferred` all need a resolvable `decision_ref`, an AI reviewer may only set `resolved`, and an AI may never close a finding under a human-only lens — privacy classification and environment constraints — whatever decision reference it cites.

The intended shape is that an AI drafts the review and a human signs it. An instruction telling an agent not to close a privacy finding is not a control; a rule that fails the gate when it does is.

`reviewer_kind` is a self-declaration, and no offline validator can prove who typed it. So the check does not rest on that word: a closure under a human-only lens must cite a `DEC-###` that exists in `decision-log.md` with a named decider. That makes the closure **traceable to a governed artifact**, not **provably human**. Provable attribution needs signed commits or a reviewed pull request, both outside this validator.

---

## Readiness is not one boolean

This is the part that changes how the gate is used.

"Ready" is not a single state. A project can be entirely ready for two engineers to start writing code and entirely unready to be demonstrated, and those two facts have different owners, different deadlines, and different fixes.

`scripts/assess-handoff.ps1` reports six:

| Stage | Blocked by |
|---|---|
| Contract Valid | any deterministic FAIL |
| Ready to Start Development | open blockers at `before_build` |
| Ready to Integrate | also `before_integration` |
| Ready to Demo | also `before_demo` |
| Ready for UAT | also `before_uat` |
| Ready for Release | also `before_release` |

An **open blocker** is either an open finding in `HANDOFF-REVIEW.json` or an open row in `HANDOFF.md`'s Open Actions table. Both use the same blocking-point vocabulary, and the operational blockers — a device that has not arrived, a certificate not yet installed — usually live in the second.

### Three states, not two

A stage verdict is `true`, `false`, or **`null`**:

| Value | Meaning |
|---|---|
| `true` | no recorded blocker |
| `false` | a recorded blocker, named in `verdict_reasons` |
| `null` | cannot be determined — usually because no usable review exists |

`null` matters. Without a review there are no *recorded* open findings, which is not the same as there being none, and reporting `true` there would turn an absence of evidence into evidence of absence. `verdict_reasons` carries a sentence per stage explaining which of the three applies.

A real output:

```text
Verdict: READY TO BUILD, NOT READY TO DEMO

  YES  Contract Valid                no deterministic failures
  YES  Ready to Start Development    no recorded blocker
  YES  Ready to Integrate            no recorded blocker
  NO   Ready to Demo                 blocked by HF-005, OA-001
  NO   Ready for UAT                 blocked by HF-005, OA-001
  NO   Ready for Release             blocked by HF-005, OA-001
```

Collapsing that into one answer forces a bad choice. "Not ready" stalls a team that could be working. "Ready" promises a demonstration that will not happen. Reporting both is the only honest option, and it is the whole reason the blocking-point enum exists.

---

## The score, and its limits

The assessment produces a number out of 100 across seven dimensions. It exists to make a trend visible across projects and over time. It is capped hard whenever the evidence behind it is thin:

| Cap | When |
|---|---|
| verdict `BLOCKED` | any deterministic FAIL |
| max 70 | semantic review missing or stale |
| max 69 | no named owner, or the build sequence is not executable |
| max 49 | an open critical finding blocks `before_build` |

Open findings cost points in the dimension their lens belongs to, and open actions cost points in the dimension their blocking point belongs to. A project therefore cannot score full marks while its own documents say the demonstration will fail — a number printed directly above `Ready to Demo: NO` and reading `100 / 100` is worse than no number, because the number is what ends up in a status report.

**The score is not an approval.** It does not transfer accountability, and no gate may be passed on the strength of it. A team that starts optimising the number instead of the plan has turned a diagnostic into a target, which is the failure mode this framework was built to avoid in the first place.

---

## What the Handoff gate does not add

**A new approval.** It reuses the existing `Design Ready` approval. Adding a fourth human sign-off to a lightweight framework would be exactly the documentation overhead Axiom-PMO exists to avoid. The gate asks a different question about the same approved design: is the contract complete enough to act on?

**A requirement on existing projects.** Handoff checks run only when `-Gate Handoff` is requested. A project validating at Draft, Scope, Design, or Release behaves exactly as it did in 1.0.

**An execution framework.** Axiom-PMO owns source, scope, risk, evidence, traceability, readiness, and human authority. It does not own the coding plan, the implementation, or the tests. See [`docs/architecture/control-plane.md`](../architecture/control-plane.md).

---

## Related

- [Artifact map](../guides/artifact-map.md) — which document plays which role
- [Three-day demo handoff](../guides/three-day-demo-handoff.md) — a worked walkthrough
- [Rule reference](../rules/) — `HANDOFF-001` to `HANDOFF-014`
- [Diagnostics contract](../reference/diagnostics-contract.md) — the machine-readable output
- [Human authority](human-authority.md) — what an AI may never decide
