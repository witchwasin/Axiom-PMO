---
name: Workflow Architect
description: ค้นหาและออกแบบ workflow ของระบบอย่างครบถ้วน ก่อนที่จะสร้าง Activity Diagram — ครอบคลุม happy path, failure modes, handoff contracts, และ state transitions ต้อง load skill นี้เมื่อผู้ใช้พูดถึง "workflow", "flow ของระบบ", "ค้นหา flow", "วิเคราะห์ flow", "flow ที่ซ่อนอยู่", "failure mode", "handoff", "state transition", หรือเมื่อต้องการ map workflow ก่อนวาด diagram อย่างละเอียด
---

# PMO Skill: Workflow Architect (Discovery and Spec)

> **ความสัมพันธ์กับ skill อื่น:**
> - **pmo-activity-diagram** = สร้าง PlantUML Swimlane (visual output)
> - **pmo-workflow-architect (skill นี้)** = ค้นหาและออกแบบ flow ก่อนวาด (spec + discovery)
> - **ใช้ร่วมกัน:** Workflow Architect ก่อน → ส่งต่อ Activity Diagram ทำ .puml
>
> Load `references/discovery-checklist.md` สำหรับ checklist ค้นหา flow
> Load `references/handoff-template.md` สำหรับ template handoff contract
> Load `references/failure-modes.md` สำหรับ 7 failure modes ที่ต้องครอบคลุม

---

## 1. Skill นี้ทำอะไร — ไม่ทำอะไร

| ทำ (Workflow Architect) | ไม่ทำ (ส่งต่อ skill อื่น) |
|------------------------|--------------------------|
| ค้นหา workflow ที่ซ่อนอยู่ | วาด PlantUML diagram → ส่งต่อ `pmo-activity-diagram` |
| เขียน Workflow Spec (.md) | ตัดสินใจ implementation → Dev ตัดสินใจ |
| กำหนด handoff contract | ออกแบบ UI → ส่งต่อ `pmo-wireframe-design` |
| ระบุ failure modes + recovery | เขียน code |
| สร้าง Workflow Registry | ทำ Task Breakdown → ส่งต่อ `pmo-task-breakdown` |

---

## 2. ถามก่อนเสมอ (Pre-requisites)

| คำถาม | ทำไมต้องถาม |
|-------|------------|
| กำลังทำ **project ไหน**? | ดึงข้อมูลจาก folder ที่ถูกต้อง |
| ต้องการ **ค้นหา flow ใหม่** หรือ **spec flow ที่รู้แล้ว**? | กำหนดว่าเริ่มจาก discovery หรือ design |
| **Actors** มีกี่ตัว ชื่ออะไร? | ใช้ใน workflow spec |
| มี **diagram เดิม**อยู่แล้วไหม? | ถ้ามี ใช้เป็น baseline cross-check |

---

## 3. ขั้นตอนการทำงาน

### Step 1: Discovery — ค้นหา Workflow ที่ซ่อนอยู่

อ่านเอกสาร PMO ตามลำดับ:

| ลำดับ | อ่านอะไร | หาอะไร |
|:-----:|----------|--------|
| 1 | `REQ/` | ทุก feature = potential workflow entry point |
| 2 | `MOM/` ทุกฉบับ | Business rule, exception case, สิ่งที่ลูกค้าพูดแต่ไม่ได้อยู่ใน REQ |
| 3 | `MOM/Transcription/` | Requirement ที่ตกหล่นจาก MOM (Safety Net) |
| 4 | `SystemFlow/` (ถ้ามี) | Diagram เดิม — cross-check ว่าครบไหม |
| 5 | `Others/` | WBS, mockup, reference — หา implicit workflow |

สำหรับทุก requirement/feature ถามตัวเอง:
- **อะไร trigger flow นี้?** (user action, API call, scheduler, event)
- **อะไรเกิดขึ้นต่อ?** (sequence ของ steps)
- **อะไรเกิดขึ้นถ้า fail?** (failure mode + recovery)
- **ใครรับผิดชอบ clean up?**

ดู checklist เต็มที่ `references/discovery-checklist.md`

### Step 2: สร้าง Workflow Registry

สร้างตารางรวม workflow ทั้งหมดของ project:

