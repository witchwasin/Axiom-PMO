# รายงานภาพรวม PMO-Template-Personal

วันที่จัดทำ: 10 กรกฎาคม 2026  
Repo: `D:\GitHub\PMO-Template-Personal`  
เป้าหมายของ repo: ทำให้ PMO / Project Delivery Template ใช้งานจริงกับทีมเล็กได้ง่ายขึ้น โดยยังคุมคุณภาพงานและการใช้ AI ได้ดี

---

## 1. Executive Summary

Repo นี้คือ PMO operating template สำหรับทีมเล็กหรือทีมส่วนตัวที่ต้องการจัดงาน project ให้เป็นระบบ ตั้งแต่รับ requirement, ออกแบบ flow, ส่งต่องานให้ dev, ตรวจ QA, จนถึง release และ close งาน

ก่อนปรับ repo มีแนวโน้มเป็น framework ที่ละเอียดและหนักเกินไปสำหรับทีมเล็ก หลังปรับแล้ว repo ถูกทำให้เป็น Lite + AI Guardrails:

- ใช้ง่ายขึ้น
- อ่าน context น้อยลง
- ลดเอกสารที่ไม่จำเป็น
- มี mode ตามความเสี่ยงของงาน
- มี validation script ที่เช็ค project ได้จริง
- มี guardrails สำหรับ AI เช่น source reference, evidence status, assumption, open question
- ยังคง core เดิม 1-2-3 เอาไว้

คะแนนประเมินหลังปรับ: 8.6/10  
ถ้าแก้จุดที่เหลืออีกเล็กน้อย เช่น เพิ่ม permission ให้ `pmo-doctor.ps1` และทำ approval check ให้เข้มขึ้น จะขึ้นได้ประมาณ 9/10

---

## 2. Repo นี้ทำอะไรได้ในภาพกว้าง

Repo นี้ช่วยทำให้การทำงาน project มีเส้นทางชัดเจน:

1. รับข้อมูลและตกลง scope
2. แปลง requirement เป็น flow / wireframe / delivery plan
3. ส่งต่องานให้ dev ทำได้โดยไม่หลุด context
4. ติดตามงานแบบเบา ไม่ต้องมี status เยอะ
5. ตรวจ QA และ release ด้วย evidence
6. บังคับให้ AI อ้างอิง source ไม่แต่งข้อมูลเอง
7. ลดการโหลด context เกินจำเป็น เพื่อลด token
8. ใช้ Strict mode เฉพาะงานเสี่ยงสูง

พูดแบบสั้น: repo นี้เป็น template สำหรับทำ project ให้มีระเบียบ โดยเฉพาะเวลาทำงานร่วมกับ AI

---

## 3. Core 1-2-3 ยังเหมือนเดิมไหม

ยังเหมือนเดิม แต่ถูกจัดให้อ่านง่ายขึ้น

### Core 1: PM / Scope / Design

หน้าที่:

- รับ requirement
- สรุป source
- แยก confirmed / assumption / open question
- ทำ flow
- ทำ wireframe
- ขอ approval ก่อนเข้าสู่ dev

ไฟล์ที่เกี่ยวข้อง:

- `PROJECT.md`
- `DESIGN/FLOW.puml`
- `DESIGN/WIREFRAME.md`
- `RAID-log.md`
- `decision-log.md`

### Core 2: Dev / Delivery

หน้าที่:

- แตกงานเป็น delivery items
- ระบุ task source of truth
- กำหนด mode ของแต่ละงาน
- ระบุ review stage
- ส่งต่องานให้ dev หรือ AI ทำต่อได้

ไฟล์ที่เกี่ยวข้อง:

- `DELIVERY.md`
- `PROJECT.md`
- `DESIGN/`

### Core 3: QA / Release

หน้าที่:

- ตรวจงาน
- เช็ค blocker
- เช็ค rollback
- เช็ค release approval
- สรุปสิ่งที่ปล่อย

ไฟล์ที่เกี่ยวข้อง:

