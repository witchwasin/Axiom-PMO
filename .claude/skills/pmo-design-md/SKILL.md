---
name: Design System (DESIGN.md)
description: เลือก/สร้าง/apply design system ให้โปรเจค โดยใช้ DESIGN.md format (Google Stitch) — ใช้เมื่อผู้ใช้พูดถึง design system, เลือก look & feel, brand style, สี/font ของ project, อยากให้ดูเหมือนแบรนด์ X, กำหนด visual identity, DESIGN.md, design token spec — แม้ไม่ได้พูดว่า "design system" โดยตรง ถ้าบริบทเป็นเรื่องกำหนด style/look ให้โปรเจคก็ให้ใช้ skill นี้
---

# PMO Skill: Design System (DESIGN.md)

> **Related Skills:**
> - Load `pmo-wireframe-design` — เมื่อต้องสร้าง wireframe หลังจากมี DESIGN.md แล้ว
> - Load `design-system-patterns` — เมื่อต้องแปลง DESIGN.md เป็น code (tokens, themes) สำหรับ Dev
> - Load `pmo-traceability` — log ทุกครั้งที่สร้าง/แก้ DESIGN.md

---

## Goal

กำหนด visual identity ให้โปรเจค โดยใช้ DESIGN.md format — ผู้ใช้สามารถ:
1. **เลือกจาก library** — มี 58 design system ของแบรนด์จริง พร้อมใช้งาน
2. **ผสมหลายแบรนด์** — หยิบ color จาก Stripe + typography จาก Linear
3. **สร้างใหม่ทั้งหมด** — custom design system เฉพาะโปรเจค
4. **Apply เข้าโปรเจค** — copy DESIGN.md เข้า project folder ให้ wireframe skill ใช้ต่อ

---

## Workflow Overview

```
Step 1: เข้าใจ Context → Step 2: เลือก/ค้นหา Design System → Step 3: Preview & Confirm
→ Step 4: Customize (ถ้าต้องการ) → Step 5: Apply เข้า Project → Step 6: บันทึก & Log
```

---

## Step 1: เข้าใจ Context

ก่อนเลือก design system ต้องเข้าใจ 4 สิ่งนี้:

| ต้องรู้ | ถามถ้าไม่ระบุ | ตัวอย่าง |
|--------|-------------|---------|
| **Project** | "ทำสำหรับ project ไหน?" | P08-JP |
| **ประเภท product** | "เป็นแอปประเภทอะไร?" | Fintech, SaaS, E-commerce |
| **Target audience** | "กลุ่มเป้าหมายเป็นใคร?" | Admin (BOF), End user (App) |
| **Mood/Feel** | "อยากให้ดูแบบไหน? professional, playful, minimal?" | Clean & modern |

**ถ้าผู้ใช้ระบุแบรนด์ชัดเจน** (เช่น "อยากได้แบบ Stripe") → ข้ามไป Step 2.2 เลย

---

## Step 2: เลือก/ค้นหา Design System

### 2.1 แนะนำจาก Context (ถ้าผู้ใช้ยังไม่เลือก)

จัด category ให้ตรง industry ของ project:

| Industry | แบรนด์แนะนำ | เหตุผล |
|----------|------------|--------|
| **Fintech / Banking** | Stripe, Wise, Revolut, Coinbase | Financial-grade design, trust-building |
| **SaaS / Dashboard** | Linear, Vercel, Supabase, PostHog | Data-heavy, clean dashboard |
| **E-commerce / Marketplace** | Airbnb, Shopify, Pinterest | Product discovery, visual browsing |
| **Developer Tools** | Cursor, Raycast, Warp, Mintlify | Code-friendly, dark mode native |
| **Enterprise / Corporate** | IBM, Apple, NVIDIA | Professional, scalable |
| **Creative / Design** | Figma, Framer, Webflow | Expressive, tool-oriented |
| **Communication / Productivity** | Notion, Miro, Intercom, Superhuman | Collaboration-focused |
| **Automotive / Luxury** | BMW, Ferrari, Tesla, Lamborghini | Premium, high-impact visual |

แสดงเป็นตาราง max 5 ตัวเลือก พร้อมเหตุผลสั้นๆ → **รอผู้ใช้เลือก**

### 2.2 เปิด DESIGN.md ของแบรนด์ที่เลือก

```
Path: design-md/{brand}/DESIGN.md
```

อ่าน DESIGN.md แล้วสรุปให้ผู้ใช้:

