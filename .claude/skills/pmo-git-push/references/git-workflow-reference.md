# Git Workflow Reference — Visual Guide

## Standard Git Push Workflow

```
┌─────────────────────────────────────────────────────────────────────┐
│                     START: Local Working Directory                   │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ↓
         ┌──────────────────────────────────────────┐
         │ STEP 1: Review Changed Files              │
         │ $ git status                              │
         │ $ git diff                                │
         └──────────────────────────────────────────┘
                                  │
                                  ↓
         ┌──────────────────────────────────────────┐
         │ STEP 2: Stage Files for Commit            │
         │ $ git add <specific-files>                │
         │ or                                        │
         │ $ git add .                               │
         └──────────────────────────────────────────┘
                                  │
                                  ↓
         ┌──────────────────────────────────────────┐
         │ STEP 3: Verify Staging                    │
         │ $ git status                              │
         │ (green = staged, red = unstaged)         │
         └──────────────────────────────────────────┘
                                  │
                                  ↓
         ┌──────────────────────────────────────────┐
         │ STEP 4: Create Commit                     │
         │ $ git commit -m "Message"                 │
         │                                           │
         │ Format:                                   │
         │ [PROJECT] TYPE: Description [Ref: MOM#X] │
         │ + Detailed body                           │
         │ + Traceability section                    │
         └──────────────────────────────────────────┘
                                  │
                                  ↓
         ┌──────────────────────────────────────────┐
         │ STEP 5: Verify Commit                     │
         │ $ git log -1                              │
         │ $ git log origin/main -n 3                │
         └──────────────────────────────────────────┘
                                  │
                                  ↓
         ┌──────────────────────────────────────────┐
         │ STEP 6: Check Remote Connection           │
         │ $ git ls-remote origin                    │
         │                                           │
         │ If fails: SSH key issue / repo not found  │
         └──────────────────────────────────────────┘
                                  │
                                  ↓
         ┌──────────────────────────────────────────┐
         │ STEP 7: Push to Origin                    │
         │ $ git push origin main                    │
         │                                           │
         │ If fails: Pull first, resolve conflicts   │
         └──────────────────────────────────────────┘
                                  │
                                  ↓
         ┌──────────────────────────────────────────┐
         │ STEP 8: Verify Push Success               │
         │ $ git log origin/main --oneline -n 5      │
         │                                           │
         │ (Should see your commit in origin)        │
         └──────────────────────────────────────────┘
                                  │
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                  SUCCESS: Changes Pushed to Origin                   │
│         (Available to all team members pulling from origin)          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Decision Tree: What Type of Commit?

```
Did you CREATE something new (diagram, flow, module)?
├─ YES → TYPE: Feature
│  └─ Example: Feature: Create App Swimlane Suite
│
└─ NO: Did you FIX something broken?
   ├─ YES → TYPE: Bugfix
   │  └─ Example: Bugfix: Fix LP Lifecycle — handle expired state
   │
   └─ NO: Did you CONSOLIDATE parallel work?
      ├─ YES → TYPE: Merge
      │  └─ Example: Merge: Resolve conflict and consolidate logs
      │
      └─ NO: Did you CHANGE existing (non-breaking)?
         ├─ YES → TYPE: Update
         │  └─ Example: Update: Revise swimlane formatting (minor)
         │
         └─ NO: Did you UPDATE TRACEABILITY/DOCS only?
            ├─ YES → TYPE: Docs
            │  └─ Example: Docs: Update Decision Log with D050-D053
            │
            └─ NO: Did you ARCHIVE/MOVE old files?
               ├─ YES → TYPE: Archive
               │  └─ Example: Archive: Move superseded swimlanes to Archived/
               │
               └─ NO: Did you FINALIZE for delivery?
                  └─ YES → TYPE: Release
                     └─ Example: Release: Finalize System Flow v1.0 for client
