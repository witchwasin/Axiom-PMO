# Wireframe Change Tracking

> Reference for `pmo-traceability` skill.
> Every Wireframe change must be recorded in `REQ_Traceability_Matrix.md`.

---

## Purpose

- **Track history** of every Wireframe change - who changed, what, why
- **Cross-reference with MOM/CR** - every change must have a source, no floating changes
- **View status** - know which pages are Done, which are Partial/Blocked

---

## Table Template

Add section "Wireframe Changes ({Platform})" in `REQ_Traceability_Matrix.md`:

```markdown
## Wireframe Changes ({Platform})

> Track every Wireframe change - reference MOM / CR source.
> **Wireframe path:** `{ProjectFolder}/Wireframe/{app-folder}/src/`

| Date | MOM / CR Ref | Module | Change Type | File | Description | Status |
|------|-------------|--------|-------------|------|-------------|--------|
| YYYY-MM-DD | MOM#X | {Module} | {Type} | `{relative path}` | {Summary of change} | {Status} |
```

---

## Column Reference

| Column | Description | Example |
|--------|-----------|---------|
| **Date** | Date of change | `2026-02-23` |
| **MOM / CR Ref** | Reference MOM or Change Request | `MOM#5`, `CR-001` |
| **Module** | Affected module (use REQ/MOM name) | `7. Transaction (Withdraw)`, `Shared (Nav)` |
| **Change Type** | Type of change | `New Page` / `Updated` / `Renamed` / `Removed` |
| **File** | File path (relative from `src/`) | `app/(dashboard)/fees/page.tsx` |
| **Description** | Brief summary of what changed | `Added Gold Price Source Config + Gap Config` |
| **Status** | Current status | `Done` / `Partial (BLOCKED - {reason})` |

---

## Change Types

| Change Type | Meaning | When to use |
|-------------|---------|-------------|
| **New Page** | New page that didn't exist before | Adding new module/feature |
| **Updated** | Modified existing page | Adding/removing/changing elements |
| **Renamed** | Changed file/folder name | Refactor, terminology change |
| **Removed** | Deleted page no longer needed | Feature descoped |

---

## Coverage Summary Metrics

After recording Wireframe Changes, update Coverage Summary in `REQ_Traceability_Matrix.md`:

```markdown
| **Total Wireframe Pages ({Platform})** | {total page count} |
| **Wireframe Pages Updated (MOM#X)** | {pages modified count} |
| **Wireframe New Pages (MOM#X)** | {new pages count} |
```

---

## Rules

1. **Every Wireframe edit** - add new row in Wireframe Changes table immediately
2. **Shared files** (mockData, Sidebar, layout) modified for new features - must record too, use Module = `Shared ({type})`
3. **Same page from multiple MOM/CR** - record separate rows per MOM/CR ref for traceability
4. **No Wireframe edit without MOM/CR ref** - every change must have a source