```markdown
## Design System Summary: {Brand}

### Visual Feel
{1-2 ประโยค จาก Section 1: Visual Theme & Atmosphere}

### Color Palette (Key Colors)
| Role | Color | Hex | Usage |
|------|-------|-----|-------|
| Primary | {name} | {hex} | {usage} |
| Accent | {name} | {hex} | {usage} |
| Background | {name} | {hex} | {usage} |
| Text | {name} | {hex} | {usage} |

### Typography
- **Primary Font:** {font family}
- **Headline Style:** {weight, size range}
- **Body Style:** {weight, size range}

### Distinctive Features
- {2-3 bullet points ที่ทำให้ design system นี้แตกต่าง}

### Best For
- {ประเภท project ที่เหมาะ}

### Preview
- Light: `design-md/{brand}/preview.html`
- Dark: `design-md/{brand}/preview-dark.html`
```

### 2.3 เปรียบเทียบหลายแบรนด์ (ถ้าผู้ใช้สนใจมากกว่า 1)

แสดงตาราง side-by-side:

```markdown
## Design System Comparison

| Aspect | {Brand A} | {Brand B} | {Brand C} |
|--------|-----------|-----------|-----------|
| **Feel** | ... | ... | ... |
| **Primary Color** | {hex} | {hex} | {hex} |
| **Font** | ... | ... | ... |
| **Border Radius** | ... | ... | ... |
| **Shadow Style** | ... | ... | ... |
| **Best For** | ... | ... | ... |
```

---

## Step 3: Preview & Confirm

**แสดง summary แล้วถามผู้ใช้:**

1. "ต้องการใช้ {Brand} เป็นหลักไหม?"
2. "ต้อง customize อะไรเพิ่มไหม? (เช่น เปลี่ยนสี primary, font)"
3. "ต้องการผสมจากแบรนด์อื่นไหม?"

**รอ confirm ก่อนดำเนินการ — ห้าม apply โดยไม่ถาม**

---

## Step 4: Customize (Optional)

### 4.1 ใช้ตรงๆ (ไม่ customize)
→ copy DESIGN.md จาก library ไป project folder ตรงๆ

### 4.2 ปรับแต่งบางส่วน
สร้าง DESIGN.md ใหม่โดย:
- ใช้ base จากแบรนด์ที่เลือก
- Override เฉพาะส่วนที่ผู้ใช้ต้องการเปลี่ยน
- เพิ่ม header comment ระบุ source:

```markdown
<!-- 
  Based on: {Brand} design system (design-md/{brand}/DESIGN.md)
  Customized for: P{XX}-{CODE}
  Changes: {สรุปสิ่งที่เปลี่ยน}
  Created: YYYY-MM-DD
-->
```

### 4.3 ผสมหลายแบรนด์
สร้าง DESIGN.md ใหม่โดยหยิบจากหลาย source:

```markdown
<!-- 
  Design System Mix for P{XX}-{CODE}
  Sources:
  - Colors: {Brand A}
  - Typography: {Brand B}
  - Components: {Brand C}
  Created: YYYY-MM-DD
-->
```

**ต้องรักษาครบ 9 sections ตาม format มาตรฐาน** (ดู references/design-md-format.md)

### 4.4 สร้าง Custom ทั้งหมด

สร้าง DESIGN.md ใหม่ตาม 9-section format โดยถามผู้ใช้:

| Section | คำถาม |
|---------|-------|
| 1. Visual Theme | "อยากให้ดูแบบไหน? (professional, playful, minimal, bold)" |
| 2. Color Palette | "มี brand color อยู่แล้วไหม? primary color คืออะไร?" |
| 3. Typography | "มี font ที่ต้องใช้ไหม? (หรือให้แนะนำ)" |
| 4. Components | "มี component style ที่ชอบไหม? (rounded buttons, sharp cards)" |
| 5. Layout | "ต้องการ spacing แบบไหน? (compact, comfortable, spacious)" |
| 6. Depth | "ต้องการ shadow แบบไหน? (flat, subtle, elevated)" |
| 7-9 | derive จาก 1-6 |

---

## Step 5: Apply เข้า Project

### 5.1 บันทึก DESIGN.md เข้า project folder

```
{ProjectFolder}/Wireframe/DESIGN.md
```

**เหตุผลที่อยู่ใน Wireframe/:** เพราะ DESIGN.md เป็น input หลักของ wireframe design — อยู่ใกล้ output ที่ใช้มัน

