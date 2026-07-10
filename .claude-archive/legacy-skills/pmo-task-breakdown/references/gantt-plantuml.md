# Gantt Chart - PlantUML Syntax

> Reference for `pmo-task-breakdown` skill.
> Save Gantt charts in `./<ProjectName>/TaskBreakdown/`

---

## Template

```plantuml
@startgantt
title Project Timeline: {Project Name}
printscale weekly
Project starts {YYYY-MM-DD}

' --- Non-working days ---
saturday are closed
sunday are closed

' --- Phase 1: Project Initiation ---
-- Project Initiation --
[Kickoff Meeting] requires 1 days
[Scope Alignment] requires 3 days
[Scope Alignment] starts at [Kickoff Meeting]'s end
[Plan Sign-off] requires 1 days
[Plan Sign-off] starts at [Scope Alignment]'s end

' --- Phase 2: Requirements ---
-- Requirements --
[Gather Requirements] requires 5 days
[Gather Requirements] starts at [Plan Sign-off]'s end
[REQ Review & Sign-off] requires 2 days
[REQ Review & Sign-off] starts at [Gather Requirements]'s end

' --- Phase 3: Design ---
-- Design --
[Architecture Design] requires 5 days
[Architecture Design] starts at [REQ Review & Sign-off]'s end
[UI/UX Design] requires 5 days
[UI/UX Design] starts at [REQ Review & Sign-off]'s end
[Design Review] requires 2 days
[Design Review] starts at [Architecture Design]'s end

' --- Phase 4: Development ---
-- Development --
[Backend Development] requires {N} days
[Backend Development] starts at [Design Review]'s end
[Frontend Development] requires {N} days
[Frontend Development] starts at [Design Review]'s end
[Integration] requires {N} days
[Integration] starts at [Backend Development]'s end

' --- Phase 5: Testing ---
-- Testing --
[Integration Testing] requires 3 days
[Integration Testing] starts at [Integration]'s end
[UAT] requires 5 days
[UAT] starts at [Integration Testing]'s end
[Bug Fixing] requires 5 days
[Bug Fixing] starts at [UAT]'s end

' --- Phase 6: Deployment ---
-- Deployment --
[Staging Deploy] requires 2 days
[Staging Deploy] starts at [Bug Fixing]'s end
[Production Deploy] requires 1 days
[Production Deploy] starts at [Staging Deploy]'s end

' --- Milestones ---
[Requirements Complete] happens at [REQ Review & Sign-off]'s end
[Design Complete] happens at [Design Review]'s end
[Dev Complete] happens at [Integration]'s end
[Go-Live] happens at [Production Deploy]'s end

@endgantt
```

---

## Key Syntax

| Syntax | Meaning |
|--------|---------|
| `[Task] requires N days` | Set duration |
| `[Task B] starts at [Task A]'s end` | Start after Task A completes |
| `[Task B] starts N days after [Task A]'s end` | Start after Task A + N days |
| `[Milestone] happens at [Task]'s end` | Milestone (diamond marker) |
| `[Task] on {Resource}` | Assign responsible person |
| `[Task] is 40% completed` | Show % complete |
| `[Task] is colored in #FFD700` | Set color |
| `printscale daily / weekly / monthly` | Time axis scale |
| `saturday are closed` | Weekend holidays |
| `YYYY-MM-DD is closed` | Specific holiday |
| `-- Section Name --` | Section divider |
