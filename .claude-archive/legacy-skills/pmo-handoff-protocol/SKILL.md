---
name: Handoff Protocol
description: Standardize การส่งต่องานระหว่าง roles (PM→Dev, Dev→QA, QA→PM) — auto-generate handoff doc, validate context ครบก่อนส่งต่อ, notify ฝ่ายรับ
---

# PMO Skill: Handoff Protocol

> **Purpose:** ทุกครั้งที่ส่งต่องาน ต้องมี "handoff document" กลาง
> ป้องกัน "ส่งงานแล้วขาด context" หรือ "ถามซ้ำเรื่องเดิม"

---

## 1. Handoff Types

| Type | From → To | Trigger |
|------|-----------|---------|
| **PM → Dev** | PM ส่ง spec ให้ Dev | Card status: Backlog → Assigned |
| **Dev → QA** | Dev ส่งงานที่ทำเสร็จ | Card status: In Progress → Dev Done |
| **QA → Dev** | QA ส่ง bug กลับ Dev | Card status: QA Testing → QA Failed |
| **QA → PM** | QA ส่งผลผ่านให้ PM review | Card status: QA Testing → QA Passed |
| **PM → Client** | PM ส่ง deliverable ให้ลูกค้า | Card status: QA Passed → Client Review |
| **PM → DevOps** | PM ส่ง infra spec ให้ DevOps | Phase: Ready for deployment |

---

## 2. Handoff Document Template

### 2.1 PM → Dev Handoff

```markdown
# Handoff: PM → Dev
**Card:** {card-id}
**Module:** {module-name}
**Date:** {date}
**Deadline:** {deadline}

## Scope
- {summary of what to build}

## Reference Files
- SystemFlow: `{path-to-puml}`
- Wireframe: `{path-to-wireframe}` (ถ้ามี)
- TaskBoard: `{path-to-taskboard}#Card-{id}`

## Test Cases (from TaskBoard)
| # | Type | Description |
|---|------|-------------|
| 1 | Happy | {test case} |
| 2 | Alt   | {test case} |
| 3 | Exc   | {test case} |

## Business Rules (from MOM)
- {rule 1} [Ref: MOM#{X}]
- {rule 2} [Ref: MOM#{X}]

## Notes
- {additional context from PM}

## Acceptance Criteria
- [ ] ผ่าน test cases ครบทุกข้อ
- [ ] Code ตรงกับ SystemFlow
- [ ] Coding Standards ตาม CODING-STANDARDS.md
```

### 2.2 Dev → QA Handoff

```markdown
# Handoff: Dev → QA
**Card:** {card-id}
**Module:** {module-name}
**Date:** {date}
**Dev:** {dev-name}

## What was implemented
- {summary}

## Files Changed
- `{file1}` — {what changed}
- `{file2}` — {what changed}

## How to Test
- {setup instructions}
- {test URL / command}

## Known Limitations
- {anything QA should know}

## Test Cases to Run
(copy from TaskBoard Card)
```

### 2.3 QA → Dev (Bug Report)

```markdown
# Bug Report: QA → Dev
**Card:** {card-id}
**Bug ID:** {bug-id}
**Severity:** Critical / Major / Minor
**Date:** {date}

## Steps to Reproduce
1. {step 1}
2. {step 2}
3. {step 3}

## Expected Result
- {what should happen}

## Actual Result
- {what actually happened}

## Screenshot / Evidence
- {path or description}

## Related Test Case
- #{test-case-number} from TaskBoard
```

---

## 3. Context Validation (Pre-Handoff Gate)

ก่อนส่งต่อ ต้องตรวจว่า context ครบ:

| Handoff Type | Required Context | ถ้าขาด |
|-------------|-----------------|--------|
| PM → Dev | SystemFlow + Test Cases + Business Rules | BLOCK — "ยังขาด {X}" |
| Dev → QA | Files Changed + How to Test + Test Cases | WARN — "Dev ยังไม่ได้ระบุ {X}" |
| QA → Dev | Steps to Reproduce + Expected vs Actual | BLOCK — "QA ต้องระบุ {X}" |
| QA → PM | All test results + Pass/Fail summary | BLOCK — "QA ยังไม่ได้รายงานครบ" |

---

## 4. Auto-Generate Behavior

เมื่อ card status เปลี่ยน (trigger จาก `pmo-team-orchestrator`):

1. **Detect** handoff type จาก status change
2. **Gather** context จาก TaskBoard, SystemFlow, Traceability Matrix
3. **Validate** context ครบตาม Pre-Handoff Gate
4. **Generate** handoff document
5. **Log** handoff event ลง Activity Log + audit-trail.jsonl
6. **Notify** ฝ่ายรับ: "คุณได้รับ handoff สำหรับ Card {X}"

---

## 5. Handoff History

ทุก handoff ถูก log ใน State Engine audit trail:

```jsonl
{"ts":"2026-04-03T14:00:00+07:00","action":"handoff","from":"PM","to":"Dev","card":"P07-M01-001","type":"pm-to-dev","contextValid":true}
```

PM สามารถดู handoff history ผ่าน `pmo-dashboard` detail view

---

## 6. Integration

- `pmo-team-orchestrator` trigger handoff เมื่อ status เปลี่ยน
- `pmo-taskboard` เป็น source ของ test cases + card info
- `pmo-traceability` log handoff เป็น Activity Log entry
- `pmo-state-engine` track handoff ใน audit-trail.jsonl
- `pmo-quality-gate` validate context ก่อน handoff (pre-handoff gate)
