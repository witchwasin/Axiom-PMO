# TaskBoard.md Template

> ไฟล์นี้วางไว้ที่ `{ProjectFolder}/TaskBreakdown/TaskBoard.md`

---

## Project Overview

| Field | Value |
|-------|-------|
| **Project** | P{XX}-{CODE} |
| **Total Cards** | {N} |
| **Status** | Backlog: X / In Progress: X / QA: X / Done: X |
| **Last Updated** | YYYY-MM-DD HH:MM |

---

## Card Board

### Active Cards

| Card # | Module | SystemFlow File | Assignee | Status | Deadline | Happy | Alt | Exception | Total Pass | Last Update |
|--------|--------|----------------|----------|--------|----------|-------|-----|-----------|------------|-------------|
| #001 | Module 04-A: Author Verification | BOF-UseF-04-A_AuthorVerification.puml | - | Backlog | - | 0/4 | 0/2 | 0/3 | 0/9 | YYYY-MM-DD |
| #002 | Module 06: Financial Config | BOF-UseF-06_FinancialConfig.puml | - | Backlog | - | 0/5 | 0/3 | 0/4 | 0/12 | YYYY-MM-DD |

### Completed Cards

| Card # | Module | Assignee | Completed Date | Total Cases | Client Approved |
|--------|--------|----------|---------------|-------------|-----------------|
| *(empty)* | | | | | |

---

## Card Details

### Card #001: Module 04-A - Author Verification

| Field | Value |
|-------|-------|
| **Module** | Module 04-A: Author Verification |
| **SystemFlow** | `UserFlow/BOF-UseF-04-A_AuthorVerification.puml` |
| **Assignee** | *(ยังไม่ assign)* |
| **Status** | Backlog |
| **Created** | YYYY-MM-DD |
| **Deadline** | - |

#### Test Cases

**Happy Cases (4):**

| # | Test Case | Description | Expected Result | Status |
|---|-----------|-------------|-----------------|--------|
| H-001 | KYC สำเร็จครั้งแรก | กรอก ID Card + Bank Page ถูกต้อง ชื่อตรงกัน | Status = verified, KYC expiry = +1 year | - |
| H-002 | Re-verify หลัง KYC หมดอายุ | KYC expired -> re-submit -> ผ่าน | Status กลับเป็น verified | - |
| H-003 | Admin approve KYC | Admin ตรวจ -> กด Approve | เปลี่ยน status + แจ้ง Author | - |
| H-004 | Author ดูสถานะ KYC | เข้าหน้า Profile -> เห็นสถานะ KYC ปัจจุบัน | แสดง status + expiry date | - |

**Alternative Cases (2):**

| # | Test Case | Description | Expected Result | Status |
|---|-----------|-------------|-----------------|--------|
| A-001 | ชื่อไม่ตรงกัน | ชื่อบัตรประชาชน != ชื่อบัญชีธนาคาร | แจ้ง error + ให้แก้ไข | - |
| A-002 | Admin request เอกสารเพิ่ม | Admin ต้องการเอกสารเพิ่มเติม | Status = pending_additional + แจ้ง Author | - |

**Exception Flows (3):**

| # | Test Case | Description | Expected Result | Status |
|---|-----------|-------------|-----------------|--------|
| E-001 | Upload file ไม่ถูก format | อัพโหลดไฟล์ที่ไม่ใช่รูปภาพ | แจ้ง error: "กรุณาอัพโหลดไฟล์รูปภาพ" | - |
| E-002 | Admin reject KYC | Admin ตรวจแล้ว reject | Status = rejected + แจ้ง Author + ระบุเหตุผล | - |
| E-003 | KYC expired ขณะมี novel ขาย | KYC หมดอายุ -> ระงับการขาย | Block sales + แจ้ง Author ให้ re-verify | - |

#### Status History

| Date | From | To | By | Note |
|------|------|----|----|------|
| YYYY-MM-DD | - | Backlog | PM | Card created |

---

### Card #002: Module 06 - Financial Config

*(repeat structure per card)*

---

## Update Log

| Date | Card # | Action | By | Detail |
|------|--------|--------|----|--------|
| YYYY-MM-DD | #001 | Created | PM | Initial card with 9 test cases |
