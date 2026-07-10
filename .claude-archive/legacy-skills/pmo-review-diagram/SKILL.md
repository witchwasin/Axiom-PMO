---
name: Review Diagram
description: รัน validation checklist ครบทุกข้อ (Case Analysis 20 ข้อ + MOM Validation 7 ข้อ + Lark 7 Rules) กับ diagram ที่เลือก
---

# PMO Skill: Review Diagram

> **Related Skills:**
> - Load `pmo-lark-plantuml` for Lark 7 Rules verification
> - Load `pmo-activity-diagram/references/case-checklist.md` for 20-item checklist
> - Load `pmo-activity-diagram/references/mom-validation.md` for MOM Validation
> - Load `references/validation-criteria.md` for severity classification + review output format

---

## Goal

รัน validation checklist ครบทุกข้อกับ diagram file ที่ผู้ใช้เลือก แล้วสรุปผลว่า pass หรือไม่ พร้อมระบุจุดที่ต้องแก้ไข

---

## Verification Tiers — เลือกระดับ Review ตามขนาดงาน

> **อ้างอิงจาก OMC Verification Tier pattern** — ไม่ต้อง review ทุก diagram เท่ากัน

| Tier | เมื่อไหร่ใช้ | ทำอะไร | Model |
|------|------------|--------|:---:|
| **LIGHT** | แก้ไขเล็กน้อย (< 5 steps เปลี่ยน), fix typo, เปลี่ยน label | Lark 7 Rules เท่านั้น | Haiku |
| **STANDARD** | สร้าง diagram ใหม่, แก้ไข flow logic, เพิ่ม/ลบ steps | Lark 7 + Case Analysis 20 + MOM Validation 7 (ครบทั้ง 3 ชุด) | Sonnet |
| **THOROUGH** | Module ที่เกี่ยวกับ Security/การเงิน/Compliance, diagram > 30 steps, cross-module impact, ก่อน Final handoff | ครบทั้ง 3 ชุด + Cross-Module Consistency Check + Pre-mortem Analysis (3-5 failure scenarios) | Opus |

### Auto-Select Tier

AI ต้องประเมิน tier อัตโนมัติก่อนเริ่ม review:

| เงื่อนไข | Tier |
|----------|------|
| แก้แค่ label/typo/color | LIGHT |
| เปลี่ยน < 5 steps, ไม่กระทบ logic | LIGHT |
| สร้างใหม่ หรือแก้ flow logic | STANDARD |
| Module เกี่ยวกับ Payment/KYC/Approve/Financial | **THOROUGH** (auto-escalate) |
| Diagram > 30 activities | **THOROUGH** (auto-escalate) |
| แก้ไขกระทบ > 3 modules | **THOROUGH** (auto-escalate) |
| ก่อนลบ [DRAFT] เป็น Final | **STANDARD** ขั้นต่ำ |
| ก่อน Dev Handoff | **THOROUGH** |

> **User สามารถ override tier ได้** — เช่น "review แบบ THOROUGH ให้หน่อย" หรือ "review แค่ Lark ก็พอ"

### THOROUGH-only: Cross-Module Consistency Check

เมื่อ tier = THOROUGH ต้องตรวจเพิ่ม:

| # | ตรวจอะไร | วิธีตรวจ |
|---|----------|---------|
| 1 | Status enum ตรงกันข้าม modules | เทียบ status values ใน note blocks ทุก module ที่ share entity เดียวกัน |
| 2 | Actor naming consistent | ชื่อ actor ใน swimlane ตรงกันทุก module |
| 3 | Shared entity fields ตรงกัน | field ใน data model notes ตรงกันทุก module ที่ใช้ entity เดียวกัน |
| 4 | Handoff points เชื่อมกัน | connector notes "ต่อจาก Module XX" ตรงกับ module ปลายทาง |
| 5 | Business rules ไม่ขัดแย้ง | validation conditions ตรงกันข้าม modules |

### THOROUGH-only: Pre-mortem Analysis

วิเคราะห์ failure scenarios ก่อน finalize:

```markdown
## Pre-mortem Analysis
| # | Failure Scenario | Likelihood | Impact | Mitigation | Status |
|---|-----------------|:---:|:---:|-----------|--------|
| 1 | {สถานการณ์ที่อาจทำให้ flow ล้มเหลว} | H/M/L | H/M/L | {วิธีป้องกัน} | {มีใน flow แล้ว / ต้องเพิ่ม} |
```

---

## Workflow

### Step 1: รับ Input + กำหนด Tier
- ถามผู้ใช้ว่าจะ review diagram ไหน (file path หรือ module name)
- ระบุ project ที่ diagram อยู่
- อ่าน diagram file ทั้งหมด
- **ประเมิน Verification Tier อัตโนมัติ** แล้วแจ้งผู้ใช้ (เช่น "Module นี้เกี่ยวกับ Payment → ใช้ THOROUGH tier")

### Step 2: รัน Lark 7 Rules (Syntax Level)
ตรวจ .puml file ว่าผ่าน 7 กฎ:
1. FLAT CODE 100% — ไม่มี leading whitespace
2. NO AMPERSAND — ไม่มี `&`
3. START KEYWORD — มี `start` หลัง swimlane แรก
4. SINGLE-LINE ACTION — action block (:...;) อยู่บรรทัดเดียว
5. ELSEIF WITH LABEL — ทุก `elseif` มี label
6. NO LEGEND BLOCK — ไม่ใช้ `legend`/`end legend`
7. SAFE ASCII — ไม่มี Unicode special characters

### Step 3: รัน Case Analysis Checklist (20 ข้อ)
ตรวจ diagram content ว่าครอบคลุม:
- Happy path ครบ
- Error handling ครบ
- Edge cases ครบ
- Actor ถูกต้องตาม MOM/REQ
- Step numbering ต่อเนื่อง
- ฯลฯ (ดูรายละเอียดใน references/case-checklist.md)

### Step 4: รัน MOM Validation (7 ข้อ)
ตรวจว่า diagram ตรงกับ MOM:
- Feature ตรงกับที่ตกลง
- Business rule ตรง
- Actor ตรง
- Terminology ตรง
- ไม่มี Gold Plating
- ฯลฯ (ดูรายละเอียดใน references/mom-validation.md)

### Step 5: สรุป Review Report

**Output Format:**

```markdown
# Diagram Review Report
**File:** [filename] | **Project:** P{XX}-{CODE} | **วันที่:** YYYY-MM-DD
**Verification Tier:** {LIGHT / STANDARD / THOROUGH} | **เหตุผล:** {ทำไมถึงเลือก tier นี้}

## Summary
- Lark 7 Rules: {PASS/FAIL} ({N}/7 passed)
- Case Analysis: {PASS/FAIL} ({N}/20 passed) *(STANDARD/THOROUGH only)*
- MOM Validation: {PASS/FAIL} ({N}/7 passed) *(STANDARD/THOROUGH only)*
- Cross-Module Consistency: {PASS/FAIL} ({N}/5 passed) *(THOROUGH only)*
- Pre-mortem: {N} scenarios analyzed *(THOROUGH only)*
- **Overall: {PASS/FAIL}**

## Lark 7 Rules Results
| # | Rule | Status | Issue (ถ้ามี) |
|---|------|--------|-------------|

## Case Analysis Results *(STANDARD/THOROUGH only)*
| # | Item | Status | Issue (ถ้ามี) |
|---|------|--------|-------------|

## MOM Validation Results *(STANDARD/THOROUGH only)*
| # | Item | Status | Issue (ถ้ามี) |
|---|------|--------|-------------|

## Cross-Module Consistency *(THOROUGH only)*
| # | Check | Status | Issue (ถ้ามี) |
|---|-------|--------|-------------|

## Pre-mortem Analysis *(THOROUGH only)*
| # | Failure Scenario | Likelihood | Impact | Mitigation | Status |
|---|-----------------|:---:|:---:|-----------|--------|

## สิ่งที่ต้องแก้ไข (เรียงตาม severity)
1. [CRITICAL] ...
2. [WARNING] ...
3. [INFO] ...
```

### Step 6: ถามผู้ใช้
- ถ้า FAIL → ถามว่าต้องการให้แก้ไขเลยไหม
- ถ้า PASS → แจ้งว่าสามารถลบ `[DRAFT]` ออกจาก title ได้
