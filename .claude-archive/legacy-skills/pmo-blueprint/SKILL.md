---
name: Blueprint — Construction Plan Generator
description: วางแผน multi-session สำหรับงานใหญ่ — แบ่งเป็น step-by-step พร้อม dependency graph, parallel detection, และ cold-start context brief สำหรับทุก step
---

# Blueprint — Multi-Session Construction Plan

> แปลงจุดประสงค์ 1 บรรทัด ให้เป็น step-by-step execution plan ที่ agent ใหม่สามารถรับช่วงต่อได้ทันทีโดยไม่ต้องอ่าน context เดิม

## เมื่อไหร่ใช้

- งานใหญ่ที่ต้องทำข้ามหลาย session (>3 tool calls)
- แตก feature ใหญ่เป็นหลาย PR ตามลำดับ dependency
- วางแผน refactor/migration ข้าม session
- coordinate งานที่ทำ parallel ได้หลาย workstream
- ต้องการให้ agent ใหม่รับช่วงต่อได้โดยไม่ต้อง re-read ทั้ง project

**ไม่ใช้เมื่อ:** งานจบใน 1 session, <3 tool calls, user บอก "ทำเลย"

## Pipeline (5 ขั้นตอน)

### Phase 1: Research (Pre-flight)
- ตรวจ project state จาก `pmo-state-engine`
- อ่านโครงสร้างโปรเจค, TaskBoard, Traceability Matrix
- อ่าน plan เดิม (ถ้ามี) จาก `{project}/Plans/`
- เช็ค context ที่มีอยู่ — อะไรทำไปแล้ว, อะไรค้าง

### Phase 2: Design (Decompose)
- แตก objective → 3-12 steps (แต่ละ step = 1 session หรือ 1 PR)
- กำหนด dependency edges ระหว่าง step
- ตรวจหา parallel steps (ไม่มี shared files/output)
- กำหนด model tier ต่อ step:
  - **Complex** (planning/arch): Opus
  - **Standard** (implementation): Sonnet
  - **Simple** (lookup/format): Haiku
- กำหนด rollback strategy ต่อ step

### Phase 3: Draft (Write Plan)
- สร้าง Markdown plan file ที่ `{project}/Plans/BLUEPRINT-{name}.md`
- **ทุก step ต้องมี Cold-Start Context Brief** — ข้อมูลเพียงพอให้ agent ใหม่ทำงานได้เลย:

```markdown
## Step {N}: {Title}

### Context Brief (สำหรับ agent ใหม่)
- **Project:** {code} — {name}
- **What happened before:** {สรุปผล step ก่อนหน้า 2-3 บรรทัด}
- **Current state:** {ไฟล์ที่สร้างแล้ว, status ปัจจุบัน}
- **Dependencies resolved:** {step ไหนเสร็จแล้วบ้าง}

### Task
- [ ] {concrete action 1}
- [ ] {concrete action 2}
- [ ] {concrete action 3}

### Verification
- [ ] {exit criteria 1 — ตรวจได้ด้วย command/visual}
- [ ] {exit criteria 2}

### Files Touched
- `path/to/file1` — create/modify/delete
- `path/to/file2` — create/modify/delete

### Rollback
- {วิธี revert ถ้า step นี้มีปัญหา}

### Model Tier: {Opus|Sonnet|Haiku}
### Estimated Effort: {S|M|L}
### Depends On: Step {X}, Step {Y}
### Can Parallel With: Step {Z}
```

### Phase 4: Review (Adversarial)
- **Self-review** ตาม checklist:
  - ☐ ทุก step มี context brief ครบ?
  - ☐ dependency graph ไม่มี circular?
  - ☐ parallel steps ไม่แชร์ file เดียวกัน?
  - ☐ exit criteria ตรวจได้จริง (ไม่ใช่แค่ "ทำให้เสร็จ")?
  - ☐ rollback strategy เป็นไปได้จริง?
  - ☐ ไม่มี gold plating (ทำเกินที่ตกลง)?
  - ☐ ครอบคลุม objective ทั้งหมด?
- **Anti-pattern detection:**
  - ❌ Step ที่ใหญ่เกินไป (>10 tasks) → แตกต่อ
  - ❌ Step ไม่มี exit criteria → เพิ่ม
  - ❌ Dependency chain ยาวเกินไป (>5 serial) → หา parallel path
  - ❌ Context brief ไม่พอให้ agent ใหม่เข้าใจ → เพิ่มรายละเอียด

### Phase 5: Register
- บันทึก plan ลง `{project}/Plans/`
- อัพเดท State Engine: `blueprintActive: true, blueprintFile: "BLUEPRINT-{name}.md"`
- Log ลง Traceability: Activity Log + Decision Log
- แสดงสรุป: จำนวน step, parallel paths, estimated effort

## Plan Mutation Protocol

เมื่อต้องเปลี่ยน plan ระหว่างทาง:

| Action | เมื่อไหร่ | วิธีทำ |
|--------|----------|-------|
| **Split** | Step ใหญ่เกินไป | แตกเป็น 2+ step, อัพเดท dependency |
| **Insert** | พบงานที่ขาดหาย | เพิ่ม step ใหม่, ตรวจ dependency |
| **Skip** | Step ไม่จำเป็นแล้ว | Mark `SKIPPED` + เหตุผล |
| **Reorder** | Priority เปลี่ยน | ย้าย step, ตรวจ dependency ไม่พัง |
| **Abandon** | Plan ทั้งหมดใช้ไม่ได้ | Archive plan + สร้างใหม่ |

**ทุก mutation ต้อง:**
1. Log ลง Decision Log ใน Traceability
2. อัพเดท dependency graph
3. อัพเดท context brief ของ step ที่ได้รับผลกระทบ

## Dependency Graph Format

```
Step 1 ──→ Step 2 ──→ Step 4
              ↓           ↑
           Step 3 ────────┘   (Step 2 + 3 → Step 4)

Step 5 (parallel กับ Step 1-4, ไม่มี dependency)
```

แสดงเป็น table:

| Step | Depends On | Blocks | Parallel With |
|------|-----------|--------|--------------|
| 1 | - | 2 | 5 |
| 2 | 1 | 3, 4 | 5 |
| 3 | 2 | 4 | 5 |
| 4 | 2, 3 | - | 5 |
| 5 | - | - | 1, 2, 3, 4 |

## Output Template

```markdown
# Blueprint: {Objective}
**Project:** {code} — {name}
**Created:** {date}
**Steps:** {N} ({M} parallel paths)
**Estimated Sessions:** {X}

## Dependency Graph
{ASCII graph หรือ table}

## Steps
{Step 1-N ตาม format ด้านบน}

## Summary
- Total steps: {N}
- Critical path: Step {X} → {Y} → {Z} ({N} sessions)
- Parallel paths: {list}
- Estimated total effort: {S/M/L/XL}
```

## Integration

- **pmo-state-engine**: อ่าน/เขียน blueprint state
- **pmo-traceability**: Log ทุก plan creation + mutation
- **pmo-task-breakdown**: Blueprint สร้าง high-level plan, task-breakdown แตกแต่ละ step
- **pmo-taskboard**: หลัง blueprint approve, สร้าง card ตาม step
