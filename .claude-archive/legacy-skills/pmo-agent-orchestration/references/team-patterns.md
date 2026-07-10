# Agent Team Patterns — Persona-Based Task Configurations

> Pattern สำเร็จรูปสำหรับงานที่พบบ่อย ใช้เป็น template เวลาจัดทีม
> **ทุก pattern ใช้ Persona System** — ดู `personas/` folder สำหรับรายละเอียดแต่ละคน

---

## Pattern 1: New Module — Full Output Set

**เมื่อไหร่:** สร้าง diagram ครบชุดสำหรับ module ใหม่ (SystemFlow + UserFlow + UseCase)

```
ลีด (Lead)
+-- อันนาลิส (Analyst)    -> สรุป requirement จาก MOM + REQ + Transcription
+-- อาร์คิเทค (Architect)   -> ออกแบบ workflow spec + flow structure
+-- ไรท์เตอร์ (Writer) x2   -> เขียน SystemFlow + UseCase
+-- รีวิว (Reviewer)     -> ตรวจ output ด้วย checklist 20+7+7
```

**Handoff Chain:**
```
อันนาลิส → ลีด → อาร์คิเทค → ลีด → ไรท์เตอร์ x2 (parallel) → ลีด → รีวิว→ ลีด → User
```

**ลำดับ:**
1. อันนาลิส อ่าน MOM + REQ + Transcription → Handoff: findings + gaps + MOM# refs
2. ลีด review findings → ส่งต่อให้ อาร์คิเทค พร้อม analyst handoff
3. อาร์คิเทค ออกแบบ workflow spec → Handoff: flow structure + actor list + edge cases
4. ลีด review spec → ส่งต่อให้ ไรท์เตอร์ x2 พร้อม architect handoff
5. ไรท์เตอร์ x2 เขียน SystemFlow + UseCase (parallel) → Handoff: ไฟล์ .puml + MOM# refs
6. ลีด review output → ส่งต่อให้ รีวิวพร้อม writer handoff + spec + findings
7. รีวิวตรวจ checklist → Handoff: ผลตรวจ (ผ่าน/ไม่ผ่าน + จุดที่ต้องแก้)
8. ลีด merge + present ให้ user

---

## Pattern 2: New MOM Impact Analysis

**เมื่อไหร่:** ได้ MOM ใหม่มา ต้องวิเคราะห์ผลกระทบ

```
ลีด (Lead)
+-- อันนาลิส (Analyst)    -> อ่าน MOM ใหม่ + เทียบ MOM เก่า + Transcription
+-- อาร์คิเทค (Architect)   -> เทียบ MOM ใหม่กับ diagram ที่มี → หา impact
+-- ซีเคียว (Security)   -> ตรวจ business logic ที่มีความเสี่ยงจาก MOM ใหม่
```

**Handoff Chain:**
```
อันนาลิส + อาร์คิเทค + ซีเคียว (parallel) → ลีด (merge) → Impact Report → User
```

**ลำดับ:**
1. ทั้ง 3 ทำพร้อมกัน (parallel) → แต่ละคนส่ง Handoff Report
2. ลีด รวม handoff ทั้ง 3 เป็น Impact Report
3. Present ให้ user ตัดสินใจ

---

## Pattern 3: Gap Analysis — Full Scan

**เมื่อไหร่:** ตรวจ coverage ทั้ง project

```
ลีด (Lead)
+-- อันนาลิส (Analyst)    -> list REQ ทั้งหมด + จัดกลุ่มตาม module
+-- ไรท์เตอร์ (Writer)      -> scan SystemFlow/, UserFlow/, UseCase/ ทั้งหมด (ใช้เป็น Code Explorer)
+-- รีวิว (Reviewer)     -> cross-reference REQ กับ diagram list
```

**Handoff Chain:**
```
อันนาลิส + ไรท์เตอร์ (parallel) → ลีด → รีวิว→ ลีด → Gap Report → User
```

**ลำดับ:**
1. อันนาลิส + ไรท์เตอร์ ทำพร้อมกัน → Handoff: REQ list + diagram list
2. ลีด review → ส่งต่อให้ รีวิวพร้อม handoff ทั้งสอง
3. รีวิวcross-reference → Handoff: gaps found + coverage %
4. ลีด สรุป Gap Report → present ให้ user

