---
name: Proposal Writer
description: สร้าง Project Proposal / Quotation สำหรับส่งลูกค้า โดยอ้างอิงจาก MOM, REQ, WBS, และข้อมูล project ที่มี — ครอบคลุม Executive Summary, Scope of Services, System Architecture, Timeline, Pricing, Payment Terms, Terms and Conditions ต้อง load skill นี้ทุกครั้งที่ผู้ใช้พูดถึง "proposal", "ใบเสนอราคา", "quotation", "เสนอโครงการ", "เขียน proposal", "ส่งลูกค้า", หรือต้องการสร้างเอกสารเสนอโครงการ
---

# PMO Skill: Proposal Writer

> **Related Skills:**
> - Load `pmo-task-breakdown` เมื่อต้องสร้าง WBS/Gantt ประกอบ Proposal
> - Load `pmo-traceability` เมื่อต้อง log การสร้าง Proposal ลง Activity Log
> - Load `references/proposal-checklist.md` สำหรับ checklist ก่อนส่งลูกค้า
> - Load `references/win-theme-guide.md` สำหรับ framework การเขียน Win Theme
> - Load `references/pricing-template.md` สำหรับ template ตาราง pricing

---

## 1. เมื่อไหร่ต้องใช้ Skill นี้

ใช้เมื่อต้องสร้างเอกสารที่จะ **ส่งให้ลูกค้าเพื่อตัดสินใจ** เช่น:
- Project Proposal (ข้อเสนอโครงการ)
- Quotation (ใบเสนอราคา)
- POC Proposal (ข้อเสนอ Proof of Concept)
- Change Request Proposal (ข้อเสนอเปลี่ยน scope)

---

## 2. ถามก่อนเสมอ (Pre-requisites)

ก่อนเริ่มเขียน Proposal ต้องถามผู้ใช้:

| คำถาม | ทำไมต้องถาม |
|-------|------------|
| กำลังทำ **project ไหน**? | เพื่อดึงข้อมูลจาก folder ที่ถูกต้อง |
| Proposal นี้ **ส่งใคร**? (ชื่อบริษัท, ชื่อผู้ติดต่อ) | ใช้ใน header และ personalize เนื้อหา |
| **ภาษา** หลักของ Proposal? (ไทย/อังกฤษ/ทั้งสอง) | กำหนด tone และ format |
| มี **WBS/Pricing** เสร็จแล้วหรือยัง? | ถ้ายังไม่มี ต้องสร้างก่อนหรือพร้อมกัน |
| **Option** ที่จะเสนอมีกี่ตัวเลือก? | เช่น Option A/B/B Lite |
| มี **ข้อกำหนดพิเศษ** ไหม? (NDA, Non-compete, Warranty) | ใส่ใน Terms and Conditions |

---

## 3. ขั้นตอนการทำงาน (Workflow)

### Step 1: รวบรวมข้อมูล (Source-Driven)

อ่านไฟล์ตามลำดับนี้:

| ลำดับ | อ่านอะไร | เอาอะไรมา |
|:-----:|----------|----------|
| 1 | `MOM/` ทุกฉบับ | Business context, Pain points, สิ่งที่ตกลงกับลูกค้า |
| 2 | `REQ/` | Feature list, Scope |
| 3 | `Others/` (WBS, Pricing, Gap Analysis) | Effort, Timeline, ราคา, ความเสี่ยง |
| 4 | `MOM/Transcription/` (ถ้ามี) | Domain knowledge, ความคาดหวังลูกค้า |

**ห้ามเขียน Proposal โดยไม่อ่าน source file** — ทุกข้อความต้องมีที่มาจากเอกสาร

### Step 2: สร้าง Win Themes (3-5 ข้อ)

Win Theme คือ ข้อความที่เชื่อม **ปัญหาของลูกค้า** กับ **ความสามารถของเรา** อย่างเฉพาะเจาะจง

ข้อความที่อ่อน vs แข็ง:
- อ่อน: "เรามีประสบการณ์ด้าน AI"
- แข็ง: "ระบบ AI Visual Search ของเราค้นหาอะไหล่จากภาพได้ภายในวินาที ลดเวลาจากที่เคยใช้ 5-10 นาทีต่อรายการ"

ดูรายละเอียดเพิ่มที่ `references/win-theme-guide.md`

### Step 3: เขียน Proposal ตาม 3-Act Structure

**Act I — เข้าใจปัญหา (2-3 paragraphs)**
- สะท้อนสถานการณ์ปัจจุบันของลูกค้าด้วยภาษาของเขา (จาก MOM)
- ระบุ Pain Points ที่ชัดเจน (จาก REQ/MOM)
- แสดงว่าเราเข้าใจ context ของเขา ไม่ใช่ copy จาก template

