# Tutorial: Your First Project

This walks through creating and validating a project with Axiom-PMO. It assumes
PowerShell is available (Windows PowerShell 5.1 or `pwsh`).

## 1. Generate a skeleton

```powershell
powershell -ExecutionPolicy Bypass -File scripts/new-project.ps1 -ProjectCode P02-DEMO -Mode Standard
```

This scaffolds a mode-aware project from `templates/`. Standard adds `DESIGN/`
and `RELEASE.md`; Strict also adds `RAID-log.md`, `decision-log.md`, and
`RTM.json`.

## 2. Add source material

Put the real inputs under `source/`:

```
source/MOM/2026-07-14-kickoff.md
source/REQ/requirements.md
source/Transcript/...
```

These are user-owned — the framework reads them but never edits them. See
[source ownership](../governance/source-ownership.md).

## 3. Fill PROJECT.md from source

For each requirement, record a `source_ref` (which source document and locator)
and an `evidence_status` (`verified`, `supported`, `inferred`, `missing`, or
`conflict`). If the source does not say, write "not found in source" — do not
invent. See [evidence-based execution](../concepts/evidence-based-execution.md).

## 4. Choose a mode per work item

Declare each work item's mode in `DELIVERY.md`. If any item carries a
[Strict trigger](../concepts/risk-modes.md), the project's effective mode becomes
Strict automatically.

## 5. Validate before each gate

```powershell
# Scope gate
powershell -ExecutionPolicy Bypass -File scripts/validate-project.ps1 `
  -ProjectPath projects/P02-DEMO -Mode Standard -Gate Scope -FailOnWarning

# Release gate
powershell -ExecutionPolicy Bypass -File scripts/validate-project.ps1 `
  -ProjectPath projects/P02-DEMO -Mode Standard -Gate Release -FailOnWarning
```

A non-zero exit means something is missing, placeholder, unresolvable, or
unapproved. Fix the artifact — do not weaken the check.

## 6. Study a worked example

Compare against [`examples/STANDARD-FEATURE`](../../examples/STANDARD-FEATURE) or,
for a high-risk project with an RTM,
[`examples/STRICT-HIGH-RISK`](../../examples/STRICT-HIGH-RISK).

Next: [using Axiom-PMO with an AI agent](using-with-an-ai-agent.md).