```

---

## File Staging Patterns

### Pattern 1: Single Diagram Update
```bash
git add P07-PROJECT/SystemFlow/BOF-SysF-03-B_LPLifecycle.puml
git add P07-PROJECT/SystemFlow/REQ_Traceability_Matrix.md
```

### Pattern 2: Folder of New Files
```bash
# Add entire folder (all files inside)
git add P07-PROJECT/SystemFlow/App_Workflow_Swimlane_byDeveloper/Swimlane/
```

### Pattern 3: Multiple Folders (Feature Complete)
```bash
git add P03-PROJECT/SystemFlow/
git add P03-PROJECT/UserFlow/
git add P03-PROJECT/UseCase/
git add P03-PROJECT/Wireframe/
git add P03-PROJECT/TaskBreakdown/
```

### Pattern 4: Selective (During Merge Conflict)
```bash
# After resolving conflict
git add P07-PROJECT/SystemFlow/REQ_Traceability_Matrix.md
# Don't add unresolved files yet
git status  # Verify conflict markers are gone
```

### Pattern 5: Everything (Use with Care)
```bash
# Add all changes in working directory
git add .
# Then verify before committing
git status
```

---

## Common Mistakes & Prevention

| ❌ Mistake | ✅ Prevention |
|-----------|------------|
| Forgot to stage files | Always run `git status` after staging |
| Staged wrong files | Run `git diff --cached` to verify |
| Commit message too short | Use template structure (WHAT/WHY/HOW/IMPACT) |
| Forgot MOM reference | Check template: `[Ref: MOM#X]` required |
| Forgot Session ID | Check traceability section: Session S00X required |
| MOM# format wrong | Format: MOM#1 or MOM#1-KickOff (not MOM 1, MOM-1) |
| Merge conflict unresolved | `git status` shows "UU" (unmerged) — resolve first |
| Remote unreachable | `git ls-remote origin` to test before push |
| File path uses backslash | Use forward slash: `P07-PROJECT/SystemFlow/` not `P07-PROJECT\SystemFlow\` |
| Large file rejected | Check .gitignore, consider Git LFS for files >100MB |

---

## Reference: Traceability in Commits

**Where to find Session Id:**
- Logged in `P{XX}-{CODE}/SystemFlow/REQ_Traceability_Matrix.md` Activity Log column
- Auto-incremented per session (S001, S002, S003, ... S005, S006)

**Where to find MOM#:**
- File names in `P{XX}-{CODE}/MOM/` folder
- Format: `YYYYMMDD_[MOM]_{label}` → MOM#1 = oldest date, MOM#N = newest date

**Where to find Decision ID:**
- In Decision Log table within REQ_Traceability_Matrix.md
- Format: D001, D002, ... D050, D051

**Where to find Activity Log Id:**
- In Activity Log table within REQ_Traceability_Matrix.md
- Format: S005-001, S005-002, ... S005-055 (session-activity number)

---

## Using Commit as Handoff Document

A well-formatted commit message serves as:
- **For Dev team:** What needs to be implemented (swimlane = spec)
- **For QA team:** What to test (cases are in swimlane + changelog)
- **For PM:** Audit trail (MOM# connects to original requirement)
- **For Future you:** Why this change was made (rationale in commit body)

**Best practice:** Commit message should be detailed enough that someone can understand the work 6 months later just by reading the commit.

---

## Bonus: Useful Git Aliases (Optional)

Add to `.git/config` or global config:

```bash
[alias]
    l1 = log --oneline -n 1
    l10 = log --oneline -n 10
    st = status
    co = checkout
    ci = commit
    br = branch
    unstage = reset HEAD --
    last = log -1 HEAD
    visual = log --graph --oneline --all
```

Then use shortcuts:
```bash
git st           # instead of git status
git l10          # instead of git log --oneline -n 10
git ci -m "..."  # instead of git commit -m "..."
```

---

## Help & Recovery

**If commit message has typo (before pushing):**
```bash
git commit --amend -m "New message"
```

**If staged wrong files:**
```bash
git reset HEAD <filename>
# File removed from staging, stays in working directory
```

**If pushed by mistake:**
```bash
# Contact team + owner before reverting
git revert HEAD
git push origin main
# Creates new commit that undoes the bad one
```

**If remote connection fails:**
```bash
# Check remote URL
git remote -v

# Test connection
git ls-remote origin

# If SSH error, try HTTPS
git remote set-url origin https://github.com/YOUR-ORG/PMO-Template.git

# Or check SSH key
ssh -T git@github.com
```

---

## Pro Tips

1. **Commit Often** — Small focused commits are easier to understand than one giant commit
2. **Clear Messages** — Imagine explaining this change to someone 6 months from now
3. **Link to MOM** — Every commit should trace back to a requirement (MOM#)
4. **Verify Before Push** — Use `git log origin/main` to see what's already there
5. **Pull Before Push** — If team members pushed since you last pulled, pull first then push
6. **Use Branches** — For experimental work, use feature branches before merging to main

---

## Related Skills

- **pmo-traceability:** Where Session IDs and Activity Logs come from
- **pmo-activity-diagram:** Creating the swimlanes you'll be committing
- **pmo-taskboard:** Tracking which Card corresponds to each commit