- `RELEASE.md`
- `DELIVERY.md`
- `RAID-log.md`

---

## 4. Execution Modes ที่เพิ่มเข้ามา

Repo ตอนนี้มี 3 mode เพื่อให้ไม่ต้องใช้ process หนักเท่ากันทุกงาน

### Lite

เหมาะกับ:

- bug fix เล็ก
- content update
- config เล็ก
- UI tweak ที่ impact ต่ำ

เอกสารที่ใช้:

- `PROJECT.md` แบบสั้น
- `DELIVERY.md` เฉพาะ task
- release note สั้นถ้าจำเป็น

จุดเด่น:

- เร็ว
- ใช้ token น้อย
- ไม่บังคับ traceability เต็ม

### Standard

เหมาะกับ:

- feature ปกติ
- งานที่มี design / handoff / QA
- งานที่ต้องให้ทีมเข้าใจร่วมกัน

เอกสารที่ใช้:

- `PROJECT.md`
- `DESIGN/FLOW.puml`
- `DESIGN/WIREFRAME.md`
- `DELIVERY.md`
- `RELEASE.md`
- `RAID-log.md` เมื่อมีประเด็นจริง

จุดเด่น:

- สมดุลระหว่างความเร็วกับคุณภาพ
- เป็น default mode ของ repo

### Strict

เหมาะกับ:

- payment
- PII / sensitive data
- auth / permission
- external integration
- legal / compliance
- migration
- public-sector acceptance
- งานที่ rollback ยากหรือกระทบ production สูง

เอกสารที่ใช้:

- ทุกไฟล์หลัก
- traceability เข้มขึ้น
- requirement ต้องมี source reference
- release ต้องมี evidence และ approval

จุดเด่น:

- ลดความเสี่ยงจาก AI hallucination
- เหมาะกับงานจริงที่มีความเสี่ยงสูง

---

## 5. สิ่งที่ปรับไปแล้ว

### 5.1 ปรับ `AGENTS.md`

จากกฎยาวและละเอียดมาก ถูกย่อเป็น operating rules หลักสำหรับ AI:

- อ่าน source ก่อนทำงาน
- ห้ามเดา requirement
- แยก confirmed / assumption / open question
- ห้ามเพิ่ม feature นอก scope
- ใช้ approval gates
- ใช้ source of truth เดียว
- AI ห้าม push / deploy / approve production เอง
- output สำคัญต้องมี source reference
- ถ้า evidence ไม่พอให้ถามหรือ flag
- sensitive data ใช้ Strict handling

ผลลัพธ์:

- AI ทำงานเป็นระบบขึ้น
- ลดการอ่าน instruction เกินจำเป็น
- เหมาะกับทีมเล็กมากขึ้น

### 5.2 ปรับ `CLAUDE.md`

เปลี่ยนเป็น router สำหรับ AI:

- route ตาม intent ของผู้ใช้
- route ตาม mode: Lite / Standard / Strict
- route ตาม core step: PM / Dev / QA
- ระบุ quick start
- ระบุ validation command
- ระบุว่า fake echo hooks ถูกถอดแล้ว

ผลลัพธ์:

- AI รู้ว่าควรอ่านอะไร
- ลด token
- ลดโอกาสโหลดทุก skill พร้อมกัน

### 5.3 เพิ่ม `CONTEXT-ROUTER.md`

ไฟล์นี้คือหัวใจของ token discipline

ใช้บอกว่าแต่ละงานควรอ่านไฟล์ไหนเท่านั้น เช่น:

- Intake อ่าน source + `PROJECT.md`
- Flow อ่าน `PROJECT.md` + `DESIGN`
- Handoff อ่าน `PROJECT.md` + `DESIGN` + `DELIVERY.md`
- QA/Release อ่าน `DELIVERY.md` + `RELEASE.md` + `RAID-log.md`

ผลลัพธ์:

- ไม่ต้องโหลดทุกไฟล์
- ลด token
- ลด noise
- AI ทำงานตรง task มากขึ้น

