---
name: Quality Gate
description: Pre/Post execution validation + Phase Gate enforcement — ป้องกันการข้าม step, auto-validate output, ให้คะแนน quality score
---

# PMO Skill: Quality Gate

> **Purpose:** Enforce quality at every step — ไม่มี output ไหนออกไปโดยไม่ผ่าน gate
> ดึง concept จาก Super-Claude quality-gate.mjs + ปรับให้เข้ากับ PMO 8-step pipeline

---

## 1. Three Gate Types

### 1.1 Pre-Gate (ก่อน execute skill)

> **ตรวจว่ามี prerequisites ครบก่อนเริ่มทำงาน**

| Skill ที่จะรัน | Pre-Gate Check | ถ้าไม่ผ่าน |
|---------------|----------------|-----------|
| `pmo-activity-diagram` | มี REQ + MOM ใน project folder? | BLOCK — แจ้ง "ยังไม่มี source file" |
| `pmo-activity-diagram` | ถามแล้วหรือยัง ว่ามี Actor กี่ตัว? | BLOCK — ถาม Actor ก่อน |
| `pmo-use-case-diagram` | มี SystemFlow หรือ UserFlow อย่างน้อย 1 ไฟล์? | WARN — "ยังไม่มี flow, สร้าง UC จาก REQ อย่างเดียวอาจไม่ครบ" |
| `pmo-wireframe-design` | มี SystemFlow ที่เป็น Final (ไม่มี DRAFT)? | BLOCK — "ต้อง finalize SystemFlow ก่อน" |
| `pmo-dev-handoff` | SystemFlow ทุกไฟล์เป็น Final? PM confirm scope? | BLOCK — "ต้อง validate ทุก flow ก่อน handoff" |
| `pmo-code-scaffold` | มี Dev Handoff Package แล้ว? | BLOCK — "ต้องสร้าง handoff ก่อน scaffold" |
| `pmo-ci-cd-template` | มี tech stack info (language, framework, DB)? | ASK — ถาม tech stack |
| `pmo-deploy-checklist` | มี CI/CD config แล้ว? | WARN — "ยังไม่มี CI/CD, สร้างก่อนจะได้ checklist ครบ" |
| `pmo-task-breakdown` | ถาม timeline/start date/milestones แล้ว? | BLOCK — ถาม timeline ก่อน |
| `pmo-gap-analysis` | มี REQ + Diagram อย่างน้อย 1 ชุด? | BLOCK — "ต้องมีทั้ง REQ และ diagram" |

### 1.2 Post-Gate (หลัง execute skill)

> **ตรวจ quality ของ output ที่เพิ่งสร้าง แล้วให้คะแนน**

#### Quality Score (0.0 - 1.0)

| Score | Label | Action |
|:-----:|-------|--------|
| 0.0 - 0.4 | FAIL | REWORK — ต้องแก้ไขก่อนส่ง |
| 0.5 - 0.7 | REVIEW | แจ้ง user ว่ามีจุดที่ควรตรวจ |
| 0.8 - 1.0 | PASS | พร้อมส่ง / finalize |

#### Scoring Criteria per Output Type

**Activity Diagram (.puml):**

