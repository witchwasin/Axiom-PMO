# Developer Handoff Template

> **ใช้ template นี้เป็นโครงสร้างหลักของ Handoff Package**
> แต่ละ section อาจปรับ column/detail ตาม project ได้

---

## Full Template

```markdown
# Developer Handoff: {Platform} — {Project Name}

> **Created:** {Date}
> **Project:** {Project Code} — {Project Name}
> **PM:** {PM Name}
> **Ref:** MOM#{numbers}, REQ: {REQ file name}
> **Scope:** {Brief scope description}

---

## 1. Module Inventory

> Summary ว่า project มี module อะไรบ้าง แต่ละ module มี artifact ครบไหม

| # | Module | SystemFlow | UserFlow | UseCase | Wireframe | Handoff Status |
|---|--------|-----------|----------|---------|-----------|---------------|
| 01 | Admin Login | BOF-SysF-01 ✓ | BOF-UseF-01 ✓ | UC-01 ✓ | WF-01 ✓ | ✅ Ready |
| 02 | Dashboard | BOF-SysF-02 ✓ | BOF-UseF-02 ✓ | UC-01 ✓ | WF-02 ✓ | ✅ Ready |
| 03 | ... | ... | ... | ... | ... | ... |

**Legend:** ✅ Ready = spec ครบ | ⚠️ Partial = ขาดบาง artifact | ❌ Not Ready = ยังไม่พร้อม

---

## 2. Data Model

> Entity ทั้งหมดที่ extract จาก SystemFlow — DEV ใช้เป็น reference สร้าง database schema

### 2.1 Entity List

| Entity | Source Module | Description | Key Relationships |
|--------|-------------|-------------|-------------------|
| Customer | SysF-03 | ข้อมูลลูกค้า | has_many: Transaction, Portfolio |
| Transaction | SysF-07 | รายการธุรกรรม | belongs_to: Customer |
| ... | ... | ... | ... |

### 2.2 Entity Detail: {EntityName}

> ทำซ้ำ section นี้สำหรับทุก entity

**Source:** BOF-SysF-{XX}_{Name}.puml

| Field | Type | Required | Validation | Notes |
|-------|------|:--------:|-----------|-------|
| id | UUID | ✓ | Auto-generated | Primary key |
| customer_id | UUID | ✓ | Must exist in customers | FK → customers.id |
| status | ENUM | ✓ | {list of valid values} | Default: "pending" |
| amount | DECIMAL(18,2) | ✓ | > 0 | ห้ามติดลบ |
| created_at | TIMESTAMP | ✓ | Auto-generated | Audit: creation time |
| updated_at | TIMESTAMP | ✓ | Auto-generated | Audit: last update |
| created_by | UUID | ✓ | Must exist in admins | Audit: who created |

**Status Flow:**
```
pending → approved → completed
pending → rejected
```

**Indexes:**
- `idx_customer_id` on customer_id (FK lookup)
- `idx_status_created` on (status, created_at) (list filtering)

---

## 3. API Specification

> Endpoint ทั้งหมดที่ extract จาก SystemFlow Backend lane — DEV ใช้เป็น reference สร้าง API

### 3.1 Endpoint Summary

| # | Method | Path | Description | Auth | Source |
|---|--------|------|-------------|:----:|--------|
| 1 | POST | /api/auth/login | Admin login | No | SysF-01 |
| 2 | GET | /api/customers | List customers | ✓ | SysF-03 |
| 3 | POST | /api/transactions | Create transaction | ✓ | SysF-07 |
| ... | ... | ... | ... | ... | ... |

### 3.2 Endpoint Detail: {Method} {Path}

> ทำซ้ำ section นี้สำหรับทุก endpoint ที่มี logic ซับซ้อน

**Source:** BOF-SysF-{XX}, Steps {N}-{M}

**Request:**
```json
{
  "customer_id": "uuid (required)",
  "amount": "decimal (required, > 0)",
  "type": "string (required, enum: buy|sell)",
  "note": "string (optional, max 500 chars)"
}
```

**Response (Success 200):**
```json
{
  "id": "uuid",
  "status": "pending",
  "created_at": "ISO 8601",
  "message": "Transaction created successfully"
}
```

**Response (Error 400):**
```json
{
  "error": "VALIDATION_ERROR",
  "message": "Amount must be greater than 0",
  "field": "amount"
}
```

**Response (Error 403):**
```json
{
  "error": "FORBIDDEN",
  "message": "Insufficient permission"
}
```

**Business Rules (from SystemFlow):**
1. ตรวจ permission ก่อน (Step X)
2. Validate input (Step Y)
3. Check business rule Z (Step Z)
4. ถ้าผ่าน → Create record + Update status
5. ถ้าไม่ผ่าน → Return error + Log attempt

---

## 4. Component Inventory

> หน้าจอทั้งหมดที่ extract จาก UserFlow + Wireframe — DEV ใช้สร้าง frontend

### 4.1 Page Summary

| # | Page | Path | Source | Components | Notes |
|---|------|------|--------|-----------|-------|
| 1 | Login | /login | UseF-01 | LoginForm | Public page |
| 2 | Dashboard | /dashboard | UseF-02 | StatCards, Chart, RecentTable | Requires auth |
| 3 | Customer List | /customers | UseF-03 | DataTable, SearchBar, FilterPanel | Pagination required |
| ... | ... | ... | ... | ... | ... |

### 4.2 Page Detail: {PageName}

> ทำซ้ำสำหรับ page ที่มี component ซับซ้อน

**Source:** BOF-UseF-{XX}, Wireframe: WF-{XX}

**Layout:**
- Header: Standard app header with navigation
- Sidebar: Module navigation (shared)
- Content: {description}

**Components:**

| Component | Type | Props/Fields | States | Backend Integration |
|-----------|------|-------------|--------|-------------------|
| CustomerTable | DataTable | columns: [name, status, balance, actions] | loading, empty, error, data | GET /api/customers |
| SearchBar | Input | placeholder: "Search by name or ID" | default, typing | Query param: ?search= |
| FilterPanel | Form | status (dropdown), date_range (datepicker) | default, applied | Query params: ?status=&from=&to= |
| ActionButtons | ButtonGroup | [View, Edit, Suspend] | enabled, disabled (by permission) | Per-row actions |

**User Interactions (from UserFlow):**
1. เปิดหน้า → Load customer list (GET /api/customers)
2. พิมพ์ค้นหา → Filter list (debounce 300ms)
3. Click "View" → Navigate to /customers/{id}
4. Click "Suspend" → Show confirmation modal → POST /api/customers/{id}/suspend

---

## 5. Implementation Roadmap

> ลำดับการ code ที่แนะนำ — DEV ใช้จัด sprint planning

### Phase 1: Foundation (Week 1-2)

| Order | Module | What to Build | Dependencies | Est. Days |
|-------|--------|--------------|-------------|-----------|
| 1 | Database Schema | Tables, indexes, migrations | None | 2d |
| 2 | Auth & Session | Login, JWT, middleware | DB Schema | 3d |
| 3 | System Config | Feature toggles, settings | DB Schema, Auth | 2d |
| 4 | Shared Components | Layout, Sidebar, Header, DataTable | None (frontend) | 3d |

### Phase 2: Core Features (Week 3-5)

| Order | Module | What to Build | Dependencies | Est. Days |
|-------|--------|--------------|-------------|-----------|
| 5 | Customer CRUD | List, View, Create, Edit | Auth, Shared | 4d |
| 6 | Transaction Flow | Create, Approve, Reject | Customer, Auth, Config | 5d |
| ... | ... | ... | ... | ... |

### Phase 3: Advanced & Integration (Week 6-7)

| Order | Module | What to Build | Dependencies | Est. Days |
|-------|--------|--------------|-------------|-----------|
| N | Reports | Dashboard stats, export | All core modules | 3d |
| N+1 | Notifications | Email, push, in-app | All modules | 3d |

### Phase 4: Testing & QA (Week 8)

| Task | Scope | Owner |
|------|-------|-------|
| Unit Tests | Per module | DEV |
| Integration Tests | Cross-module | DEV + QA |
| UAT | Full system | PM + Client |

### Database Migration Order

```
001_create_users_table
002_create_customers_table
003_create_transactions_table
004_create_system_config_table
005_create_audit_logs_table
...
```

---

## 6. Security & Compliance Checklist

> DEV ต้องตรวจสอบทุกข้อก่อน deploy

### Per-Module Security

| Module | Auth | RBAC | Audit Log | Input Validation | Rate Limit | PDPA |
|--------|:----:|:----:|:---------:|:----------------:|:----------:|:----:|
| Login | - | - | ✓ | ✓ | ✓ (5/min) | - |
| Customer Mgmt | ✓ | ✓ | ✓ | ✓ | - | ✓ |
| Transaction | ✓ | ✓ | ✓ | ✓ | - | - |
| Withdraw Approval | ✓ | ✓ (Maker-Checker) | ✓ | ✓ | - | - |

### Global Security Requirements

- [ ] **Authentication:** JWT with refresh token, session timeout {X} minutes
- [ ] **Authorization:** RBAC — permission per module per action (view/create/edit/delete/approve)
- [ ] **Audit Trail:** Log ทุก write operation (create/update/delete/approve/reject)
- [ ] **Input Validation:** Validate ทั้ง frontend + backend (never trust frontend only)
- [ ] **Error Handling:** ห้ามแสดง stack trace / technical error ให้ end user
- [ ] **PDPA Compliance:** Consent flow, data retention policy, right to delete
- [ ] **Fraud Prevention:** Maker-Checker สำหรับ transaction > threshold
- [ ] **Encryption:** Password hashing (bcrypt), sensitive data at rest, HTTPS in transit

---

## 7. Analytics & Tracking Spec

> Event ทั้งหมดที่ DEV ต้องฝัง — ใช้ `trackEvent()` helper ติดตั้งตั้งแต่ตอนประกอบ Component

### Event Catalog

| # | Event Name | Category | Trigger | Properties | Tool | Source |
|---|-----------|----------|---------|-----------|------|--------|
| 1 | user_signup_completed | Auth | กดปุ่ม Confirm บน Modal ยืนยันอีเมล | method (Email/Google), plan_type | Mixpanel | UseF-01 |
| 2 | page_view_dashboard | Navigation | เปิดหน้า Dashboard | referrer, load_time_ms | GA4 | UseF-02 |
| 3 | transaction_created | Business | สร้าง Transaction สำเร็จ | amount, type, customer_id | Mixpanel | SysF-07 |
| ... | ... | ... | ... | ... | ... | ... |

### Implementation Notes
- ใช้ helper `trackEvent(eventName, properties)` กลาง — auto-attach `user_id`, `session_id`, `timestamp`
- ฝังเข้าใน Component ตั้งแต่ตอนประกอบหน้าจอ ไม่ต้องมารื้อโค้ดฝัง Event ทีหลัง
- ถ้ายังไม่ตัดสินใจ tool → ใส่ "TBD" แล้วถาม PM

---

## 8. UX Copy & Error Message Dictionary

> ข้อความจริงที่ต้องใช้แสดงผลบนหน้าจอ — DEV ก๊อปไปวาง i18n ได้เลย

### Error Messages

| Error Code | HTTP | Toast/Alert | Display Message (TH) | Display Message (EN) | Source |
|-----------|:----:|:-----------:|---------------------|---------------------|--------|
| VALIDATION_INVALID_EMAIL | 400 | Toast Error | รูปแบบอีเมลไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง | Invalid email format | SysF-01 |
| AUTH_WRONG_PASSWORD | 401 | Toast Error | รหัสผ่านไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง | Incorrect password | SysF-01 |
| ... | ... | ... | ... | ... | ... |

### Empty State Messages

| Page/Component | Condition | Display Message | Action Button | Source |
|---------------|-----------|----------------|--------------|--------|
| Dashboard | No data | คุณยังไม่มีรายการใดๆ เริ่มต้นสร้างโปรเจคแรกของคุณได้เลย! | + สร้างโปรเจค | UseF-02 |
| ... | ... | ... | ... | ... |

### Success Messages

| Action | Display Message | Type | Source |
|--------|----------------|------|--------|
| Create Customer | สร้างข้อมูลลูกค้าเรียบร้อยแล้ว | Toast Success | SysF-03 |
| ... | ... | ... | ... |

### UI Labels

| Component | Element | Label (TH) | Label (EN) | Notes |
|-----------|---------|-----------|-----------|-------|
| LoginForm | Submit | เข้าสู่ระบบ | Sign In | Not "Login" |
| ... | ... | ... | ... | ... |

### Implementation Notes
- ใช้ i18n locale files — ก๊อปข้อความจากตารางนี้ไปวาง
- Error messages ต้อง user-friendly — ห้าม show technical error
- Terminology ต้องตรงกับ MOM/REQ ทุกจุด

---

## 9. Configuration Schema

> ค่า config ทั้งหมดที่ระบบต้องตั้ง — DEV ใช้สร้าง config/env

| Key | Type | Default | Description | Source |
|-----|------|---------|-------------|--------|
| SESSION_TIMEOUT_MIN | int | 30 | Auto logout after N minutes | SysF-01 |
| MAX_LOGIN_ATTEMPTS | int | 5 | Lock account after N failed attempts | SysF-01 |
| TRANSACTION_APPROVE_THRESHOLD | decimal | 50000 | Amount requiring 2-person approval | SysF-07 |
| FEATURE_TOGGLE_XXX | boolean | true | Enable/disable feature XXX | SysF-15 |

---

## Appendix: Validation Result

> สรุปผล Handoff Checklist

| # | Check | Result | Notes |
|---|-------|--------|-------|
| 1 | ทุก module มี Data Model ครบ | ✅ / ❌ | |
| 2 | ทุก module มี API Spec | ✅ / ❌ | |
| 3 | ทุก module มี Component Inventory | ✅ / ❌ | |
| 4 | Implementation Roadmap dependency ถูกต้อง | ✅ / ❌ | |
| 5 | Security Checklist ครอบคลุมทุก module | ✅ / ❌ | |
| 6 | ทุก spec อ้างอิง SystemFlow ได้ | ✅ / ❌ | |
| 7 | ไม่มี Gold Plating | ✅ / ❌ | |
| 8 | Terminology ตรงกับ MOM/REQ | ✅ / ❌ | |
| 9 | PM review + confirm | ✅ / ❌ | |
```

---

## How to Use This Template

1. Copy template ข้างบนลงไฟล์ `DEV_Handoff_{Platform}_{Date}.md`
2. เติมข้อมูลจาก extraction (Step 2-6 ใน SKILL.md)
3. ลบ section ที่ไม่เกี่ยวข้อง (เช่น ถ้าไม่มี PDPA ก็ลบ PDPA row)
4. เพิ่ม section ถ้า project ต้องการ (เช่น 3rd party integration spec)
5. Run Handoff Checklist → fix issues → ให้ PM review
