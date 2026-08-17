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
`PROJECT.md`, relevant `source/**`, and any user-stated goal. Read only the context set allowed by `CONTEXT-ROUTER.md` and `pmo-config/context-map.json`.

## Allowed Context
Default to `PROJECT.md` plus the specific source files needed. Do not bulk-load archived skills or every source file unless the task is an impact analysis or conflict review.

## Onboarding
Before any intake work on a project whose `PROJECT.md` does not yet declare
both `Execution path:` and `Default mode:`, ask the user directly. Do not
infer, detect, or silently default either answer — `docs/concepts/execution-paths.md`
and `DEC-011` both treat a system claiming to have "detected" either answer,
rather than stating what the user declared, as a fabricated evidence claim.
This mirrors `axiom init`'s interactive wizard (`cli/axiom.mjs`) for the
skill-based flow, which never invokes that CLI.

Ask, in the user's own words if useful, but cover both:

1. **Who builds this work** — a developer or vendor after a verified
   handoff (`development_handoff`), or an AI execution agent under a
   governed contract, verified afterward against git ground truth
   (`governed_ai_execution`)? See `docs/concepts/execution-paths.md`.
2. **How strictly should this be governed** — Lite, Standard, or Strict?
   If the user is unsure, walk through `pmo-config/policy.json`
   `enums.strict_triggers` (payment, financial calculation, PII, sensitive
   data, authentication, authorization, permission, irreversible action,
   external integration, compliance, production migration, critical
   infrastructure, public-sector formal acceptance) — any match recommends
   Strict.

Record both answers in `PROJECT.md` (`Execution path:` and `Default mode:`
lines) and log the choice in `decision-log.md` if the project keeps one,
stating plainly that this is what the user declared. Skip this step only
when `PROJECT.md` already carries both declarations from a prior session —
re-asking on every message is not required. A project may still escalate a
specific work item to Strict later via the normal per-item mode
recommendation below; this onboarding step sets the project-level default,
not a ceiling.

## Mode Behavior
Use the mode, strict-trigger, evidence-status, and approval enums from `pmo-config/policy.json`; do not repeat or extend them inside the skill. Lite captures only essential source, scope, and release approval needs. Standard captures normal requirements and design implications. Strict escalation follows the configured strict triggers.

## Execution Steps
0. Complete Onboarding above if `PROJECT.md` does not yet declare both `Execution path:` and `Default mode:`.
1. Identify confirmed facts, assumptions, and open questions.
2. Assign stable requirement IDs and `source_ref`.
3. Mark evidence status from configured policy values.
4. Recommend Lite, Standard, or Strict per work item.
5. Update or request Source Snapshot refresh when source files change.
6. When the project declares Research mode `guided` or `auto`, draft the Research Brief from preliminary requirements and unknowns (see `docs/concepts/research-workflow.md`); keep every material claim source-backed in `RESEARCH/PROVENANCE.json`. Research findings are candidate evidence that only a Human decision at Scope can act on.

## Output Contract
Return confirmed requirements, assumptions, open questions, source references, confidence notes, and mode recommendation.

## Approval Rules
Scope approval is human-owned. AI may draft rows but must not mark approval as granted without explicit source evidence.

## Validation Command
`node cli/axiom.mjs validate --project <project> --mode <mode> --gate Scope`

## Prohibited Actions
Do not invent requirements, bulk-load all source by default, silently resolve conflicts, push commits, deploy, or approve release. Do not write or infer `Execution path:` or `Default mode:` into `PROJECT.md` without first asking the user per Onboarding above, and never describe either as "detected."

## Completion Criteria
Every in-scope requirement has `source_ref`, evidence status, and either confirmed acceptance or an open question.
