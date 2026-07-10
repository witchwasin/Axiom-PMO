# Extraction Guide: วิธีดึง Spec จาก Diagram

> **คู่มือนี้อธิบายวิธี extract Data Model, API, Components จาก PlantUML Activity Diagram**
> ใช้ประกอบกับ SKILL.md Step 2-4

---

## 1. อ่าน .puml File: สิ่งที่ต้องมองหา

PlantUML Activity Diagram (Swimlane) มีโครงสร้างดังนี้:

```plantuml
@startuml
title Module XX-A: Workflow Name [Ref: MOM#X - Topic]

|#FFF9E0|Backend API|        ← Lane = Actor/System
:1. First action;            ← Activity Step
note right                   ← Note = Detail/Fields/Columns
**Bold Header:**
- Detail
end note

if (Condition?) then (yes)   ← Decision = Business Rule / Validation
  :2. Do something;
else (no)
  :3. Do other;
endif

stop
@enduml
```

---

## 2. Extract Data Model

### 2.1 หา Entity Name

**Pattern ที่บอกว่ามี Entity:**

| Pattern ใน Activity Step | Entity ที่ได้ |
|-------------------------|--------------|
| `:N. Create {Name};` | → Entity: {Name} |
| `:N. Save {Name};` | → Entity: {Name} |
| `:N. Update {Name} Record;` | → Entity: {Name} |
| `:N. Insert to {Name} table;` | → Entity: {Name} |
| `:N. Log {Name};` | → Entity: {Name} (audit) |

**ตัวอย่าง:**
```
:12. Create Withdraw Request;  → Entity: WithdrawRequest
:15. Log Activity;             → Entity: ActivityLog
:8. Update Customer Status;    → Entity: Customer (has status field)
```

### 2.2 หา Fields

**Pattern ที่บอก fields:**

| ที่มา | วิธี Extract |
|-------|-------------|
| `note right` ที่มี "Table Columns" | แต่ละ bullet = 1 column/field |
| `note right` ที่มี "Form Fields" / "Admin must fill" | แต่ละ bullet = 1 input field |
| `note right` ที่มี "Details" | แต่ละ bullet = 1 display field |
| Activity ที่มี `Status = "value"` | → status field + enum value |
| Activity ที่มี `\n` (multiple lines) | แต่ละบรรทัด = 1 action/field |

**ตัวอย่าง:**
```
note right
**Table Columns:**
- Transaction ID       → field: transaction_id (string/UUID)
- Customer Name        → field: customer_name (string) [FK or denormalized]
- Amount              → field: amount (decimal)
- Status              → field: status (enum)
- Created Date        → field: created_at (timestamp)
**Actions:**
-> View               → endpoint: GET /api/transactions/{id}
-> Approve            → endpoint: POST /api/transactions/{id}/approve
end note
```

### 2.3 หา Validation Rules

**Pattern ที่บอก validation:**

| ที่มา | Validation Rule |
|-------|----------------|
| `if (Amount > 50000?)` | → amount: max_without_approval = 50000 |
| `if (Status = "Pending"?)` | → status must be "Pending" to proceed |
| `if (Duplicate check?)` | → unique constraint on some field |
| `note right` ที่มี "Condition" | → business rule / precondition |
| `note right` ที่มี "Validation" | → input validation rules |

### 2.4 หา Status Flow

**Pattern:**
```
:N. Update Status = "approved";
```

รวบรวมทุก status value ที่พบ → สร้าง status enum + state machine:
```
pending → processing → approved → completed
                    → rejected
```

---

## 3. Extract API Specification

### 3.1 หา Endpoint

**Pattern ที่บอกว่ามี API call:**

| Transition Pattern | Endpoint Type |
|-------------------|--------------|
| Frontend lane → Backend lane (user click) | → POST/PUT (write action) |
| Backend lane → Frontend lane (display) | → GET (read/list) |
| Backend lane activity "Check/Validate" | → Part of endpoint logic |
| Backend lane activity "Send Notification" | → Side effect (async) |

**Naming Convention สำหรับ endpoint path:**

| Action ใน diagram | Method + Path |
|-------------------|--------------|
| Display list | GET /api/{resource}s |
| View detail | GET /api/{resource}s/{id} |
| Create new | POST /api/{resource}s |
| Update existing | PUT /api/{resource}s/{id} |
| Delete | DELETE /api/{resource}s/{id} |
| Approve/Reject | POST /api/{resource}s/{id}/{action} |
| Change status | PATCH /api/{resource}s/{id}/status |

### 3.2 หา Request Payload

**จาก:**
- `note right` ที่มี "Admin must fill" / "Form Fields" → required fields
- Activity step ก่อน Backend lane → ข้อมูลที่ส่งมา
- Decision point ก่อน Execute → validation ที่ต้อง pass

### 3.3 หา Response Payload

**จาก:**
- Activity step หลัง Backend ทำเสร็จ → success response
- `note right` ที่แสดงข้อมูลบน Frontend → response fields
- Error/Exception path → error response

### 3.4 หา Error Cases

**จาก:**
- `else` branch ของ decision → error scenario
- Activity ที่มี "Display Error" → error message
- Activity ที่มี "Return to" / "Redirect" → error flow

---

## 4. Extract Component Inventory

### 4.1 หา Page/Screen

**Pattern:**

| Activity ใน Frontend lane | Component Type |
|--------------------------|---------------|
| `:N. Enter/Open {page name};` | → Page component |
| `:N. Display {name} list;` | → Page with DataTable |
| `:N. Show {name} form;` | → Page with Form |
| `:N. Show Confirmation Modal;` | → Modal component |
| `:N. Display "Success";` | → Toast/Notification |

### 4.2 หา Component Detail

**จาก note right:**

| Note Header | Component Type | Detail |
|-------------|---------------|--------|
| "Table Columns" | DataTable | columns list |
| "Form Fields" / "Must fill" | Form | input fields |
| "Details" | DetailView | display fields |
| "Actions" | ButtonGroup | action buttons |
| "Filter" | FilterPanel | filter options |

### 4.3 หา States

**ทุก component ต้องมีอย่างน้อย 4 states:**

| State | เมื่อไหร่ | มาจากไหนใน diagram |
|-------|---------|-------------------|
| Loading | กำลังโหลดข้อมูล | Transition ระหว่าง Frontend → Backend |
| Data | แสดงข้อมูลสำเร็จ | Activity หลัง Backend ส่งกลับ |
| Empty | ไม่มีข้อมูล | ไม่ค่อยมีใน diagram → ต้องเพิ่มเอง |
| Error | โหลดไม่สำเร็จ | Error/Exception path |

---

## 5. Cross-Reference Checklist

หลัง extract เสร็จ ต้องตรวจ:

| # | ตรวจอะไร | วิธีตรวจ |
|---|---------|---------|
| 1 | ทุก Entity มี CRUD endpoints ครบไหม | นับ entity vs endpoints |
| 2 | ทุก Form มี POST/PUT endpoint ไหม | จับคู่ form → endpoint |
| 3 | ทุก DataTable มี GET endpoint ไหม | จับคู่ table → endpoint |
| 4 | ทุก Action Button มี endpoint ไหม | จับคู่ button → endpoint |
| 5 | ทุก Decision point มี validation ใน API ไหม | จับคู่ condition → validation |
| 6 | ทุก Status change มี endpoint ไหม | จับคู่ status → endpoint |
| 7 | ทุก Notification มี trigger ไหม | จับคู่ notification → event |

**ถ้าพบ gap → แจ้งผู้ใช้ว่า diagram อาจไม่ครอบคลุมจุดนี้ ห้ามสมมติเอง**
