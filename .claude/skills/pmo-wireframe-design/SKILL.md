---
name: Wireframe Design
description: สร้าง Wireframe / UI Design โดยใช้ Refero MCP ค้นหา reference จาก product จริง 124,000+ หน้าจอก่อนออกแบบทุกครั้ง — ใช้เมื่อผู้ใช้พูดถึง wireframe, mockup, UI design, ออกแบบหน้าจอ, หน้าตาแอป, หา design reference, เปรียบเทียบ UX pattern, design review, หรือต้องการสร้าง UI จาก User Flow ที่เสร็จแล้ว แม้ผู้ใช้จะไม่ได้พูดว่า "wireframe" โดยตรง ถ้าบริบทเป็นเรื่องหน้าตา UI ก็ให้ใช้ skill นี้
---

# PMO Skill: Wireframe Design (with Refero MCP)

> **Related Skills:**
> - Load `pmo-traceability` — log Wireframe Changes ทุกครั้งที่สร้าง/แก้ไข wireframe
> - Load `pmo-activity-diagram` — ถ้าต้อง derive wireframe จาก User Flow
> - Load `pmo-design-md` — ถ้าโปรเจคยังไม่มี DESIGN.md และต้องการเลือก design system ก่อนวาด
>
> **Required MCP: Refero** — ถ้า Refero MCP tools ไม่พร้อมใช้งาน (เช่น ไม่เจอ `search_screens`) ให้แจ้งผู้ใช้:
> ```
> claude mcp add --transport http refero https://api.refero.design/mcp --header "Authorization: Bearer <token>"
> ```
> ถ้า Refero ใช้ไม่ได้จริงๆ → ยังสร้าง wireframe ได้ แต่ต้องแจ้งผู้ใช้ว่าไม่มี reference จาก product จริง

---

## Goal

สร้าง Wireframe ที่อ้างอิงจาก design ของ product จริง ไม่ใช่สร้างจาก generic template — เพราะ wireframe ที่อ้างอิง pattern จริง communicate กับลูกค้าและ dev team ได้ดีกว่า และลดจำนวนรอบ revision

---

## Workflow Overview

```
Step 1: เข้าใจ Context → Step 2: Research (Refero) → Step 3: สรุป & Confirm
→ Step 4: สร้าง Wireframe → Step 5: Review ด้วย Checklist → Step 6: บันทึก & Log
```

---

## Step 1: เข้าใจ Context

ก่อนออกแบบ ต้องเข้าใจ 4 สิ่งนี้:

| ต้องรู้ | ถามถ้าไม่ระบุ | ตัวอย่าง |
|--------|-------------|---------|
| **Project** | "ทำสำหรับ project ไหน?" | P01-PROJECT |
| **หน้าจอ/Module** | "ออกแบบหน้าอะไร?" | Admin Login, Dashboard |
| **Platform** | "สำหรับ Web, iOS, หรือ Android?" | BOF (Back Office = Web) |
| **Fidelity** | "ต้องการ low-fi (โครง) หรือ high-fi (สมจริง)?" | low-fi สำหรับ review, high-fi สำหรับ handoff |

**อ่าน source files:**
- `Wireframe/DESIGN.md` — **ตรวจก่อนเสมอ** ถ้ามี DESIGN.md ต้องใช้เป็น style guide (สี, font, component style, spacing, shadow) ให้ wireframe ตรงตาม design system ของ project — ถ้าไม่มี DESIGN.md ให้แจ้งผู้ใช้: "โปรเจคนี้ยังไม่มี DESIGN.md ต้องการเลือก design system ก่อนไหม? (ใช้ skill `pmo-design-md`)" แล้วรอคำตอบ ถ้าผู้ใช้บอกไม่ต้อง → วาดด้วย generic style ตามปกติ
- `UserFlow/` — ดู flow ที่เกี่ยวข้อง (ถ้ามี) เพื่อเข้าใจ journey ก่อนออกแบบ
- `MOM/` — ดู requirement/business rule ที่ตกลงกับลูกค้า
- `REQ/` — ดู feature list ที่ต้องครอบคลุม
- `Wireframe/` — ดู wireframe ที่มีอยู่แล้ว เพื่อรักษา consistency