```markdown
# Workflow Registry — {ProjectCode}

## Workflows

| Workflow | Spec file | Status | Trigger | Primary Actor |
|---------|-----------|--------|---------|--------------|
| User Login | WORKFLOW-user-login.md | Draft | User clicks login | Frontend |
| Payment | WORKFLOW-payment.md | Missing | Order confirmed | Payment Gateway |
| Admin Approve | WORKFLOW-admin-approve.md | Missing | New request | Admin |
```

**Status:** `Approved` | `Draft` | `Missing` | `Deprecated`
**Missing = อยู่ใน MOM/REQ แต่ยังไม่มี spec** — ต้อง flag ทันที

### Step 3: เขียน Workflow Spec ทีละ flow

ใช้ template นี้สำหรับแต่ละ workflow:

```markdown
# WORKFLOW: [ชื่อ Flow]
**Version:** 0.1
**Date:** YYYY-MM-DD
**Status:** Draft
**Ref:** MOM#X - [หัวข้อ], REQ item [#]

---

## Overview
[2-3 ประโยค: flow นี้ทำอะไร, ใครเป็นคน trigger, ผลลัพธ์คืออะไร]

## Actors
| Actor | บทบาทใน flow นี้ |
|-------|----------------|
| [Actor 1] | [บทบาท] |

## Prerequisites
- [สิ่งที่ต้องเป็นจริงก่อนเริ่ม flow]

## Trigger
[อะไรเริ่ม flow — user action, API call, scheduler, event]

## Workflow Steps

### STEP 1: [ชื่อ]
**Actor:** [ใครทำ]
**Action:** [ทำอะไร]
**Input:** [ข้อมูลที่รับ]
**Success:** [ผลเมื่อสำเร็จ] → GO TO STEP 2
**Failure:**
  - FAIL(validation): [อะไรผิด] → [recovery: แสดง error]
  - FAIL(timeout): [ระบบค้าง] → [recovery: retry 2 ครั้ง → แจ้ง admin]

### STEP 2: [ชื่อ]
[format เดียวกัน]

## Handoff Contracts
[ดู references/handoff-template.md]

## Failure Modes ที่ต้องครอบคลุม
[ดู references/failure-modes.md — ทุก flow ต้อง cover 7 ประเภท]

## Assumptions
| # | สมมติฐาน | ยืนยันแล้วหรือยัง | ความเสี่ยงถ้าผิด |
|---|---------|:-----------------:|----------------|
| A1 | [สมมติฐาน] | ยังไม่ | [ผลกระทบ] |

## Open Questions
- [สิ่งที่ยังไม่รู้ ต้องถามลูกค้า/ทีม]
```

### Step 4: Cross-check กับ Activity Diagram เดิม (ถ้ามี)

ถ้า project มี `SystemFlow/*.puml` อยู่แล้ว:
1. เปรียบเทียบ workflow spec กับ diagram
2. หา **flow ที่อยู่ใน spec แต่ไม่อยู่ใน diagram** → flag เป็น gap
3. หา **flow ที่อยู่ใน diagram แต่ไม่อยู่ใน spec** → เพิ่มเข้า spec
4. รายงานให้ผู้ใช้ก่อนแก้ไข

### Step 5: ส่งต่อ Activity Diagram

เมื่อ spec พร้อม → แนะนำผู้ใช้ load `pmo-activity-diagram` เพื่อสร้าง PlantUML จาก spec:
- Actors จาก spec → Swimlane
- Steps จาก spec → Activities
- Failure modes → Alternative/Exception cases

---

## 4. Output

บันทึก Workflow Spec ที่ `./{ProjectFolder}/SystemFlow/`:
```
WORKFLOW-{XX}_{ชื่อ-flow}.md
```
ตัวอย่าง: `WORKFLOW-01_UserLogin.md`, `WORKFLOW-02_Payment.md`

บันทึก Workflow Registry ที่:
```
./{ProjectFolder}/SystemFlow/WORKFLOW-Registry.md
```

---

## 5. Traceability

หลังสร้าง spec เสร็จ ต้อง:
1. Log ลง Activity Log: `Created | WORKFLOW-XX | [รายละเอียด]`
2. อ้างอิง MOM# ทุกครั้งที่ reference business rule จาก MOM
