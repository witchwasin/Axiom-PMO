---
name: pmo-intake
description: Use when turning source material into scoped, source-referenced PMO requirements and intake decisions.
---

# pmo-intake

## Purpose
Convert source material into confirmed requirements, assumptions, questions, scope, and mode recommendations.

## Trigger
Use for new source review, requirement extraction, gap analysis, scope clarification, or source conflict triage.

## Required Inputs
`PROJECT.md`, relevant `source/**`, and any user-stated goal. Read only the context set allowed by `CONTEXT-ROUTER.md`.

## Allowed Context
Default to `PROJECT.md` plus the specific source files needed. Do not bulk-load archived skills or every source file unless the task is an impact analysis or conflict review.

## Mode Behavior
Lite captures only essential source, scope, and release approval needs. Standard captures normal requirements and design implications. Strict flags payment, PII, auth, permission, integration, compliance, migration, and public-sector acceptance triggers.

## Execution Steps
1. Identify confirmed facts, assumptions, and open questions.
2. Assign stable requirement IDs and `source_ref`.
3. Mark evidence status from configured policy values.
4. Recommend Lite, Standard, or Strict per work item.
5. Update or request Source Snapshot refresh when source files change.

## Output Contract
Return confirmed requirements, assumptions, open questions, source references, confidence notes, and mode recommendation.

## Approval Rules
Scope approval is human-owned. AI may draft rows but must not mark approval as granted without explicit source evidence.

## Validation Command
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/validate-project.ps1 -ProjectPath <project> -Mode <mode> -Gate Scope`

## Prohibited Actions
Do not invent requirements, silently resolve conflicts, push commits, deploy, or approve release.

## Completion Criteria
Every in-scope requirement has `source_ref`, evidence status, and either confirmed acceptance or an open question.
