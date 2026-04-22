---
name: QA Report
description: Protocol สำหรับ QA รายงานผล Test กลับมาใน PMO Repo — AI บันทึกผล Test ตาม Test Cases ใน TaskBoard, อัพเดท Traceability Matrix and Card status — ใช้เมื่อ QA บอกว่า "test เสร็จแล้ว", "ผล test Module X", "Module X ผ่าน/ไม่ผ่าน", หรือต้องการบันทึกผล test ครอบคลุม Step 24-28 ของ PMO Collaboration Workflow (WF-C)
---

# PMO Skill: QA Test Report Protocol

> **Related Skills:**
> - Load `pmo-taskboard` เพื่ออัพเดท Card status + test results
> - Load `pmo-traceability` เพื่อ log activity + update Traceability Matrix
> - Load `references/qa-report-format.md` for report format

---

## Purpose

Skill นี้กำหนด protocol ที่ QA ใช้รายงานผล test กลับมาใน PMO Repo ผ่าน Claude AI

**ปัญหาที่ skill นี้แก้:**
- QA test เสร็จแล้วไม่รู้จะรายงานอะไรบ้าง format ไหน
- PM ไม่เห็นผล test ละเอียด (แค่ "ผ่าน/ไม่ผ่าน" ไม่พอ)
- Bug ที่เจอไม่ถูก track กลับไปที่ Dev อย่างชัดเจน
- Traceability ขาด — ไม่รู้ว่า test ครอบคลุม case ไหนบ้าง

---

## QA Setup (ก่อนเริ่ม Test)

QA ต้องเตรียม 2 VS Code Windows:
1. **Window 1 — Dev Repo:** Code ที่ Dev ทำเสร็จ (clone/pull branch ที่ Dev แจ้ง)
2. **Window 2 — PMO Repo:** ดู SystemFlow + TaskBoard + คุยกับ AI

### QA ถาม AI ว่ามีงาน Test อะไร

เมื่อ QA ถาม AI ใน PMO Repo → AI ต้อง:
1. อ่าน TaskBoard.md → หา Card ที่ status = "QA Testing"
2. สรุป:
   - Module ที่ต้อง test
   - Dev Branch ที่ต้อง pull
   - Test Cases ทั้งหมด (Happy/Alt/Exception) พร้อมรายละเอียด
   - Dev notes (ถ้ามี)

---

## QA Report Format

เมื่อ QA test เสร็จแล้ว → รายงานกลับ AI:

### Required Information

| # | Field | ตัวอย่าง | Required? |
|---|-------|---------|-----------|
| 1 | **Module ที่ Test** | Module 12 - Manage Pricing | Yes |
| 2 | **Happy Case Results** | 4/4 Pass | Yes |
| 3 | **Alternative Case Results** | 2/2 Pass | Yes |
| 4 | **Exception Flow Results** | 2/3 Pass (E-003 Fail) | Yes |
| 5 | **Bug Details** (ถ้ามี Fail) | รายละเอียด bug แต่ละ case | Yes (ถ้ามี Fail) |
| 6 | **Test Environment** | Local / Staging / Production | Optional |
| 7 | **Screenshots/Evidence** | แนบ screenshot | Optional |

### QA Report Template (สำหรับ QA copy-paste)

```
Module: [ชื่อ Module]
Test Results:
- Happy: [x/y] Pass
- Alternative: [x/y] Pass
- Exception: [x/y] Pass
Failed Cases:
- [Case ID]: [อธิบาย bug]
Notes: [หมายเหตุ ถ้ามี]
```

---

## AI Processing QA Report

เมื่อ QA ส่ง report → AI ทำ 3 ขั้นตอน:

### Step 1: Validate Report Completeness

| ตรวจอะไร | เงื่อนไข |
|----------|---------|
| Module ตรงกับ Card ที่ status = QA Testing | ชื่อ Module match |
| Test case ครบทุกประเภท | Happy + Alt + Exception |
| Failed cases มี detail | ทุก Fail case ต้องมีรายละเอียด bug |

### Step 2: Update TaskBoard

**ถ้า Test ผ่านครบ 100%:**

| Update | Value |
|--------|-------|
| Card Status | "QA Passed" |
| Test Results | บันทึกผลทุก case (Pass) |
| QA Sign-off | QA name + date |

**ถ้ามี Test Fail:**

| Update | Value |
|--------|-------|
| Card Status | "Revision" |
| Failed Cases | บันทึก case ที่ Fail + bug detail |
| Revision Note | สรุปสิ่งที่ Dev ต้องแก้ |

### Step 3: Update Traceability + Logs

1. **Traceability Matrix** → Change Log: "QA completed Module X — [Pass/Fail]"
2. **Activity Log** → "QA Report: Card #X — Happy x/x, Alt x/x, Exc x/x"
3. **ถ้า Pass** → แจ้ง PM: "Module X QA ผ่านแล้ว พร้อม Client Review"
4. **ถ้า Fail** → แจ้ง Dev: "Module X QA ไม่ผ่าน [X] cases — ดู Revision Note"

---

## Bug Report Format (สำหรับ Failed Cases)

ทุก Failed case ต้องมีข้อมูลนี้:

| Field | Description |
|-------|-------------|
| **Case ID** | จาก Test Cases (เช่น E-003) |
| **Severity** | Critical / Major / Minor |
| **Steps to Reproduce** | ขั้นตอนที่ทำแล้วเกิด bug |
| **Expected Result** | ผลที่ควรจะเป็น (จาก Test Case) |
| **Actual Result** | ผลที่เกิดขึ้นจริง |
| **Screenshot** | แนบ screenshot (ถ้ามี) |

### Severity Guide

| Severity | เงื่อนไข | ตัวอย่าง |
|----------|---------|---------|
| **Critical** | Feature ใช้งานไม่ได้เลย / Data loss / Security issue | กดปุ่ม Save แล้ว crash, ข้อมูลหาย |
| **Major** | Feature ทำงานผิดปกติ แต่มี workaround | คำนวณราคาผิด, แสดงข้อมูลผิด field |
| **Minor** | UI/UX issue, Typo, ไม่กระทบ logic | ปุ่มไม่ตรงกลาง, ข้อความ typo |

---

## Retest Flow (เมื่อ Dev แก้แล้ว)

1. Dev แก้ bug → รายงานกลับผ่าน `pmo-dev-report`
2. AI อัพเดท Card status = "QA Testing" (รอบ 2)
3. QA test **เฉพาะ case ที่ Fail** + **Regression test** (ทดสอบว่า case ที่เคย Pass ยังผ่านอยู่)
4. รายงานผล retest ด้วย format เดิม + เพิ่ม "Retest Round: 2"

---

## Do's and Don'ts

### Do's
1. ให้ QA ดู Test Cases จาก TaskBoard ก่อนเริ่ม test ทุกครั้ง
2. บันทึก bug detail ทุก Failed case (ห้ามแค่ "Fail")
3. ทำ regression test ทุกรอบ retest
4. อัพเดท TaskBoard + Traceability + Activity Log พร้อมกัน

### Don'ts
1. ห้าม mark Pass ถ้ายังไม่ได้ test จริง
2. ห้ามข้าม case ใดๆ (ต้อง test ครบทุก case)
3. ห้าม QA แก้ code เอง — ต้องส่งกลับ Dev เสมอ
4. ห้ามปิด Card ถ้ามี Failed case แม้แต่ 1 case
