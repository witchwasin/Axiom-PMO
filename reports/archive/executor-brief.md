# Executor Brief — วิธีสั่ง AI ตัวอื่นให้ทำ Remediation

> ใช้คู่กับ `reports/remediation-plan.md` (v3) รายละเอียดเต็มอยู่ในไฟล์นั้น ไฟล์นี้คือ "คำสั่ง + การแบ่ง part"

---

## A. คำสั่งตั้งต้น (ก๊อปวางให้ AI ตัวอื่นได้เลย)

```text
คุณคือ Executor / Lead Maintainer ของ repo `Axiom-PMO`
ภารกิจ: ทำตาม `reports/remediation-plan.md` (v3) เพื่อยกคะแนน framework จาก ~7.5 → 9.0+ อย่างมีหลักฐาน

อ่านก่อนเริ่ม (บังคับ):
1. reports/remediation-plan.md  (แผนเต็ม P0/P1 + Final Acceptance Gate + evidence appendix)
2. AGENTS.md, CLAUDE.md, CONTEXT-ROUTER.md
3. scripts/validate-project.ps1, scripts/pmo-doctor.ps1, scripts/run-validation-tests.ps1, scripts/run-all-checks.ps1

กฎการทำงาน (ห้ามละเมิด):
- ห้ามแก้/ลบอะไรใน source/, MOM/, REQ/, Transcript/ (เป็นของผู้ใช้)
- Commit protocol (plan R3.8): ทำงานบน branch `remediation/9plus`
  ทุก Round: รัน test → มนุษย์ตรวจ diff → อนุมัติ → commit local ได้ (ห้าม push)
  push ครั้งเดียวตอนจบหลัง Final Gate + อนุมัติรวม → เปิด PR → CI เขียว → merge
- Archive แทน Delete เสมอ (.claude-archive/)
- ห้ามลดความเข้มของ validator เพื่อให้ test ผ่าน — ต้องแก้ root cause
- รันชุดตรวจหลังจบทุก Part แล้วแปะ output จริง
- ถ้ารัน PowerShell ไม่ได้ ให้บอกตรง ๆ ห้ามสมมติผล PASS
- ห้ามประกาศว่าได้ 9+ จนกว่า Final Acceptance Gate จะผ่านครบด้วยการรันจริง

baseline (ตัดสินแล้วโดยเจ้าของ repo เมื่อ 2026-07-11 — ไม่ต้องถามซ้ำ):
  baseline_decision: accept
  baseline_commit: 37c919b
  log_process_violation: true
- ยอมรับ commit 37c919b เป็น baseline; งาน remediation ทั้งหมดต้องเป็น commit ใหม่ที่ผ่าน diff review ก่อน push
- การ commit/push ที่ไม่ได้ review ถูกบันทึกไว้แล้วที่ reports/process-violation.md (ห้ามลบ)

ลำดับการทำ (ทำทีละ Part หยุดให้ตรวจ diff ก่อนไป Part ถัดไป):
Part 0 → Part 1 → (ตรวจ) → Part 2 → (ตรวจ) → Part 3 → (ตรวจ) → Final Gate

ชุดตรวจที่ต้องรันหลังทุก Part (คาดว่าเขียว):
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/pmo-doctor.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-validation-tests.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-all-checks.ps1

Definition of Done:
- Final Acceptance Gate ใน remediation-plan.md §5 ผ่านครบทุกข้อ ด้วย command ที่รันจริง

รายงานตอนจบ (ต้องมีครบ):
1. Version ก่อน/หลัง
2. Files Created / Modified / Moved
3. Commands ที่รัน + Exit Codes
4. Test Summary (positive/negative/E2E)
5. Before–After Metrics
6. Known Limitations + Remaining Risks
7. Final Score พร้อมสูตรคำนวณ
8. git status + diff summary (ยังไม่ commit)
```

---

## B. การแบ่ง Part (สั่งทีละก้อนได้ — รายละเอียดเต็มอยู่ใน remediation-plan.md)

### Part 0 — Baseline & Safety (ก่อนแตะโค้ด)
- baseline ตัดสินแล้ว = **accept** (37c919b เป็น baseline) — ไม่ต้องถามซ้ำ, ไม่ต้อง revert
- Process-Violation ถูกบันทึกแล้วที่ `reports/process-violation.md` — ยืนยันว่ามีอยู่ (ห้ามลบ/แก้)
- อ่าน plan + ไฟล์หลักให้ครบ
- **Gate:** ยืนยัน `reports/process-violation.md` มีอยู่ แล้วจึงไป Part 1

