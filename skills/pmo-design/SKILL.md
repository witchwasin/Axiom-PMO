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
`PROJECT.md`, applicable `DESIGN/**`, requirements with source references, and the context/artifact contract in `pmo-config/context-map.json` and `pmo-config/artifact-policy.json`.

## Allowed Context
Read only requirement rows and design files relevant to the requested flow. Avoid loading delivery or release docs unless checking impact.

## Mode Behavior
Use `pmo-config/policy.json` for mode, sentinel, evidence, and approval values, and `pmo-config/artifact-policy.json` for when design artifacts are required. Lite design is conditional and can use `not_required` only where the configured sentinel policy allows it. Standard and Strict design expectations follow the configured artifact and reference contracts.

## Execution Steps
1. Map requirement IDs to user/system flow steps.
2. Create or update `DESIGN/FLOW.puml` and `DESIGN/WIREFRAME.md` only when the configured artifact contract or confirmed design impact requires them.
3. Record design assumptions and open questions.
4. Confirm design references are usable by delivery work items.

## Output Contract
Return design files changed, requirement coverage, assumptions, and unresolved design questions.

## Approval Rules
Design Ready is human-owned and follows the configured artifact and approval contracts for the active mode and gate.

## Validation Command
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath <project> -Mode <mode> -Gate Design`

## Prohibited Actions
Do not expand scope, remove source references, hardcode artifact matrices, or mark design approval without human evidence.

## Completion Criteria
Each design-affecting work item has a design reference or an intentional `not_required` sentinel where allowed.
