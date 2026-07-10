---
name: TaskBoard
description: จัดการ TaskBoard (Card) ตาม Module จาก SystemFlow — สร้าง Card, Assign งาน, Generate Test Cases, อัพเดทสถานะ, ปิด Card — ใช้ทุกครั้งที่ PM แตก Card, Dev/QA ถามงาน, หรืออัพเดทสถานะงาน ครอบคลุม Step 5-9 (PM แตก Card) และ Step 12-13 (Dev ถาม AI) ของ PMO Collaboration Workflow
---

# PMO Skill: TaskBoard Management

> **Related Skills:**
> - Load `pmo-traceability` เพื่อ log activity + update Traceability Matrix
> - Load `pmo-activity-diagram` เมื่อต้องอ่าน SystemFlow เพื่อ generate test cases
> - Load `references/taskboard-template.md` for TaskBoard format
> - Load `references/testcase-template.md` for Test Case generation guide

---

## Purpose

Skill นี้จัดการ **TaskBoard.md** ซึ่งเป็นไฟล์ track สถานะ Card ของทุก Module ใน project

**ปัญหาที่ skill นี้แก้:**
- PM แตก Card แล้วไม่มีที่ track สถานะรวม
- Dev ไม่รู้ว่า PM assign งานอะไรมาให้
- QA ไม่รู้ว่า Module ไหน Dev ทำเสร็จแล้ว รอ test
- PM ไม่เห็นภาพรวมว่างานทั้ง project อยู่ขั้นตอนไหน

---

## TaskBoard Location

```
{ProjectFolder}/TaskBreakdown/TaskBoard.md
```

---

## Card Lifecycle (สถานะของ Card)

```
Backlog -> Assigned -> In Progress -> Dev Done -> QA Testing -> QA Passed -> Client Review -> Done
                                        |             |              |              |
                                        v             v              v              v
                                    Revision      QA Failed     Revision      Revision
                                    (-> In Progress) (-> In Progress) (-> In Progress) (-> In Progress)
```

| Status | ความหมาย | ใครเป็นเจ้าของ |
|--------|---------|--------------|
| **Backlog** | Card สร้างแล้ว ยังไม่ assign | PM |
| **Assigned** | Assign ให้ Dev แล้ว รอเริ่มทำ | Dev |
| **In Progress** | Dev กำลังทำ | Dev |
| **Dev Done** | Dev ทำเสร็จ รอ AI Review | Dev -> AI |
| **QA Testing** | QA กำลัง test | QA |
| **QA Passed** | QA test ผ่านแล้ว | QA -> PM |
| **Client Review** | PM นำเสนอลูกค้า รอ approve | PM -> Client |
| **Done** | ลูกค้า approve แล้ว ปิด Card | PM |
| **Revision** | ต้องแก้ไข (จาก AI/QA/Client feedback) | Dev |

---

## Workflow: PM สร้าง Card (Step 5-9 ของ WF-A)

### Step 1: อ่าน SystemFlow ของ Module

```
AI อ่าน SystemFlow .puml file ของ Module ที่ต้องการแตก Card
```

### Step 2: Generate Test Cases อัตโนมัติ

AI วิเคราะห์ SystemFlow แล้วสร้าง Test Cases 3 ประเภท:

| ประเภท | วิธีหา | ตัวอย่าง |
|--------|-------|---------|
| **Happy Case** | Main flow path ตั้งแต่ start ถึง stop โดยไม่มี error | User กรอกข้อมูลครบ -> Submit -> สำเร็จ |
| **Alternative Case** | ทุก branch ที่เกิดจาก Decision (if/elseif/else) ที่ไม่ใช่ error | User เลือก "แก้ไข" แทน "ลบ" |
| **Exception Flow** | ทุก error/fail/reject path | Validation ไม่ผ่าน, API timeout, Permission denied |

**วิธี Generate:**

1. **Happy Case:** trace main path (ทุก "then (Yes/OK)" ของ if) จาก start -> stop
2. **Alternative Case:** ทุก branch ที่ไม่ใช่ main path และไม่ใช่ error (เช่น elseif branches, optional paths)
3. **Exception Flow:** ทุก branch ที่เป็น error/fail/reject/invalid/timeout

