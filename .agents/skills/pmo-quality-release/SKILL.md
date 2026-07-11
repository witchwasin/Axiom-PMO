---
name: pmo-quality-release
description: Use for QA evidence, release readiness, rollback review, and close-out decisions.
---

# pmo-quality-release

## Purpose
Verify release readiness, QA evidence, rollback planning, blocker status, and human release approval.

## Trigger
Use for QA review, UAT/release gate, rollback review, or close-out summary.

## Required Inputs
`DELIVERY.md`, `PROJECT.md`, release notes if present, and Strict guardrail files when mode is Strict.

## Allowed Context
Use QA/release context only. Read source docs only when evidence conflicts with requirements.

## Mode Behavior
Lite does not require `RELEASE.md`, `RAID-log.md`, `decision-log.md`, `DESIGN/`, or `RTM.yaml` by default, but Release Approved is always required. Standard requires release artifact when releasing. Strict requires RTM, RAID, decision log, QA/security review, and rollback evidence.

## Execution Steps
1. Check open blockers.
2. Verify work-item evidence and status.
3. Confirm rollback table rows when `RELEASE.md` exists.
4. Confirm Release Approved human evidence for every mode.
5. Run release validation.

## Output Contract
Return pass/fail summary, open blockers, release approval status, rollback status, and next action.

## Approval Rules
AI must not approve production release, deploy, tag, or push. Human Release Approved evidence is mandatory.

## Validation Command
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath <project> -Mode <mode> -Gate Release`

## Prohibited Actions
Do not release with missing human approval, unresolved blockers, missing Strict guardrails, or unverified rollback.

## Completion Criteria
Release gate passes with zero failures and required human approval evidence is present.
