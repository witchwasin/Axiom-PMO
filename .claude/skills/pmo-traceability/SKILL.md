---
name: Traceability
description: จัดการ MOM references, Requirement Traceability Matrix, Wireframe change tracking, Change Log, Activity Log (บันทึกทุก action ของ AI) และ Decision Log (บันทึกทุก decision ของผู้ใช้) — ใช้ทุกครั้งที่ต้อง log, track, audit trail ข้อมูลใดๆ ใน project
---

# PMO Skill: Traceability and MOM Reference

> **Related Skills:** None (self-contained).
> Load `references/wireframe-tracking.md` for Wireframe Change Tracking.
> Load `references/implicit-requirements.md` for Industry and Cross-Platform checklists.

---

## MOM Reference in Diagram Title

Every diagram must reference its source MOM in the title:

```
title Module XX-A: Workflow Name [Ref: MOM#X - Topic]
```

If diagram references multiple MOMs, include all separated by `,`:

```
title Module 12-A: Report Generation [Ref: MOM#1 - Dashboard Requirements, MOM#2 - Export Features]
```

### MOM# to File Mapping

> **MOM# numbering is per-project** - each project starts counting from MOM#1.

| MOM# | File in ./<ProjectName>/MOM/ | Transcription (if exists) | Date | Project |
|------|----------------------------|----------------------|-------|---------|
| MOM#1 | `YYYYMMDD_[MOM] {Project}_ {Topic 1}.docx` | `YYYYMMDD_[Transcript] {Project}_ {Topic 1}.{ext}` | YYYY-MM-DD | P{XX}-{CODE} |
| MOM#2 | `YYYYMMDD_[MOM] {Project}_ {Topic 2}.docx` | *(none)* | YYYY-MM-DD | P{XX}-{CODE} |

