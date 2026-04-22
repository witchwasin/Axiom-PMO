# 7 Failure Modes — ทุก Workflow Spec ต้องครอบคลุม

ทุก step ของทุก workflow ต้องพิจารณา failure mode 7 ประเภทนี้:

| # | Failure Mode | คำถาม | ตัวอย่าง | Recovery |
|---|-------------|-------|---------|---------|
| 1 | **Happy Path** | ทุกอย่างสำเร็จ ข้อมูลถูกต้อง | ลูกค้ากรอกข้อมูลถูก จ่ายเงินผ่าน | ดำเนินการต่อ |
| 2 | **Input Validation Failure** | ข้อมูลผิด format หรือไม่ครบ | Email ไม่ถูก format, จำนวนเงินติดลบ | แสดง error ชัดเจน, ให้แก้ไข |
| 3 | **Timeout** | ระบบรอนานเกิน threshold | API ภายนอกไม่ตอบภายใน 30 วินาที | Retry 2 ครั้ง → แจ้ง admin → rollback |
| 4 | **Transient Failure** | ปัญหาชั่วคราว แก้ได้ด้วย retry | Network glitch, rate limit | Retry with exponential backoff |
| 5 | **Permanent Failure** | ปัญหาถาวร retry ไม่ช่วย | บัญชีถูกปิด, quota หมด | Fail ทันที + แจ้ง user + cleanup |
| 6 | **Partial Failure** | ทำได้ครึ่งทาง แล้ว fail | สร้าง order แล้ว แต่ payment fail | ต้อง rollback สิ่งที่สร้างไปแล้ว |
| 7 | **Concurrent Conflict** | 2 คนทำพร้อมกัน | 2 admin approve คนเดียวกันพร้อมกัน | Optimistic locking / conflict resolution |

## วิธีใช้

เมื่อเขียน STEP ใน workflow spec ให้ถามทั้ง 7 ข้อ:

```markdown
### STEP 3: ชำระเงิน
**Actor:** Payment Gateway
**Action:** หักเงินจากบัญชีลูกค้า
**Success:** เงินหักสำเร็จ → GO TO STEP 4
**Failure:**
  - FAIL(validation): ข้อมูลบัตรไม่ถูกต้อง → แสดง error ให้กรอกใหม่
  - FAIL(timeout): Gateway ไม่ตอบภายใน 30s → retry 2 ครั้ง → แจ้งลูกค้า "กรุณาลองใหม่"
  - FAIL(transient): Rate limit → retry หลัง 5s
  - FAIL(permanent): บัญชีถูกปิด → แจ้งลูกค้าติดต่อธนาคาร
  - FAIL(partial): หักเงินแล้วแต่บันทึก order ไม่ได้ → refund + แจ้ง admin
  - FAIL(conflict): 2 คำสั่งจ่ายพร้อมกัน → ตรวจ idempotency key → ปฏิเสธซ้ำ
```

ไม่จำเป็นต้องครบทุกประเภทในทุก step — แต่ต้อง **พิจารณาทุกประเภท** และระบุว่า "ไม่เกี่ยว" ถ้าไม่เกี่ยว