---

## Step 2: Research ด้วย Refero MCP

ใช้ Refero tools ค้นหา reference ก่อนออกแบบ ต้องดูอย่างน้อย **3 references** จากต่างแหล่ง

### 2.1 Refero Tools ที่ใช้ได้

| Tool | เมื่อไหร่ใช้ | ตัวอย่าง |
|------|------------|---------|
| `search_screens` | ค้นหาหน้าจอ specific เช่น login, dashboard, settings | `search_screens("admin dashboard with analytics")` |
| `search_flows` | ค้นหา flow ทั้ง flow เช่น onboarding, checkout | `search_flows("user registration flow")` |
| `get_screen` | ดูรายละเอียดหน้าจอที่สนใจ | `get_screen(<screen_id>)` |
| `get_flow` | ดูรายละเอียด flow ทั้งหมด | `get_flow(<flow_id>)` |
| `get_design_guidance` | ขอคำแนะนำด้าน design | `get_design_guidance("best practices for form validation UX")` |

### 2.2 กลยุทธ์การ Search

**ค้นหาจากหลายมุม** — อย่า search แค่ชื่อหน้าจอ ให้ search จาก:

1. **ชื่อหน้าจอตรงๆ:** `search_screens("login page")`
2. **Feature เฉพาะ:** `search_screens("OTP verification input")`
3. **Industry ที่ตรง:** `search_screens("fintech dashboard")`
4. **Flow ทั้งหมด:** `search_flows("authentication flow")`

**สิ่งที่ต้องสังเกตจาก reference:**
- **Layout & Structure** — content hierarchy เป็นยังไง? อะไรอยู่ตรงไหน?
- **Interaction Pattern** — user ต้องทำอะไรบ้าง? button/form/modal แบบไหน?
- **Information Architecture** — ข้อมูลจัดกลุ่มยังไง? navigation เป็นยังไง?
- **Error & Empty States** — จัดการ error ยังไง? หน้าว่างแสดงอะไร?
- **Responsive Behavior** — ปรับตัวกับหน้าจอขนาดต่างๆ ยังไง?

---

## Step 3: สรุป Research & ขอ Confirm

**ก่อนลงมือออกแบบ ต้องสรุปให้ผู้ใช้ดูและ confirm ก่อนเสมอ:**

```markdown
## Design Research Summary
**หน้าจอ:** [ชื่อ] | **Project:** P{XX}-{CODE} | **Platform:** [BOF/CSA/...]

### Reference ที่พบ (อย่างน้อย 3 แหล่ง)
| # | Product | หน้าจอ | Pattern ที่น่าสนใจ | Refero Link |
|---|---------|-------|-------------------|-------------|
| 1 | Stripe | Dashboard | Card-based metrics + chart ด้านล่าง | [link] |
| 2 | Shopify | Analytics | Filter bar ด้านบน + data table | [link] |
| 3 | Mixpanel | Overview | Sidebar nav + main content area | [link] |

### Pattern ที่เห็นซ้ำ (Consensus)
- [pattern ที่ 2+ products ใช้เหมือนกัน = น่าจะเป็น best practice]

### สิ่งที่แนะนำสำหรับ Wireframe ของเรา
1. [recommendation + เหตุผลจาก research]
2. [recommendation + เหตุผลจาก research]

### Requirement จาก MOM/REQ ที่ต้องครอบคลุม
- [list จาก source files]
```

**รอผู้ใช้ confirm ก่อนเริ่มออกแบบ — ห้ามออกแบบเลยโดยไม่ถาม**

---

## Step 4: สร้าง Wireframe

### 4.1 เลือก Output Format

| Format | เมื่อไหร่ใช้ | Pros | Cons |
|--------|------------|------|------|
| **HTML** (แนะนำ) | Interactive wireframe ที่เปิดดูใน browser ได้ | Clickable, responsive, แชร์ง่าย | ต้องเขียน code |
| **React (.jsx)** | Wireframe ที่จะพัฒนาต่อเป็น production | Reuse ได้, ใช้ Tailwind + shadcn/ui | ต้องมี React setup |
| **SVG** | Low-fi sketch/diagram | เร็ว, เบา | ไม่ interactive |
| **Markdown + ASCII** | Quick sketch ใน conversation | เร็วมาก | จำกัด visual |

