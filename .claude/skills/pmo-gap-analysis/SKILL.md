---
name: Gap Analysis
description: เทียบ REQ กับ diagram ที่มีอยู่ → หา requirement ที่ยังไม่ถูก implement หรือ implement ไม่ครบ
---

# PMO Skill: Gap Analysis

> **Related Skills:**
> - Load `pmo-traceability` for Traceability Matrix format
> - Load `pmo-activity-diagram` for diagram structure understanding

---

## Goal

เทียบ REQ ทั้งหมดกับ diagram ที่สร้างไปแล้ว (SystemFlow, UserFlow, UseCase) เพื่อหา gap — requirement ไหนยังไม่ถูก implement, implement ไม่ครบ, หรือมี diagram ที่ไม่มี REQ รองรับ

---

## Workflow

### Step 1: ระบุ Project และอ่าน REQ
- ถามผู้ใช้ว่าจะ analyze project ไหน (ถ้าไม่ระบุ)
- อ่าน REQ/ ทั้งหมด → สร้าง requirement list
- ถามผู้ใช้ว่า column ไหนคือ feature name, module, priority (ถ้ายังไม่เคยถาม)

### Step 2: Scan Output ที่มีอยู่
- อ่าน SystemFlow/ → list ทุก diagram + module ที่ครอบคลุม
- อ่าน UserFlow/ → list ทุก diagram
- อ่าน UseCase/ → list ทุก use case diagram
- อ่าน Wireframe/ → list ทุก wireframe (ถ้ามี)
- อ่าน REQ_Traceability_Matrix.md (ถ้ามี)

### Step 3: Cross-Reference
- เทียบ REQ แต่ละข้อ กับ diagram ที่มี
- จัดกลุ่มเป็น 4 สถานะ:
  - **Covered** — REQ ถูก implement ใน diagram แล้ว
  - **Partial** — REQ ถูก implement แต่ไม่ครบ (เช่น มี SystemFlow แต่ไม่มี UserFlow)
  - **Missing** — REQ ยังไม่มี diagram ใดๆ
  - **Orphan** — มี diagram แต่ไม่มี REQ รองรับ (อาจเป็น gold plating)

### Step 4: สรุป Gap Report ให้ผู้ใช้

**Output Format:**

```markdown
# Gap Analysis Report
**Project:** P{XX}-{CODE} | **วันที่:** YYYY-MM-DD | **REQ File:** [ชื่อ]

## Summary
- Total Requirements: {N}
- Covered: {N} ({%})
- Partial: {N} ({%})
- Missing: {N} ({%})
- Orphan Diagrams: {N}

## Missing Requirements (ยังไม่มี diagram)
| # | REQ Item | Module | Priority | แนะนำ |
|---|----------|--------|----------|-------|

## Partial Coverage (implement ไม่ครบ)
| # | REQ Item | มีแล้ว | ยังขาด |
|---|----------|--------|-------|

## Orphan Diagrams (ไม่มี REQ รองรับ)
| # | Diagram File | เนื้อหา | ควรทำอย่างไร |
|---|-------------|--------|------------|

## สิ่งที่แนะนำให้ทำ (เรียงตาม priority)
1. [action items]
```

### Step 5: รอคำสั่งจากผู้ใช้
- ถามว่าต้องการสร้าง diagram สำหรับ missing requirements ไหม
- ถ้า approve → โหลด skill ที่เกี่ยวข้องเพื่อสร้าง diagram ใหม่
