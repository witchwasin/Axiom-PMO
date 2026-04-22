---
name: pmo-git-push
description: Prepare commit message with proper traceability, format git commands, track changes to origin (push workflow for PMO projects)
---

# PMO Skill: Git Push & Commit Workflow

> **Trigger words:** push to origin, git push, commit and push, stage files, submit to git, send to origin, ready to push
> **Related Skills:** pmo-traceability (Activity/Decision/Change Log), pmo-taskboard (card status tracking)
> **Key Output:** Formatted commit message + git commands + traceability logging

---

## Before You Push: Pre-Flight Checklist

### 1. Verify Traceability Logging
Before committing, ensure `P{XX}-{CODE}/SystemFlow/REQ_Traceability_Matrix.md` contains:

- ✅ **Change Log entry** — what files changed, when, why, status
- ✅ **Activity Log entry** — AI actions (Created/Updated/Merged/Validated)
- ✅ **Decision Log entry** — any decisions made during work
- ✅ **Session ID** — which Claude session number (S001, S005, etc.)

### 2. File Status Check
```bash
git status
```
Expected output shows:
- **Staged changes** (green) — files marked for commit
- **Untracked files** (red) — new files not yet added
- **Modified files** (red) — changed files not yet staged

### 3. Review Changed Files
```bash
git diff --cached
```
Verify all changes are intentional before committing.

---

## Commit Message Format

### Template Structure

```
[PROJECT] TYPE: Brief description [Ref: MOM#X[-] Topic]

Detailed Body:
- What changed (file list / feature / fix)
- Why changed (requirement / feedback / issue)
- How changed (approach / method / validation)
- Impact (modules / workflows / scope affected)

Traceability:
- Session: S{NNN} (Claude session number)
- MOM Reference: MOM#X (link to Minutes of Meeting)
- Activity Log: Reference ID from Activity Log table
- Status: ✓ Ready / ⏳ Pending / ⚠️ Flagged
```

### Fields Explanation

