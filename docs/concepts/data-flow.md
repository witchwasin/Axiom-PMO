# Data Flow, Dictionary, and Journeys

Under `Spec depth: full`, three artifacts answer three separate questions about
data that `DESIGN/BUILD-SPEC.md`'s Data Model table alone cannot:

| Artifact | Question it answers |
|---|---|
| `DESIGN/DATA-DICTIONARY.md` | For each field, who is allowed to see it, and does that agree with the Security/Privacy Inventory? |
| `DESIGN/DATA-FLOW.md` | What is the exact sequence of steps, actors, and state changes a tester walks through? |
| `DESIGN/ERD.puml` | How do the entities relate to each other? |

They are deliberately three separate files because they answer three separate
questions a single Data Model table conflates: a flat attribute list has no
relationship graph, no PII-classification join, and no ordered journey.

## Data Dictionary — the join that did not exist before

`BUILD-SPEC.md` already carries two tables that describe data: the **Data
Model** (entity, attribute, type, unit, cardinality, constraint) and the
**Security, Privacy and Data Inventory** (data element, sensitivity,
classification decision, retention decision). Nothing bound them together by
key — a reviewer had to manually cross-reference "does this attribute appear
in the sensitive-data table, correctly?"

`DESIGN/DATA-DICTIONARY.md` is that join, one row per field:

```
| Field ID | Entity | Attribute | Type | Unit | Allowed Values | Classification | Source of Record | Enters At | Leaves At | Transformation | Retention | Masking | Source Ref |
```

Two rules enforce it:

- **`DATAFLOW-001`** — every attribute declared in `BUILD-SPEC.md`'s Data Model
  table must appear in the dictionary.
- **`DATAFLOW-002`** — a field the dictionary marks sensitive must agree with
  `BUILD-SPEC.md`'s Security/Privacy Inventory; a disagreement (dictionary says
  sensitive, inventory says no, or the reverse) fails.

## Journeys — the thing a tester actually follows

`DESIGN/DATA-FLOW.md`'s End-to-End Journeys table is what a QA engineer walks
through to exercise the system, not just its individual endpoints:

```
| Step ID | Journey | Actor | Trigger | Data In | System Action | Data Out | State Before | State After | Observable Result | Spec Element Ref |
```

- **`JOURNEY-001`** — every step's `State Before` / `State After` must resolve
  to a state or `Transition ID` declared in `BUILD-SPEC.md`'s State Machine
  table. A journey that references a state the state machine never declared
  is describing behavior the system does not actually have.
- **`JOURNEY-002`** (Strict only) — every scoped requirement must be reachable
  from at least one journey step. A requirement nobody can walk through in a
  journey is a requirement nobody can demo.

## ERD — structure, not flow

`DESIGN/ERD.puml` is a PlantUML entity-relationship diagram, generated
alongside `BUILD-SPEC.md`'s Entity Relationships table
(`| Relationship ID | From Entity | To Entity | Cardinality | FK Field | Required | On Delete |`,
checked by `DATA-003`/`DATA-004`) and distinct from `DESIGN/DATA-FLOW.puml`'s
data-flow diagram — one shows what the data *is*, the other shows how it
*moves*. Like `FLOW.puml`, no validator parses its content; it is generated as
part of the handoff pack and reviewed by a human alongside the table it
illustrates.

## See Also

- [document-depth](document-depth.md)
- [handoff-readiness](handoff-readiness.md)
