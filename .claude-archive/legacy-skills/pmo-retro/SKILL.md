---
name: Retrospective
description: สรุป Sprint Retrospective อัตโนมัติจาก Decision Log + Activity Log + TaskBoard — วิเคราะห์ rework rate, bottlenecks, positive patterns
---

# PMO Skill: Retrospective

> **Purpose:** PM พิมพ์ "retro" → AI สรุป sprint retrospective ให้

---

## 1. Data Sources

| Source | ข้อมูล |
|--------|-------|
| `.state/audit-trail.jsonl` | Actions ทั้ง sprint |
| `REQ_Traceability_Matrix.md` | Decision/Change/Activity Log |
| `TaskBoard.md` | Card lifecycle, rework count |
| `.state/cost-tracking.jsonl` | Token usage |

---

## 2. Output

```markdown
# Sprint Retrospective — P{XX}-{CODE}
**Period:** {start} — {end}

## What Went Well
- UserFlow validated in 1 round
- Security scan caught 3 critical before deploy

## What Needs Improvement
- Module 05: 3 rounds rework (unclear MOM#2 rule)
- QA backlog grew — only 1 tester

## Action Items
| # | Action | Owner | Deadline |
|---|--------|-------|----------|
| 1 | Clarify rules before complex modules | PM | Next sprint |
| 2 | Add 2nd QA resource | PM | Next sprint |

## Metrics
| Metric | Value |
|--------|-------|
| Cards Completed | 8/12 |
| Avg Time/Card | 3.2 days |
| Rework Rate | 25% |
| Quality Gate 1st Pass | 85% |
```

---

## 3. Analysis Logic

- **Rework:** Card QA Failed→Dev = rework, Diagram edited >2x after finalize
- **Bottleneck:** Card stuck >3 days, Phase gate blocked >2x
- **Positive:** QA pass 1st round, Quality Gate >= 0.8 first attempt
