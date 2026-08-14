# RESEARCH - OPTIONAL-TRACKS

> Research is optional, happens before Scope approval, and is never authority.
> Every material claim maps to a source in `RESEARCH/PROVENANCE.json`. An
> AI-drafted conclusion cannot change Scope on its own; only a traceable Human
> decision at Scope can do that.

## Research Status and Scope

Status: complete

Guided research before Scope approval for the warehouse stock-take demo:
whether a single-site demo needs multi-warehouse stock, and what the photo
attachment flow implies for data handling. Multi-warehouse stock and photo
retention are deliberately out of research scope beyond the two questions
above.

## Problem and Research Questions

The sponsor asked for a stock-take demo on a workshop tablet. Two questions
needed evidence before Scope could be approved: (1) is multi-warehouse stock
required for the demonstration, and (2) does attaching a photo to a part imply
data that must not leave the site network?

## Existing Solutions

The existing part master and scanner flow cover stock consumption only; there
is no receive operation and no photo attachment path today. See RC-001.

## Feature Parity

The demo must match the current single-site stock model exactly; no existing
capability is removed.

## Relevant Standards and Regulations

None beyond the sponsor's stated network boundary for photos. See RC-002.

## Differentiation and Value Implications

Deferring multi-warehouse stock keeps the demo single-site (matching the
sponsor's ask) and lets the team ship the scan/photo path first. Photo data
stays on the site network, which matches the sponsor's constraint.

## Risks and Unknowns

| Risk / Unknown | Impact | Source Ref | Status |
|---|---|---|---|
| Tablet availability before demo day | demo cannot run | MOM-20260714 item 2 | open |
| Camera requires a secure serving context | scan flow blocked on plain HTTP | MOM-20260714 item 2 | mitigated |

## Impact Assessment

| Finding Ref | Maps To | Proposed Impact | Status |
|---|---|---|---|
| RC-001 | Scope (REQ-003 receive) | receive is a first-class operation | accepted |
| RC-002 | BR-002 (photo network boundary) | photos stay internal-only | accepted |

## Change Proposals

| Proposal ID | Proposal | Impact | Accepted Impact | Status | Human Owner | Decision Ref |
|---|---|---|---|---|---|---|
| CP-001 | Defer multi-warehouse stock; demo covers a single site | scope | yes | accepted | Demo PO | DEC-004 |
| CP-002 | Photo attachments are internal-only and purged on reset | scope | yes | accepted | Demo Tech Lead | DEC-003 |

## Explicit Limits and Unanswered Questions

Research could not confirm tablet availability in writing; that remains an
open risk tracked in `RAID-log.md` (R-001). No provider-returned claim was
accepted without a Human decision at Scope.
