---
name: pmo-design
description: Use for flow, UX, wireframe, and design-ready acceptance criteria tied to scoped requirements.
---

# pmo-design

## Purpose
Turn scoped requirements into flow, wireframe, and design-ready decisions.

## Trigger
Use when UI, workflow, user journey, integration flow, or acceptance wording needs design clarification.

## Required Inputs
`PROJECT.md`, applicable `DESIGN/**`, and requirements with source references.

## Allowed Context
Read only requirement rows and design files relevant to the requested flow. Avoid loading delivery or release docs unless checking impact.

## Mode Behavior
Lite design is conditional and can use `not_required` when no design impact exists. Standard expects resolvable design references when flow/UI exists. Strict requires explicit design evidence for high-risk paths.

## Execution Steps
1. Map requirement IDs to user/system flow steps.
2. Create or update `DESIGN/FLOW.puml` and `DESIGN/WIREFRAME.md` when required.
3. Record design assumptions and open questions.
4. Confirm design references are usable by delivery work items.

## Output Contract
Return design files changed, requirement coverage, assumptions, and unresolved design questions.

## Approval Rules
Design Ready is required for Standard/Strict design or release gates, but remains conditional for Lite.

## Validation Command
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath <project> -Mode <mode> -Gate Design`

## Prohibited Actions
Do not expand scope, remove source references, or mark design approval without human evidence.

## Completion Criteria
Each design-affecting work item has a design reference or an intentional `not_required` sentinel where allowed.