### 4.2 ข้อกำหนดสำหรับทุก Wireframe

**Structure ที่ต้องมี:**
- **Header comment** — ระบุ project, page, reference sources, MOM/REQ ref
- **Page layout** — ตาม pattern ที่ research มา
- **All states** — Default state, Loading state, Empty state, Error state (ดู checklist ใน references/)
- **Annotations** — อธิบาย interaction/behavior ที่สำคัญในรูปแบบ comment หรือ tooltip

**ข้อกำหนดจาก AGENTS.md:**
- ตาม requirement ใน MOM/REQ ครบ — **ห้ามเพิ่ม feature/element ที่ไม่ได้ตกลง (No Gold Plating)**
- ใช้ terminology ตรงกับ MOM/REQ — ห้ามเปลี่ยนชื่อเอง
- ถ้าเห็นว่าขาดอะไร → **ถามผู้ใช้ ไม่ใช่เพิ่มเอง**

### 4.3 HTML Wireframe Template

```html
<!DOCTYPE html>
<html lang="th">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>WF-XX: [Page Name] — P{XX}-{CODE}</title>
  <!--
    Project: P{XX}-{CODE}
    Page: [Page Name]
    Platform: [BOF/CSA/...]
    MOM Ref: MOM#X
    Design System: [Brand name from DESIGN.md / "Generic" if none]
    Design References:
    - [Product 1]: [Refero link]
    - [Product 2]: [Refero link]
    - [Product 3]: [Refero link]
    Created: YYYY-MM-DD
  -->
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-50">
  <!-- Wireframe content here -->
</body>
</html>
```

### 4.4 Shared Components

เมื่อ project มีหลายหน้า ให้สังเกต component ที่ใช้ซ้ำ:

| Component | เมื่อไหร่แยกออกมา |
|-----------|-----------------|
| **Sidebar / Navigation** | ใช้ซ้ำ 2+ หน้า |
| **Header / Topbar** | ใช้ซ้ำทุกหน้า |
| **Table component** | ใช้ซ้ำ 2+ หน้า |
| **Modal / Dialog** | ใช้ซ้ำ 2+ flow |
| **Form patterns** | Input + validation ใช้ซ้ำ |

ถ้ามี shared component → สร้างเป็นไฟล์แยก (เช่น `WF-00_BOF_SharedLayout.html`) แล้ว reference จาก wireframe อื่น

---

## Step 5: Review ด้วย Wireframe Checklist

ก่อน deliver wireframe ให้ผู้ใช้ ต้องตรวจด้วย checklist นี้ (ดูรายละเอียดใน `references/wireframe-checklist.md`):

| # | หมวด | ตรวจอะไร |
|---|------|---------|
| 1 | **Requirement Coverage** | ครอบคลุม feature ทั้งหมดใน MOM/REQ? |
| 2 | **User Flow Alignment** | ตรงกับ User Flow ที่ validate แล้ว? |
| 3 | **All States** | มีครบ: Default, Empty, Loading, Error, Success? |
| 4 | **Navigation** | user รู้ว่าตัวเองอยู่ตรงไหน? ไปไหนต่อได้? |
| 5 | **Data Display** | ข้อมูลจัดกลุ่มชัดเจน? อ่านง่าย? |
| 6 | **Actions** | ปุ่ม/action ชัดเจน? user รู้ว่ากดแล้วจะเกิดอะไร? |
| 7 | **Form & Input** | validation rules ตรงกับ MOM? error message ชัด? |
| 8 | **Responsive** | ทำงานได้กับหน้าจอขนาดต่างๆ? (ถ้า platform ต้องการ) |
| 9 | **Terminology** | ชื่อ/label ตรงกับ MOM/REQ? ไม่เปลี่ยนเอง? |
| 10 | **No Gold Plating** | ไม่มี feature/element ที่ MOM ไม่ได้ตกลง? |
| 11 | **Consistency** | style, spacing, color ตรงกับ wireframe หน้าอื่นใน project? |
| 12 | **Reference Cited** | มี comment อ้างอิง Refero reference ที่ใช้? |

