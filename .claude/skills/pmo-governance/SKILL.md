---
name: pmo-governance
description: Use for RAID, decisions, traceability, risk, policy checks, and Strict-mode guardrails.
---

# pmo-governance

## Purpose
Maintain governance consistency without turning Lite projects into heavyweight programs.

## Trigger
Use for risk triage, decision logging, RTM checks, approval policy, blocker handling, Strict-mode escalation, Change Control, or Externalization review.

## Required Inputs
`PROJECT.md`, relevant governance artifacts, and runtime config from `pmo-config/context-map.json`, `pmo-config/policy.json`, `pmo-config/artifact-policy.json`, `pmo-config/reference-types.json`, and `pmo-config/validation-rules.json`.

## Allowed Context
Read only governance artifacts needed for the gate. Do not load archived skills.

## Mode Behavior
Use `pmo-config/artifact-policy.json` for required/conditional/optional governance artifacts and `pmo-config/policy.json` for strict triggers, approval roles, and evidence values. Lite logs only material decisions/risks; Standard logs meaningful risk or business decision; Strict follows the configured governance artifact contract.

## Execution Steps
1. Classify risk and strict triggers.
2. Check approval gates and evidence.
3. Verify RTM coverage for Strict.
4. Confirm config and docs do not drift.
5. Validate `CHANGE-REQUESTS.json` when a real deviation exists; AI-proposed impact is candidate evidence, not exhaustive discovery or approval.
6. For Externalization, maintain `EXTERNALIZATION.json` as a registry of what leaves the governed boundary: exact outgoing artifact paths and digests, declared classification, minimization/redaction, deterministic scan result, and truthful network-transfer declaration. Confidential/Restricted transfers and non-clean scans require a named Human reviewer and a resolvable `DEC-###`; never declare such content safe on your own, never echo a detected value in a diagnostic.
7. For Research, keep `RESEARCH/RESEARCH.md` and `RESEARCH/PROVENANCE.json` source-backed and draft Impact Assessment and Change Proposals as candidate evidence. Only a Human accepts proposals at Scope (`RESEARCH-004`); an unresolved accepted-impact proposal blocks Scope (`RESEARCH-005`).

## Output Contract
Return risk status, required artifacts, missing evidence, and policy deviations.

## Approval Rules
Human approval is required for scope, design where applicable, release, mode escalation, and production-sensitive decisions.

## Validation Command
`node cli/axiom.mjs doctor`

## Prohibited Actions
Do not downgrade Strict triggers silently, fabricate decision evidence, hardcode artifact matrices, log every minor AI action, or approve on behalf of a human.

## Completion Criteria
Governance artifacts match mode requirements and doctor/validator checks pass.
