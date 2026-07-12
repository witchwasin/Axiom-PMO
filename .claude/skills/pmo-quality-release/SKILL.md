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
`PROJECT.md`, configured task source of truth, release notes if present, and any conditional artifacts required by `pmo-config/context-map.json` and `pmo-config/artifact-policy.json`.

## Allowed Context
Use QA/release context only. Read source docs only when evidence conflicts with requirements.

## Mode Behavior
Use `pmo-config/artifact-policy.json` for mode/gate artifact requirements and `pmo-config/policy.json` for approval gates and roles. Lite release requires `PROJECT.md` and `DELIVERY.md` (a prose "work item" mention is not parseable evidence); `RELEASE.md` stays optional unless the configured artifact policy or a real release/UAT trigger requires it. Never auto-create `RTM.json` or `RELEASE.md` for Lite without a trigger.

## Execution Steps
1. Check open blockers.
2. Verify work-item evidence and status.
3. Confirm rollback table rows when `RELEASE.md` exists.
4. Confirm Release Approved human evidence for every mode.
5. Run release validation.

## Output Contract
Return pass/fail summary, open blockers, release approval status, rollback status, and next action.

## Approval Rules
AI must not approve production release, mark Release Approved for a human, deploy, tag, or push. Human Release Approved evidence is mandatory when required by the configured gate policy.

## Validation Command
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath <project> -Mode <mode> -Gate Release`

## Prohibited Actions
Do not release with missing human approval, unresolved blockers, missing configured guardrails, unverified rollback, or Lite artifacts created only to satisfy a hardcoded checklist.

## Completion Criteria
Release gate passes with zero failures and required human approval evidence is present.
