---
name: State Engine
description: Centralize project state ทั้งหมดใน .state/ folder — phase tracking, deliverables, JSONL audit trail, integrity check — ให้ทุก session เห็นสถานะเดียวกัน
---

# PMO Skill: State Engine

> **Purpose:** รวมศูนย์ state ของทุก project ไว้ที่เดียว
> ทุก session ที่เปิดมาใหม่ อ่าน state แล้วรู้ทันทีว่า project อยู่ phase ไหน ทำอะไรไปแล้ว

---

## 1. State Directory Structure

```
{ProjectFolder}/
└── .state/
    ├── project-state.json      <- Current phase, deliverables, blockers
    ├── audit-trail.jsonl        <- Append-only log ทุก action (tamper-evident)
    ├── cost-tracking.jsonl      <- Token usage per skill per session
    └── sessions/
        └── {session-id}.json    <- Per-session snapshot
```

---

## 2. project-state.json Schema

```json
{
  "project": "P07-PROJECT",
  "version": "2.0.0",
  "currentPhase": 7,
  "phaseLabel": "SystemFlow",
  "lastUpdated": "2026-04-03T10:30:00+07:00",
  "phases": {
    "1_meeting": { "status": "completed", "date": "2026-03-19" },
    "2_mom_transcript": { "status": "completed", "date": "2026-03-19", "momCount": 3 },
    "3_extract_reqs": { "status": "completed", "date": "2026-03-20", "reqCount": 45 },
    "4_userflow": { "status": "completed", "date": "2026-03-25", "fileCount": 12 },
    "5_validate_user": { "status": "completed", "date": "2026-03-28" },
    "6_usecase_qa": { "status": "completed", "date": "2026-03-30", "fileCount": 3 },
    "7_systemflow": { "status": "in_progress", "fileCount": 14, "draftCount": 2 },
    "8_wireframe": { "status": "pending" }
  },
  "deliverables": {
    "systemflow": ["BOF-SysF-01_GateMapping.puml", "..."],
    "userflow": ["BOF-UseF-01_GateMapping.puml", "..."],
    "usecase": ["UC-01_AuthAccessControl.puml"],
    "wireframe": [],
    "taskbreakdown": ["TaskBreakdown_v3.md"],
    "handoff": null,
    "scaffold": null
  },
  "blockers": [],
  "teamStatus": {
    "pm": "active",
    "dev": "waiting_for_handoff",
    "qa": "idle"
  },
  "totalSessions": 45,
  "totalTokensUsed": 0
}
```

---

## 3. audit-trail.jsonl Format

Append-only JSONL — แต่ละบรรทัดคือ 1 event:

```jsonl
{"ts":"2026-04-03T10:30:00+07:00","session":"S045","action":"created","target":"BOF-SysF-15_Report.puml","detail":"Module 15 Report flow","actor":"ai","skill":"pmo-activity-diagram"}
{"ts":"2026-04-03T10:35:00+07:00","session":"S045","action":"validated","target":"BOF-SysF-15_Report.puml","detail":"Post-gate score: 0.85 PASS","actor":"ai","skill":"pmo-quality-gate"}
{"ts":"2026-04-03T10:40:00+07:00","session":"S045","action":"decision","target":"Module 15","detail":"User approved flow without error handling","actor":"user","decisionId":"D055"}
```

---

## 4. cost-tracking.jsonl Format

```jsonl
{"ts":"2026-04-03T10:30:00+07:00","session":"S045","project":"P07-PROJECT","skill":"pmo-activity-diagram","model":"sonnet","inputTokens":1500,"outputTokens":3200}
```

---

## 5. Operations

### 5.1 State Read (ทุก session start)

เมื่อเริ่ม session ใหม่กับ project:
1. อ่าน `{ProjectFolder}/.state/project-state.json`
2. สรุปให้ user: "Project {code} อยู่ Phase {N}: {label}, ทำไปแล้ว {X} deliverables, มี {Y} blockers"
3. ถ้าไม่มี `.state/` → สร้างใหม่จากการ scan ไฟล์ใน project folder

### 5.2 State Write (ทุกครั้งที่มี change)

เมื่อ skill ใดๆ สร้าง/แก้/ลบ deliverable:
1. Update `project-state.json` (phase, deliverables, dates)
2. Append event ลง `audit-trail.jsonl`
3. Append cost ลง `cost-tracking.jsonl` (ถ้ามี token data)

### 5.3 State Init (project ใหม่)

เมื่อ `init-project.sh` รัน:
1. สร้าง `.state/` directory
2. สร้าง `project-state.json` ด้วย default values (phase 1, all pending)
3. สร้าง `audit-trail.jsonl` ว่าง
4. สร้าง `cost-tracking.jsonl` ว่าง

### 5.4 State Recovery

ถ้า `project-state.json` เสียหาย/หาย:
1. Rebuild จาก `audit-trail.jsonl` (replay events)
2. ถ้า audit-trail ก็หาย → scan files in project folder → infer state

---

## 6. Integration

- `pmo-quality-gate` Phase Gate อ่าน state เพื่อตรวจ prerequisites
- `pmo-dashboard` อ่าน state จากทุก project เพื่อแสดง overview
- `pmo-smart-router` อ่าน currentPhase เพื่อ context-aware routing
- `pmo-traceability` Activity Log ยังคงอยู่ — audit-trail.jsonl เป็น structured version เพิ่ม

---

## 7. State vs Traceability Matrix

| | State Engine (.state/) | Traceability Matrix (REQ_Traceability_Matrix.md) |
|---|---|---|
| **Format** | JSON/JSONL (machine-readable) | Markdown table (human-readable) |
| **Purpose** | AI ใช้ track progress อัตโนมัติ | คน/ลูกค้าใช้ดู audit trail |
| **Update** | Automatic ทุก action | Manual + automatic |
| **Cross-session** | อ่าน state ทันที | ต้อง parse markdown |

**ทั้งสองระบบ complement กัน — ไม่ได้แทนที่กัน**
