---
name: Dev Report
description: Protocol สำหรับ Dev รายงานผลงานกลับมาใน PMO Repo — AI ตรวจสอบ Code เทียบกับ SystemFlow, ตรวจ Test Coverage, อัพเดท Traceability Matrix and TaskBoard — ใช้เมื่อ Dev บอกว่า "ทำเสร็จแล้ว", "Module X เสร็จ", "อัพเดท PM ให้หน่อย", หรือต้องการ AI review code/ผลงาน ครอบคลุม Step 16-21 ของ PMO Collaboration Workflow (WF-B)
---

# PMO Skill: Dev Completion Report Protocol

> **Related Skills:**
> - Load `pmo-taskboard` เพื่ออัพเดท Card status
> - Load `pmo-traceability` เพื่อ log activity + update Traceability Matrix
> - Load `references/dev-report-format.md` for report format

---

## Purpose

Skill นี้กำหนด protocol ที่ Dev ใช้รายงานผลงานกลับมาใน PMO Repo ผ่าน Claude AI และ AI ใช้ตรวจสอบ + อัพเดทระบบ

**ปัญหาที่ skill นี้แก้:**
- Dev ทำเสร็จแล้วไม่รู้จะรายงานอะไรบ้าง
- PM ไม่รู้ว่า Dev ทำตรงกับ SystemFlow ไหม
- Test coverage ไม่ชัดเจน — ไม่รู้ว่าผ่านกี่ case
- Traceability Matrix ไม่ถูก update

---

## Dev Report Format

เมื่อ Dev บอก AI ว่า "ทำเสร็จแล้ว" → AI ต้องถาม (ถ้า Dev ไม่ได้ให้ข้อมูลครบ):

### Required Information

| # | Field | ตัวอย่าง | Required? |
|---|-------|---------|-----------|
| 1 | **Module ที่ทำเสร็จ** | Module 12 - Manage Pricing | Yes |
| 2 | **Branch Name** | feature/useF-12-pricing | Yes |
| 3 | **Happy Case Results** | 4/4 ผ่าน | Yes |
| 4 | **Alternative Case Results** | 2/2 ผ่าน | Yes |
| 5 | **Exception Flow Results** | 3/3 ผ่าน | Yes |
| 6 | **Files Changed** | รายชื่อไฟล์หลักที่แก้ไข | Optional |
| 7 | **Issues/Blockers** | ปัญหาที่เจอระหว่างทำ | Optional |
| 8 | **Code/File for Review** | แนบ code snippet หรือไฟล์ | Optional |

### Dev Report Template (สำหรับ Dev copy-paste)

```
Module: [ชื่อ Module]
Branch: [branch name]
Test Results:
- Happy: [x/y] ผ่าน
- Alternative: [x/y] ผ่าน
- Exception: [x/y] ผ่าน
Notes: [หมายเหตุ ถ้ามี]
```

---

## AI Review Process (Step 17 ของ WF-B)

เมื่อ Dev ส่ง report มา → AI ทำ 4 ขั้นตอน:

### Step 1: ตรวจ Completeness

| ตรวจอะไร | เงื่อนไข Pass |
|----------|-------------|
| Module ตรงกับ Card ที่ assign | ชื่อ Module ตรงกับ TaskBoard |
| Test case ครบทุกประเภท | มี Happy + Alt + Exception |
| Test case ผ่านครบ | ทุก case = Pass (ไม่มี 0/x หรือ x/y ที่ x < y) |

### Step 2: ตรวจ SystemFlow Alignment (ถ้า Dev แนบ code/file)

| ตรวจอะไร | วิธีตรวจ |
|----------|---------|
| Steps ครบตาม flow | เทียบ code logic กับ steps ใน .puml |
| Business rules ตรง | เทียบ validations/conditions กับ notes ใน flow |
| Actors/roles ถูกต้อง | ตรวจ role check ใน code กับ lanes ใน flow |

### Step 2.5: Structured Code Review (ถ้า Dev แนบ code)

> **อ้างอิง ECC code-reviewer agent pattern** — จัดผลตรวจตาม severity เพื่อให้ Dev แก้ไขได้ตามลำดับความสำคัญ

**ตรวจ 6 หมวด เรียงตาม priority:**

| Priority | หมวด | ตรวจอะไร |
|:---:|------|---------|
| **CRITICAL** | Security | Hardcoded secrets, SQL injection, XSS, missing auth check |
| **HIGH** | Logic Correctness | Business rule ไม่ตรง SystemFlow, missing validation, dead code path |
| **HIGH** | Error Handling | Unhandled exceptions, missing error response, incorrect status code |
| **MEDIUM** | Code Quality | Code duplication, function > 50 lines, unclear naming |
| **MEDIUM** | Performance | N+1 queries, missing pagination, unnecessary re-renders |
| **LOW** | Style/Convention | Naming convention, import order, missing type annotation |

**Severity Definitions:**

