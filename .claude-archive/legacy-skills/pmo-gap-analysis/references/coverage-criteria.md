# Coverage Criteria — เกณฑ์ตัดสินว่า REQ ถูก implement หรือยัง

> ใช้เป็น reference เมื่อจัดกลุ่ม REQ เป็น Covered / Partial / Missing / Orphan

---

## 1. Coverage Status Definitions

### Covered (ครบแล้ว)

REQ ถูก implement ครบทั้ง 3 ระดับ:

| ระดับ | ต้องมี | ตัวอย่าง |
|-------|--------|---------|
| **SystemFlow** | มี .puml ที่ครอบคลุม feature นี้ | `BOF-SysF-01_AdminLogin.puml` มี step login |
| **UserFlow** | มี .puml ที่แสดง user journey | `BOF-UseF-01_AdminLogin.puml` |
| **UseCase** | มี use case ที่ระบุ actor + system interaction | `UC-01_AuthAccessControl.puml` |

**หมายเหตุ:** ไม่จำเป็นต้องมี Wireframe ถึงจะนับว่า Covered (Wireframe เป็น optional layer)

### Partial (ครบบางส่วน)

REQ ถูก implement แต่ไม่ครบ:

| สถานการณ์ | ตัวอย่าง |
|----------|---------|
| มี SystemFlow แต่ไม่มี UserFlow | สร้าง flow แล้วแต่ยังไม่ derive user journey |
| มี diagram แต่ไม่ครอบคลุม sub-feature ทั้งหมด | REQ บอก Login + Forgot Password แต่ diagram มีแค่ Login |
| มี Happy Case แต่ไม่มี Error/Alt Case | Flow แสดงแค่กรณีสำเร็จ ไม่มีกรณีผิดพลาด |
| มี diagram แต่ใช้ terminology ไม่ตรง REQ | Diagram เขียน "Sign In" แต่ REQ เขียน "เข้าสู่ระบบ" |

### Missing (ยังไม่มีเลย)

ไม่มี diagram ใดๆ ที่ครอบคลุม REQ นี้ ไม่ว่าจะ SystemFlow, UserFlow, หรือ UseCase

### Orphan (มี diagram แต่ไม่มี REQ)

มี diagram ที่ไม่สามารถ trace กลับไป REQ ได้ — อาจเกิดจาก:

| สาเหตุ | ควรทำอย่างไร |
|--------|------------|
| **Gold Plating** — AI เพิ่มเอง | ลบออก หรือถาม user ว่าต้องการเพิ่มเป็น REQ ไหม |
| **REQ ตกหล่น** — ลืมใส่ใน REQ file | เพิ่ม REQ (ต้อง user approve) |
| **Descoped** — feature ถูกตัดแล้ว | Archive diagram + update Traceability Matrix |
| **Phase อื่น** — อยู่คนละ phase | ย้ายไป future phase folder |

---

## 2. Cross-Reference Method

### วิธีเทียบ REQ กับ Diagram

1. **สร้าง REQ List** — อ่าน REQ CSV แล้ว list ทุก feature + module
2. **สร้าง Diagram List** — scan folder แล้ว list ทุกไฟล์ + module ที่ครอบคลุม
3. **Match ทีละ REQ** — หา diagram ที่ตรงกัน โดยดูจาก:
   - ชื่อ module ตรงกัน
   - Feature name ตรงกัน (หรือ synonym)
   - MOM# reference ตรงกัน
4. **ตรวจ depth ของ coverage** — ไม่ใช่แค่มี diagram ก็นับว่า covered ต้องตรวจ:
   - ครอบคลุม sub-features ทั้งหมดไหม
   - มี Happy + Alt + Exception case ครบไหม
   - terminology ตรงกับ REQ/MOM ไหม

### วิธีหา Orphan Diagram

1. **List diagram ทั้งหมด**
2. **เทียบกลับไป REQ** — diagram ไหนไม่มี REQ ตรงกัน
3. **ตรวจ MOM reference** — ถ้ามี `[Ref: MOM#X]` อาจเป็น feature ที่ MOM ตกลงแต่ยังไม่ได้ใส่ REQ

---

## 3. Priority-Based Reporting

เมื่อสรุป Gap Report ให้เรียงตาม priority:

| ลำดับ | Priority | ทำไมต้องทำก่อน |
|-------|----------|---------------|
| 1 | **Critical/Must-have Missing** | Feature หลักยังไม่มี diagram |
| 2 | **Partial ที่ขาด Error Case** | มี Happy Case แต่ไม่มี error handling |
| 3 | **Partial ที่ขาด UserFlow** | มี SystemFlow แล้วแต่ยังไม่มี UserFlow |
| 4 | **Nice-to-have Missing** | Feature รองยังไม่มี |
| 5 | **Orphan Diagrams** | ต้องตัดสินใจ: เก็บ หรือ archive |

---

## 4. Output Integration

หลังจาก Gap Analysis เสร็จ ต้อง:

1. **Update Traceability Matrix** — เพิ่ม status column (Covered/Partial/Missing)
2. **Log ใน Change Log** — บันทึกว่ารัน Gap Analysis เมื่อไหร่ ผลเป็นอย่างไร
3. **เสนอ Action Plan** — REQ ที่ Missing ควรสร้าง diagram ไหนก่อน (ตาม priority)
