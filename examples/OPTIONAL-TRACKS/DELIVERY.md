# DELIVERY - OPTIONAL-TRACKS

## Delivery Mode

- Mode: Standard
- Task source of truth: `file`
- Mode owner: Demo PM / Demo Tech Lead
- Current status set: `To Do`, `In Progress`, `Review / Test`, `Done`

## Work Items

| ID | Mode | Strict Trigger | Mode Reason | Mode Approved By | Feature / Deliverable | Requirement Ref | Design Ref | Acceptance Criteria | Test Checklist | Owner | Priority | Status | Review Stage | Evidence Ref | Labels |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| D-001 | Standard | none | shared prerequisite | Demo PM | Part master and stock schema | REQ-002, BR-001 | DESIGN/BUILD-SPEC.md | Part and stock entities exist with whole-piece quantities | Schema migration, constraint | R. Silva | high | To Do | none | DEC-002 | |
| D-002 | Standard | none | normal feature | Demo PM | Scan to find a part | REQ-001 | DESIGN/FLOW.puml, DESIGN/WIREFRAME.md WF-001 | Scanning a printed code opens the matching part | Happy, unknown code | K. Owusu | high | To Do | none | DEC-002 | |
| D-003 | Standard | none | normal feature | Demo PM | Consume and receive stock | REQ-002, REQ-003, BR-001 | DESIGN/FLOW.puml, DESIGN/WIREFRAME.md WF-002 | On-hand count moves both directions and never goes below zero | Happy, boundary at zero, concurrent | R. Silva | high | To Do | none | DEC-002 | |
| D-004 | Standard | none | normal feature | Demo PM | Attach a photo to a part | REQ-004, BR-002 | DESIGN/WIREFRAME.md WF-003 | A photo file can be attached and viewed on the part record | Happy, oversized file | K. Owusu | medium | To Do | none | DEC-003 | |
