---
name: Dev Handoff
description: สร้าง Developer Handoff Package จาก SystemFlow, UserFlow, UseCase, Wireframe ที่ PM ทำเสร็จแล้ว — แปลง diagram เป็น spec ที่ DEV เอาไปเขียนโค้ดได้เลย ครอบคลุม Data Model, API Spec, Component Inventory, Implementation Roadmap, Security Checklist — ใช้ทุกครั้งที่ต้องส่งมอบงานจาก PM ไป DEV, สร้าง developer spec, สรุปงานสำหรับ developer, handoff document, implementation guide, หรือเมื่อ DEV ถามว่า "ต้องทำอะไรบ้าง"
---

# PMO Skill: Developer Handoff Package

> **Related Skills:**
> - Load `pmo-traceability` เพื่อ log activity + update Traceability Matrix
> - Load `references/handoff-template.md` for full output template
> - Load `references/extraction-guide.md` for how to extract specs from diagrams
> - Load `references/project-claudemd-template.md` for project-level CLAUDE.md with language rules
> - Load `references/api-conventions.md` for REST API standard conventions
> - Load `references/security-checklist.md` for OWASP Top 10 pre-deployment checklist

---

## Purpose

Skill นี้แปลง output ของ PM (SystemFlow, UserFlow, UseCase, Wireframe, TaskBreakdown) ให้เป็น **Developer Specification Package** ที่ DEV เปิดอ่านแล้วเข้าใจทันทีว่าต้อง code อะไร

**ปัญหาที่ skill นี้แก้:**
- PM สร้าง diagram ดีมาก แต่ DEV เปิดดู .puml แล้วไม่รู้จะเริ่ม code ตรงไหน
- ข้อมูลกระจายอยู่ใน 37+ ไฟล์ — DEV ต้องการ summary ที่รวมทุกอย่าง
- Diagram แสดง "flow" แต่ DEV ต้องการ "spec" (Data Model, API, Components)

---

## Pre-requisite: ตรวจสอบก่อนเริ่ม

**ก่อนสร้าง Handoff Package ต้องตรวจว่า:**

| # | เงื่อนไข | วิธีเช็ค |
|---|---------|---------|
| 1 | SystemFlow มีไฟล์ Final (ไม่มี [DRAFT]) | ดู title ใน .puml files |
| 2 | UserFlow ครบทุก module ที่จำเป็น | เทียบกับ REQ Traceability Matrix |
| 3 | UseCase Diagram ครบทุก Actor | ดู UseCase/ folder |
| 4 | Traceability Matrix อัพเดทล่าสุด | ดู Change Log ใน REQ_Traceability_Matrix.md |
| 5 | User confirm ว่า scope ครบแล้ว | ถามผู้ใช้ |

**ถ้าไม่ผ่านข้อใดข้อหนึ่ง → แจ้งผู้ใช้ว่าต้องทำอะไรก่อน ห้ามสร้าง Handoff Package จาก draft**

---

## Workflow: 8 ขั้นตอน

### Step 1: Scan & Inventory

อ่านไฟล์ทั้งหมดใน project:

```
1. ls SystemFlow/ → list ทุก .puml files
2. ls UserFlow/ → list ทุก .puml files
3. ls UseCase/ → list ทุก .puml files
4. ls Wireframe/ → ดูว่ามี wireframe อะไรบ้าง
5. ls TaskBreakdown/ → ดูว่ามี task breakdown ไหม
6. Read REQ_Traceability_Matrix.md → ดู requirement coverage
```

**Output:** Module Inventory Table

```markdown
| Module | SystemFlow | UserFlow | UseCase | Wireframe | Status |
|--------|-----------|----------|---------|-----------|--------|
| 01 Admin Login | BOF-SysF-01 ✓ | BOF-UseF-01 ✓ | UC-01 ✓ | - | Ready |
| 02 Dashboard | BOF-SysF-02 ✓ | BOF-UseF-02 ✓ | UC-01 ✓ | WF-02 ✓ | Ready |
| 03 Customer Mgmt | BOF-SysF-03 ✓ | - | UC-02 ✓ | - | Missing UserFlow |
```

### Step 2: Extract Data Model

**อ่านทุก SystemFlow .puml file แล้วดึงข้อมูล:**

สิ่งที่ต้อง extract จาก diagram:

| ดูจากตรงไหนใน .puml | Extract เป็นอะไร |
|---------------------|-----------------|
| `note right` ที่มี "Table Columns", "Fields", "Data" | → Entity fields |
| Activity step ที่มี "Create", "Update", "Save" | → Entity name + operations |
| Decision point (`if` / `elseif`) | → Validation rules |
| Activity step ที่มี "Status =" | → Status enum values |
| `note right` ที่มี "Actions" | → UI actions → API endpoints |

