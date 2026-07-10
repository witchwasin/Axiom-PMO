# Impact Analysis Guide — วิธีวิเคราะห์ MOM ใหม่ให้ครบถ้วน

> Checklist สำหรับตรวจผลกระทบจาก MOM ใหม่ทุกมุม ไม่ให้ตกหล่น

---

## 1. Comparison Dimensions — ต้องเทียบอะไรบ้าง

### 1.1 MOM ใหม่ vs MOM เก่า

| ตรวจอะไร | ตัวอย่างผลกระทบ |
|----------|----------------|
| **Business Rule เปลี่ยน** | OTP จาก email → SMS, Lockout จาก 5 → 3 ครั้ง |
| **Feature เพิ่ม/ลด** | เพิ่ม Remember Device, ลด Social Login |
| **Actor เปลี่ยน** | เพิ่ม Supervisor role, รวม Admin + Manager |
| **Scope/Phase เปลี่ยน** | ย้าย LINE OA จาก Phase 1 → Phase 2 |
| **Priority เปลี่ยน** | Dashboard จาก Nice-to-have → Must-have |
| **Terminology เปลี่ยน** | "ค่าธรรมเนียม" → "Service Fee" |

### 1.2 MOM ใหม่ vs REQ

| ตรวจอะไร | ตัวอย่างผลกระทบ |
|----------|----------------|
| **REQ ใหม่ที่ไม่มีใน REQ file** | ต้องเพิ่ม row ใน REQ |
| **REQ ที่ขัดแย้งกับ MOM ใหม่** | MOM บอกลด feature แต่ REQ ยังอยู่ |
| **REQ ที่ descope** | Feature ถูกตัดออกจาก scope |

### 1.3 MOM ใหม่ vs Existing Diagrams

| ตรวจอะไร | ตัวอย่างผลกระทบ |
|----------|----------------|
| **SystemFlow ที่ต้อง update** | Business rule เปลี่ยน → flow เปลี่ยน |
| **UserFlow ที่ต้อง update** | UI flow เปลี่ยนตาม SystemFlow |
| **UseCase ที่ต้อง update** | Actor เพิ่ม/ลด → relationship เปลี่ยน |
| **Wireframe ที่ต้อง update** | UI element เพิ่ม/เปลี่ยน |
| **TaskBreakdown ที่ต้อง update** | Timeline/scope เปลี่ยน |

---

## 2. Risk Detection Checklist

เมื่ออ่าน MOM ใหม่ ต้องตรวจ business logic ที่มีความเสี่ยง:

| # | ประเภท | สิ่งที่ต้องมองหา | ตัวอย่าง |
|---|--------|----------------|---------|
| 1 | **Fraud** | Self-approve, bypass limit, double claim | Admin อนุมัติตัวเอง, ไม่มี limit ต่อวัน |
| 2 | **Logic Broken** | Rule ขัดแย้งกัน, dead end, infinite loop | MOM#1 บอก OTP 5 นาที, MOM#2 บอก 3 นาที ไม่ระบุว่าแทนที่ |
| 3 | **Missing Validation** | ไม่มี input check, auth check, duplicate check | ฟอร์มไม่มี validation, ไม่เช็ค permission |
| 4 | **Financial Risk** | คำนวณเงินไม่ชัด, ไม่มี audit trail | ไม่บันทึก transaction log |
| 5 | **Data Integrity** | ข้อมูลไม่ sync, race condition | 2 platform แก้ข้อมูลเดียวกันพร้อมกัน |
| 6 | **Privacy** | PDPA, ข้อมูลส่วนบุคคลไม่มี consent | เก็บ biometric โดยไม่ขอ consent |

---

## 3. Impact Severity Classification

| ระดับ | เกณฑ์ | Action |
|-------|-------|--------|
| **Critical** | ต้องแก้ทันที — กระทบ business logic หลัก, มี security risk | แจ้ง user ทันที + เสนอ fix |
| **High** | ต้องแก้ก่อน finalize — กระทบ flow หลัก, terminology เปลี่ยน | ใส่ใน Impact Report ด้านบน |
| **Medium** | แก้ได้ใน sprint ถัดไป — กระทบ flow รอง, UI detail | ใส่ใน Impact Report กลาง |
| **Low** | Nice-to-have — cosmetic, annotation update | ใส่ใน Impact Report ด้านล่าง |

---

## 4. Conflict Resolution Rules

เมื่อ MOM ใหม่ขัดแย้งกับ MOM เก่า:

1. **MOM ใหม่ (วันที่ล่าสุด) ถือเป็น version ที่ถูกต้องที่สุด** — ตามกฎใน AGENTS.md
2. **แต่ต้องแจ้งผู้ใช้เสมอ** — ระบุจุดที่ขัดแย้ง + ถามว่าจะ override จริงหรือไม่
3. **ถ้า MOM ใหม่ไม่ได้พูดถึง feature เดิม** — ถาม user: "feature นี้ยังอยู่ไหม หรือ descope แล้ว?"
4. **ถ้า Transcription ขัดแย้งกับ MOM** — ยึด MOM เสมอ แล้วแจ้ง user ว่า Transcription บอกต่าง
