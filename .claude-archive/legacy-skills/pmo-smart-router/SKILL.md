---
name: Smart Router
description: Fuzzy keyword matching — วิเคราะห์ prompt ผู้ใช้แล้ว auto-route ไปหา PMO skill ที่เหมาะที่สุด ลด friction ไม่ต้องจำชื่อ skill
---

# PMO Skill: Smart Router

> **Purpose:** ผู้ใช้พิมพ์ภาษาธรรมชาติ → AI จับ intent → route ไปหา skill ที่ถูกต้องอัตโนมัติ
> ลดปัญหา "ไม่รู้จะใช้ skill ไหน" และ "พิมพ์ชื่อ skill ผิด"

---

## 1. Keyword Mapping Table

> **เมื่อ prompt ผู้ใช้มีคำเหล่านี้ → route ไปหา skill ที่ระบุ**

| Keywords (Thai + English) | Route to Skill | Priority |
|--------------------------|----------------|:--------:|
| วาด flow, สร้าง flow, activity diagram, swimlane, system flow, user flow | `pmo-activity-diagram` | 1 |
| use case, actor, ความสัมพันธ์ actor | `pmo-use-case-diagram` | 1 |
| แตก card, สร้าง card, taskboard, assign งาน, มอบหมายงาน | `pmo-taskboard` | 1 |
| แตก task, task breakdown, gantt, timeline, ไทม์ไลน์ | `pmo-task-breakdown` | 1 |
| design system, DESIGN.md, look & feel, brand style, visual identity, อยากให้ดูเหมือน, เลือก style, สี font ของ project, กำหนด look | `pmo-design-md` | 1 |
| วาด wireframe, mockup, UI, ออกแบบหน้าจอ, design reference | `pmo-wireframe-design` | 1 |
| เทียบ REQ, gap analysis, หา gap, requirement ไหนยังไม่ทำ | `pmo-gap-analysis` | 1 |
| validate, ตรวจ diagram, review diagram, checklist | `pmo-review-diagram` | 1 |
| MOM ใหม่, วิเคราะห์ MOM, impact report, ข้อมูลใหม่ | `pmo-analyze-new-mom` | 1 |
| dev handoff, ส่งมอบ dev, spec สำหรับ developer | `pmo-dev-handoff` | 1 |
| dev เสร็จ, ทำเสร็จแล้ว, อัพเดท PM, dev report | `pmo-dev-report` | 1 |
| test เสร็จ, QA report, ผล test, ผ่าน/ไม่ผ่าน | `pmo-qa-report` | 1 |
| traceability, log, track, audit trail, บันทึก | `pmo-traceability` | 2 |
| ไม่แน่ใจ, ยังไม่ชัด, clarify, สัมภาษณ์, deep interview | `pmo-deep-interview` | 1 |
| proposal, quotation, ใบเสนอราคา, เสนอโปรเจค | `pmo-proposal-writer` | 1 |
| workflow, ค้นหา flow, วิเคราะห์ flow, ออกแบบ workflow | `pmo-workflow-architect` | 1 |
| scaffold, สร้างโค้ด, boilerplate, generate code, โครงสร้างไฟล์ | `pmo-code-scaffold` | 1 |
| coding standard, convention, naming, linting | `pmo-coding-standards` | 1 |
| CI/CD, pipeline, GitHub Actions, deploy อัตโนมัติ | `pmo-ci-cd-template` | 1 |
| deploy checklist, ก่อน deploy, pre-deploy, go-live checklist | `pmo-deploy-checklist` | 1 |
| infra, infrastructure, server spec, docker, scaling | `pmo-infra-spec` | 1 |
| สถานะ project, dashboard, ภาพรวม, สรุปทุก project | `pmo-dashboard` | 1 |
| state, save state, สถานะงาน, progress snapshot | `pmo-state-engine` | 2 |
| ทีม, orchestrate, แบ่งงาน agent, multi-agent | `pmo-team-orchestrator` | 1 |
| handoff, ส่งต่องาน, ส่งต่อ QA, ส่งต่อ Dev | `pmo-handoff-protocol` | 1 |
| teaching script, talking point, สคริปต์, เตรียมพูด | `key-talking-point` | 1 |
| blueprint, construction plan, วางแผนข้ามหลาย session, multi-session, dependency graph, cold-start | `pmo-blueprint` | 1 |
| context เต็ม, token, compact, optimize context, session ยาว, token budget | `pmo-context-optimizer` | 1 |
| evidence, หลักฐาน, verify task, proof of completion, เสร็จจริงหรือเปล่า, verification | `pmo-verification-evidence` | 1 |
| hook profile, minimal, strict, ลด validation, hook ช้า, ปรับ hook | `pmo-hook-profiles` | 1 |

