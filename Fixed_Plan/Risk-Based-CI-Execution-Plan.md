# V2.1 Risk-Based CI Execution Plan

สถานะเอกสาร: แผนส่งต่อให้ AI ผู้ดำเนินการรอบถัดไป
ขอบเขต: ปรับวิธีตรวจสอบ CI ของ branch `V2.1` โดยไม่ลดการตรวจในจุดเสี่ยง
ผู้อนุมัติแผน: Human Owner

## เป้าหมาย

เปลี่ยนจากการรันทุก suite และทุก host ทุกครั้ง เป็น **risk-based CI**:

- งานเล็กใช้ local/fast checks
- งานที่แก้เฉพาะส่วนใช้ targeted suite และ host ที่เกี่ยวข้อง
- Full cross-host CI ใช้เฉพาะก่อน merge/release หรือเมื่อแก้ส่วนที่มีความเสี่ยงสูง
- ห้ามอ้างว่า Definition of Done หรือ cross-host compatibility ผ่าน หากยังไม่มีหลักฐานจาก host ที่กำหนด

## สถานะตั้งต้น

- Branch: `V2.1`
- Baseline commit: `ff2f43b`
- Local targeted evidence ผ่านแล้วตามรายงานใน `Fixed_Plan/Codex_Review-Feedback.md`
- Cross-host CI หลังแพตช์ล่าสุดยังไม่มีผลครบทุก host; ห้ามรันซ้ำแบบไม่เลือก profile เพียงเพื่อเติมตัวเลข
- ห้าม merge เข้า `main` จนกว่าจะมี CI evidence หรือ Human Owner บันทึก waiver

## งานที่ต้องทำ

### 1. ออกแบบ workflow profiles

ปรับ `.github/workflows/pmo-checks.yml` ให้รองรับโปรไฟล์ต่อไปนี้:

| Profile | ใช้เมื่อ | ขอบเขต |
|---|---|---|
| `fast` | งานทั่วไป, docs, รายงาน, การแก้เล็ก | Doctor, hygiene, golden, CLI, plugin drift และ targeted local-equivalent checks |
| `targeted` | แก้โค้ดหรือ test เฉพาะส่วน | เลือก suite และ host ที่เกี่ยวข้องเท่านั้น |
| `full` | ก่อน merge/release หรือแก้ความเสี่ยงสูง | ทุก required host และชุดตรวจที่เกี่ยวข้องทั้งหมด |

เพิ่ม `workflow_dispatch` inputs:

- `profile`: `fast`, `targeted`, `full`
- `suite`: ชื่อ suite ที่ต้องการเมื่อใช้ `targeted`
- `host`: `windows-ps51`, `windows-ps7`, `linux`, `macos`, หรือ `all`

ถ้าแก้ workflow ให้คง behavior เดิมของ `full` ไว้ และอย่าให้ค่า default ยิงทุก host โดยอัตโนมัติในงานทั่วไป

### 2. กำหนด automatic trigger ที่ประหยัดเวลา

- Pull request ปกติใช้ `fast`
- การแก้เฉพาะ `Fixed_Plan/**`, `docs/**` หรือ Markdown รายงาน ไม่ควรบังคับ Full CI
- การแก้ `scripts/**`, `tests/**`, `cli/**`, `pmo-config/**`, `templates/**` ให้เลือก `targeted` ตาม mapping
- การแก้ `.github/workflows/**`, shared PowerShell library, hash/path/encoding/runtime code ให้ถือเป็น high risk
- ห้ามใช้ path filter ที่ทำให้การแก้ validator หรือ configuration สำคัญถูกข้ามโดยไม่ตั้งใจ

หาก GitHub event ไม่สามารถเลือก profile ตาม changed paths ได้ ให้ใช้ workflow fast เป็นค่าเริ่มต้น และให้ AI/Human dispatch targeted profile อย่างชัดเจน

### 3. สร้าง mapping ระหว่างไฟล์กับ suite/host

จัดทำ mapping ในเอกสารหรือ config ที่อ่านได้ง่าย โดยใช้กติกาขั้นต่ำนี้:

| พื้นที่ที่แก้ | Suite ขั้นต่ำ | Host ขั้นต่ำ |
|---|---|---|
| `cli/**`, `tests/helpers/cli-tests.mjs` | CLI tests | Linux หรือ macOS PowerShell 7 |
| `scripts/**` หรือ validator | suite ที่เกี่ยวข้อง + doctor | Windows PowerShell 5.1 และ PowerShell 7 |
| encoding, line ending, path, junction, native command | line-ending/relevant mutation tests | Windows PowerShell 5.1 |
| `pmo-config/**`, `templates/**`, generator | config mutation + generator/E2E | Windows PowerShell 5.1 และ PowerShell 7 |
| `.github/workflows/**` | workflow smoke + relevant suite | host ที่ workflow เปลี่ยน และ full ก่อน merge |
| `docs/**`, `Fixed_Plan/**` เท่านั้น | markdown/public hygiene | ไม่ต้อง cross-host โดยอัตโนมัติ |

