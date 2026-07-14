# Evidence-Based Execution

Axiom-PMO treats every consequential statement as a claim that must be backed by
evidence and carry a status. This applies to requirements, design decisions, test
cases, and release claims alike.

## The guardrail fields

A well-formed requirement looks like this:

```yaml
id: REQ-001
statement: "User can reset password by verified email."
source_ref:
  - source_id: MOM-20260710
    locator: item-2.1
evidence_status: supported
acceptance_criteria:
  - "Given a registered email, when the user requests reset, then a reset link is sent."
```

- `source_ref` is **mandatory** for requirements, design decisions, test cases,
  and release claims.
- `evidence_status` records how solid the backing is (see
  [anti-hallucination](anti-hallucination.md) for the full vocabulary).
- If the source does not contain the information, the correct output is "not
  found in source" — not a fabricated requirement.
- An empty result is valid. Do not invent items to fill a section.

## Candidate evidence vs. trusted evidence

When an AI execution framework produces test results, reviews, or a "done"
signal, that output is **candidate evidence**. It becomes trusted only after
Axiom-PMO validates it — resolvable references, valid statuses, met acceptance
criteria, no unresolved deviations. This is the same standard the framework
applies to its own development (see the
[case study](../../case-studies/unauthorized-git-mutation.md)).

## How it is enforced

References must resolve through the typed reference resolver
(`pmo-config/reference-types.json`), and evidence that cannot be resolved is
raised as a blocking condition rather than accepted. See
[the validation engine](../architecture/validation-engine.md).
