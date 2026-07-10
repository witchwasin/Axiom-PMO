# Gantt Chart - Mermaid Syntax (for Lark Docs)

> Reference for `pmo-task-breakdown` skill.
> Lark Docs supports Mermaid via `/Mermaid` add-on.

---

## Template

```mermaid
gantt
    title Project Timeline: {Project Name}
    dateFormat YYYY-MM-DD
    axisFormat %m/%d
    excludes weekends

    section Project Initiation
    Kickoff Meeting           : kick, {start-date}, 1d
    Scope Alignment           : scope, after kick, 3d
    Plan Sign-off             : milestone, after scope, 0d

    section Requirements
    Gather Requirements       : req, after scope, 5d
    REQ Review & Sign-off     : crit, reqrev, after req, 2d
    Requirements Complete     : milestone, after reqrev, 0d

    section Design
    Architecture Design       : arch, after reqrev, 5d
    UI/UX Design              : ui, after reqrev, 5d
    Design Review             : crit, desrev, after arch ui, 2d
    Design Complete           : milestone, after desrev, 0d

    section Development
    Backend Development       : back, after desrev, 15d
    Frontend Development      : front, after desrev, 12d
    Integration               : integ, after back front, 5d
    Dev Complete              : milestone, after integ, 0d

    section Testing
    Integration Testing       : it, after integ, 3d
    UAT                       : crit, uat, after it, 5d
    Bug Fixing                : bugfix, after uat, 5d

    section Deployment
    Staging Deploy            : stg, after bugfix, 2d
    Production Deploy         : crit, prod, after stg, 1d
    Go-Live                   : milestone, after prod, 0d
```

---

## Key Syntax

| Syntax | Meaning |
|--------|---------|
| `Task : taskId, start, duration` | Define task (ID, start, duration) |
| `Task : after taskId, duration` | Start after another task completes |
| `Task : after id1 id2, duration` | Start after multiple tasks complete |
| `milestone, after taskId, 0d` | Milestone (diamond marker) |
| `done` | Completed task (gray) |
| `active` | Active task (highlighted) |
| `crit` | Critical path (red) |
| `excludes weekends` | Exclude weekends |
| `section Name` | Section divider |

---

## How to Insert in Lark Docs

1. Open Lark Docs -> type `/Mermaid` or click `+` and select Mermaid
2. Paste Mermaid Gantt code
3. Diagram renders inline in the document
4. Can choose view: Code + Diagram, Code Only, Diagram Only

> **Limitation:** Mermaid editing only on Desktop/Web. Mobile is view-only.
