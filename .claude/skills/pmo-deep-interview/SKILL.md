---
name: Deep Interview
description: Socratic requirements clarification พร้อม Ambiguity Scoring — ใช้กับ project ใหม่ที่ requirements ยังไม่ชัด หรือเมื่อ MOM/REQ มีจุดคลุมเครือมาก ช่วยให้ PM ถามคำถามที่ถูกต้องก่อนเริ่มสร้าง diagram
---

# PMO Skill: Deep Interview — Requirements Clarification

> **อ้างอิง OMC (oh-my-claudecode) deep-interview skill** — ปรับให้เข้ากับ PMO workflow
> **Related Skills:**
> - Load `pmo-traceability` เพื่อ log decisions + activity
> - Load `pmo-activity-diagram` เมื่อ interview เสร็จแล้วจะสร้าง diagram

---

## Purpose

Skill นี้ช่วย PM clarify requirements ก่อนเริ่ม Pipeline 8 ขั้นตอน เมื่อ:
- Project ใหม่ที่เพิ่งได้ MOM แรก
- MOM/REQ มีจุดคลุมเครือมาก (> 3 จุดที่ไม่ชัดเจน)
- Stakeholder หลายฝ่ายที่อาจมี requirements ขัดแย้ง
- Domain ที่ AI/PM ไม่คุ้นเคย

**ปัญหาที่ skill นี้แก้:**
- เริ่มสร้าง diagram ทั้งที่ requirements ยังไม่ชัด → ต้องแก้ซ้ำหลายรอบ
- PM ไม่รู้ว่าต้องถามลูกค้าเรื่องอะไรอีก
- Gold Plating เพราะ AI สมมติ requirement แทนที่จะถาม

---

## Ambiguity Scoring System

> **ก่อนเริ่มสร้าง diagram AI ต้องประเมิน Ambiguity Score ก่อน**
> ถ้า score > 20% → ต้องทำ Deep Interview ก่อน ห้ามเริ่ม diagram

### 5 Dimensions

| Dimension | คำถามที่ใช้วัด | Score Range |
|-----------|---------------|:-----------:|
| **Goal Clarity** | รู้ไหมว่าระบบนี้แก้ปัญหาอะไร? ใครเป็น primary user? | 0-20% |
| **Scope Clarity** | รู้ไหมว่า feature ไหนอยู่ใน scope? phase ไหน? | 0-20% |
| **Constraint Clarity** | รู้ไหมว่ามี budget/timeline/tech constraint อะไร? | 0-20% |
| **Success Criteria** | รู้ไหมว่า "เสร็จ" แปลว่าอะไร? KPI อะไร? | 0-20% |
| **Context Clarity** | รู้ไหมว่ามีระบบเดิม (brownfield) หรือทำใหม่ (greenfield)? มี integration อะไร? | 0-20% |

### Scoring

| Score | ความหมาย | Action |
|:---:|---|---|
| **0-20%** | Ambiguity ต่ำ — requirements ชัดเจน | ข้ามไปเริ่ม Pipeline ได้เลย |
| **21-40%** | Ambiguity ปานกลาง — มีจุดไม่ชัดบางจุด | ทำ Quick Interview (3-5 คำถาม) |
| **41-60%** | Ambiguity สูง — ต้อง clarify หลายจุด | ทำ Full Interview (8-15 คำถาม) |
| **61-100%** | Ambiguity สูงมาก — ยังไม่พร้อมสร้าง diagram | ทำ Deep Interview + แนะนำนัดประชุมลูกค้าเพิ่ม |

---

## Workflow

### Step 1: Assess Ambiguity

อ่าน MOM + REQ ทั้งหมดของ project แล้วให้คะแนน:

```markdown
## Ambiguity Assessment — P{XX}-{CODE}

| Dimension | Score | เหตุผล | คำถามที่ต้องถาม |
|-----------|:---:|---|---|
| Goal Clarity | {X}% | {ทำไมให้คะแนนนี้} | {คำถามที่ช่วย clarify} |
| Scope Clarity | {X}% | ... | ... |
| Constraint Clarity | {X}% | ... | ... |
| Success Criteria | {X}% | ... | ... |
| Context Clarity | {X}% | ... | ... |
| **Total Ambiguity** | **{X}%** | | |

**Recommendation:** {ข้ามได้ / Quick Interview / Full Interview / Deep Interview + นัดประชุม}
```

### Step 2: Generate Questions (ถ้า score > 20%)

**จัดคำถามตาม dimension ที่ score สูงสุด (ถามด้าน unclear ก่อน):**

