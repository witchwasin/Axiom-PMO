# Test Case Generation Guide

> AI ใช้ guide นี้เพื่อ generate test cases จาก SystemFlow (.puml) อัตโนมัติ

---

## วิธี Generate Test Cases จาก PlantUML Activity Diagram

### Step 1: Parse Flow Structure

อ่าน .puml file แล้วระบุ:
- **Activities** (`:X. action;`) — ทุก step ใน flow
- **Decisions** (`if/elseif/else/endif`) — ทุกจุดตัดสินใจ
- **Lanes** (`|#color|Actor|`) — actors ที่เกี่ยวข้อง
- **Notes** (`note right...end note`) — business rules and validations

### Step 2: Trace Paths

| ประเภท Path | วิธีหา | เป็น Test Case ประเภท |
|------------|-------|---------------------|
| **Main Path** | Follow ทุก `then (Yes/OK/Approve/Pass)` จาก start -> stop | Happy Case |
| **Branch Path** | ทุก `else` and `elseif` ที่ไม่ใช่ error | Alternative Case |
| **Error Path** | ทุก branch ที่มี error/fail/reject/invalid/timeout/block | Exception Flow |

### Step 3: Write Test Cases

แต่ละ Test Case ต้องมี:

| Field | Description |
|-------|-------------|
| **ID** | `H-001`, `A-001`, `E-001` (H=Happy, A=Alternative, E=Exception) |
| **Test Case** | ชื่อสั้นๆ อธิบาย scenario |
| **Description** | รายละเอียดว่าต้องทำอะไร (step-by-step) |
| **Precondition** | เงื่อนไขก่อนเริ่ม test (เช่น user ต้อง login แล้ว) |
| **Expected Result** | ผลลัพธ์ที่ต้องเกิดขึ้น |
| **Status** | `-` (ยังไม่ test) / `Pass` / `Fail` |

### Step 4: Coverage Check

หลัง generate แล้ว ตรวจว่า:
- [ ] ทุก Decision branch มี test case ครอบคลุม
- [ ] Main path (Happy) ครบตั้งแต่ start ถึง stop
- [ ] ทุก error message ใน flow มี exception test case
- [ ] ทุก validation rule มี test case (ทั้ง pass and fail)

---

## ตัวอย่าง: Generate จาก UseF-12 (Manage Pricing)

**Flow Structure:**
```
start -> Admin เข้าหน้า Pricing -> ตรวจ sales_approved
  -> if (sales_approved?)
    -> then: แสดงหน้า Pricing
    -> else: แจ้ง "ต้อง approve ก่อน"
  -> Admin toggle Free/Paid
  -> if (เปลี่ยนเป็น Paid?)
    -> then: ราคาคงที่ 3 NC
    -> else: ราคา = 0
  -> Confirm -> Save -> stop
```

**Generated Test Cases:**

| ID | Type | Test Case | Expected Result |
|----|------|-----------|-----------------|
| H-001 | Happy | Toggle novel เป็น Paid สำเร็จ | ราคา = 3 NC, status = Paid |
| H-002 | Happy | Toggle novel เป็น Free สำเร็จ | ราคา = 0, status = Free |
| H-003 | Happy | ดูหน้า Pricing list ทั้งหมด | แสดง list novel + สถานะ Free/Paid |
| H-004 | Happy | ดู Pricing history | แสดง log การเปลี่ยนราคาย้อนหลัง |
| A-001 | Alt | Toggle Paid -> Free ขณะมีคนซื้อ episode อยู่ | แจ้ง warning + ยืนยันก่อนเปลี่ยน |
| A-002 | Alt | Batch toggle หลาย novel พร้อมกัน | ทุก novel เปลี่ยนสถานะพร้อมกัน |
| E-001 | Exception | เข้าหน้า Pricing แต่ไม่มี sales_approved | แจ้ง error: "ต้อง approve ก่อน" + link ไป Module 11 |
| E-002 | Exception | Toggle Paid แต่ novel ยังไม่มี 10 episode | แจ้ง error: "ต้องมีอย่างน้อย 10 ตอน" |
| E-003 | Exception | API timeout ขณะ save | แจ้ง error + retry option |
