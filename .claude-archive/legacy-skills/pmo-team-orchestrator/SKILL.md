---
name: Team Orchestrator
description: Coordinate PM/Dev/QA agents แบบ Pipeline Pattern — auto-route งานตาม role, ส่งต่ออัตโนมัติเมื่อ status เปลี่ยน, track progress ทุก handoff
---

# PMO Skill: Team Orchestrator

> **Purpose:** ยกระดับ PM-Dev-QA loop (WF-A/B/C) ให้เป็น automated pipeline
> ดึง concept จาก external execution-framework agent coordination patterns

---

## 1. Coordination Patterns

### 1.1 Pipeline Pattern (Default สำหรับ PMO)

```
PM Agent ──→ Dev Agent ──→ QA Agent ──→ PM Agent (Review)
  │             │             │             │
  │ แตก Card    │ Implement   │ Test        │ Client Review
  │ + Handoff   │ + Report    │ + Report    │ + Close Card
  ↓             ↓             ↓             ↓
TaskBoard    Dev Report    QA Report    Done
```

### 1.2 Parallel Pattern (สำหรับงานเร่ง)

```
         ┌──→ Dev Agent (Module A) ──→ QA ──┐
PM Agent ├──→ Dev Agent (Module B) ──→ QA ──┤──→ PM Review
         └──→ Dev Agent (Module C) ──→ QA ──┘
```

### 1.3 Review Pattern (สำหรับ quality-critical)

```
PM Agent ──→ Dev Agent ──→ Code Review ──→ QA Agent ──→ PM Review
                              │
                              └──→ Security Review (ถ้า FinTech)
```

---

## 2. Agent Roles & Capabilities

| Agent Role | ทำอะไรได้ | Skills ที่ใช้ |
|-----------|---------|--------------|
| **PM Agent** | แตก Card, assign, validate deliverables, client review | `pmo-taskboard`, `pmo-quality-gate`, `pmo-dashboard` |
| **Dev Agent** | รับ spec, implement, report, ถามเรื่อง flow | `pmo-dev-report`, `pmo-code-scaffold`, `pmo-coding-standards` |
| **QA Agent** | รับ test cases, test, report results, file bugs | `pmo-qa-report`, `pmo-deploy-checklist` |
| **DevOps Agent** | Setup CI/CD, deploy, monitor | `pmo-ci-cd-template`, `pmo-infra-spec`, `pmo-deploy-checklist` |

---

## 3. Auto-Dispatch Rules

เมื่อ status เปลี่ยนใน TaskBoard → auto-dispatch ไปหา agent ที่เหมาะ:

| Card Status Change | Dispatch To | Auto Action |
|-------------------|------------|-------------|
| Backlog → Assigned | Dev Agent | แจ้ง: "คุณได้รับ Card {X} แล้ว" + สรุป spec |
| In Progress → Dev Done | QA Agent | แจ้ง: "Card {X} พร้อม test" + link test cases |
| QA Testing → QA Passed | PM Agent | แจ้ง: "Card {X} ผ่าน QA" + สรุปผล |
| QA Testing → QA Failed | Dev Agent | แจ้ง: "Card {X} ไม่ผ่าน" + bug details |
| Client Review → Done | All | แจ้ง: "Card {X} close แล้ว" |

---

## 4. Context Passing Protocol

เมื่อส่งต่องานระหว่าง agents ต้องส่ง context:

```json
{
  "handoff": {
    "from": "PM Agent",
    "to": "Dev Agent",
    "card": "P07-M01-001",
    "module": "Module 01: Gate Mapping",
    "artifacts": [
      "SystemFlow/BOF-SysF-01_GateMapping.puml",
      "TaskBoard.md#Card-M01-001"
    ],
    "testCases": 5,
    "deadline": "2026-04-10",
    "notes": "ดู MOM#2 สำหรับ business rule เรื่อง gate status"
  }
}
```

---

## 5. Team Status Tracking

State Engine `.state/project-state.json` field `teamStatus`:

```json
{
  "teamStatus": {
    "pm": { "status": "active", "currentTask": "Reviewing Module 05" },
    "dev": { "status": "implementing", "currentCard": "P07-M03-001", "progress": "60%" },
    "qa": { "status": "testing", "currentCard": "P07-M01-001", "testsPassed": "3/5" },
    "devops": { "status": "idle" }
  }
}
```

---

## 6. Escalation Rules

| Condition | Action |
|-----------|--------|
| Dev stuck > 2 days on same card | Notify PM + suggest breaking card into smaller tasks |
| QA finds > 3 bugs on same card | Escalate to PM for scope review |
| Card blocked by external dependency | Flag to PM + suggest workaround or re-prioritize |
| No response from agent > 1 day | Reminder notification |

---

## 7. Workflow

1. **อ่าน** TaskBoard + State Engine เพื่อดูสถานะ
2. **Detect** status changes หรือ user request
3. **Dispatch** งานไปหา agent ที่เหมาะ พร้อม context
4. **Track** progress ผ่าน State Engine
5. **Escalate** ถ้าเจอ blockers
6. **Log** ทุก dispatch + handoff ลง audit-trail.jsonl

---

## 8. Integration

- ต่อจาก `pmo-taskboard` — ใช้ card status เป็น trigger
- ต่อจาก `pmo-handoff-protocol` — ใช้ protocol เดียวกันสำหรับ context passing
- ต่อจาก `pmo-state-engine` — read/write team status
- ต่อจาก `pmo-agent-orchestration` — persona system ยังใช้ได้ (Lead, Analyst, Architect, Writer, Reviewer, Security)
