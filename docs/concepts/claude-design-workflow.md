# Claude Design optional workflow

Claude Design is an external Design Execution Provider (binding decision D6):
Axiom-PMO prepares a governed handoff, a Human operates the provider, and
validated output is reconciled back into the Final Handoff. No provider API is
invoked by this framework; there is no automated Claude Design call.

## The flow

1. `pmo-design` prepares `DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json` from
   `templates/DESIGN-PROVIDER-INPUT.json` — a digest-bound reference set over
   the minimum necessary canonical inputs (`PROJECT.md`, `SCOPE.json` when
   present, `DESIGN/BUILD-SPEC.md`, selected Visual Direction and brand assets
   when present, relevant Acceptance Cases), an approved externalization
   reference, the provider, the purpose, and a generated timestamp. `source/**`
   is not copied by default.
2. A Human points Claude Design at that folder and answers its questions.
   Candidate deliverables are exported to `DESIGN/CLAUDE-DESIGN/OUTPUT/**`.
3. The deterministic preflight checks paths, manifest, declared
   screens/states, digests, and scope references (`scripts/design-provider-digest.ps1`
   recomputes the digests it records).
4. `pmo-design` performs semantic candidate reconciliation
   (business/API/data/permission) before Human review.
5. A Human reviews UX/UI/business fit and records accept/revise/reject in
   `DESIGN/CLAUDE-DESIGN/REVIEW.json` with a decision reference. Only a Human
   can accept; an AI may propose revision.
6. Revision returns to provider output and recomputes all digests. A
   technical or scope finding routes to `CHANGE-REQUESTS.json` and returns to
   the relevant upstream contract before the accepted design baseline is
   finalized.
7. Accepted current output is merged into the Final Handoff. Existing Visual
   Proof remains the final conditional render evidence when its activation
   conditions are present.

## What the checks can and cannot detect

The validator proves the manifest contract is complete and current, the
externalization citation is approved, output placement is contained, no review
predates preflight, Human acceptance carries a resolvable decision, and
technical findings are routed through Change Control. It does not judge
whether the design is good, whether the Human who typed the review is the
person named, or whether the provider actually produced the output — those are
the semantic reconciliation and the Human review, and the review's digests
only prove which output set was seen.