### 5.2 แจ้งผู้ใช้เรื่อง next steps

```markdown
## DESIGN.md Applied

**Project:** P{XX}-{CODE}
**Based on:** {Brand} / Custom
**Location:** `{ProjectFolder}/Wireframe/DESIGN.md`

### Next Steps
1. **สร้าง Wireframe** — skill `pmo-wireframe-design` จะอ่าน DESIGN.md นี้โดยอัตโนมัติ
2. **สร้าง Design Tokens** (เมื่อถึง phase Dev) — skill `design-system-patterns` จะแปลงเป็น CSS/code
3. **Preview** — เปิด `design-md/{brand}/preview.html` ในเบราว์เซอร์เพื่อดู token catalog
```

---

## Step 6: บันทึก & Log

### 6.1 Log to Traceability Matrix

บันทึกลง `SystemFlow/REQ_Traceability_Matrix.md`:

**Change Log:**
```
| Date | Source | Module | Action | File | Description | Status |
| YYYY-MM-DD | PM Decision | Design System | Created | Wireframe/DESIGN.md | Apply {Brand} design system | Active |
```

**Decision Log:**
```
| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Impact |
| YYYY-MM-DD | D{NNN} | Design System Selection | {options shown} | {brand chosen} | {why} | Wireframe + Dev Handoff |
```

**Activity Log:**
```
| Timestamp | Session | Action | Target File | Detail | Result |
| YYYY-MM-DD | S{NNN} | Created | Wireframe/DESIGN.md | Applied {Brand} design system | Done |
```

---

## Available Design Systems (58 brands)

ดูรายการเต็มที่ `references/brand-catalog.md`

### Quick Reference by Category

| Category | Brands |
|----------|--------|
| **AI & ML** | Claude, Cohere, ElevenLabs, Minimax, Mistral AI, Ollama, OpenCode AI, Replicate, RunwayML, Together AI, VoltAgent, xAI |
| **Developer Tools** | Cursor, Expo, Linear, Lovable, Mintlify, PostHog, Raycast, Resend, Sentry, Supabase, Superhuman, Vercel, Warp, Zapier |
| **Infrastructure** | ClickHouse, Composio, HashiCorp, MongoDB, Sanity, Stripe |
| **Design & Productivity** | Airtable, Cal.com, Clay, Figma, Framer, Intercom, Miro, Notion, Pinterest, Webflow |
| **Fintech & Crypto** | Coinbase, Kraken, Revolut, Wise |
| **Enterprise & Consumer** | Airbnb, Apple, IBM, NVIDIA, SpaceX, Spotify, Uber |
| **Automotive & Luxury** | BMW, Ferrari, Lamborghini, Renault, Tesla |

---

## DESIGN.md 9-Section Format

ทุก DESIGN.md ต้องมีครบ 9 sections (ดูรายละเอียดที่ `references/design-md-format.md`):

| # | Section | What it captures |
|---|---------|-----------------|
| 1 | **Visual Theme & Atmosphere** | Mood, density, design philosophy |
| 2 | **Color Palette & Roles** | Semantic name + hex + functional role |
| 3 | **Typography Rules** | Font families, full hierarchy table |
| 4 | **Component Stylings** | Buttons, cards, inputs, navigation with states |
| 5 | **Layout Principles** | Spacing scale, grid, whitespace philosophy |
| 6 | **Depth & Elevation** | Shadow system, surface hierarchy |
| 7 | **Do's and Don'ts** | Design guardrails and anti-patterns |
| 8 | **Responsive Behavior** | Breakpoints, touch targets, collapsing strategy |
| 9 | **Agent Prompt Guide** | Quick color reference, ready-to-use prompts |

---

## ข้อห้าม

- **ห้าม apply DESIGN.md โดยไม่ผ่าน confirm จากผู้ใช้** — ต้องแสดง summary + รอ approve ก่อน
- **ห้ามแก้ไข DESIGN.md ใน `design-md/` library โดยตรง** — library เป็น read-only reference, customize ที่ project folder เท่านั้น
- **ห้ามสร้าง DESIGN.md ที่ไม่ครบ 9 sections** — ถ้า custom ต้องมีครบทุก section
- **ห้ามเลือก design system โดยไม่ดู context ของ project** — Fintech ไม่ควรใช้ style ของ gaming site
- **ห้ามแก้ DESIGN.md ใน project โดยไม่ log** — ทุก change ต้องลง Traceability Matrix
