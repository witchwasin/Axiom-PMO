# Commit Message Checklist

## Quick Validation (Before Commit)

**Format Check:**
- [ ] Starts with `[PROJECT]` (e.g., `[P07-PROJECT]`)
- [ ] Contains `TYPE:` (Feature/Bugfix/Merge/Update/Docs/Archive/Release)
- [ ] Brief description under 60 characters
- [ ] Ends with `[Ref: MOM#X]` or `[Ref: MOM#X-Topic]`

**Content Check:**
- [ ] "What changed" section explains files/flows/diagrams
- [ ] "Why changed" section references requirement/feedback/issue
- [ ] "How changed" section describes approach/method
- [ ] "Impact" section lists affected modules/workflows

**Traceability Check:**
- [ ] Session ID included (S001, S005, etc.)
- [ ] MOM reference(s) listed (MOM#1, MOM#2-KickOff, etc.)
- [ ] Activity Log reference included
- [ ] Status marked (✓ Ready, ⏳ Pending, ⚠️ Flagged)

**Quality Check:**
- [ ] No typos or grammatical errors
- [ ] No sensitive data (credentials, private info)
- [ ] All file paths are relative (use / not \)
- [ ] RR references included if applicable ([RR #XX])
- [ ] Consistent terminology matching MOM/REQ

---

## Type Selection Matrix

```
Feature  = New diagram / New workflow / New module => ✅ FEATURE
Bugfix   = Logic error / Conflict resolve / Wrong flow => ✅ BUGFIX
Merge    = Consolidate streams / Conflict resolution => ✅ MERGE
Update   = Modify existing (not new, not bug) => ✅ UPDATE
Docs     = Traceability only / Description-only change => ✅ DOCS
Archive  = Move old files / Backup / Deprecated => ✅ ARCHIVE
Release  = Ready for client / Phase delivery => ✅ RELEASE
```

---

## Message Length Guidelines

- **[PROJECT] TYPE: Description** ← 1 line, max 80 chars total
- **First blank line** ← Required separator
- **Detailed body** ← Multiple lines, bullet format preferred
- **Traceability section** ← Starts after body, clearly labeled

**❌ Too Short:**
```
[P07] Update swimlane
```

**✅ Correct:**
```
[P07-PROJECT] Feature: Create App Swimlane Suite (12 files) [Ref: MOM#1-KickOff]

Created 12-swimlane Member App workflow suite based on Figma mockups...
[full details]

Traceability:
- Session: S005
- MOM Reference: MOM#1
- Status: ✓ Ready
```

---

## MOM Reference Standards

**Format Examples:**

| Scenario | Format | Example |
|----------|--------|---------|
| Single MOM | `[Ref: MOM#X]` | `[Ref: MOM#1]` |
| MOM with topic | `[Ref: MOM#X-Topic]` | `[Ref: MOM#1-KickOff]` |
| Multiple MOMs | `[Ref: MOM#X, MOM#Y]` | `[Ref: MOM#1, MOM#2]` |
| Mixed | `[Ref: MOM#X-Topic, MOM#Y]` | `[Ref: MOM#1-Feature, MOM#2]` |
| Range | `[Ref: MOM#X-Y]` | `[Ref: MOM#1-3]` |

**In Body (for detailed reference):**

```
Traceability:
- Session: S005
- MOM Reference: MOM#1 (KickOff with Figma coordination), MOM#2 (Bot feedback rules)
- Activity Log: S005-050, S005-051, S005-merge-001
- Decision: D036 (Swimlane format: original simple, no emoji)
- Status: ✓ Ready for dev handoff
```

---

## Session ID Format

Tracked sequentially per Claude session:

```
Session: S001  ← First session with this project
Session: S005  ← Fifth session with this project
Sessions: S003, S004  ← Multiple sessions contributed to this work
```

**Auto-populated from Activity Log** — Agent logs session ID automatically when tracking activities.

---

## Status Flags

| Flag | Meaning | When to Use |
|------|---------|------------|
| **✓ Ready** | All validation passed, safe to push | Default for completed work |
| **⏳ Pending** | Waiting for upstream merge / approval | If dependent on other work |
| **⚠️ Flagged** | Has caveat / known issue / needs review | If pushing risky changes |
| **🔴 Blocked** | Cannot push, needs resolution | If critical issue detected |

**In Commit:**
```
Status: ✓ Ready for dev handoff
Status: ⏳ Pending UAT approval, holding pending review
Status: ⚠️ Flagged: BOF feedback revision needed (12 action items pending)
```