**Output Format:** ดู `references/handoff-template.md` section "Data Model"

### Step 3: Extract API Specification

> **ใช้ `references/api-conventions.md`** เป็น standard สำหรับ URL naming, response envelope, error codes, pagination, status codes

**จาก SystemFlow ที่มี Backend API lane:**

| ดูจากตรงไหน | Extract เป็นอะไร |
|------------|-----------------|
| Backend lane activity "Execute: Action1, Action2" | → API endpoint operations |
| Frontend lane → Backend lane transition | → Request trigger + payload |
| Backend lane → Frontend lane transition | → Response payload |
| Error/Exception paths | → Error codes + messages |
| `note right` ที่มี "Validation" | → Request validation rules |

**Output Format:** ดู `references/handoff-template.md` section "API Specification"

### Step 4: Extract Component Inventory

**จาก UserFlow + Wireframe (ถ้ามี):**

| ดูจากตรงไหน | Extract เป็นอะไร |
|------------|-----------------|
| Frontend lane activities "Display list/form/modal" | → Page/Component name |
| `note right` ที่มี "Table Columns" | → Table component + columns |
| `note right` ที่มี "Admin must fill" / "Form Fields" | → Form component + fields |
| Activity "Show Confirmation Modal" | → Modal component |
| Activity "Display Success/Error" | → Toast/Alert component |
| Decision point ที่ user ต้องเลือก | → UI interaction (button, toggle, etc.) |

**Output Format:** ดู `references/handoff-template.md` section "Component Inventory"

### Step 5: Generate Implementation Roadmap

**จัดลำดับ module ที่ DEV ควร code ก่อน-หลัง:**

กฎจัดลำดับ:

1. **Foundation first** — Auth, Config, Core Models ต้องทำก่อน
2. **Dependency order** — Module ที่ module อื่นพึ่งพาต้องทำก่อน
3. **Complexity gradient** — เริ่มจาก CRUD ง่ายๆ ก่อน แล้วค่อยทำ complex workflow
4. **Business priority** — Feature ที่ลูกค้าต้องการเร็วทำก่อน (ดูจาก MOM priority)

**Output Format:**

```markdown
## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)
| Order | Module | Reason | Dependencies |
|-------|--------|--------|-------------|
| 1 | Auth & Login | ทุก module ต้อง auth ก่อน | None |
| 2 | System Config | Feature toggle ใช้ทุก module | Auth |
| 3 | User Management | CRUD พื้นฐาน | Auth |

### Phase 2: Core Business (Week 3-5)
| Order | Module | Reason | Dependencies |
|-------|--------|--------|-------------|
| 4 | Customer Management | Data หลักของระบบ | Auth, Config |
| 5 | Transaction | Core business logic | Customer, Config |
```

### Step 6: Security & Compliance Checklist

**อ่าน AGENTS.md section 3.6 + 3.11 + `references/security-checklist.md` (OWASP Top 10) แล้วสร้าง checklist per module:**

> **ใหม่:** ใช้ OWASP Top 10 Pre-Deployment Checklist จาก `references/security-checklist.md` เพื่อให้ Dev มี actionable checklist ครบ 10 หมวด

```markdown
## Security & Compliance

### Per-Module Checklist
| Module | Auth Required | Audit Log | PDPA | Fraud Prevention | Notes |
|--------|:---:|:---:|:---:|:---:|-------|
| Admin Login | ✓ | ✓ | - | Rate limit, lockout | Max 5 attempts |
| Withdraw Approval | ✓ | ✓ | - | Maker-Checker | 2-person approve > 50K |
| Customer Data | ✓ | ✓ | ✓ | - | Consent required |

### Global Requirements
- [ ] PDPA: Privacy policy consent flow
- [ ] Audit Trail: Log ทุก action ที่เกี่ยวกับเงินและข้อมูลส่วนบุคคล
- [ ] Session Management: Timeout, concurrent session limit
- [ ] Input Validation: ทุก form ต้อง validate ทั้ง frontend + backend
- [ ] Error Handling: ห้ามแสดง technical error ให้ end user
```

### Step 7: Extract Analytics & Tracking Spec

**จาก UserFlow + Wireframe ดึงจุดที่ต้องเก็บ Event:**

สิ่งที่ต้อง extract:

| ดูจากตรงไหน | Extract เป็นอะไร |
|------------|-----------------|
| UserFlow: Activity "Click Button X" / "Submit Form Y" | → Trigger event (user action) |
| UserFlow: Activity "Navigate to Page Z" | → Page view event |
| UserFlow: Decision point "ผ่าน/ไม่ผ่าน" | → Outcome events (success/failure) |
| Wireframe: CTA buttons, forms, modals | → UI interaction events |
| SystemFlow: API success/error paths | → Backend events (transaction completed/failed) |
| MOM/REQ: Business KPI ที่ลูกค้าต้องการ track | → Business metric events |

**Output Format:**

```markdown
## Analytics & Tracking Spec

### Event Catalog

| # | Event Name | Category | Trigger | Properties | Tool | Source |
|---|-----------|----------|---------|-----------|------|--------|
| 1 | user_signup_completed | Auth | กดปุ่ม Confirm บน Modal ยืนยันอีเมล | method (Email/Google), plan_type | Mixpanel | UseF-01 |
| 2 | page_view_dashboard | Navigation | เปิดหน้า Dashboard | referrer, load_time_ms | GA4 | UseF-02 |
| 3 | transaction_created | Business | สร้าง Transaction สำเร็จ | amount, type, customer_id | Mixpanel | SysF-07 |
| 4 | transaction_failed | Error | สร้าง Transaction ล้มเหลว | error_code, error_message | Mixpanel | SysF-07 |
| 5 | filter_applied | UI | ใช้ filter บน List page | filter_type, filter_value | GA4 | UseF-03 |

### Implementation Notes for DEV
- ใช้ helper function `trackEvent(eventName, properties)` กลาง — ฝังเข้าใน Component ตั้งแต่ตอนประกอบหน้าจอ
- ทุก event ต้องแนบ `user_id`, `session_id`, `timestamp` อัตโนมัติ (ใส่ใน helper)
- ถ้า project ยังไม่ตัดสินใจ tool → ใส่ column "Tool" เป็น "TBD" แล้วถามผู้ใช้
```

**กฎสำคัญ:**
- Extract event เฉพาะจาก UserFlow/Wireframe/SystemFlow ที่มี — ห้ามสมมติ event ที่ไม่มี source
- ถ้า MOM/REQ ระบุ KPI ที่ต้อง track → เพิ่ม event สำหรับ KPI นั้นด้วย
- ถ้าไม่แน่ใจว่าต้อง track อะไร → ถามผู้ใช้ก่อน (ห้าม Gold Plate)

### Step 8: Extract UX Copy & Error Message Dictionary

**จาก API Spec (Step 3) + Component Inventory (Step 4) + UserFlow ดึงข้อความที่ต้องแสดงผลจริง:**

สิ่งที่ต้อง extract:

| ดูจากตรงไหน | Extract เป็นอะไร |
|------------|-----------------|
| API Error paths (Step 3) — error codes | → Error messages ที่แสดงให้ user เห็น |
| Component empty states (Step 4) | → Empty state copy |
| Component loading states (Step 4) | → Loading messages |
| UserFlow: Success activities | → Success/confirmation messages |
| Wireframe: Button labels, form labels | → UI labels |
| MOM/REQ: Business terms ที่ลูกค้าใช้ | → Correct terminology for UI |

**Output Format:**