### 5.4 เพิ่ม `pmo-config/context-map.yaml`

เป็น machine-readable map ของ context policy

ประโยชน์:

- ให้ AI หรือ tool อ่าน rule ได้ง่าย
- ต่อไปสามารถเอาไปทำ automation หรือ checker ได้
- ทำให้ context router ไม่ได้เป็นแค่ text manual

### 5.5 เพิ่ม process docs

เพิ่มเอกสาร process แยกตาม mode:

- `docs/process/lite.md`
- `docs/process/standard.md`
- `docs/process/strict.md`

ประโยชน์:

- คนในทีมเลือกวิธีทำงานตามความเสี่ยงได้
- ไม่ต้องใช้ process หนักกับทุกงาน
- อธิบายกับ AI ได้ชัดว่าแต่ละ mode ต่างกันอย่างไร

### 5.6 เพิ่ม templates

เพิ่ม template หลัก:

- `templates/PROJECT.md`
- `templates/DELIVERY.md`
- `templates/RELEASE.md`
- `templates/RAID-log.md`
- `templates/decision-log.md`
- `templates/RTM.yaml`
- `templates/WIREFRAME.md`

ประโยชน์:

- เริ่ม project ใหม่ได้เร็ว
- มี format กลาง
- AI ไม่ต้องเดา structure
- ทีมเล็กใช้ซ้ำได้

### 5.7 เพิ่ม sample project

เพิ่มตัวอย่าง:

- `examples/P01-DEMO/`

ในตัวอย่างมี:

- `PROJECT.md`
- `DESIGN/FLOW.puml`
- `DESIGN/WIREFRAME.md`
- `DELIVERY.md`
- `RELEASE.md`
- `RAID-log.md`
- `decision-log.md`
- source ตัวอย่างแบบ fake data

ประโยชน์:

- เห็นภาพการใช้งานจริง
- AI มีตัวอย่างให้ pattern match
- คนใหม่เข้าใจ repo เร็วขึ้น

### 5.8 เพิ่ม validation scripts

เพิ่ม script 2 ตัว:

- `scripts/validate-project.ps1`
- `scripts/pmo-doctor.ps1`

`validate-project.ps1` ใช้ตรวจ project:

- structure
- placeholder / TODO / TBD
- source reference
- evidence status
- approval gate
- blocker
- rollback note
- sensitive filename
- broken local markdown links

`pmo-doctor.ps1` ใช้ตรวจ framework:

- ไฟล์หลักครบไหม
- template ครบไหม
- ไม่มี fake PMO echo hooks
- ไม่ allow git push / commit / tag โดย default
- markdown links ภายในไม่พัง

ผลลัพธ์:

- repo ไม่ได้มีแค่ guideline แต่มี checker ใช้งานจริง
- ใช้บน Windows PowerShell ได้

---

## 6. สิ่งที่เอามาจากแนวคิด WWSFramework

ไม่ได้ย้าย WWSFramework ทั้งก้อนมา แต่เลือกเฉพาะส่วนที่คุ้ม

### Token discipline

ใช้ `CONTEXT-ROUTER.md` และ `context-map.yaml` เพื่อบอกว่า task แต่ละชนิดควรอ่านไฟล์ไหน ไม่โหลดทุกอย่าง

### Context router

AI ต้อง route ตัวเองก่อนทำงาน:

- งานนี้คือ PM, Dev, หรือ QA
- งานนี้ Lite, Standard, หรือ Strict
- ต้องอ่าน source อะไร
- ต้องใช้ template ไหน

### Source reference

Requirement สำคัญต้องมี `source_ref`

ตัวอย่าง:

- `source_ref: MOM:20260710-demo-kickoff#decision-1`
- `source_ref: REQ:20260710-demo#REQ-001`

### Evidence status

ใช้แทน numeric confidence เพื่อให้เข้าใจง่ายกว่า

ตัวอย่าง:

- `confirmed`
- `partial`
- `missing`
- `conflict`

### Human verification

