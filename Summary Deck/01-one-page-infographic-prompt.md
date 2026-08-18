# Prompt: One-Page Infographic (Axiom-PMO)

ไฟล์นี้เก็บ prompt สำหรับส่งให้เครื่องมือออกแบบ (เช่น Claude Design) เพื่อสร้าง
one-page infographic ที่อธิบายกระบวนการทั้งหมดของ Axiom-PMO อย่างถูกต้อง
ตรงกับสิ่งที่ repo นี้ทำจริง (อ้างอิงจาก `README.md` ของ repo ณ v2.2.0)

คัดลอกข้อความในกรอบด้านล่างทั้งหมดไปวางใน Claude Design ได้เลย

---

## Prompt (คัดลอกทั้งหมดนี้)

```
สร้าง one-page infographic เพื่ออธิบาย "Axiom-PMO" ให้คนที่ไม่เคยรู้จักเข้าใจ
ภาพรวมทั้งหมดได้ภายในการดูครั้งเดียว

## บริบท / ผู้ชม
- ผู้ชม: ทีมพัฒนาซอฟต์แวร์, Product Manager, Tech Lead ที่กำลังพิจารณานำ
  Axiom-PMO ไปใช้ในทีม
- วัตถุประสงค์: ให้เข้าใจ "มันคืออะไร แก้ปัญหาอะไร ทำงานเป็นขั้นตอนยังไง" —
  เป็นสื่อให้ความรู้ (educational) ไม่ใช่สื่อขาย
- โทน: มืออาชีพ น่าเชื่อถือ เป็นระบบ (governance / engineering feel) ไม่ใช่
  playful หรือ startup-hype

## ข้อมูลจริงที่ต้องใช้ (ห้ามแต่งเติมหรือเดาข้อมูลใหม่นอกเหนือจากนี้)

**ชื่อผลิตภัณฑ์:** Axiom-PMO

**Tagline (ใช้คำนี้เท่านั้น อย่าแต่งคำใหม่):**
"The governance control plane for AI-assisted software delivery."
(คำแปลไทยแนะนำ: "ศูนย์กลางกำกับดูแลงานพัฒนาซอฟต์แวร์ที่มี AI ร่วมทำงาน")

**ปัญหาที่แก้ (ประโยคหลัก ใช้เป็น hook ของภาพ):**
"AI agents can write code. They should not invent the project." — AI เขียน
โค้ดเก่ง แต่ไม่ควรเป็นคนกำหนด requirement, scope หรืออนุมัติงานของตัวเอง
Axiom-PMO คือกลไกที่กันไม่ให้ AI agent "คิดเอง" นอกเหนือจากสิ่งที่มีหลักฐานจริง

**Axiom-PMO ทำอะไร / ไม่ทำอะไร (ต้องมีตาราง 2 คอลัมน์นี้ในภาพ):**

ทำ:
- แปลงต้นฉบับ (MOM / Transcript / Requirement) ให้กลายเป็น requirement ที่
  ตรวจสอบย้อนกลับได้ (traceable)
- ตรวจสอบความพร้อมของ design และความครบถ้วนของ handoff
- ตรวจสอบ scope, test, หลักฐาน และสิทธิ์การอนุมัติ
- ตรวจสอบว่าสิ่งที่ AI รายงานว่าทำ ตรงกับสถานะจริงใน repository หรือไม่

ไม่ทำ:
- ไม่เขียนระบบให้คุณ (ไม่ใช่ execution framework)
- ไม่แทนที่ทีมพัฒนา
- ไม่แทนที่ Jira / Azure DevOps / Linear
- ไม่ใช่ project management tool ที่มี dashboard / portfolio management /
  KPI tracking

**โครงสร้างการทำงาน 3 Core (แสดงเป็นลำดับ 3 กล่อง):**
1. Core 1 — Discovery & Product Design: เข้าใจต้นฉบับ ยืนยัน scope ออกแบบ
   เท่าที่จำเป็น → Output: `PROJECT.md`, `DESIGN/FLOW.puml`, wireframe (ถ้ามี)
2. Core 2 — Delivery & Engineering: แตกงาน ส่งต่อให้ทีม/AI ทำ ตรวจความพร้อม
   ทาง engineering → Output: `DELIVERY.md`, `HANDOFF.md`
3. Core 3 — Quality & Release: ตรวจสอบ ทดสอบ อนุมัติ ปิดงาน release อย่าง
   ปลอดภัย → Output: `RELEASE.md`, `RAID-log.md`, `decision-log.md`

**Gate การอนุมัติ (แสดงเป็น flow เรียงลำดับ เป็นแกนกลางของภาพ):**
Draft → Scope (อนุมัติโดยมนุษย์) → Design (อนุมัติโดยมนุษย์) → Handoff
(ตรวจสอบความพร้อม ไม่ใช่จุดอนุมัติใหม่) → Release (อนุมัติโดยมนุษย์)

หมายเหตุที่ต้องสื่อ: มีจุดอนุมัติโดยมนุษย์ 3 จุดคือ Scope Approved, Design
Ready, Release Approved — AI ไม่มีสิทธิ์อนุมัติงานตัวเองในจุดใดเลย

**3 โหมดตามความเสี่ยงของงาน (แสดงเป็น 3 ระดับ/สี ไล่จากเบาไปหนัก):**
- Lite — งานความเสี่ยงต่ำ เอกสารขั้นต่ำ
- Standard — งานปกติ มี design/flow ตามต้องการ
- Strict — งานความเสี่ยงสูง (การเงิน, ข้อมูลส่วนบุคคล, สิทธิ์การเข้าถึง,
  ระบบที่แก้คืนไม่ได้ ฯลฯ) ต้องมี RAID-log, decision-log, การอนุมัติแยกจาก
  คนทำ

หลักการที่ต้องสื่อ: เลือกโหมดที่เล็กที่สุดเท่าที่ยังคุมความเสี่ยงจริงได้
ไม่ใช่ยิ่งเข้มยิ่งดีเสมอไป

**ระบบหลักฐาน (Evidence System) — จุดขายเชิงเทคนิคที่ควรเน้น:**
ทุก requirement / decision / test ต้องมี source_ref (อ้างอิงต้นฉบับ) และ
evidence_status หนึ่งในนี้:
- verified = มีต้นฉบับ + มนุษย์อนุมัติแล้ว
- supported = มีต้นฉบับ รออนุมัติ
- inferred = อนุมานจากข้อมูลบางส่วน ต้องรีวิว
- missing = ไม่พบในต้นฉบับ ห้ามใช้เป็น requirement
- conflict = ต้นฉบับขัดแย้งกัน ต้องแก้ก่อน

**เอกสาร/Artifact หลักที่ระบบสร้าง:**
`PROJECT.md`, `DESIGN/` (FLOW.puml, WIREFRAME, BUILD-SPEC.md), `DELIVERY.md`,
`HANDOFF.md`, `RELEASE.md`, `RAID-log.md`, `decision-log.md`

## สิ่งที่ห้ามใส่ในภาพ (สำคัญ — มีคนทำผิดมาแล้วในเวอร์ชันก่อนหน้า)
ห้ามเติมฟีเจอร์ที่ไม่มีจริงต่อไปนี้: Portfolio Management (คัดเลือก/จัด
ลำดับหลายโครงการ), KPI Dashboard, Business Outcome / Stakeholder
Satisfaction metrics, Resource/Budget allocation tool, Org chart แบบ
Executive Sponsor / PMO Team / Project Team, Data & Analytics tool,
Collaboration tool — สิ่งเหล่านี้ไม่ใช่ความสามารถจริงของ Axiom-PMO

## แนวทางการออกแบบ (Visual Direction)
- Layout: one page เดียว อ่านจบใน 1 สายตา ใช้ grid ที่เป็นระเบียบ สื่อคำว่า
  "Structure"
- โทนสี: โทนน้ำเงิน/กรมท่า/ม่วงเข้ม (enterprise governance feel) มี accent
  สีเดียวสำหรับจุดสำคัญ (เช่น จุดอนุมัติของมนุษย์ในไดอะแกรม gate)
- Typography: sans-serif สะอาด อ่านง่าย
- ต้องมี: ชื่อ + tagline ด้านบน, ไดอะแกรม flow ของ 5 gate เป็นแกนกลางของภาพ,
  ตาราง ทำ/ไม่ทำ, แถบ 3 โหมด Lite/Standard/Strict, สรุป evidence system
  แบบย่อ, พื้นที่เล็กๆ ท้ายภาพสำหรับชื่อ repository (Axiom-PMO, GitHub)
- ห้ามให้ภาพรกเกินไป — ตัดรายละเอียดปลีกย่อยออก เหลือแค่สิ่งที่ทำให้
  "เข้าใจภาพรวม" ได้จริงภายในการดูครั้งเดียว
```