---

## Pattern 4: Task Breakdown Creation

**เมื่อไหร่:** สร้าง Task Breakdown + Gantt Chart

```
ลีด (Lead)
+-- อันนาลิส (Analyst)    -> สรุป scope + timeline จาก MOM
+-- ไรท์เตอร์ (Writer)      -> เขียน Task Breakdown + Gantt จาก findings
```

**Handoff Chain:**
```
อันนาลิส → ลีด → (ถาม user timeline) → ไรท์เตอร์ → ลีด → User
```

**ลำดับ:**
1. อันนาลิส อ่าน MOM + REQ → Handoff: scope summary + module list + effort estimate
2. ลีด review → **ถาม user เรื่อง timeline** (วันเริ่ม, milestone, phase)
3. ไรท์เตอร์ เขียน Task Breakdown + Gantt → Handoff: .md file + สรุป
4. ลีด review + present ให้ user

---

## Pattern 5: Simple — Single Persona

**เมื่อไหร่:** งานเล็กที่ต้องการแค่ research หรือ review

**Research:**
```
ลีด (Lead)
+-- อันนาลิส (Analyst)    -> ค้นหาข้อมูล + สรุปให้ user verify
```

**Review:**
```
ลีด (Lead)
+-- รีวิว (Reviewer)     -> ตรวจ diagram 1 ไฟล์ด้วย checklist
```

**Handoff Chain:**
```
{persona} → ลีด (review) → User
```

---

## Pattern 6: Wireframe Design (New)

**เมื่อไหร่:** ออกแบบ UI Wireframe จาก SystemFlow ที่เสร็จแล้ว

```
ลีด (Lead)
+-- อันนาลิส (Analyst)    -> สรุป requirement ที่เกี่ยวกับ UI จาก MOM/REQ
+-- ไรท์เตอร์ (Writer)      -> ออกแบบ wireframe ใช้ Refero MCP
+-- รีวิว (Reviewer)     -> ตรวจ wireframe ตรง SystemFlow ไหม
```

**Handoff Chain:**
```
อันนาลิส → ลีด → ไรท์เตอร์ → ลีด → รีวิว→ ลีด → User
```

---

## Pattern 7: Dev Handoff Package (New)

**เมื่อไหร่:** สร้าง spec สำหรับส่งมอบให้ Dev

```
ลีด (Lead)
+-- อันนาลิส (Analyst)    -> รวม requirement ทั้งหมด + decision log
+-- อาร์คิเทค (Architect)   -> ออกแบบ Data Model + API Spec
+-- ไรท์เตอร์ (Writer)      -> เขียน Handoff Package (Components, Roadmap, Security, UX Copy)
+-- ซีเคียว (Security)   -> ตรวจ Security Checklist
```

**Handoff Chain:**
```
อันนาลิส → ลีด → อาร์คิเทค + ไรท์เตอร์ (parallel) → ลีด → ซีเคียว → ลีด → User
```

---

## Decision Guide — เลือก Pattern ไหน

| สถานการณ์ | Pattern | Personas | Handoff Steps |
|----------|---------|----------|---------------|
| สร้าง module ใหม่ครบชุด | Pattern 1 | 5 (อันนาลิส→อาร์คิเทค→ไรท์เตอร์x2→รีวิว) | 8 |
| ได้ MOM ใหม่มา | Pattern 2 | 3 (อันนาลิส+อาร์คิเทค+ซีเคียว) | 3 |
| ตรวจ coverage ทั้ง project | Pattern 3 | 3 (อันนาลิส+ไรท์เตอร์→รีวิว) | 5 |
| สร้าง Task Breakdown | Pattern 4 | 2 (อันนาลิส→ไรท์เตอร์) | 4 |
| Research/Review อย่างเดียว | Pattern 5 | 1 | 2 |
| ออกแบบ Wireframe | Pattern 6 | 3 (อันนาลิส→ไรท์เตอร์→รีวิว) | 6 |
| สร้าง Dev Handoff | Pattern 7 | 4 (อันนาลิส→อาร์คิเทค+ไรท์เตอร์→ซีเคียว) | 6 |
| แก้ typo / syntax | ไม่ต้องใช้ team | 0 | 0 |