| Criteria | Weight | Check |
|----------|:------:|-------|
| Lark 11 Rules compliance | 0.25 | ทุก rule ผ่าน? |
| Case Analysis 20 items | 0.25 | ผ่านกี่ข้อจาก 20? |
| MOM Validation 7 items | 0.20 | ผ่านกี่ข้อจาก 7? |
| Naming Convention | 0.10 | ชื่อไฟล์ถูก format? |
| MOM Reference in title | 0.10 | มี [Ref: MOM#X]? |
| Sequential numbering | 0.10 | Step numbering ต่อเนื่อง? |

**Task Breakdown (.md):**

| Criteria | Weight | Check |
|----------|:------:|-------|
| ครอบคลุม REQ ทุกข้อ | 0.30 | map task กับ REQ ครบ? |
| Timeline สมเหตุสมผล | 0.20 | ไม่มี task overlap ที่ขัดแย้ง? |
| Dependencies ถูกต้อง | 0.20 | task ที่ depend กันเรียงลำดับถูก? |
| Gantt chart ตรงกับ table | 0.15 | ข้อมูลตรงกัน? |
| MOM/REQ reference | 0.15 | อ้างอิง source? |

**Dev Handoff Package:**

| Criteria | Weight | Check |
|----------|:------:|-------|
| Data Model ครบ | 0.20 | ทุก entity จาก SystemFlow มี? |
| API Spec ครบ | 0.20 | ทุก action มี endpoint? |
| Component Inventory | 0.15 | ทุกหน้าจอมี component list? |
| Security Checklist | 0.15 | auth/authz/validation ครบ? |
| Analytics Spec | 0.15 | tracking events defined? |
| UX Copy | 0.15 | error messages + labels? |

### 1.3 Phase Gate (ก่อนข้ามขั้นตอน Pipeline)

> **ตรวจว่า step ก่อนหน้าเสร็จสมบูรณ์ก่อนไปต่อ**

| Current Step | ต้องมีก่อน (Prerequisites) | Gate Action |
|-------------|--------------------------|-------------|
| Step 4: UserFlow | Step 3 done (REQ extracted) | ตรวจว่ามี REQ file ที่ parsed แล้ว |
| Step 5: Validate w/ User | Step 4 done (UserFlow created) | ตรวจว่ามี UserFlow [DRAFT] |
| Step 6: UseCase QA | Step 5 done (UserFlow approved) | ตรวจว่า UserFlow ไม่มี [DRAFT] ใน title |
| Step 7: SystemFlow | Step 6 done (UseCase created) | ตรวจว่ามี UseCase + UserFlow Final |
| Step 8: Wireframe | Step 7 done (SystemFlow Final) | ตรวจว่า SystemFlow ไม่มี [DRAFT] |
| Handoff | Step 8 done (Wireframe done) | ตรวจว่า Wireframe + SystemFlow Final ครบ |

**Gate Enforcement:**
- **BLOCK**: ไม่ให้ทำ step ถัดไปเลย + แจ้ง user ว่าต้องทำ step ก่อนหน้าให้เสร็จ
- **WARN**: แจ้ง user แต่ให้เลือกได้ว่าจะข้ามหรือไม่ (กรณี urgent)
- **Log**: บันทึกลง Activity Log ทุกครั้งที่ gate trigger

---

## 2. Auto-Validate Flow

```
User Request
    ↓
[Pre-Gate] → BLOCK/WARN/PASS
    ↓ (PASS)
Execute Skill
    ↓
[Post-Gate] → Score 0.0-1.0
    ↓
FAIL (< 0.5)  → Auto-fix + Re-score
REVIEW (0.5-0.7) → แจ้ง user จุดที่ควรตรวจ
PASS (>= 0.8) → Ready for next step
    ↓
[Phase Gate] → ตรวจ pipeline position
    ↓
Next Step
```

---

## 3. Gate Override

ผู้ใช้สามารถ override gate ได้โดย:
- พูดว่า "ข้าม gate" หรือ "skip validation" → AI จะแจ้ง warning + log Decision Log แล้วทำต่อ
- Gate override ต้อง log เป็น Decision Log entry เสมอ (rationale: user override)

---

## 4. Integration with Existing Validation

Quality Gate **ไม่ได้แทนที่** validation เดิม แต่ **ทำงานร่วมกัน:**

- `pmo-review-diagram` (38-point checklist) = **detailed validation** → ผู้ใช้ต้อง trigger เอง
- `pmo-quality-gate` = **automated quick check** → trigger อัตโนมัติทุกครั้งที่สร้าง/แก้ output

ผล Quality Gate score จะรวม subset ของ 38-point checklist ที่ตรวจอัตโนมัติได้ (ไม่รวมข้อที่ต้อง human judgment)