| Severity | ความหมาย | Action |
|:---:|---|---|
| **CRITICAL** | ต้องแก้ก่อน merge — ถ้าไม่แก้จะเกิดปัญหา production | **Block**: ห้าม approve จนกว่าจะแก้ |
| **HIGH** | ควรแก้ก่อน merge — กระทบ business logic หรือ user experience | **Block**: แนะนำแก้ก่อน แต่ PM ตัดสินใจได้ |
| **MEDIUM** | ควรแก้แต่ไม่ urgent — กระทบ maintainability | **Non-block**: แก้ใน sprint ถัดไปได้ |
| **LOW** | Nice to have — ปรับปรุง code quality | **Non-block**: แก้เมื่อมีเวลา |

**Review Output Format:**

```markdown
## Code Review Report
**Module:** {Module Name} | **Branch:** {branch} | **วันที่:** YYYY-MM-DD
**Reviewer:** PMO AI | **Verdict:** {APPROVED / CHANGES REQUIRED / BLOCKED}

### Summary
- CRITICAL: {N} issues
- HIGH: {N} issues
- MEDIUM: {N} issues
- LOW: {N} issues

### Findings

#### CRITICAL
| # | File | Line | Issue | SystemFlow Ref | Fix Suggestion |
|---|------|------|-------|---------------|---------------|
| 1 | auth.py:45 | 45 | Hardcoded API key | SysF-01 Step 3 | Move to env var |

#### HIGH
| # | File | Line | Issue | SystemFlow Ref | Fix Suggestion |
|---|------|------|-------|---------------|---------------|

#### MEDIUM
| # | File | Line | Issue | SystemFlow Ref | Fix Suggestion |
|---|------|------|-------|---------------|---------------|

#### LOW
| # | File | Line | Issue | SystemFlow Ref | Fix Suggestion |
|---|------|------|-------|---------------|---------------|
```

**Verdict Rules:**
- มี CRITICAL > 0 → **BLOCKED** (ต้องแก้ก่อน)
- มี HIGH > 0, CRITICAL = 0 → **CHANGES REQUIRED** (แนะนำแก้)
- มีแค่ MEDIUM/LOW → **APPROVED** (พร้อม QA)

### Step 3: Feedback

| ผลตรวจ | AI ตอบ |
|--------|-------|
| **APPROVED** | "Review ผ่านครับ ไม่มี critical/high issues พร้อม update PM ได้เลย" |
| **CHANGES REQUIRED** | ระบุ HIGH issues + อ้างอิง SystemFlow step + fix suggestion |
| **BLOCKED** | ระบุ CRITICAL issues + **ห้าม proceed** จนกว่าจะแก้ |
| **ข้อมูลไม่ครบ** | ถามข้อมูลเพิ่มเติมที่ต้องการ |

### Step 4: Update System (เมื่อ Dev confirm "อัพเดท PM ให้หน่อย")

AI ต้องทำทั้ง 4 อย่าง:

1. **TaskBoard.md** → เปลี่ยน Card status เป็น "QA Testing" + เพิ่ม test results
2. **Traceability Matrix** → Change Log: "Dev completed Module X, branch: Y"
3. **Activity Log** → "Updated: Card #X status to QA Testing"
4. **แจ้ง QA** → "Module X พร้อมให้ QA test แล้ว, branch: Y"

---

## Revision Flow (เมื่อต้องแก้ไข)

ถ้า AI review ไม่ผ่าน หรือ QA/Client reject:

1. AI สรุป **Revision Note** — จุดที่ต้องแก้ + อ้างอิง SystemFlow
2. อัพเดท TaskBoard → status = "Revision"
3. Dev แก้ Code → รายงานกลับมาใหม่ (ใช้ protocol เดิม)
4. AI ตรวจ Revision ว่าแก้ครบหรือไม่ (เทียบกับ Revision Note)

---

## Test Coverage Analysis (v2.1.0)

| Metric | Minimum |
|--------|:-------:|
| Line Coverage | >= 80% |
| Branch Coverage | >= 70% |
| Function Coverage | >= 90% |

Dev แนบ coverage → AI เทียบ threshold → ถ้าต่ำ แจ้ง areas ที่ขาด (อ้างอิง SystemFlow)

หลัง Dev report → แนะนำรัน `pmo-security-scan` ก่อนส่ง QA (Critical = block, High = warn)

---

## Do's and Don'ts

### Do's
1. ถาม Dev ให้ครบถ้าข้อมูลไม่พอ (ห้ามเดา)
2. เทียบ test results กับ test cases ใน TaskBoard ทุกครั้ง
3. อัพเดททั้ง TaskBoard + Traceability + Activity Log พร้อมกัน
4. ให้ feedback ที่ specific — อ้างอิง SystemFlow step number
5. ตรวจ test coverage ก่อน approve (v2.1.0)

### Don'ts
1. ห้าม approve ถ้า test ไม่ครบ (แม้ Dev บอกว่า "เสร็จแล้ว")
2. ห้ามข้าม AI Review ไป update PM ตรง
3. ห้ามเปลี่ยน status เป็น QA Testing ถ้ายังไม่ได้ Dev confirm
4. ห้ามสร้าง test results ขึ้นมาเอง — ต้องใช้ข้อมูลจาก Dev เท่านั้น
5. ห้าม approve ถ้า coverage ต่ำกว่า threshold โดยไม่แจ้ง (v2.1.0)
