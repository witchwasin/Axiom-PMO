---
name: pmo-delivery
description: Use for delivery planning, handoff, task source of truth, and engineering sequencing.
---

# pmo-delivery

## Purpose
Translate approved scope/design into executable work items and handoff notes.

## Trigger
Use when creating or reviewing `DELIVERY.md`, sequencing work, assigning owners, or checking task-source consistency.

## Required Inputs
`PROJECT.md`, `DELIVERY.md`, and relevant `DESIGN/**` for Standard/Strict or design-impacting Lite work.

## Allowed Context
Use the context router handoff set. Do not read release artifacts unless the user asks for release readiness.

## Mode Behavior
Lite keeps work items minimal and may use `not_required` for non-required design refs. Standard uses full work-item fields. Strict requires trigger reason, approval, review stage, and traceability.

## Execution Steps
1. Confirm task source of truth: file or GitHub.
2. Create work items with mode, strict trigger, requirement ref, design ref, status, review stage, evidence, and labels.
3. Check enum values against runtime policy.
4. Flag missing blockers or client decisions.

## Output Contract
Return work-item changes, dependency notes, owner gaps, and validation result.

## Approval Rules
Mode escalation and high-risk work require human confirmation before delivery starts.

## Validation Command
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath <project> -Mode <mode> -Gate Scope`

## Prohibited Actions
Do not create hidden task systems, duplicate source of truth, or add features outside scope.

## Completion Criteria
Every work item references an existing requirement/business rule and has valid mode, status, and review stage.