### Part 1 — Runtime Hotfix (P0)  → คาดว่า ~8.5
อ้าง plan §2 (R1.1–R1.7):
- R1.1 เพิ่ม YAML frontmatter ให้ 7 skills + doctor rule `DOCTOR-SKILL-001`
- R1.2 แก้ตาราง approval พัง + **canonical schema เดียวทั้ง repo** (templates + examples + positive fixtures + generator, ประกาศใน config) + check `TABLE-001` — ยกเว้น negative fixture ที่ตั้งใจทดสอบตารางพัง
- R1.3 `run-all-checks.ps1` propagate exit code (ทดสอบด้วย `tests/helpers/exit-1.ps1`)
- R1.4 documented Release command ใส่ `-FailOnWarning`
- R1.5 เพิ่ม test: skill-frontmatter, generated-project, broken-table (missing/extra/order column)
- R1.6 เพิ่ม GitHub Actions CI (`.github/workflows/pmo-checks.yml`, ใช้ `powershell.exe` 5.1) + บันทึก human action: ตั้ง branch protection บน main
- R1.7 แปะ SUPERSEDED banner บน `reports/final-acceptance.md` (คะแนน 9.1 ไม่ถูกยอมรับ)
- **Gate:** doctor+matrix เขียว, aggregator fail เมื่อ child fail, หยุดให้ตรวจ diff

### Part 2 — Validator Hardening (P1)  → คาดว่า ~8.9–9.1
อ้าง plan §3 (R2.0–R2.10):
- **R2.0 (P0): แยก governed files ออกจาก user source** — placeholder/link check ห้ามสแกน `source/` (TODO ใน MOM ลูกค้าต้องไม่ทำให้ Release fail); link ใน source = `SOURCE-LINK-001` INFO/WARN
- **R2.1: Mode × Gate matrix** — แก้ 2 inversion ของ Lite (Design approval = conditional; Lite Release ใช้ DELIVERY หรือ Work Item section แทนบังคับ RELEASE.md) + sentinel `not_required`
- R2.2: Reference integrity แบบ mode-aware (Lite เบา / Standard กลาง / Strict full chain) + parse RTM จริง + parse rollback rows จริง
- แก้บั๊ก HTML placeholder + reconcile source-ref patterns + approval evidence exists
- ขยาย negative matrix + test runner primary/secondary/forbidden model (R2.9)
- R2.10: E2E เป็น **script deterministic** (`tests/e2e/*.ps1`, fixed content + fixed dates, temp dir + cleanup ใน finally) — ห้ามด้นสดเนื้อหาระหว่างรัน + case path มีช่องว่าง/ชื่อไฟล์ไทย
- **Gate:** fabricated ID / empty RTM / rollback ว่าง / HTML wireframe / TODO-ใน-source → ผลถูกต้องทุกเคส, Lite ยังเบาเท่าเดิม, หยุดให้ตรวจ diff

### Part 3 — Governance Consistency  → คาดว่า ~9.1–9.3
อ้าง plan §4 (R3.1–R3.11):
- Config เป็น SoT จริง (แปลงเป็น **JSON** parse ด้วย ConvertFrom-Json) — รวม Mode×Gate matrix และ approval-table schema
- แก้ context-map RAID conflict, WebSearch→ask, `.gitignore` เจาะจง
- upgrade `new-project.ps1` เป็น generator จริง, จัดการ `update-source-snapshot.ps1`
- ขยายเนื้อ 7 skills (content contract, ~≤1,500 คำ), archive เอกสารเก่า + version consistency check
- R3.9: แจ้ง human action — branch protection บน main (executor ทำเองไม่ได้)
- R3.10: คำนวณคะแนนสุดท้ายด้วย **rubric 8 มิติ + floors** ใน plan (ห้ามตั้งเลขเอง; ห้ามเคลม 9+ ถ้าติด floor ใดก็ตาม)
- R3.11: ทุกสคริปต์ verify บน Windows PowerShell 5.1 (`powershell.exe`) — ห้ามใช้ feature PS7-only
- **Gate:** config edit เปลี่ยน behavior จริง, หยุดให้ตรวจ diff

### Part 4 — Final Acceptance Gate
- รัน plan §5 checklist ครบทุกข้อด้วย command จริง
- ออกรายงานตามฟอร์แมตในคำสั่งข้อ A
- **หยุด** ให้มนุษย์ตรวจ diff และอนุมัติ ก่อน commit/push ใด ๆ

---

## C. เงื่อนไขหยุด (Stop conditions)
หยุดและถามมนุษย์ทันที ถ้า:
- ยังไม่มี baseline_decision
- ต้องแตะไฟล์ใน source/
- test fail แล้วทางแก้เดียวคือลดความเข้ม validator
- จะ commit/push/tag
- PowerShell รันไม่ได้ (รายงานตรง ๆ ห้ามเดาผล)
