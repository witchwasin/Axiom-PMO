---
name: Standup
description: สรุป Daily Standup อัตโนมัติจาก TaskBoard + State Engine + Activity Log — PM ไม่ต้องเขียนเอง
---

# PMO Skill: Standup

> **Purpose:** PM พิมพ์ "standup" → AI สรุป daily standup ให้ทันที

---

## 1. Data Sources

| Source | ข้อมูล |
|--------|-------|
| `.state/project-state.json` | Phase, deliverables |
| `.state/audit-trail.jsonl` | Actions ล่าสุด 24 ชม. |
| `REQ_Traceability_Matrix.md` | Activity/Decision Log |
| `TaskBoard.md` | Card statuses, blockers |

---

## 2. Output

```markdown
# Daily Standup — P{XX}-{CODE}
**Date:** {date} | **Phase:** {N}. {label}

## Done
- [Card M01] Module 01 — Dev Done, QA Testing
- Validated BOF-SysF-14 (PASS 0.92)

## In Progress
- [Card M03] Module 03 — Dev 60%
- Creating SystemFlow Module 15

## Blockers
- (none)

## Next Steps
- Finalize Module 15
- Start Wireframe phase

## Stats
Cards: 5 Done / 3 In Progress / 8 Total
Phase: 87% complete
```

Multi-project: "standup ทุก project" → สรุปทุก Active project ในหน้าเดียว
