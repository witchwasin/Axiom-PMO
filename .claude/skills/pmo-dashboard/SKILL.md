---
name: Dashboard
description: แสดงสถานะทุก project ใน 1 หน้า — phase, progress, blockers, team status — ให้ PM เห็นภาพรวมทันที
---

# PMO Skill: Dashboard

> **Purpose:** PM พิมพ์ "สถานะ" หรือ "dashboard" → เห็นทุก project ในภาพเดียว
> ไม่ต้องเปิดทีละ project

---

## 1. Dashboard Output Format

```
╔══════════════════════════════════════════════════════════════╗
║                  PMO Dashboard — 2026-04-03                  ║
║                  16 Projects | 8 Active                      ║
╠══════════════════════════════════════════════════════════════╣

 Project         Phase              Progress   Blockers   Team
 ─────────────── ────────────────── ────────── ────────── ──────
 P07-PROJECT      7. SystemFlow      ████████░░  0         PM
 P03-PROJECT 8. Wireframe       █████████░  1         PM+Dev
 P13-RR-EWALLET  3. Extract REQs    ████░░░░░░  0         PM
 P09-HRM         4. UserFlow        █████░░░░░  0         PM
 P10-PROJECT 7. SystemFlow    ███████░░░  0         Dev
 P12-PROJECT   4. UserFlow        ████░░░░░░  2         PM
 P16-PROJECT         2. MOM/Transcript  ██░░░░░░░░  0         PM
 P14-EX-SHABU    RELEASED v1.0.0    ██████████  0         Dev

 ────────────────────────────────────────────────────────────
 Legend: PM=Planning | Dev=Development | QA=Testing
```

---

## 2. Data Sources

Dashboard อ่านจาก 2 แหล่ง:

### 2.1 State Engine (preferred)
ถ้า project มี `.state/project-state.json`:
- อ่าน currentPhase, deliverables count, blockers, teamStatus

### 2.2 File Scan (fallback)
ถ้า project ไม่มี `.state/`:
- Scan folders (SystemFlow/, UserFlow/, UseCase/, Wireframe/, TaskBreakdown/)
- Count files + check for [DRAFT] in titles
- Infer phase from which folders have content

---

## 3. Detail View

เมื่อ user ถามเจาะลึก project ใดๆ:

```
╔══════════════════════════════════════════════════════════════╗
║  P07-PROJECT — RR Access Control                             ║
╠══════════════════════════════════════════════════════════════╣

 Phase: 7. SystemFlow (In Progress)

 Deliverables:
   SystemFlow    14 files (12 Final, 2 Draft)
   UserFlow      12 files (12 Final)
   UseCase        3 files (3 Final)
   Wireframe      0 files
   TaskBreakdown  1 file (v3)
   Handoff        Not started
   Scaffold       Not started

 Recent Activity (last 5):
   2026-04-03  Created BOF-SysF-15_Report.puml
   2026-04-03  Validated BOF-SysF-14_AccessRights.puml (PASS)
   2026-04-01  Updated P07 Timeline v5
   2026-04-01  Decision D055: No Log for CRUD Modules
   2026-03-30  Created UC-01_AuthAccessControl.puml

 Blockers: None

 Next Steps:
   1. Finalize 2 remaining DRAFT SystemFlows
   2. Start Wireframe (Phase 8)
   3. Create Dev Handoff Package
```

---

## 4. Filters

| Command | Result |
|---------|--------|
| "dashboard" / "สถานะทุก project" | แสดงทุก project |
| "dashboard active" | แสดงเฉพาะ In Progress |
| "dashboard P07" | Detail view ของ P07 |
| "dashboard blockers" | แสดงเฉพาะ project ที่มี blockers |
| "dashboard dev" | แสดงเฉพาะ project ที่อยู่ phase Dev/QA |

---

## 5. Workflow

1. **Scan** ทุก project folder ใน repo root (P01-*, P02-*, ...)
2. **อ่าน** `.state/project-state.json` ของแต่ละ project (ถ้ามี)
3. **Fallback** scan files ถ้าไม่มี state
4. **Format** output ตาม template
5. **แสดง** ผู้ใช้

ไม่ต้อง log Activity Log (read-only operation)