### Step 3: สร้าง Card ใน TaskBoard

เพิ่ม entry ใน TaskBoard.md ตาม format ใน `references/taskboard-template.md`

### Step 4: Assign Card

PM ระบุ Assignee (Dev) และ Deadline -> AI อัพเดท TaskBoard

---

## Workflow: Dev ถาม AI ว่ามีงานอะไร (Step 12-13 ของ WF-B)

เมื่อ Dev ถาม AI ใน PMO Repo ว่า "งานรอบนี้ทำอะไร?" หรือ "PM assign อะไรมาให้?"

### AI ต้องตอบ:

1. **อ่าน TaskBoard.md** -> หา Card ที่ status = "Assigned" หรือ "In Progress" ของ Dev คนนั้น
2. **สรุปงาน:**
   - Module ที่ต้องทำ
   - SystemFlow file ที่ต้องดู (ชื่อไฟล์ + path)
   - Test Cases ที่ต้องผ่าน (สรุปจำนวน Happy/Alt/Exception)
   - Deadline
3. **อัพเดทสถานะ** เป็น "In Progress" (ถ้ายังเป็น Assigned)

### ตัวอย่าง AI Response:

```
งานรอบนี้ PM assign ให้คุณทำ:

**Card #003: Module 12 - Manage Pricing**
- SystemFlow: BOF-UseF-12_ManagePricing.puml
- Test Cases ที่ต้องผ่าน:
  - Happy Case: 4 cases
  - Alternative Case: 2 cases
  - Exception Flow: 3 cases
- Deadline: 2026-03-20

ดู SystemFlow ได้ที่: P03-PROJECT/UserFlow/BOF-UseF-12_ManagePricing.puml
ดู Test Cases ละเอียดได้ที่: P03-PROJECT/TaskBreakdown/TaskBoard.md > Card #003
```

---

## Workflow: อัพเดทสถานะ Card

เมื่อได้รับ update จาก Dev/QA/PM -> AI ต้อง:

1. **อัพเดท TaskBoard.md** -> เปลี่ยน status + เพิ่ม update note
2. **Log Activity Log** ใน Traceability Matrix
3. **แจ้งเจ้าของขั้นตอนถัดไป** (เช่น Dev Done -> แจ้ง QA)

---

## เงื่อนไขปิด Card (Card Closure Criteria)

Card จะปิดได้ก็ต่อเมื่อ **ผ่านทุกข้อ:**

| # | เงื่อนไข | ตรวจสอบโดย |
|---|---------|----------|
| 1 | Happy Case ผ่านครบ 100% | QA |
| 2 | Alternative Case ผ่านครบ 100% | QA |
| 3 | Exception Flow ผ่านครบ 100% | QA |
| 4 | Code ตรงกับ SystemFlow (AI Review ผ่าน) | AI |
| 5 | Client Approve (PM confirm) | PM |

**ถ้าไม่ครบ -> ห้ามปิด Card -> สร้าง Revision note แล้วส่งกลับ Dev**

---

## Do's and Don'ts

### Do's
1. อ่าน SystemFlow ก่อน generate test cases ทุกครั้ง
2. นับ Test Cases จาก decision branches ใน flow จริง (ไม่ใช่เดา)
3. อัพเดท TaskBoard ทันทีเมื่อสถานะเปลี่ยน
4. Log ทุก status change ลง Activity Log
5. แจ้ง context ให้ Dev/QA เข้าใจเมื่อถามงาน

### Don'ts
1. ห้าม generate test cases โดยไม่อ่าน SystemFlow
2. ห้ามปิด Card ถ้ายังไม่ผ่านครบทุกข้อ
3. ห้ามเปลี่ยนสถานะข้ามขั้น (เช่น Assigned -> QA Testing)
4. ห้ามลบ Card ที่สร้างแล้ว (ใช้ status tracking เท่านั้น)
5. ห้าม assign Card ให้คนที่ PM ไม่ได้ระบุ
