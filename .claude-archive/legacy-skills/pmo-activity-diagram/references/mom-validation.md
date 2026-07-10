# MOM Validation Workflow and Checklist

> Reference for `pmo-activity-diagram` skill.
> Every diagram must pass MOM validation before becoming Final.

---

## 5-Step Validation Workflow

| Step | Name | Input | Details |
|------|------|-------|---------|
| **Step 1** | **System Flow V1 (REQ)** | `./<ProjectName>/REQ/` | Read REQ only -> create System Flow per feature list. Add `[V1-REQ]` in title |
| **Step 2** | **System Flow V2 (MOM)** | `./<ProjectName>/MOM/` | Read all MOMs -> adjust business rules, exceptions, actors. Add `[V2-MOM]` in title |
| **Step 3** | **Additional Inputs** | `./<ProjectName>/Others/` + user | Check Others/ folder + ask user: "Any additional inputs?" Adjust per additional data |
| **Step 4** | **Final System Flow** | All inputs | Run 20-item case checklist + 7-item MOM checklist -> remove prefix from title |
| **Step 5** | **User Flow** | System Flow (Final) | Derive from Final System Flow -> focus on user-visible actions + important logic + conditions affecting flow |

### Step Details

**Step 1: System Flow V1 (REQ)**
1. Read files from `./<ProjectName>/REQ/` - check requirements for the module
2. Create System Flow per requirements - all actors, error handling, audit log, technical terms
3. Add `[V1-REQ]` in title: `title [V1-REQ] Module XX-A: Workflow Name`

**Step 2: System Flow V2 (MOM)**
1. Read all MOM files from `./<ProjectName>/MOM/` - use latest as primary
2. Adjust System Flow per business rules, exception cases, actors from MOM
3. Change title to `[V2-MOM]`: `title [V2-MOM] Module XX-A: Workflow Name [Ref: MOM#X - Topic]`

**Step 3: Additional Inputs**
1. Check `./<ProjectName>/Others/` folder for additional files (CI, Project Plan, Design specs)
2. Ask user: "Any additional inputs beyond MOM/REQ?"
3. Adjust System Flow per additional data (if any)

**Step 4: Final System Flow**
1. Run **20-item Case Analysis Checklist** - verify all cases covered
2. Run **7-item MOM Validation Checklist** - verify matches MOM
3. Remove prefix from title -> Final version
4. Add validation result note at end of diagram
5. Save in `./<ProjectName>/SystemFlow/`

**Step 5: User Flow**
1. **Derive from Final System Flow** - not created from scratch
2. Reduce technical detail: combine Backend/Scheduler/3rd Party into "System" lane
3. **Must keep important logic:**
   - Decision points affecting next actions
   - Business conditions client must know and decide
   - Results of each choice affecting subsequent flow
4. Use business language, not technical jargon
5. Save in `./<ProjectName>/UserFlow/`

---

## MOM Validation Checklist (7 Items)

| # | Category | Cross-check Question | Pass/Fail |
|---|---------|---------------------|-----------|
| 1 | **Requirement Coverage** | Every Functional Requirement/Feature in MOM covered in diagram? Nothing missing? | + / x |
| 2 | **Business Rule** | Business conditions, work sequence, access rights match MOM? | + / x |
| 3 | **Actor Complete** | Every Role/Actor/System mentioned in MOM appears in Swimlane? None missing? | + / x |
| 4 | **Case Complete** | Happy/Alternative/Exception cases from MOM all covered? | + / x |
| 5 | **No Gold Plating** | Diagram doesn't include Features/Steps/Logic not agreed in MOM? No assumed requirements? | + / x |
| 6 | **Terminology Match** | Terms, Feature names, Status names, Field names match MOM exactly? | + / x |
| 7 | **Priority/Phase Correct** | Diagram is within agreed Scope/Phase? No features from other phases mixed in? | + / x |

### How to Use

1. Read MOM files from `./<ProjectName>/MOM/` referenced (MOM#X) - use latest as primary
2. Read REQ files from `./<ProjectName>/REQ/` to compare requirement list
3. Check each item (1-7) comparing diagram to MOM and REQ content
4. Summarize:
   - **All pass** -> proceed to Step 4 (Final Flow)
   - **Some fail** -> identify gaps and fix diagram or ask user to clarify
5. Record validation result in note at end of diagram

### Validation Result Note Format (as Lark-safe comments)

```
' ==========================================
' MOM Validation Result (XX-X):
' - Ref: MOM#X - {Topic}
' - Validated Date: YYYY-MM-DD
' - Checklist Result:
' + 1. Requirement Coverage - All FRs covered
' + 2. Business Rule - Conditions match MOM
' + 3. Actor Complete - {Actor list}
' + 4. Case Complete - Happy + N Alt + N Exception
' + 5. No Gold Plating - None
' + 6. Terminology Match - Uses MOM terms
' + 7. Phase Correct - Phase N Scope
' - Status: VALIDATED
' ==========================================
```

**If gaps found:**

```
' - Status: GAP FOUND - must fix items 2, 4
' - Action Required:
' -> {Fix item 1}
' -> {Fix item 2}
```
