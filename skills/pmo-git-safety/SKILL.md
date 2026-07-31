---
name: pmo-git-safety
description: Use for branch, diff, sensitive file, commit, push, tag, and release safety.
---

# pmo-git-safety

## Purpose
Keep git operations reviewable, intentional, and safe.

## Trigger
Use before commit, push, tag, branch changes, release publication, or when sensitive files may be present.

## Required Inputs
Current branch, git status, diff summary, validation output, human approval state, and git/release permissions from `pmo-config/policy.json`.

## Allowed Context
Read git metadata and changed files needed for review. Do not inspect denied secret files.

## Mode Behavior
Use `pmo-config/policy.json` for git mutation and production release permission requirements. Lite, Standard, and Strict all require human confirmation for commit/push/tag; push requires explicit per-push confirmation.

## Execution Steps
1. Confirm branch and remote.
2. Summarize staged/unstaged/untracked changes.
3. Check sensitive filenames and denied paths.
4. Confirm tests and human review before commit.
5. Never push until explicitly approved.

## Output Contract
Return branch, account/remote if requested, changed files, test result, and pending human actions.

## Approval Rules
Commit is local only after per-round diff approval. Push/PR/merge require final explicit approval. Production release approval cannot be automated.

## Validation Command
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-all-checks.ps1`

## Prohibited Actions
Do not use destructive git commands, force push, bypass permissions, approve production release, push without explicit per-push confirmation, or commit unrelated user changes.

## Completion Criteria
Working tree changes are intentional, tests are green, no sensitive files are included, and human approval is recorded.
