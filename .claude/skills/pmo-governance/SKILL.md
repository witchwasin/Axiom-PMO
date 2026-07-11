---
name: pmo-governance
description: Use for RAID, decisions, traceability, risk, policy checks, and Strict-mode guardrails.
---

# pmo-governance

## Purpose
Maintain governance consistency without turning Lite projects into heavyweight programs.

## Trigger
Use for risk triage, decision logging, RTM checks, approval policy, blocker handling, or Strict-mode escalation.

## Required Inputs
`PROJECT.md`, relevant `RAID-log.md`, `decision-log.md`, `RTM.yaml`, and runtime config.

## Allowed Context
Read only governance artifacts needed for the gate. Do not load archived skills.

## Mode Behavior
Lite logs only material decisions/risks and still needs release approval. Standard logs meaningful risk or business decision. Strict requires full governance artifacts.

## Execution Steps
1. Classify risk and strict triggers.
2. Check approval gates and evidence.
3. Verify RTM coverage for Strict.
4. Confirm config and docs do not drift.

## Output Contract
Return risk status, required artifacts, missing evidence, and policy deviations.

## Approval Rules
Human approval is required for scope, design where applicable, release, mode escalation, and production-sensitive decisions.

## Validation Command
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/pmo-doctor.ps1`

## Prohibited Actions
Do not downgrade Strict triggers silently, fabricate decision evidence, or approve on behalf of a human.

## Completion Criteria
Governance artifacts match mode requirements and doctor/validator checks pass.
