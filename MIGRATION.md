# Migration

## From Legacy PMO Structure

Legacy folders can be mapped into the lightweight structure:

| Legacy | Current |
|---|---|
| `MOM/`, `REQ/`, `Others/` | `source/` |
| `UserFlow/`, `SystemFlow/`, `UseCase/` | `DESIGN/` |
| `Wireframe/` | `DESIGN/WIREFRAME.md` or `.html` |
| `TaskBreakdown/` | `DELIVERY.md` or GitHub Issues |

## Skill Runtime Migration

Old skills were archived instead of deleted:

- `.claude-archive/optional-skills/`
- `.claude-archive/legacy-skills/`

The active runtime now uses only the 7 skills listed in `pmo-config/skill-manifest.yaml`.

## Project Migration Steps

1. Create or update `PROJECT.md`.
2. Declare the task source of truth.
3. Move delivery work into `DELIVERY.md` or GitHub Issues.
4. Add `source_ref`, `evidence_status`, and `approval_status`.
5. Validate with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath <project-path> -Mode Standard -Gate Release
```