| Field | Required | Example | Notes |
|-------|----------|---------|-------|
| **[PROJECT]** | ✅ Yes | `[P07-PROJECT]` | Project code from folder name |
| **TYPE** | ✅ Yes | `Feature` `Bugfix` `Merge` `Update` `Docs` | One word describing action type |
| **Brief Description** | ✅ Yes | `Create App Swimlane Suite (12 files)` | Max 60 characters, action-oriented |
| **[Ref: MOM#X]** | ✅ Yes | `[Ref: MOM#1-KickOff]` | Which MOM triggered this work |
| **Detailed Body** | ✅ Yes | Bullet list of changes | Help team understand scope |
| **Session** | ✅ Yes | `S005` | Which Claude session (auto-tracked in Activity Log) |
| **MOM Reference** | ✅ Yes | `MOM#1, MOM#2` | All relevant MOM#s |
| **Activity Log** | ✅ Yes | `Activity Log entry {timestamp} {action}` | Link to traceability matrix |
| **Status** | ✅ Yes | `✓ Ready`, `⏳ Pending`, `⚠️ Flagged` | Current state before push |

---

## TYPE Categories (Commit Classification)

| Type | When to Use | Example |
|------|------------|---------|
| **Feature** | New flows / diagrams / modules created | Create App Swimlane Suite, Add UseCase Diagram |
| **Bugfix** | Fix issues in existing flows / diagrams | Fix conflicting logic in Module X, Correct terminology |
| **Merge** | Resolved merge conflict / pull consolidation | Merge BOF feedback with App workflows, Resolve git conflict |
| **Update** | Modified existing diagram / doc (not new, not bug) | Update Activity Log, Revise timeline based on feedback |
| **Docs** | Update documentation / traceability only | Add decision log, Update Traceability Matrix |
| **Archive** | Move old versions / backups | Archive old swimlane v1 files |
| **Release** | Finalize for client delivery / phase completion | Release System Flow v1.0, Finalize wireframes for handoff |

---

## Commit Message Examples

### Example 1: Feature + New Deliverable

```
[P07-PROJECT] Feature: Create App Swimlane Suite v0.2 (12 workflows) + integrate BOF insights [Ref: MOM#1-KickOff]

Parallel Deliverables:
- Created 12-swimlane Member App workflow suite (APP-01, APP-02-A/B1/B2/C, APP-03-A/B/C, APP-05, APP-06-A1/A2, Master-Index)
  * Based on Figma mockups (3/27) covering Email validation, Biometric toggle, Language switch, PIN edit, QR generation, Settings
  * Format: PlantUML Activity Diagram (User + App + API swimlanes)
  * RR embedding: All 12 flows reference relevant RR feedback items (#7, #28, #39, etc.)

- Analyzed RR BOF swimlane feedback (74 comments, 3/30-3/31)
  * 5 categories: Business Logic (18), Clarification (18), Terminology (11), Quality (12), Features (15)
  * Output: Reply Excel (summary + action items), Impact Analysis across 19 BOF modules
  * Integration: App workflow design informed by BOF rigor standards

Traceability:
- Session: S005 (Claude session covering both App creation + BOF analysis)
- MOM Reference: MOM#1 (KickOff with Figma/swimlane coordination)
- Activity Log: S005 entries (12 swimlane creations, 1 merge conflict resolution)
- Status: ✓ Ready for client review + development handoff
```

### Example 2: Bugfix + Updated Flow

```
[P01-PROJECT] Bugfix: Fix LP Lifecycle (Module 03-B) — handle expired LP state [Ref: MOM#2-Business Rules]

Changes:
- Updated SystemFlow/BOF-SysF-03-B_LPLifecycle.puml
  * Added missing branch: When LP status = "EXPIRED" → trigger notification + archive workflow
  * Fixed attempt counter logic: reset on successful validation (was infinite loop)
  * Corrected API endpoint: /lp/check-status → /lp/validate (per MOM#2 Section 3.2)

Validation:
- Lark 7 rules: ✓ PASSED
- MOM Validation (7 checklist): ✓ PASSED (6/7 + gap noted in #4)
- Case coverage: Happy + 3 alternative paths + 2 exception handlers

Traceability:
- Session: S003
- MOM Reference: MOM#2 (LP Lifecycle requirements)
- Activity Log: S003-050 (bugfix review + lark validation)
- Decision: D042 (approved using API v2 endpoint)
- Status: ✓ Ready for QA testing
```

### Example 3: Merge + Conflict Resolution

```
[P07-PROJECT] Merge: Resolve REQ_Traceability_Matrix.md conflict — consolidate BOF + App logs [Ref: MOM#1-KickOff]

Conflict Details:
- File: REQ_Traceability_Matrix.md (Change Log + Activity Log sections)
- Upstream: BOF feedback analysis entries (3/30-3/31, RR comment review + reply Excel)
- Local: App workflow creation entries (3/27, 7 workflow files + readiness check)
- Resolution: Kept both, chronologically ordered (3/27 App → 3/31 BOF)

Result:
- Single source of truth for project timeline + all parallel activities
- No data loss — both streams preserved in correct sequence
- Cross-references updated: Activity Log references both BOF + App creation tasks

Traceability:
- Session: S005 (conflict resolution + final consolidation)
- MOM Reference: MOM#1
- Activity Log: S005-merge-001 (conflict resolution)
- Changed Files: 1 (REQ_Traceability_Matrix.md) + 13 related files (staged)
- Status: ✓ Merge complete, ready to push
```

### Example 4: Documentation Only

```
[P03-PROJECT] Docs: Update Decision Log — Novel status display logic [Ref: MOM#1-Feature Spec]

Changes:
- Updated Decision Log in SystemFlow/REQ_Traceability_Matrix.md
  * Added D034 (Novel status filtering: Browse page keeps filter dropdown, no badge on cover)
  * Added D050 (Sold Novel Protection: action requires Admin approval once any sale exists)
  * Added D051 (Tag Admin Only: Writer cannot create custom tags)

Rationale:
- Decisions made in daily standup emails (3/27-3/31)
- Reflected in wireframe updates (D034~D051 span 4 design iterations)
- Needed immediate logging for dev team baseline

Traceability:
- Session: S005
- MOM Reference: MOM#1 (kickoff requirements)
- Activity Log: S005-docs-001, S005-docs-002 (decision logging)
- Impact: No diagram changes, documentation-only update
- Status: ✓ Ready
```

---

## Git Commands (Step by Step)

### Step 1: Stage Files
```bash
# Stage specific files
git add P07-PROJECT/SystemFlow/REQ_Traceability_Matrix.md
git add P07-PROJECT/SystemFlow/App_Workflow_Swimlane_byDeveloper/Swimlane/*.puml

# Or stage all changes
git add .

# Verify staged changes
git status
```

### Step 2: Create Commit
```bash
# Using command line
git commit -m "[PROJECT] TYPE: Description [Ref: MOM#X]" \
  -m "Detailed body here" \
  -m "- Bullet 1" \
  -m "- Bullet 2"

# Or create in editor
git commit
# [Opens text editor, paste formatted message, save and close]
```

### Step 3: Verify Commit
```bash
# Show latest commit
git log --oneline -n 1

# Show detailed commit
git log -1
```

### Step 4: Check Remote
```bash
# List remotes
git remote -v

# Check if remote is accessible
git ls-remote origin
```

### Step 5: Push to Origin
```bash
# Push current branch to origin
git push origin main

# Or push all branches
git push origin --all

# Push with tracking (if branch doesn't exist remotely)
git push --set-upstream origin feature-branch-name
```

### Step 6: Verify Push
```bash
# Check if push succeeded
git log origin/main --oneline -n 5

# Compare local vs remote
git log --oneline -n 5 main
git log --oneline -n 5 origin/main
```

---

## Checklist Before Hitting "Push"

- ✅ All files staged correctly (`git status` shows only intended files)
- ✅ Commit message follows [PROJECT] TYPE: Description [Ref: MOM#X] format
- ✅ Detailed body explains WHAT/WHY/HOW/IMPACT
- ✅ Traceability section includes Session + MOM + Activity Log + Status
- ✅ No sensitive data in message (credentials, private paths, etc.)
- ✅ Latest commit message is correct (`git log -1`)
- ✅ No merge conflicts remain (`git status` shows no "UU" files)
- ✅ Remote is reachable and accessible (`git ls-remote origin` succeeds)
- ✅ Branch is up-to-date or you've resolved conflicts (`git pull` if needed)
- ✅ `.gitignore` prevents staging unwanted files (node_modules, .env, etc.)

---

## Common Issues & Solutions

| Issue | Symptom | Solution |
|-------|---------|----------|
| **Wrong files staged** | `git status` shows files you didn't intend | `git reset HEAD filename` to unstage |
| **Need to edit last commit** | Forgot something in the commit | `git commit --amend` (before pushing) |
| **Merge conflict on push** | "your branch has diverged" | `git pull` to merge upstream, resolve conflicts, push again |
| **Remote not found** | "fatal: repository not found" | Check `.git/config` remote URL, verify SSH/HTTPS access |
| **Authentication failed** | "Permission denied" at push | Re-authenticate: `git config --global user.name/email` or SSH key |
| **Large file rejected** | "file too large" | Check `.gitattributes`, use Git LFS if needed |

---

## Reference: MOM Reference Format

When writing commit message with MOM reference:

```
[Ref: MOM#1-TopicName]           # Single MOM
[Ref: MOM#1, MOM#2]              # Multiple MOMs (comma-separated)
[Ref: MOM#1-KickOff]             # MOM# + descriptive topic
[Ref: MOM#1-BugFix, MOM#3]       # Mixed (some with topics, some without)
```

---

## Session Tracking Format

In commit message, reference session like:

```
Session: S005                    # Current session number (auto-incremented)
Sessions: S003, S004, S005       # If work spans multiple sessions
Session: S005 (spanning 3/27-3/31) # With date range if helpful
```

Session numbers are logged in Activity Log table under "Session" column.

---

## Auto Changelog Generation (v2.1.0)

```
สร้าง changelog สำหรับ P07-PROJECT
```

AI จะ: อ่าน git log (filter by project code) → จัดกลุ่มตาม type → generate:

```markdown
# Changelog — P{XX}-{CODE}
## [Unreleased]
### Added
- feat(P07): Add Module 15 Report flow
### Changed
- update(P07): Update Module 03 per MOM#3
### Fixed
- fix(P07): Fix swimlane color
### Data
- data(P07): Add MOM#3 Review Session
```

เมื่อรัน `pmo-git-push` + มี > 5 commits ใหม่ → แนะนำ generate changelog