**Act II — ทางออก (หัวข้อ 3-5 ของ Proposal)**
- Scope of Services: ระบุสิ่งที่ทำและไม่ทำ
- System Architecture: อธิบายเข้าใจง่าย ใช้ diagram ประกอบ
- Timeline: แสดง phase และ milestone ชัดเจน
- ทุก feature ต้องเชื่อมกลับไปที่ pain point ใน Act I

**Act III — ภาพอนาคต (Executive Summary + Closing)**
- ผลลัพธ์ที่วัดได้ (ลดเวลา X%, ประหยัด Y บาท/เดือน)
- ROI analysis (ถ้ามีข้อมูล)
- Timeline milestone ที่ลูกค้าจะเห็นผลแรก

### Step 4: จัดทำ Pricing Section

ใช้ format ตาม `references/pricing-template.md`:
- ตารางหลัก: ลำดับ | รายการ | งบประมาณ
- Payment Terms: แบ่งเป็นงวด (Milestone-based)
- หมายเหตุ: สิ่งที่ไม่รวม (Hardware, Cloud API, VAT)

**ราคาต้องมาหลังการสร้าง value เสมอ** — ผู้อ่านต้องเข้าใจคุณค่าก่อนเห็นตัวเลข

### Step 5: Validate ด้วย Checklist

รัน checklist จาก `references/proposal-checklist.md` ก่อนส่ง

---

## 4. โครงสร้าง Proposal (Template)

```markdown
# ข้อเสนอโครงการ (Project Proposal)

**โครงการ:** [ชื่อโครงการ]
**นำเสนอ:** [ชื่อบริษัทลูกค้า]
**เลขที่เอกสาร:** PRO-YYYY-NNN_RX
**จัดทำโดย:** [ชื่อบริษัทเรา]
**วันที่:** [วันที่จัดทำ]

---

## 1. บทสรุปผู้บริหาร (Executive Summary)
[1 หน้า — สะท้อนปัญหา → ทางออกของเรา → ผลลัพธ์ที่คาดหวัง]

## 2. สถานการณ์ปัจจุบันและปัญหา (Current Situation and Pain Points)
[Pain points 3-5 ข้อ จาก MOM/REQ]

## 3. ขอบเขตและฟังก์ชันการทำงาน (Scope of Services)
### 3.1 [Module/Component A]
### 3.2 [Module/Component B]

## 4. สถาปัตยกรรมระบบ (System Architecture)
[Diagram + คำอธิบายสั้น]

## 5. แผนการดำเนินงาน (Project Timeline)
[Phase breakdown + Gantt ถ้ามี]

## 6. ข้อเสนอด้านราคา (Commercial Proposal)
[ตาราง pricing + หมายเหตุ]

## 7. เงื่อนไขการชำระเงิน (Payment Terms)
[ตาราง milestone-based payments]

## 8. เงื่อนไขและข้อกำหนดเพิ่มเติม (Terms and Conditions)
### 8.1 ขอบเขตความรับผิดชอบข้อมูล
### 8.2 การรับประกันและสิทธิ์ในข้อมูล
### 8.3 ข้อตกลงเฉพาะโครงการ
### 8.4 ขอบเขตความปลอดภัย
```

---

## 5. Content Quality Rules

- **ห้ามใช้คำกว้างไม่มีหลักฐาน** เช่น "ทันสมัย", "ครบวงจร", "ชั้นนำ" — ต้องมี metric หรือ case study
- **ทุก claim ต้องมี evidence** จาก MOM/REQ/WBS หรือ technical fact
- **ห้ามเพิ่ม feature ที่ไม่ได้ตกลง** (No Gold Plating) — ตาม AGENTS.md ข้อ 3.4
- **Terminology ต้องตรงกับ MOM/REQ** — ตาม AGENTS.md ข้อ 3.5
- **ราคาต้องอ้างอิง WBS** — ห้ามกำหนดราคาเอง
- **อ้างอิง MOM#** ทุกครั้งที่อ้างสิ่งที่ตกลง

---

## 6. Output Format

บันทึก Proposal ที่ `./{ProjectFolder}/Others/Proposal/` โดยใช้ naming:
```
YYYYMMDD_Project-Proposal_{ProjectCode}_RX.md
```
ตัวอย่าง: `20260318_Project-Proposal_PROJECT-AI_R2.md`

หากต้องการเป็น .docx ให้ใช้ร่วมกับ docx skill

---

## 7. Traceability

หลังสร้าง Proposal เสร็จ ต้อง:
1. Log ลง Activity Log: `Created | Proposal RX | [รายละเอียด]`
2. Log ลง Change Log: ถ้าเป็น Revision ต้องระบุว่าเปลี่ยนอะไรจาก version ก่อน
