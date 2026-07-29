# Decision Log - HANDOFF-DEMO

| ID | Decision | Rationale | Source Ref | Date | Decided By |
|---|---|---|---|---|---|
| DEC-001 | Scope approved for the four in-scope requirements. | Matches the sponsor's demo ask. | MOM-20260714 item 1 | 2026-07-14 | Demo PO |
| DEC-002 | Design approved; flow and wireframe cover scan, adjust, and photo. | Reviewed against REQ-20260714. | REQ-20260714 row 1 | 2026-07-15 | Demo Tech Lead |
| DEC-003 | Part photos are classified internal-only and are purged on demo reset. | Sponsor asked that photos not leave the site network; the demo dataset is disposable. | MOM-20260714 item 5 | 2026-07-15 | Demo Tech Lead |
| DEC-004 | Multi-warehouse stock is deferred; the demo covers a single site. | Not required for the 2026-08-05 demonstration. | MOM-20260714 item 1 | 2026-07-15 | Demo PO |
| DEC-005 | The scanner page is served over HTTPS from a local reverse proxy with a trusted certificate. | The rear camera is unavailable to a page served over plain HTTP on the sponsor's tablet. | MOM-20260714 item 2 | 2026-07-15 | Demo Tech Lead |
| DEC-006 | Photo capture is deferred to the pilot; the demo attaches a pre-existing file. | Keeps the camera dependency to the scanner path only. | MOM-20260714 item 5 | 2026-07-16 | Demo Tech Lead |