AI ห้าม approve production เอง และต้องแยก:

- confirmed
- assumption
- open question

### Risk-based mode

งานเสี่ยงสูงเข้า Strict mode เท่านั้น ไม่ทำให้ทุกงานหนักโดยไม่จำเป็น

### Health check

ใช้ `pmo-doctor.ps1` เช็คว่า framework ยังอยู่ในสภาพดีหรือไม่

---

## 7. Hook และ automation ตอนนี้เป็นอย่างไร

ตอนนี้ไม่มี fake echo hook แล้ว

สิ่งที่พบ:

- ไม่มี hook หลอกที่แค่ echo แล้วดูเหมือนทำงาน
- `.git/hooks/*.sample` เป็นไฟล์ sample มาตรฐานของ Git และไม่ทำงานจริง
- validation ใช้ผ่าน script แทน hook อัตโนมัติ

ความหมาย:

- ถ้าต้องการตรวจ ให้รัน `validate-project.ps1` หรือ `pmo-doctor.ps1`
- ถ้าต้องการให้ตรวจอัตโนมัติก่อน commit ต้องเพิ่ม real hook ภายหลัง

สถานะปัจจุบัน:

- validation script ใช้ได้จริง
- hook อัตโนมัติยังไม่ได้เปิดใช้

---

## 8. Windows compatibility

ทดสอบแล้วบน Windows PowerShell 5.1

ผล:

- `validate-project.ps1` ผ่าน
- `pmo-doctor.ps1` ผ่าน
- path แบบ `D:\GitHub\PMO-Template-Personal` ใช้งานได้
- script ใช้ `-LiteralPath` หลายจุด จึงเหมาะกับ Windows path

ข้อควรระวัง:

- ถ้า path มีช่องว่าง ควรใส่ quote เสมอ
- ตัวอย่าง command ในเอกสารบางบรรทัดยังเขียนแบบสั้น เพื่ออ่านง่าย

ตัวอย่างที่ปลอดภัยกว่า:

```powershell
powershell -ExecutionPolicy Bypass -File "scripts/validate-project.ps1" -ProjectPath "examples/P01-DEMO" -Mode Standard -Gate Release
```

---

## 9. ผลตรวจล่าสุด

### Project validation

รันกับ `examples/P01-DEMO`

ผล:

- PASS = 21
- WARN = 0
- FAIL = 0

สรุป:

- ตัวอย่าง project ผ่าน validation
- release gate ผ่าน
- ไม่มี unresolved blocker
- ไม่มี placeholder สำคัญค้าง
- source reference และ evidence status ครบ

### Framework doctor

รันกับ repo หลัก

ผล:

- PASS = 15
- WARN = 0
- FAIL = 0

สรุป:

- ไฟล์ framework หลักครบ
- templates ครบ
- ไม่มี fake echo hook
- ไม่ allow git push / commit / tag โดย default
- markdown link ภายในไม่พัง

---

## 10. ประเมินคะแนน

### Usability

คะแนน: 8.8/10

เหตุผล:

- ใช้งานง่ายกว่า framework หนัก
- มี mode ให้เลือก
- มี sample project
- มี template พร้อมใช้

จุดที่ยังทำให้ไม่เต็ม:

- ยังไม่มี CLI หรือ wizard สำหรับสร้าง project ใหม่อัตโนมัติ

### AI readiness

คะแนน: 8.7/10

เหตุผล:

- มี AI router
- มี context router
- มี source reference
- มี evidence status
- ลด token ได้ดีขึ้น

จุดที่ยังทำให้ไม่เต็ม:

- ยังไม่มี automated context loader จริง
- ยังต้องให้ AI อ่าน rule และปฏิบัติตาม

### Governance / Guardrails

คะแนน: 8.5/10

เหตุผล:

- มี approval gates
- มี Strict mode
- มี no-push/no-deploy/no-production-approval rule
- มี validation script

จุดที่ยังทำให้ไม่เต็ม:

- approval row check ยังควรเข้มขึ้น
- ยังไม่มี real hook บังคับก่อน commit

