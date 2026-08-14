# Migration

## From Legacy PMO Structure

Legacy folders can be mapped into the lightweight structure:

| Legacy | Current |
|---|---|
| `MOM/`, `REQ/`, `Others/` | `source/` |
| `UserFlow/`, `SystemFlow/`, `UseCase/` | `DESIGN/` |
| `Wireframe/` | `DESIGN/WIREFRAME.md` or `.html` |
| `TaskBreakdown/` | `DELIVERY.md` or GitHub Issues |
| *(no legacy equivalent)* | `HANDOFF.md`, `DESIGN/BUILD-SPEC.md` |

The last row is the point of 1.1: no legacy artifact answered "can a developer
start on Monday?", which is why that question kept being answered in a meeting
instead of in a document. See [artifact map](docs/guides/artifact-map.md).

## Skill Runtime Migration

Old skills were archived instead of deleted:

- `.claude-archive/optional-skills/`
- `.claude-archive/legacy-skills/`

The active runtime now uses only the 7 skills listed in `pmo-config/skill-manifest.json`.

## V2.1 declaration compatibility (M0–M3)

Existing projects do not need a bulk migration. If `PROJECT.md` omits the new
declarations, validators use these compatibility defaults silently:

| Declaration | Effective default |
|---|---|
| `Execution path` | `development_handoff` |
| `Research mode` | `off` |
| `Research depth` | `standard` |
| `Research provider` | `none` |
| `UI delivery` | `legacy` |

New Standard/Strict projects may declare `UI delivery` and receive the early
`DESIGN/BUILD-SPEC.md` Test Strategy contract. Research, Externalization, and
Claude Design provider artifacts are intentionally not created until their
owning M4–M6 work is implemented.

## Project Migration Steps

1. Create or update `PROJECT.md`.
2. Declare the task source of truth.
3. Move delivery work into `DELIVERY.md` or GitHub Issues.
4. Add `source_ref`, `evidence_status`, and `approval_status`.
5. Validate with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath <project-path> -Mode Standard -Gate Release
```

## From 1.0 to 1.1

**Nothing is required.** A project that does not request the `Handoff` gate
validates exactly as it did in 1.0, and the only change a JSON consumer sees is
additive fields on each diagnostic.

To adopt the gate on an existing project:

1. Copy `templates/HANDOFF.md` into the project root and fill the metadata block
   (target, horizon, handoff owner, named integrator).
2. For Standard/Strict, copy `templates/BUILD-SPEC.md` to
   `DESIGN/BUILD-SPEC.md`. Each section declares `Status: specified` or
   `not_required` with a written rationale — a blank section is never valid.
3. Record a semantic review in `HANDOFF-REVIEW.json`. Get the freshness digest
   with `scripts/handoff-digest.ps1 -ProjectPath <project>`.
4. Run the gate and the assessment:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath <project-path> -Mode Standard -Gate Handoff
powershell -ExecutionPolicy Bypass -File scripts/assess-handoff.ps1 -ProjectPath <project-path> -Mode Standard
```

The gate adds no new human approval — it reuses the `Design Ready` row already in
`PROJECT.md`. See [handoff readiness](docs/concepts/handoff-readiness.md).

### For consumers of the JSON output

`level`, `rule_id`, `message`, and `blocking` are unchanged. Six fields were
added; ignore the ones you do not use. Fields that do not apply are `null`, never
absent. The contract and its deprecation policy are in
[`docs/reference/diagnostics-contract.md`](docs/reference/diagnostics-contract.md).
