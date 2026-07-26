# Artifact map

Which document plays which role, and what it maps to in conventional software documentation vocabulary.

Axiom-PMO deliberately uses short names for artifacts rather than industry acronyms. This page is the translation, for teams arriving with an SRS/FSD/Tech-Spec habit.

---

## The map

| Artifact | Conventional name | Answers | Required at |
|---|---|---|---|
| `PROJECT.md` | SRS-lite | What must the system do, and where did each requirement come from? | Scope |
| `DESIGN/FLOW.puml` | Functional flow | How does the actor move through the system? | Design |
| `DESIGN/WIREFRAME.md` | FSD / UX specification | What does the user see and interact with? | Design (UI work) |
| `DESIGN/BUILD-SPEC.md` | Technical specification | What will be built, and how does it behave at the boundaries? | Handoff (Standard, Strict) |
| `DELIVERY.md` | Work breakdown | What are the units of work, who owns each, what is its status? | Scope |
| `HANDOFF.md` | Developer entry point | What do I build first, who do I ask, what would stop the demo? | Handoff |
| `HANDOFF-REVIEW.json` | Readiness evidence | Did someone read this for sense, what did they find, and is it still current? | Handoff (Standard, Strict) |
| `RELEASE.md` | QA / release evidence | Was it tested, approved, and can it be rolled back? | Release |
| `RAID-log.md` | Risk register | What could go wrong, what are we assuming? | Strict, or when real risks exist |
| `decision-log.md` | Decision record | What did we decide, why, and who decided it? | Strict, or when real decisions exist |
| `RTM.json` | Traceability matrix | Can every requirement be traced to delivery, test, and release? | Strict Release |

The exact Mode × Gate matrix lives in [`pmo-config/artifact-policy.json`](../../pmo-config/artifact-policy.json). That file is the authority; this table is orientation.

---

## The distinction people get wrong

**`PROJECT.md` and `DESIGN/BUILD-SPEC.md` are not the same document at different levels of detail.**

`PROJECT.md` states what the system must do, traced to a source. It is the record of what was agreed, and it is written in the customer's vocabulary. Its audience is anyone who needs to know what was promised.

`DESIGN/BUILD-SPEC.md` states what will be built. Stack, data model with units and cardinality, transaction boundaries, concurrency, error states, seed data, acceptance cases. Its audience is the person writing the code, and the person who will have to run it on a specific device on a specific day.

A requirement says "a user can record stock consumed from a part's on-hand count." A build spec says the count is a whole number of pieces, cannot go below zero, and that the read-check-write happens inside one transaction because two people share the tablet.

Conflating them is how a project ends up with an approved requirement and a data model that cannot express it.

**`DELIVERY.md` and `HANDOFF.md` are also different.**

`DELIVERY.md` is the board: one row per unit of work, with owner and status. It answers "what is the state of the work?"

`HANDOFF.md` is the entry point: build order, dependencies, hard constraints, demo milestone, blocking points. It answers "what do I do first, and what would stop us?" Work-item numbering is not build order, and the difference between those two is exactly what `HANDOFF-004` exists to catch.

---

## Reading order for a new developer

1. `HANDOFF.md` — start here. Build order, owners, constraints, what is deferred.
2. `DESIGN/BUILD-SPEC.md` — the technical contract for the first item in the sequence.
3. `PROJECT.md` — the requirement behind it, and its source.
4. `DESIGN/FLOW.puml` and `DESIGN/WIREFRAME.md` — the behaviour and the screens.
5. `DELIVERY.md` — the board, for status.
6. `HANDOFF-REVIEW.json` — what a reviewer already found, and what is still open.

If step 1 does not exist, the project has not reached the Handoff gate and there is nothing to start from.

---

## Legacy folder mapping

Older projects predate this shape and remain valid:

| Legacy | Current |
|---|---|
| `MOM/`, `REQ/`, `Others/` | `source/` |
| `UserFlow/`, `SystemFlow/`, `UseCase/` | `DESIGN/` |
| `Wireframe/` | `DESIGN/WIREFRAME.*` |
| `TaskBreakdown/` | `DELIVERY.md` or GitHub Issues |
| *(no equivalent)* | `HANDOFF.md`, `DESIGN/BUILD-SPEC.md` |

The last row is the point of v1.1: there was no legacy artifact that answered "can a developer start on Monday?", which is why the question kept being answered in a meeting instead of in a document.

---

## Ownership

`source/`, `MOM/`, `REQ/`, `Transcript/`, and `Others/` are **user-owned**. The framework reads them and never writes to them. Everything else in the table above is **governed** — generated, validated, and edited under the rules in [`AGENTS.md`](../../AGENTS.md).