### Token efficiency

คะแนน: 8.8/10

เหตุผล:

- มี context router
- มี context map
- แนะนำให้ใช้ `PROJECT.md` เป็น context summary กลาง
- ห้ามโหลดทุก skill พร้อมกัน

จุดที่ยังทำให้ไม่เต็ม:

- ยังไม่มี script ตรวจว่า AI อ่าน context เกิน policy หรือไม่

### Windows readiness

คะแนน: 8.3/10

เหตุผล:

- PowerShell script ใช้งานได้จริงบน Windows
- ใช้ `-LiteralPath`
- path หลักในเครื่องทำงานได้

จุดที่ยังทำให้ไม่เต็ม:

- ควร quote path ในเอกสารให้ครบทุกตัวอย่าง
- ยังไม่ได้เพิ่ม real Windows-friendly hook installer

### Overall

คะแนนรวม: 8.6/10

หลังแก้ minor issues คาดว่าได้: 9.0/10

---

## 11. จุดที่ควรแก้ต่อ

### 11.1 เพิ่ม permission ให้ `pmo-doctor.ps1`

ตอนนี้ `.claude/settings.json` อนุญาต `validate-project.ps1` แต่ยังไม่อนุญาต `pmo-doctor.ps1`

ควรเพิ่ม:

```json
"Bash(powershell -ExecutionPolicy Bypass -File scripts/pmo-doctor.ps1:*)"
```

เหตุผล:

- คู่มือบอกให้ใช้ doctor
- แต่ settings ยังไม่ได้เปิดให้ตรงกัน

### 11.2 ทำ approval check ให้เข้มขึ้น

ตอนนี้ approval row ดูจากช่องที่ไม่ว่างเป็นหลัก

ควรให้ fail ถ้าเจอ:

- `<name>`
- `<date>`
- `YYYY-MM-DD`
- `TBD`
- `TODO`

เหตุผล:

- กัน approval ปลอม
- ทำให้ release gate น่าเชื่อถือขึ้น

### 11.3 เพิ่ม real hook แบบ optional

ถ้าต้องการให้ repo ตรวจอัตโนมัติ ควรเพิ่ม:

- `scripts/install-hooks.ps1`
- `.githooks/pre-commit`
- หรือเอกสารวิธีเปิด hook

แต่ควรเป็น optional เพราะทีมเล็กบางครั้งไม่อยากให้ process หนักเกินไป

### 11.4 เพิ่ม project generator

อนาคตอาจเพิ่ม:

- `scripts/new-project.ps1`

เพื่อ copy template ไปเป็น project ใหม่ เช่น:

```powershell
scripts/new-project.ps1 -ProjectId P02 -Name "Client Portal"
```

ประโยชน์:

- ลด manual setup
- ลด typo
- ใช้ template ได้เร็วขึ้น

---

## 12. อธิบายให้ AI อีกตัวเข้าใจแบบสั้น

เราไม่ได้ทำ repo นี้ให้เป็น framework ใหญ่ แต่ทำให้เป็น PMO operating template สำหรับทีมเล็กที่ใช้ AI ช่วยงาน

เราเก็บ core เดิม 1-2-3 ไว้:

- Core 1: PM / Scope / Design
- Core 2: Dev / Delivery
- Core 3: QA / Release

แต่เพิ่ม mode เพื่อให้ process เบาหรือเข้มตามความเสี่ยง:

- Lite สำหรับงานเล็ก
- Standard สำหรับ feature ปกติ
- Strict สำหรับงานเสี่ยงสูง

สิ่งที่เพิ่มจากแนว WWS คือ:

- token discipline
- context router
- source reference
- evidence status
- human verification
- risk-based mode
- health check script

สิ่งที่ลดออก:

- เอกสารเยอะเกินจำเป็น
- status งานหลายชั้น
- fake echo hooks
- การบังคับโหลดทุก skill
- logging ทุก action

ผลคือ repo เบาลงในเชิงการใช้งาน แต่ฉลาดขึ้นในเชิง governance และ AI safety

