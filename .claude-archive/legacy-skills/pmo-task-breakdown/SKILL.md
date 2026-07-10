---
name: Task Breakdown
description: สร้าง Task Breakdown table + Gantt chart สำหรับ timeline planning จาก REQ และ MOM
---

# PMO Skill: Task Breakdown

> **Related Skills:**
> - Load `pmo-workflow-architect` ก่อน ถ้าต้องการ map flow ก่อนแตก task
> - Load `references/gantt-plantuml.md` for PlantUML Gantt syntax
> - Load `references/gantt-mermaid.md` for Mermaid Gantt syntax (Lark Docs)
> - Load `references/realistic-scope-guide.md` สำหรับแนวทางตั้ง scope สมจริง + acceptance criteria

---

## Purpose

Task Breakdown is used for:
- **Discussing with client and PM** about timeline overview
- **Track progress** at high-level (no sub-task detail needed)
- **Copy to Lark Docs** as native table or Markdown

> **Lark Docs note:** Lark Docs **does not support** Markdown table syntax (`| col |`) - pasted Markdown tables show as plain text. Use `/table` or `+` icon to insert tables instead. We keep Task Breakdown as `.md` in repo for source of truth and version control.

---

## Pre-requisite: Ask Timeline First (MANDATORY)

**Before creating Task Breakdown, must ask user:**
- **Timeline scope** - how long total? (e.g., 3 months, 6 months, 1 year)
- **Start date** - when does project start? (or planned start date)
- **Milestone / Deadline** - any key deadlines? (e.g., UAT must complete by date X)
- **Phases** - already divided? (e.g., Phase 1 = Core features, Phase 2 = Nice-to-have)

---

## Markdown Table Template

```markdown
# Task Breakdown: {Project Name}

> **Timeline:** {Start} - {End} ({N} weeks)
> **Ref:** MOM#X, MOM#Y

| # | Phase / Task | Duration | Start | End | Owner | Status |
|---|-------------|----------|-------|-----|-------|--------|
| **1** | **Project Initiation** | | | | | |
| 1.1 | Kickoff Meeting | 1d | | | PM | Not Started |
| 1.2 | Scope & Requirement Alignment | 3d | | | PM + BA | Not Started |
| 1.3 | Project Plan Sign-off | 1d | | | PM | Not Started |
| **2** | **Requirements & Analysis** | | | | | |
| 2.1 | Gather Functional Requirements | 5d | | | BA | Not Started |
| 2.2 | Gather Non-Functional Requirements | 3d | | | BA + Tech Lead | Not Started |
| 2.3 | Requirement Review & Sign-off | 2d | | | PM + Client | Not Started |
| **3** | **System Design** | | | | | |
| 3.1 | Architecture Design | 5d | | | Tech Lead | Not Started |
| 3.2 | Database Design | 3d | | | Backend Lead | Not Started |
| 3.3 | API Design | 3d | | | Backend Lead | Not Started |
| 3.4 | UI/UX Design | 5d | | | Designer | Not Started |
| 3.5 | Design Review & Sign-off | 2d | | | PM + Client | Not Started |
| **4** | **Development** | | | | | |
| 4.1 | Backend Development | {N}d | | | Backend Team | Not Started |
| 4.2 | Frontend Development | {N}d | | | Frontend Team | Not Started |
| 4.3 | Integration | {N}d | | | Full Team | Not Started |
| **5** | **Testing & QA** | | | | | |
| 5.1 | Integration Testing | 3d | | | QA Team | Not Started |
| 5.2 | UAT (User Acceptance Testing) | 5d | | | Client + QA | Not Started |
| 5.3 | Bug Fixing | 5d | | | Dev Team | Not Started |
| **6** | **Deployment & Go-Live** | | | | | |
| 6.1 | Staging Deployment | 2d | | | DevOps | Not Started |
| 6.2 | Production Deployment | 1d | | | DevOps | Not Started |
| 6.3 | Smoke Testing | 1d | | | QA Team | Not Started |
| **7** | **Post-Launch Support** | | | | | |
| 7.1 | Monitoring & Bug Fixes | {N}d | | | Dev Team | Not Started |
| 7.2 | Knowledge Transfer | 3d | | | PM + Tech Lead | Not Started |
| 7.3 | Project Closure | 1d | | | PM | Not Started |
```

**Status values:** `Not Started`, `In Progress`, `Done`, `Blocked`, `On Hold`

### Template Adjustment Rules

- **Phases/Tasks are examples** - must adjust to match actual project. Read REQ and MOM first.
- **Duration must fit within Timeline** - total of all tasks must not exceed user-defined timeframe
- **Keep high-level** - focus on main topics, no detailed sub-tasks
- **Owner uses Role not person name** - e.g., PM, BA, Tech Lead, Backend Team
- **Start/End fill with actuals** - leave blank or TBD if no actual start date yet

---

## Task Breakdown Checklist

**Verify before finalizing:**

| # | Category | Question |
|---|---------|---------|
| 1 | **Timeline Fits** | Total duration of all tasks fits within user-defined timeframe? |
| 2 | **Phases Complete** | Has phases from Initiation through Post-Launch? |
| 3 | **Dependencies Logical** | Task order correct? No task starts before its dependency completes? |
| 4 | **Milestones Complete** | All key milestones per user requirements present? |
| 5 | **Owners Complete** | Every task has an Owner (Role) assigned? |
| 6 | **Buffer** | Has buffer for Bug Fixing and contingency? |
| 7 | **Matches REQ/MOM** | Tasks cover all requirements from REQ and MOM? |

---

## File Location

Save in `./<ProjectName>/TaskBreakdown/`
