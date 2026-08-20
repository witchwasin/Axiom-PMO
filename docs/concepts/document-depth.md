# Mode-Scaled Specification Depth

Axiom-PMO was designed around the principle that governance scales with risk:
small fixes require lightweight process, while high-risk features require rigorous
controls. However, early versions of the framework made an important structural
mistake:

> **Mode scaled artifact breadth, never artifact depth.**

This document explains why artifact presence alone is insufficient for high-risk
governance, and how Axiom-PMO enforces specification depth deterministically.

---

## The Breadth-vs-Depth Problem

In traditional risk-mode designs, escalating from `Standard` to `Strict` only
added **more files to the required list** (`RAID-log.md`, `decision-log.md`,
`RTM.json`). But nothing governed **how much was inside them**.

When evaluated against high-risk real-world projects touching PII, payment
calculations, or life-safety emergency SLAs, a project could pass the Handoff gate
with:
- 12 scoped requirements,
- only 5 shallow acceptance cases covering 6 requirements,
- 0 non-functional requirements (NFRs),
- no entity relationship or data flow definitions, and
- an RTM claiming `status: verified` before any code was written or tested.

Because the validator only verified that files existed and headers matched, the
governance control plane gave a false sense of security (`PASS=39 FAIL=0`) to an
engineering pack that was severely underspecified.

---

## Prompts vs Deterministic Validation

`docs/concepts/anti-hallucination.md` establishes the governing rule:

> An instruction in a prompt is advisory: the agent can ignore or misreport it.
> A control is enforced by a validator that exits non-zero.

Telling an AI agent to "write more comprehensive test cases in Strict mode" does
not work. Depth must be a **validated declaration**, derived mathematically from
the project's own declared specification elements.

---

## The Specification Depth Architecture

Axiom-PMO 2.3.0 introduces a centralized depth policy
(`pmo-config/depth-policy.json`), keyed by the same three profile names
`pmo-config/orchestration-policy.json` `testability` declares (the mode-to-profile
mapping is fixed and lives directly in the validator, since Strict never needs a
profile other than `detailed_requirement_and_risk_cases`):

| Profile | Mode | Depth Expectation |
|---|---|---|
| `delivery_checklist` | Lite | Basic happy-path verification per requirement |
| `strategy_and_scenarios` | Standard | Happy + negative cases per requirement, business rule, API operation, and state transition |
| `detailed_requirement_and_risk_cases` | Strict | Multi-dimensional coverage across requirements, NFRs, constraints, state transitions, journeys, and strict risk triggers |

### Derived Depth Matrix

Rather than imposing an arbitrary fixed number (e.g. "Strict requires 50 test cases",
which an agent easily games by writing 50 trivial lines), the required test volume
is **derived from the project's own declared specification units**:

```
Total Required Cases = ∑ (Declared Elements × Required Categories for Profile)
```

Spec elements include:
- Requirements (`REQ-###`)
- Business Rules (`BR-###`)
- Non-Functional Requirements (`NFR-###`)
- Data Constraints (`Constraint ID`)
- API Operations (`Operation ID`)
- State Transitions (`Transition ID`)
- Journey Steps (`Step ID`)
- Strict Triggers (`strict_trigger`)

For a standard Strict project with 12 requirements, 5 business rules, 8 NFRs,
25 data constraints, 5 API operations, and 7 state transitions, the matrix naturally
demands ~180+ individually addressable, categorized test cases across happy,
negative, boundary, security, concurrency, and recovery dimensions.

---

## Handoff Readiness: The Four Engineering Questions

At the Handoff gate, an engineering lead must be able to answer four critical
questions **from the artifacts alone**:

1. **What stack do we use, and why?**
   Answered by governed Technology Decisions (`BUILD-SPEC.md`), with alternatives,
   trade-offs, and resolvable `DEC-###` decision references.
2. **How do entities relate?**
   Answered by Entity Relationships (`BUILD-SPEC.md`) and `DESIGN/ERD.puml`.
3. **How do frontend and backend stay in sync?**
   Answered by `DESIGN/API/openapi.yaml` and the governed API Operation table.
4. **What does "done" mean?**
   Answered by the derived `TESTS/` coverage matrix and the `HANDOFF.md` Definition of Done.

---

## Backward Compatibility & Opt-in Gate

To ensure existing projects and golden fixture suites continue to pass without
unintended regressions, specification depth is gated via `PROJECT.md` declarations:

```markdown
> Spec depth: legacy       # existing projects; new rules stay silent
> Spec depth: full         # enforces SRS, FSD depth, and the derived test matrix
```

`node cli/axiom.mjs init` scaffolds `Spec depth: full` by default; pass
`--spec-depth legacy` to opt a new project out. Any project created before this
declaration existed has no `Spec depth` line and is treated as `legacy`
automatically — it is unaffected by every rule this document describes until
someone deliberately adds the line.

---

## See Also

- [Risk-Adaptive Modes](risk-modes.md)
- [Anti-Hallucination Controls](anti-hallucination.md)
- [Handoff Readiness](handoff-readiness.md)
- [Validation Engine Architecture](../architecture/validation-engine.md)