---

## 13. คำตัดสินสุดท้าย

Repo นี้ตอนนี้เหมาะสำหรับ:

- ทีมเล็กไม่เกิน 10 คน
- founder / PM / BA / dev ที่ใช้ AI ช่วยทำงาน
- project ที่ต้องมี requirement, delivery, QA, release แบบเป็นระบบ
- งานที่ไม่อยากใช้ PMO framework หนักเกินไป

ไม่เหมาะสำหรับ:

- enterprise PMO เต็มรูปแบบ
- งาน compliance ระดับสูงมากที่ต้องมี audit trail เต็มระบบ
- งานที่ต้องมี workflow automation เต็มรูปแบบตั้งแต่วันแรก

คำตัดสิน:

แผนที่ทำมาเดินถูกทาง และ implementation ตอนนี้ใช้งานจริงได้แล้วในระดับดีมากสำหรับทีมเล็ก

Repo นี้ไม่ได้แค่จัดเอกสารใหม่ แต่เปลี่ยนจาก template หนัก ๆ ให้กลายเป็น lightweight AI-ready PMO system ที่มี guardrails, validation, context discipline และ sample ที่ใช้งานได้จริง

---

## 14. Hardening Update

หลังรายงานฉบับแรก มีการปิดช่องว่าง Priority 1 เพิ่มเติม:

- เพิ่ม permission ให้ `scripts/pmo-doctor.ps1`
- เพิ่ม permission ให้ `scripts/run-validation-tests.ps1`
- ทำ approval validation ให้ reject placeholder, date format ผิด, approver ว่าง, evidence ว่าง
- ทำให้ release gate fail เมื่อ requirement ไม่มี source reference หรือ evidence status
- เพิ่ม task source consistency check ระหว่าง `PROJECT.md` และ `DELIVERY.md`
- เพิ่ม work item fields: `Mode Reason`, `Mode Approved By`, `PR / Evidence`
- เพิ่ม `Task Management` section เพื่อประกาศ source of truth
- เพิ่ม validation fixture runner
- เพิ่ม negative fixtures สำหรับ missing project, missing source ref, fake approval, open blocker, missing rollback, และ broken link

ผลตรวจหลัง hardening:

- Demo project validation: PASS=21 WARN=0 FAIL=0
- Validation fixture tests: PASS=7 FAIL=0
- Framework doctor: PASS=19 WARN=0 FAIL=0

สถานะหลัง update: พร้อมใช้เป็น Pilot ที่แข็งแรงขึ้น และเข้าใกล้ Stable มากกว่าเวอร์ชันรายงานแรก

---

## 15. Versioning And Examples Update

เพิ่ม version marker และ changelog:

- `VERSION`: `0.3.0-lite-ai-guardrails`
- `CHANGELOG.md`: บันทึกการเปลี่ยนแปลงของ baseline, Lite AI workflow, และ validation hardening

แยก examples ตาม mode:

- `examples/LITE-BUGFIX`: แสดง Lite mode ที่ใช้เอกสารน้อยจริง เหมาะกับ bug fix หรือ content/config change เล็ก
- `examples/STANDARD-FEATURE`: แสดง Standard mode สำหรับ feature ปกติที่มี flow, delivery, QA และ release
- `examples/STRICT-HIGH-RISK`: แสดง Strict mode สำหรับงาน permission/audit พร้อม RTM, RAID, decision log, release และ rollback

ผลลัพธ์:

- AI เห็นชัดว่าแต่ละ mode ไม่ต้องใช้เอกสารเท่ากัน
- Repo ดู mature ขึ้นเพราะมี version และ changelog
- ตัวอย่างช่วยลดโอกาสที่ Lite mode จะถูกทำให้หนักเกินจำเป็น
# SUPERSEDED - ARCHIVED REPORT

This report is archived and is not the current acceptance source. It references older scores and version state. Use `reports/current-acceptance.md` for the current computed score, pending human actions, and final gate status.
