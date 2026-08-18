# Prompt: Slide Deck (Axiom-PMO)

ไฟล์นี้เก็บ prompt สำหรับส่งให้เครื่องมือออกแบบ (เช่น Claude Design) เพื่อสร้าง
slide deck สำหรับ present หลักการ/framework ของ Axiom-PMO ให้คนดูแล้ว
"อยากใช้" — เน้นความน่าประทับใจแบบงานขาย แต่**ไม่ใช่สื่อขายจริง** เป็นสื่อ
โน้มน้าวให้คนเข้าใจคุณค่าและอยากลองใช้ ข้อมูลยังต้องอ้างอิงจากของจริงใน
`README.md` เหมือนไฟล์ one-page (`01-one-page-infographic-prompt.md`) —
ห้ามเติมสถิติหรือฟีเจอร์ที่ไม่มีจริงเพื่อความว้าว

คัดลอกข้อความในกรอบด้านล่างทั้งหมดไปวางใน Claude Design ได้เลย

---

## Prompt (คัดลอกทั้งหมดนี้)

```
สร้าง slide deck (แนะนำ 10-13 สไลด์) เพื่อ present framework "Axiom-PMO"
ให้คนดูแล้วรู้สึกว่า "น่าเชื่อถือ ทันสมัย น่าเอาไปใช้" — โทนแบบ pitch deck
มืออาชีพระดับ product launch แต่**ไม่ใช่สื่อขายจริง** เป็นสื่อโน้มน้าวให้
ทีมพัฒนา/PM เข้าใจคุณค่าและอยากลองเอาไปใช้ในทีมตัวเอง

## บริบท / ผู้ชม
- ผู้ชม: ทีมพัฒนาซอฟต์แวร์, Product Manager, Tech Lead, CTO ระดับที่ตัดสินใจ
  เลือกเครื่องมือ/กระบวนการทำงานของทีม
- วัตถุประสงค์: โน้มน้าวให้เข้าใจปัญหาที่ Axiom-PMO แก้ และอยากลองใช้ —
  ไม่ใช่คู่มือเทคนิคละเอียด (สไลด์ต้องเดินเรื่องเป็น narrative ไม่ใช่ list
  ฟีเจอร์แบนราบ)
- โทน: มั่นใจ ทันสมัย น่าเชื่อถือ มีจังหวะดราม่าเบาๆ (ปัญหา → ทางแก้ →
  หลักฐาน → ชวนลองใช้) แบบ pitch deck ของผลิตภัณฑ์ software จริงจัง ไม่ใช่
  playful หรือ corporate เกินไป

## ข้อมูลจริงที่ต้องใช้ (ห้ามแต่งเติมหรือเดาสถิติ/ฟีเจอร์ใหม่)

**ชื่อผลิตภัณฑ์:** Axiom-PMO
**เวอร์ชัน:** 2.2.0 · MIT License · Node.js reference implementation

**Tagline (ใช้คำนี้เท่านั้น):**
"The governance control plane for AI-assisted software delivery."

**Hook เปิดเรื่อง (ใช้เป็นสไลด์ปัญหา):**
"AI agents can write code. They should not invent the project." — AI
ช่วยเขียนโค้ดได้เร็วขึ้นมาก แต่ถ้าไม่มีกลไกกำกับ AI จะเริ่ม "เดา" requirement
เอง, อนุมัติงานตัวเอง, รายงานผลที่ตรวจสอบไม่ได้ — นี่คือช่องว่างด้าน
governance ที่เกิดขึ้นจริงเมื่อทีมเริ่มใช้ AI coding agent ในงานจริง

**แนวคิดหลัก (สไลด์ทางออก):**
Axiom-PMO เปลี่ยนงาน AI-assisted delivery ให้เป็นกระบวนการที่มีหลักฐาน
ตรวจสอบย้อนกลับได้ (traceable) และต้องผ่านการอนุมัติจากมนุษย์เสมอ — ไม่มี
ขั้นตอนไหนที่ AI อนุมัติงานของตัวเองได้

**Axiom-PMO ทำอะไร / ไม่ทำอะไร (ต้องมีสไลด์นี้ แม้จะเป็น pitch deck ก็ต้อง
ตั้งความคาดหวังให้ถูกต้อง):**

ทำ:
- แปลงต้นฉบับ (MOM / Transcript / Requirement) ให้กลายเป็น requirement ที่
  ตรวจสอบย้อนกลับได้
- ตรวจสอบความพร้อมของ design และความครบถ้วนของ handoff
- ตรวจสอบ scope, test, หลักฐาน และสิทธิ์การอนุมัติ
- ตรวจสอบว่าสิ่งที่ AI รายงานว่าทำ ตรงกับสถานะจริงใน repository หรือไม่

ไม่ทำ:
- ไม่เขียนระบบให้คุณ (ไม่ใช่ execution framework)
- ไม่แทนที่ทีมพัฒนา
- ไม่แทนที่ Jira / Azure DevOps / Linear (ทำงานร่วมกันได้ ไม่ใช่คู่แข่ง)
- ไม่ใช่ project management tool ที่มี dashboard / portfolio management /
  KPI tracking

**โครงสร้างการทำงาน 3 Core (สไลด์ "how it works" หลัก):**
1. Core 1 — Discovery & Product Design: เข้าใจต้นฉบับ ยืนยัน scope ออกแบบ
   เท่าที่จำเป็น → Output: `PROJECT.md`, `DESIGN/FLOW.puml`, wireframe
2. Core 2 — Delivery & Engineering: แตกงาน ส่งต่อให้ทีม/AI ทำ ตรวจความพร้อม
   ทาง engineering → Output: `DELIVERY.md`, `HANDOFF.md`
3. Core 3 — Quality & Release: ตรวจสอบ ทดสอบ อนุมัติ ปิดงาน release อย่าง
   ปลอดภัย → Output: `RELEASE.md`, `RAID-log.md`, `decision-log.md`

**Gate การอนุมัติ (สไลด์ diagram แกนกลาง):**
Draft → Scope (อนุมัติโดยมนุษย์) → Design (อนุมัติโดยมนุษย์) → Handoff
(ตรวจสอบความพร้อม ไม่ใช่จุดอนุมัติใหม่) → Release (อนุมัติโดยมนุษย์)

จุดขาย: มีจุดอนุมัติโดยมนุษย์ 3 จุด — AI ไม่มีสิทธิ์อนุมัติงานตัวเองใน
จุดใดเลย

**3 โหมดตามความเสี่ยงของงาน (สไลด์เดียว แสดงเป็น 3 ระดับ):**
- Lite — งานความเสี่ยงต่ำ เอกสารขั้นต่ำ
- Standard — งานปกติ มี design/flow ตามต้องการ
- Strict — งานความเสี่ยงสูง (การเงิน, ข้อมูลส่วนบุคคล, สิทธิ์การเข้าถึง,
  ระบบที่แก้คืนไม่ได้) ต้องมี RAID-log, decision-log, อนุมัติแยกจากคนทำ

จุดขาย: เลือกโหมดที่เล็กที่สุดเท่าที่ยังคุมความเสี่ยงจริงได้ — ไม่บังคับให้
ทุกงานหนักเท่ากันหมด

**ระบบหลักฐาน (Evidence System) — สไลด์ที่ควรเน้นเป็นจุดต่างจากคู่แข่ง:**
ทุก requirement / decision / test ต้องมี source_ref และ evidence_status:
verified (มีต้นฉบับ+อนุมัติแล้ว) / supported (มีต้นฉบับ รออนุมัติ) /
inferred (อนุมาน ต้องรีวิว) / missing (ไม่พบในต้นฉบับ ห้ามใช้) / conflict
(ต้นฉบับขัดแย้งกัน ต้องแก้ก่อน)

**สไลด์ "หลักฐานว่าทำงานจริง" (proof/credibility slide — ใช้ตัวเลขจริง
เท่านั้น ห้ามปัดตัวเลขหรือแต่งเพิ่ม):**
- 219/219 automated tests ผ่านทั้งหมด (รวม adversarial test ที่จำลองการ
  ปลอมแปลง approval, symlink attack, marker ที่ถูกดัดแปลง)
- 57/57 framework health checks (`axiom doctor`) ผ่าน
- Validation fixture suite 161/161 เคสผ่าน (ทั้งเคสที่ควรผ่านและควรถูก
  บล็อก)
- ตรวจสอบทุก push/PR ด้วย CI จริง (GitHub Actions)
- ไม่มี runtime dependency ภายนอกเลย (`dependencies: {}`) — รันด้วย
  Node.js อย่างเดียว

**เอกสาร/Artifact ที่ระบบสร้าง (git-native, ไม่มีเครื่องมือใหม่ต้องเรียนรู้):**
`PROJECT.md`, `DESIGN/`, `DELIVERY.md`, `HANDOFF.md`, `RELEASE.md`,
`RAID-log.md`, `decision-log.md` — เป็นไฟล์ markdown ธรรมดาที่อยู่ใน repo
เดียวกับโค้ด ไม่ใช่ SaaS แยกต่างหาก

**เข้ากับ workflow เดิม:**
ใช้ร่วมกับ Claude Code, Cursor, Copilot, Codex ได้ (agent-agnostic) และไม่
แทนที่ Jira/Azure DevOps/Linear ที่ทีมใช้อยู่แล้ว

**Call to action ปิดท้าย:**
เริ่มต้นด้วยคำสั่งเดียว `node cli/axiom.mjs init` — MIT License, เปิดซอร์ส
เต็มรูปแบบบน GitHub

## โครงเรื่องที่แนะนำ (ปรับจำนวนสไลด์ได้ตามความเหมาะสม)
1. Cover — ชื่อ + tagline
2. ปัญหา (hook)
3. แนวคิดหลัก / ทางออก
4. ทำ / ไม่ทำ (ตั้งความคาดหวังให้ถูกต้อง)
5. How it works — 3 Core
6. Gate flow (Draft→Scope→Design→Handoff→Release) + จุดอนุมัติมนุษย์
7. 3 โหมดตามความเสี่ยง
8. Evidence System
9. หลักฐานว่าทำงานจริง (ตัวเลขทดสอบ/CI)
10. Artifact ที่ได้ + เข้ากับ workflow เดิม
11. Call to action + วิธีเริ่มต้น

## สิ่งที่ห้ามใส่ในภาพ/สไลด์ (สำคัญมาก — เคยผิดพลาดมาแล้วในเวอร์ชันก่อนหน้า)
ห้ามเติมฟีเจอร์หรือสถิติที่ไม่มีจริงต่อไปนี้: Portfolio Management, KPI
Dashboard, Business Outcome / Stakeholder Satisfaction metrics,
Resource/Budget allocation, Org chart แบบ Executive Sponsor/PMO
Team/Project Team, Data & Analytics tool, Collaboration tool, ตัวเลข
performance/productivity ที่ไม่ได้มาจากรายการข้างต้น (เช่น "เร็วขึ้น X%",
"ลด bug Y%") — ห้ามสร้างตัวเลขเหล่านี้ขึ้นมาเองแม้เพื่อความน่าประทับใจ

## แนวทางการออกแบบ (Visual Direction)
- สไตล์: pitch deck ระดับ product launch ทันสมัย มั่นใจ มีจังหวะ (แต่ละ
  สไลด์สื่อความคิดเดียว ไม่ยัดข้อมูลแน่นเกินไป)
- โทนสี: น้ำเงินเข้ม/กรมท่า/ม่วง (governance/engineering feel) มี accent
  สว่างสำหรับตัวเลขสำคัญและจุดอนุมัติมนุษย์
- ใช้ big number callout สำหรับสไลด์หลักฐาน (219/219, 57/57, 161/161)
- Diagram gate flow และ Core 1-2-3 ควรเป็นภาพ ไม่ใช่ bullet list
- Typography: sans-serif หนา ชัด อ่านจากที่ไกลได้ (ใช้ present จริง)
- ปิดท้ายด้วยสไลด์ call to action ที่มีคำสั่งเดียวชัดเจนให้เริ่มต้น
```