กฎการถาม:
1. **ถามทีละ 1-2 คำถาม** — ห้ามถามรวดเดียว 10 คำถาม
2. **ถามแบบ Socratic** — ชวนคิด ไม่ใช่ yes/no
3. **อ้างอิง source** — "จาก MOM#1 ข้อ 1.3 ระบุว่า... แต่ไม่ชัดว่า..."
4. **เสนอตัวเลือก** — "เป็นแบบ A หรือ B?" ไม่ใช่ "เป็นยังไง?"
5. **ถาม follow-up** — ถ้าคำตอบนำไปสู่คำถามใหม่

### Question Templates by Dimension

**Goal Clarity:**
- "จาก MOM#X ระบบนี้แก้ปัญหาอะไรเป็นหลัก? {A} หรือ {B}?"
- "Primary user คือใคร? ใช้งานยังไง? (use case หลัก)"
- "ถ้าระบบนี้สำเร็จ ลูกค้าจะวัดผลจากอะไร?"

**Scope Clarity:**
- "Feature X ที่พูดใน MOM#Y — อยู่ใน Phase 1 ไหม?"
- "มี feature ไหนที่ 'มีก็ดี แต่ไม่ต้องก็ได้' (nice-to-have)?"
- "Platform ไหนบ้างที่ต้องรองรับ? (Web/Mobile/BOF)"

**Constraint Clarity:**
- "มี deadline เมื่อไหร่? มี hard deadline ไหม?"
- "มี tech stack ที่กำหนดแล้วไหม? หรือเลือกได้?"
- "มี budget constraint สำหรับ infrastructure ไหม?"

**Success Criteria:**
- "'เสร็จ' แปลว่าอะไร? ลูกค้า accept ตอนไหน?"
- "มี KPI ที่ต้อง track ไหม? (เช่น response time, concurrent users)"
- "UAT criteria คืออะไร?"

**Context Clarity:**
- "มีระบบเดิมที่ต้อง migrate/integrate ไหม?"
- "มี 3rd party ที่ต้องเชื่อมต่อไหม? (Payment, SMS, etc.)"
- "Data เดิมที่ต้อง import มีไหม?"

### Step 3: Log Results

**ทุก answer จาก PM/User ต้อง:**
1. Log ลง Decision Log (ถ้าเป็น decision)
2. Log ลง Change Log (ถ้าเป็น new info)
3. Update Ambiguity Score
4. ถ้า score < 20% → แจ้ง "พร้อมเริ่ม Pipeline แล้ว"

### Step 4: Generate Interview Summary

เมื่อ interview เสร็จ:

```markdown
## Deep Interview Summary — P{XX}-{CODE}
**วันที่:** YYYY-MM-DD | **Ambiguity: {Before}% → {After}%**

### Key Findings
1. {Finding 1 — จากคำถาม X}
2. {Finding 2 — จากคำถาม X}

### Decisions Made
| # | Topic | Decision | Rationale |
|---|-------|----------|-----------|

### Open Questions (ต้องถามลูกค้าอีก)
| # | คำถาม | ถามใคร | Priority |
|---|-------|--------|:---:|
| 1 | {คำถามที่ PM/AI ตอบไม่ได้} | {ชื่อลูกค้า/stakeholder} | H/M/L |

### Ready to Start
- [ ] Ambiguity Score < 20%
- [ ] Open Questions ที่ priority H ได้คำตอบหมดแล้ว
- [ ] PM confirm ว่า scope ครบ
```

---

## Auto-Trigger

AI ต้องเสนอ Deep Interview อัตโนมัติเมื่อ:
- Project ใหม่ (มีแค่ MOM#1)
- MOM มี "TBD", "ยังไม่แน่ใจ", "ต้อง confirm อีกที" > 3 จุด
- REQ มี column ที่ว่าง > 20%
- PM พูดว่า "ไม่แน่ใจ", "ยังไม่ชัด", "ต้องถามลูกค้า"

---

## Do's and Don'ts

### Do's
1. ถามทีละ 1-2 คำถาม ไม่ใช่ทีเดียว 10 ข้อ
2. อ้างอิง MOM/REQ เสมอเมื่อถาม
3. เสนอ options ให้เลือก (A/B/C) ไม่ใช่ open-ended
4. Log ทุกคำตอบลง Traceability Matrix ทันที
5. Update Ambiguity Score หลังทุก round ของคำถาม

### Don'ts
1. ห้ามเริ่มสร้าง diagram ถ้า Ambiguity > 20%
2. ห้ามถามคำถามที่ MOM/REQ ตอบอยู่แล้ว (อ่านให้ครบก่อน)
3. ห้ามสมมติคำตอบ — ถ้า PM ไม่รู้ ให้ใส่ใน Open Questions
4. ห้ามทำ interview ยาวเกินไป (max 15 คำถามต่อ session)