---

## 2. Fuzzy Matching Rules

เมื่อ prompt ไม่ตรงกับ keyword table โดยตรง:

### 2.1 Levenshtein Distance Matching
- คำที่มี edit distance <= 2 จาก keyword → match (เช่น "activty" → "activity")
- คำที่มี edit distance <= 3 สำหรับคำยาว > 8 ตัวอักษร → match

### 2.2 Synonym Expansion
| คำที่ผู้ใช้อาจใช้ | map ไปที่ |
|-----------------|----------|
| วาด, เขียน, สร้าง, ทำ | create/generate |
| ดู, เช็ค, ตรวจ | review/validate |
| แก้, ปรับ, อัพเดท | update/modify |
| ลบ, เอาออก | remove/delete |
| หา, ค้น, เทียบ | search/compare |

### 2.3 Context-Aware Routing
ถ้า keyword match หลาย skill → ใช้ context ตัดสิน:
1. ถ้าอยู่ใน `SystemFlow/` → prefer diagram skills
2. ถ้าอยู่ใน `Wireframe/` → prefer `pmo-wireframe-design`
3. ถ้าอยู่ใน `TaskBreakdown/` → prefer `pmo-task-breakdown`
4. ถ้ามี project context → prefer skill ที่ตรงกับ phase ปัจจุบันของ project

---

## 3. Multi-Skill Detection

เมื่อ prompt มี intent หลายอย่าง:

**ตัวอย่าง:** "วาด flow แล้วแตก card ให้ dev"
- Detect: `pmo-activity-diagram` + `pmo-taskboard`
- Action: แจ้งผู้ใช้ว่าจะทำ 2 skill ตามลำดับ → execute sequentially

**ตัวอย่าง:** "เทียบ REQ แล้ว validate diagram ที่มี"
- Detect: `pmo-gap-analysis` + `pmo-review-diagram`
- Action: แจ้งลำดับ → execute sequentially

---

## 4. Fallback Behavior

เมื่อไม่มี keyword match ใดเลย:
1. ถามผู้ใช้: "ต้องการทำอะไรกับ project? เลือกจากรายการ:"
2. แสดงรายการ skill ที่เกี่ยวข้องกับ context ปัจจุบัน (max 5 ตัวเลือก)
3. ให้ผู้ใช้เลือก

---

## 5. Auto-Load Dependencies

เมื่อ route ไป skill ใด → auto-load dependencies ตาม Cross-Skill Dependencies table ใน CLAUDE.md:

| Routed Skill | Auto-Load |
|-------------|-----------|
| `pmo-activity-diagram` | `pmo-lark-plantuml` |
| `pmo-use-case-diagram` | `pmo-lark-plantuml` |
| `pmo-review-diagram` | `pmo-lark-plantuml` |
| `pmo-design-md` | `pmo-traceability` |
| `pmo-wireframe-design` | `pmo-traceability`, `pmo-design-md` |
| `pmo-dev-handoff` | `pmo-traceability` |
| `pmo-dev-report` | `pmo-taskboard`, `pmo-traceability` |
| `pmo-qa-report` | `pmo-taskboard`, `pmo-traceability` |
| `pmo-analyze-new-mom` | `pmo-traceability` |
| `pmo-code-scaffold` | `pmo-coding-standards` |
| `pmo-ci-cd-template` | `pmo-deploy-checklist` |
