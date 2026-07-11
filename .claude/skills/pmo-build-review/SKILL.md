---
name: pmo-build-review
description: Use for build completion evidence, code review readiness, and ready-for-QA checks.
---

# pmo-build-review

## Purpose
Confirm that implementation evidence is ready for review or QA.

## Trigger
Use after build work, before review/test, or when checking a PR or patch against requirements.

## Required Inputs
`DELIVERY.md`, changed-file summary, relevant requirement/design references, and test evidence.

## Allowed Context
Read only work items and code/design artifacts relevant to the change. Use source docs only for disputed requirements.

## Mode Behavior
Lite checks smoke evidence and release approval readiness. Standard checks requirement/design coverage. Strict adds security/QA review, traceability, rollback, and high-risk evidence expectations.

## Execution Steps
1. Map changed work to delivery item IDs.
2. Check acceptance criteria and test checklist evidence.
3. Identify missing review stage or unresolved blocker.
4. Recommend next gate or corrective action.

## Output Contract
Return review findings, missing tests, risk flags, and ready/not-ready status.

## Approval Rules
AI can recommend ready-for-review but cannot approve production release.

## Validation Command
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath <project> -Mode <mode> -Gate Design`

## Prohibited Actions
Do not hide failing checks, skip risk escalation, or mutate git state without human approval.

## Completion Criteria
Work items are traceable, review stage is valid, and unresolved issues are documented.