```markdown
## UX Copy & Error Message Dictionary

### Error Messages (from API Spec)

| Error Code | HTTP Status | Toast/Alert Type | Display Message (TH) | Display Message (EN) | Source |
|-----------|:-----------:|:----------------:|---------------------|---------------------|--------|
| VALIDATION_INVALID_EMAIL | 400 | Toast Error | รูปแบบอีเมลไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง | Invalid email format. Please check and try again. | SysF-01 |
| AUTH_WRONG_PASSWORD | 401 | Toast Error | รหัสผ่านไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง | Incorrect password. Please try again. | SysF-01 |
| AUTH_ACCOUNT_LOCKED | 403 | Alert Warning | บัญชีถูกล็อกชั่วคราว กรุณาติดต่อ Admin | Account temporarily locked. Please contact Admin. | SysF-01 |
| FORBIDDEN_NO_PERMISSION | 403 | Toast Error | คุณไม่มีสิทธิ์ในการทำรายการนี้ | You don't have permission for this action. | Global |

### Empty State Messages

| Page/Component | Condition | Display Message | Action Button | Source |
|---------------|-----------|----------------|--------------|--------|
| Dashboard | No data yet | คุณยังไม่มีรายการใดๆ เริ่มต้นสร้างโปรเจคแรกของคุณได้เลย! | + สร้างโปรเจค | UseF-02 |
| Customer List | No results | ไม่พบรายการที่ค้นหา ลองเปลี่ยนคำค้นหาหรือตัวกรอง | ล้างตัวกรอง | UseF-03 |
| Transaction History | Empty | ยังไม่มีรายการธุรกรรม | — | UseF-07 |

### Success Messages

| Action | Display Message | Type | Source |
|--------|----------------|------|--------|
| Create Customer | สร้างข้อมูลลูกค้าเรียบร้อยแล้ว | Toast Success | SysF-03 |
| Approve Transaction | อนุมัติรายการเรียบร้อยแล้ว | Toast Success | SysF-07 |
| Update Profile | บันทึกข้อมูลเรียบร้อยแล้ว | Toast Success | SysF-05 |

### UI Labels & Button Text

| Component | Element | Label (TH) | Label (EN) | Notes |
|-----------|---------|-----------|-----------|-------|
| LoginForm | Submit Button | เข้าสู่ระบบ | Sign In | Not "Login" |
| CustomerForm | Save Button | บันทึก | Save | Not "Submit" |
| ConfirmModal | Confirm Button | ยืนยัน | Confirm | — |
| ConfirmModal | Cancel Button | ยกเลิก | Cancel | — |

### Implementation Notes for DEV
- ใช้ไฟล์ i18n/Language แยกภาษา — ก๊อปปี้ข้อความจากตารางนี้ไปวางใน locale files ได้เลย
- Error messages ต้อง user-friendly — ห้ามแสดง technical error (error code, stack trace) ให้ end user
- Terminology ต้องตรงกับ MOM/REQ ทุกจุด — ถ้า MOM ใช้คำว่า "ลูกค้า" ห้ามใช้ "ผู้ใช้" บน UI
```

**กฎสำคัญ:**
- Error messages extract จาก API error paths ใน Step 3 — ทุก error code ต้องมี display message
- Empty state messages extract จาก Component states ใน Step 4 — ทุก component ที่มี "empty" state ต้องมี copy
- Terminology ต้องตรงกับ MOM/REQ — ห้ามใช้คำอื่น
- ถ้า project ต้องการ 2 ภาษา → ใส่ทั้ง TH และ EN column ถ้าภาษาเดียว → ใส่แค่ภาษาที่ใช้
- ถ้าไม่แน่ใจ tone of voice → ถามผู้ใช้ (formal vs casual)

---

## Output: Handoff Package

**บันทึกทั้งหมดเป็น 1 ไฟล์ใน `SystemFlow/` folder:**

Filename: `DEV_Handoff_{Platform}_{Date}.md`
Example: `DEV_Handoff_BOF_20260310.md`

**โครงสร้างไฟล์:** ดู `references/handoff-template.md` สำหรับ full template

---

## Handoff Checklist (ก่อนส่งมอบ)

| # | ตรวจสอบ | PASS/FAIL |
|---|--------|-----------|
| 1 | ทุก module มี Data Model ครบ (entity + fields + validation) | |
| 2 | ทุก module มี API Spec อย่างน้อย CRUD endpoints | |
| 3 | ทุก module มี Component Inventory (pages + forms + tables) | |
| 4 | Implementation Roadmap มีลำดับที่ dependency ถูกต้อง | |
| 5 | Security Checklist ครอบคลุมทุก module | |
| 6 | Analytics & Tracking Spec ครอบคลุมทุก user action สำคัญ + business KPI | |
| 7 | UX Copy & Error Messages ครบทุก error code + empty state + success message | |
| 8 | ทุก spec อ้างอิงกลับไปหา SystemFlow ได้ (มี Ref) | |
| 9 | ไม่มี Gold Plating — spec ตรงกับ MOM/REQ เท่านั้น | |
| 10 | Terminology ตรงกับ MOM/REQ ทุกจุด | |
| 11 | ผู้ใช้ (PM) review แล้ว confirm | |

---

## Important Notes

- **ห้ามสมมติ Data Model** — extract จาก diagram เท่านั้น ถ้า diagram ไม่ได้ระบุ field → ถามผู้ใช้
- **ห้าม Gold Plate API** — สร้างเฉพาะ endpoint ที่ diagram แสดงเท่านั้น
- **ห้ามเพิ่ม feature ที่ไม่อยู่ใน scope** — ตรวจกับ Traceability Matrix
- **ภาษา spec ใช้ English** — Data Model, API, Component names ใช้ภาษาอังกฤษ ส่วน description/notes ใช้ไทยได้
- **อ้างอิง SystemFlow เสมอ** — ทุก entity/endpoint/component ต้องระบุว่ามาจาก module ไหน