> When new MOM files are added, update this table. Order by date (next MOM# = newest date). Transcription column shows *(none)* if no transcript paired.

---

## REQ Reference in Diagrams

Reference Requirement files from `./<ProjectName>/REQ/`:

```
note right
**Source:**
- REQ: YYYYMMDD_REQs_{Project} - {Details}
- Feature: "{Feature Name from REQ}"
end note
```

---

## Requirement Traceability Matrix

When project has multiple MOMs, REQs, and Modules, create a Traceability Matrix to track which requirement is implemented in which diagram:

```
| Project | MOM | Item # | Requirement | Module | Diagram | Status |
|---------|-----|--------|-------------|--------|---------|--------|
| P{XX}-{CODE} | MOM#1 | 1.1 | {Requirement Name} | Module XX-A | XX-A: {Diagram Name} | Validated |
| P{XX}-{CODE} | MOM#2 | 2.1 | {Requirement Name} | Module XX-B | XX-B: {Diagram Name} | Draft |
| P{XX}-{CODE} | MOM#2 | 2.2 | {Requirement Name} | Module XX-C | XX-C: {Diagram Name} | Gap Found |
```

**Status values:**
- `Validated` - passed validation, matches MOM
- `Draft` - still in draft, not validated yet
- `Gap Found` - gap found between diagram and MOM, needs fix
- `Out of Scope` - outside scope of this phase

---

## Validation Result Note Format

Every Final Flow must have a validation result note at the end (as Lark-safe comments in .puml files):

### Passed

```
' MOM Validation Result (XX-X):
' - Ref: MOM#X - {Topic}
' - Validated Date: YYYY-MM-DD
' - Checklist Result:
' + 1. Requirement Coverage - All FRs covered
' + 2. Business Rule - Conditions match MOM
' + 3. Actor Complete - {Actor list}
' + 4. Case Complete - Happy + N Alt + N Exception
' + 5. No Gold Plating - None
' + 6. Terminology Match - Uses MOM terms
' + 7. Phase Correct - Phase N Scope
' - Status: VALIDATED
```

### Gap Found

```
' - Status: GAP FOUND - must fix items 2, 4
' - Action Required:
' -> {Fix 1}
' -> {Fix 2}
```

---

## Mandatory Update Rule

> **Every time new information is received from the user, log to Traceability Matrix immediately.**

### When to Log

Every time new information arrives from any source:
- **New MOM** (.docx file added)
- **Phone Call** (user reports client/team call with new decisions)
- **Chat / Message update** (user sends new info via chat)
- **Decision / Approval** (user reports client approve/reject)
- **Any change** affecting requirements, diagrams, wireframes, or task breakdown

### 2 Mandatory Steps

**Step 1: Update `SystemFlow/REQ_Traceability_Matrix.md`**

Add new entry in **Change Log** table (end of file):

```markdown
| Date | Source | Module | Action | File | Description | Status |
|------|--------|--------|--------|------|-------------|--------|
| YYYY-MM-DD | {MOM#X / Phone Call / Chat / Decision} | {Affected Module} | {Created / Updated / Deleted / Approved / Rejected / Hold} | {File name} | {Brief summary of change} | {Done / Pending / Blocked} |
```

**Step 2: Update `CLAUDE.md` (if important decision or new rule)**

If new information is:
- **New rule** (business rule, process, policy) - add to CLAUDE.md relevant section
- **Decision affecting agent behavior** - add to CLAUDE.md so future sessions don't forget
- **Terminology change** - update in CLAUDE.md + AGENTS.md
- If just ordinary data update (e.g., wireframe change) - only log in Traceability Matrix

### Prohibitions

- **Never receive new info without logging** - failing to log is a rule violation
- **Never batch-log retroactively** - must log immediately when info is received

---

## Activity Log

> **บันทึกทุก action ที่ Claude ทำ** — เหมือน audit trail ของ AI agent

### When to Log

ทุกครั้งที่ Claude ทำ action ใดๆ ต่อไปนี้:
- **Created** — สร้างไฟล์ใหม่ (diagram, wireframe, task breakdown, traceability matrix)
- **Updated** — แก้ไขไฟล์ที่มีอยู่ (ปรับ diagram, เพิ่ม step, แก้ business rule)
- **Validated** — รัน validation checklist (Case Analysis, MOM Validation, Lark Rules)
- **Asked User** — ถามผู้ใช้เพื่อ clarify ข้อมูล (actor, terminology, business rule)
- **Read Source** — อ่าน MOM/REQ/Others เพื่อดึงข้อมูล (บันทึกเฉพาะรอบแรกของแต่ละไฟล์)
- **Flagged Risk** — แจ้งผู้ใช้เรื่องความเสี่ยง (fraud, logic broken, missing validation)
- **Impact Analysis** — วิเคราะห์ผลกระทบจากข้อมูลใหม่

### Format

บันทึกใน `SystemFlow/REQ_Traceability_Matrix.md` section **Activity Log**:

```markdown
## Activity Log

| Timestamp | Session | Action | Target File | Detail | Result |
|-----------|---------|--------|-------------|--------|--------|
| YYYY-MM-DD HH:MM | S{NNN} | {Action Type} | {filename or —} | {สรุปสั้นๆ ว่าทำอะไร} | {ผลลัพธ์} |
```

### Field Definitions

| Field | Description | ตัวอย่าง |
|-------|-------------|---------|
| **Timestamp** | วันเวลาที่ทำ | `2026-03-09 14:30` |
| **Session** | Session ID (นับเริ่มจาก S001 ต่อ project) | `S001` |
| **Action** | ประเภท action (Created/Updated/Validated/Asked User/Read Source/Flagged Risk/Impact Analysis) | `Created` |
| **Target File** | ไฟล์ที่เกี่ยวข้อง หรือ `—` ถ้าไม่มี | `BOF-SysF-01_AdminLogin.puml` |
| **Detail** | สรุปสั้นๆ ว่าทำอะไร | `สร้าง System Flow V1 จาก REQ` |
| **Result** | ผลลัพธ์ | `DRAFT-V1` / `FINAL` / `Answered: 3 actors` / `PASS 20/20` |

### Session Numbering

- Session ID นับต่อ project — `S001`, `S002`, `S003`...
- Session ใหม่ = ทุกครั้งที่เริ่ม conversation ใหม่กับ Claude
- ถ้าไม่แน่ใจว่า session ปัจจุบันเป็นเลขอะไร → ดู Activity Log entry ล่าสุดแล้วนับต่อ

---

## Decision Log

> **บันทึกทุก decision สำคัญที่ผู้ใช้ตัดสินใจ** — ป้องกันการตัดสินใจซ้ำหรือขัดแย้งกัน

### When to Log

ทุกครั้งที่เกิด decision ใดๆ ต่อไปนี้:
- **Scope Decision** — เลือกว่าจะ include/exclude feature หรือ requirement
- **Design Decision** — เลือก approach, pattern, architecture
- **Conflict Resolution** — MOM ขัดแย้งกัน ผู้ใช้ตัดสินว่ายึดอันไหน
- **Risk Acceptance** — Claude flag ความเสี่ยง ผู้ใช้ตัดสินว่า accept/mitigate
- **Approval / Rejection** — ผู้ใช้ approve หรือ reject output ที่ Claude สร้าง
- **Terminology Decision** — เลือกว่าจะใช้คำศัพท์อะไร
- **Priority / Phase Decision** — เลือกว่า feature ไหนอยู่ phase ไหน

### Format — ADR-Enhanced Decision Log

> **อ้างอิง Architecture Decision Records (ADR) pattern จาก ECC** — เพิ่ม Alternatives Considered + Consequences เพื่อให้ตัดสินใจได้ดีขึ้นและป้องกันการตัดสินใจซ้ำ

บันทึกใน `SystemFlow/REQ_Traceability_Matrix.md` section **Decision Log**:

```markdown
## Decision Log

| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Consequences | Impact |
|------|------------|-------|-------------------|-------------|-----------|--------------|--------|
| YYYY-MM-DD | D{NNN} | {หัวข้อ} | {ตัวเลือกที่ Claude เสนอ} | {ผู้ใช้เลือกอะไร} | {เหตุผล} | {ผลที่ตามมา ทั้งดีและไม่ดี} | {ผลกระทบต่อ output} |
```

### Field Definitions

| Field | Description | ตัวอย่าง |
|-------|-------------|---------|
| **Date** | วันที่ตัดสินใจ | `2026-03-09` |
| **Decision ID** | D + เลข 3 หลัก (นับต่อ project) | `D001` |
| **Topic** | หัวข้อที่ตัดสินใจ | `Actor ของ Admin module` |
| **Options Presented** | ตัวเลือกที่ Claude เสนอ (ถ้ามี) | `1.Admin 2.SuperAdmin 3.แยกทั้งคู่` |
| **User Choice** | ผู้ใช้เลือกอะไร | `แยกทั้งคู่` |
| **Rationale** | เหตุผล (จากผู้ใช้ หรือ `—` ถ้าไม่ได้ระบุ) | `ลูกค้าต้องการแยก permission` |
| **Consequences** | ผลที่ตามมาจากการเลือก (ทั้ง positive + negative + trade-off) | `(+) permission ละเอียด, (-) UI ซับซ้อนขึ้น, (!) ต้องแก้ flow 3 ตัว` |
| **Impact** | ผลกระทบต่อ output ที่มีอยู่ | `แก้ SystemFlow 3 ไฟล์` |

### Consequences Format Guide

| Prefix | ความหมาย | ตัวอย่าง |
|--------|---------|---------|
| **(+)** | Positive consequence | `(+) ลดความเสี่ยง fraud` |
| **(-)** | Negative consequence / trade-off | `(-) เพิ่ม complexity ใน auth flow` |
| **(!)** | Action required / follow-up | `(!) ต้อง update UseCase UC-01` |

### เมื่อไหร่ต้องใส่ Consequences ละเอียด

| สถานการณ์ | ระดับ Consequences |
|----------|-------------------|
| Decision ง่าย (terminology, naming) | สั้น 1 บรรทัด หรือ `—` |
| Decision ปานกลาง (scope in/out, phase) | 2-3 บรรทัด (+/-/!) |
| **Decision สำคัญ** (architecture, flow structure, integration, compliance) | **สร้าง ADR Note แยก** (ดูด้านล่าง) |

### ADR Note — สำหรับ Decision สำคัญ

เมื่อ decision มีผลกระทบสูง (เปลี่ยน architecture, กระทบ > 5 modules, เกี่ยวกับ compliance/legal) → สร้าง ADR Note แนบใต้ Decision Log table:

```markdown
### ADR-D{NNN}: {Topic}

**Status:** Accepted | **Date:** YYYY-MM-DD | **Decider:** {ชื่อผู้ตัดสินใจ}

**Context:**
{ปัญหาหรือสถานการณ์ที่นำไปสู่การตัดสินใจ — 2-3 ประโยค}

**Decision:**
{สิ่งที่ตัดสินใจ — 1-2 ประโยค}

**Alternatives Considered:**
| # | Alternative | Pros | Cons | ทำไมไม่เลือก |
|---|-----------|------|------|-------------|
| 1 | {ทางเลือก A} | {ข้อดี} | {ข้อเสีย} | {เหตุผล} |
| 2 | {ทางเลือก B} | {ข้อดี} | {ข้อเสีย} | {เหตุผล} |

**Consequences:**
- (+) {positive outcomes}
- (-) {negative outcomes / trade-offs}
- (!) {required follow-up actions}

**Related:** D{NNN}, MOM#{X}, Module XX
```

**กฎ:** ADR Note บันทึกในไฟล์เดียวกัน (`REQ_Traceability_Matrix.md`) ใต้ Decision Log table — ไม่ต้องแยกไฟล์ เพื่อให้ทุกอย่างอยู่ที่เดียว

### Decision Cross-Reference

เมื่อ decision กระทบ output ที่มีอยู่:
1. Log ใน Decision Log ก่อน
2. Update Activity Log เมื่อแก้ไขไฟล์จริง (reference Decision ID ใน Detail column)
3. ถ้าเป็น decision ที่กระทบ agent behavior ข้าม session → update `CLAUDE.md` "Project-Specific Decisions" ด้วย

---

## REQ_Traceability_Matrix.md — Full Template

ไฟล์ `SystemFlow/REQ_Traceability_Matrix.md` ของแต่ละ project ต้องมี sections ครบดังนี้:

```markdown
# REQ Traceability Matrix — P{XX}-{CODE}

## MOM# Mapping
| MOM# | File | Date |
|------|------|------|

## Requirement Traceability
| Project | MOM | Item # | Requirement | Module | Diagram | Status |
|---------|-----|--------|-------------|--------|---------|--------|

## Wireframe Changes
| Date | Page/Component | Change Type | Description | MOM/CR Ref | File Changed |
|------|---------------|-------------|-------------|------------|--------------|

## Change Log
| Date | Source | Module | Action | File | Description | Status |
|------|--------|--------|--------|------|-------------|--------|

## Activity Log
| Timestamp | Session | Action | Target File | Detail | Result |
|-----------|---------|--------|-------------|--------|--------|

## Decision Log
| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Consequences | Impact |
|------|------------|-------|-------------------|-------------|-----------|--------------|--------|

<!-- ADR Notes สำหรับ Decision สำคัญ ใส่ต่อจาก table ด้านบน -->
```