---

## Step 6: บันทึกและ Log

### 6.1 File Naming

```
{ProjectFolder}/Wireframe/WF-{XX}_{PlatformPrefix}_{PageName}.{ext}
```

| ส่วน | Format | ตัวอย่าง |
|------|--------|---------|
| `WF-{XX}` | เลข 2 หลัก เรียงตามลำดับ | `WF-01`, `WF-02` |
| `{PlatformPrefix}` | BOF, CSA, etc. | `BOF` (Back Office) |
| `{PageName}` | PascalCase ชื่อหน้า | `AdminLogin`, `Dashboard` |
| `{ext}` | ตาม format ที่เลือก | `.html`, `.jsx`, `.svg` |

**ตัวอย่าง:**
- `WF-01_BOF_AdminLogin.html`
- `WF-02_BOF_Dashboard.html`
- `WF-00_BOF_SharedLayout.html` (shared components ใช้ 00)

### 6.2 Log Wireframe Changes (Mandatory)

ทุกครั้งที่สร้างหรือแก้ wireframe ต้อง log ลง `SystemFlow/REQ_Traceability_Matrix.md`:

```markdown
## Wireframe Changes

| วันที่ | Page | Action | MOM/CR Ref | รายละเอียด | Refero Ref | ผู้ทำ |
|--------|------|--------|-----------|-----------|-----------|------|
| 2026-03-09 | WF-01_BOF_AdminLogin | Created | MOM#1 | สร้างใหม่จาก UseF-01 | Stripe Login, Auth0 Login | AI |
| 2026-03-10 | WF-01_BOF_AdminLogin | Updated | MOM#2 | เปลี่ยน OTP จาก email เป็น SMS | — | AI |
```

**ห้ามสร้าง/แก้ wireframe โดยไม่ log — ทุก change ต้องมีที่มา (MOM/CR ref)**

---

## Design Principles

1. **DESIGN.md First** — ถ้าโปรเจคมี `Wireframe/DESIGN.md` ต้องใช้เป็น style guide หลัก (สี, font, spacing, shadow, component style) ก่อน Refero reference — เพราะ DESIGN.md คือ visual identity ที่เลือกไว้แล้วสำหรับโปรเจค
2. **Research First** — ค้นหา reference ก่อนออกแบบเสมอ เพราะ AI ที่เห็น design จริงมาก่อนจะสร้าง output ที่ดีกว่า AI ที่สร้างจาก generic knowledge
2. **Pattern > Invention** — หา pattern ที่ซ้ำจากหลาย product ดีกว่าคิดใหม่เอง เพราะ pattern ที่ใช้ซ้ำ = user คุ้นเคยแล้ว
3. **Context Matching** — ดู reference ที่ industry/use case ตรงกัน ไม่ใช่แค่หน้าตาสวย (fintech dashboard ≠ social media dashboard)
4. **Flow Drives UI** — wireframe ต้อง align กับ User Flow ที่ validate แล้ว ไม่ใช่ออกแบบ UI แล้วค่อย fit flow
5. **Annotate for Clarity** — wireframe ที่ดีต้องมี annotation อธิบาย behavior ไม่ใช่แค่ภาพ เพราะ dev ต้องเข้าใจ interaction ไม่ใช่แค่ layout

---

## ข้อห้าม

- **ห้ามออกแบบโดยไม่ research ก่อน** — ถ้ามี Refero MCP ต้อง search อย่างน้อย 3 references
- **ห้ามเพิ่ม feature/element ที่ MOM/REQ ไม่ได้ระบุ** (No Gold Plating)
- **ห้ามแก้ wireframe เดิมโดยไม่ log** Wireframe Changes ลง Traceability Matrix
- **ห้ามใช้ reference จาก product เดียว** — ต้องดูอย่างน้อย 3 references เพื่อหา consensus pattern
- **ห้าม deliver wireframe ที่ไม่ผ่าน checklist** — ต้องตรวจ 12 ข้อก่อน
- **ห้ามเปลี่ยน terminology** จาก MOM/REQ โดยไม่ถามผู้ใช้