เมื่อไม่แน่ใจ ให้เลือก risk สูงขึ้นหนึ่งระดับ ไม่ใช่รัน Full CI ทันทีโดยไม่มีการจำแนก

### 4. กำหนด fast checks ที่รันได้ก่อน CI

AI ผู้ดำเนินการต้องรันเฉพาะชุดที่เกี่ยวข้องก่อน dispatch CI:

- `pmo-doctor`
- public hygiene
- golden verification
- CLI tests
- plugin mirror drift
- targeted contract/mutation tests ตาม mapping

ต้องบันทึกชื่อคำสั่ง, ผลลัพธ์, และ commit SHA ใน `Fixed_Plan/FreeBuff_fixed-update.md` หรือรายงานของผู้ดำเนินการ ห้ามบันทึกเพียงคำว่า “ผ่าน”

### 5. กติกา dispatch CI

- ห้าม dispatch `full` ซ้ำเพราะ job ช้า หากยังไม่มีหลักฐานว่าเป็น code failure
- หาก job ค้างหรือใช้เวลานาน ให้หยุดและบันทึกสถานะ ไม่วนซ้ำอัตโนมัติ
- ก่อน retry ให้ตรวจว่า failure เป็น code, environment, timeout หรือ runner issue
- เริ่มจาก `targeted` บน host ที่เกี่ยวข้องก่อน
- ใช้ `full` เฉพาะเมื่อ targeted ผ่านและเหตุผลอยู่ใน high-risk list หรือเป็น release gate
- ถ้าไม่สามารถรัน host ใดได้ ให้ระบุ host และเหตุผลเป็น pending evidence

### 6. แบ่งความรับผิดชอบของหลักฐาน

รายงานทุกครั้งต้องแยกสามสถานะ:

1. **Local verified** — รันบนเครื่องผู้ดำเนินการแล้ว
2. **Targeted CI verified** — รันบน host/suite ที่เลือกแล้ว
3. **Full cross-host verified** — รันครบ required matrix หลัง commit เดียวกัน

ห้ามใช้ผลระดับ 1 หรือ 2 แทนระดับ 3 และห้ามปิด CR-021 ด้วยผล local เพียงอย่างเดียว

### 7. เอกสารที่ต้องปรับ

AI ผู้ดำเนินการต้องตรวจและปรับให้สอดคล้องกัน:

- `.github/workflows/pmo-checks.yml`
- `docs/architecture/lessons-learned.md`
- `docs/architecture/powershell-portability.md`
- `Fixed_Plan/Codex_Review-Feedback.md`
- `README.md` หรือ Quick Start ที่อธิบายวิธีตรวจ

เพิ่ม SOP นี้เป็นแหล่งอ้างอิงถาวร ห้ามลบหรือย่อกติกา risk-based CI ในรอบถัดไป

## ขั้นตอนปฏิบัติสำหรับ AI ผู้รับช่วง

1. อ่าน `AGENTS.md`, แผนนี้, `Fixed_Plan/master-plan.md` และ review ล่าสุด
2. ตรวจ `git status`, branch และ commit ที่กำลังทำงาน
3. จำแนกไฟล์ที่เปลี่ยนตาม mapping ก่อนรันคำสั่งใด ๆ
4. รัน fast/local checks ที่จำเป็นเท่านั้น
5. เลือก `targeted` CI เมื่อมี code/host risk
6. รัน `full` เฉพาะเมื่อเข้าเงื่อนไข high risk หรือก่อน merge/release
7. ถ้า job ช้า/ค้าง ให้หยุด ไม่วน loop และบันทึก blocker
8. อัปเดต `Fixed_Plan/FreeBuff_fixed-update.md` ด้วยหลักฐานตามจริง
9. ให้ Codex/Human review ผลและคำถามค้าง
10. Commit/push เฉพาะเมื่อได้รับมอบหมาย และห้าม merge หากยังมี CI evidence ที่จำเป็นค้างอยู่

## เกณฑ์รับงาน

งานรอบนี้ถือว่าเสร็จเมื่อ:

- workflow เลือก `fast`, `targeted`, `full` ได้จริง
- งาน docs-only ไม่บังคับ Full CI
- งาน PowerShell เลือก Windows PowerShell 5.1 เป็น host ขั้นต่ำเมื่อเหมาะสม
- มี mapping และ SOP ที่ AI รอบถัดไปอ่านแล้วทำตามได้
- มี regression test สำหรับ profile selection และไม่เกิดการกลืน failure
- รายงานแยก local, targeted CI และ full cross-host evidence ชัดเจน
- ไม่มีการอ้างว่า CI ผ่านจาก partial หรือ cancelled run

## สิ่งที่ยังไม่ถือว่าเสร็จโดยอัตโนมัติ

- Cross-host CI ของ `V2.1` หลัง `ff2f43b`
- การปิด CR-021 โดยไม่มี required-host evidence
- การ merge เข้า `main`
- การอ้าง Feyman integration; สถานะต้องเป็น `unavailable/deferred` จนกว่าจะมี Human-approved interface และ evidence

