---
name: Verification Evidence Protocol
description: เก็บหลักฐาน (evidence) ก่อนปิด task — build pass, test pass, lint clean, review approved — เสริม quality gate ให้แข็งแกร่ง
---

# Verification Evidence Protocol

> ไม่มีหลักฐาน = ไม่ผ่าน — ทุก task ต้องมี structured evidence ก่อนปิด

## เมื่อไหร่ใช้

- ก่อนเปลี่ยน Card status เป็น "Dev Done" หรือ "QA Passed"
- ก่อน handoff (PM→Dev, Dev→QA, QA→PM)
- ก่อน phase gate transition
- ก่อน deploy / go-live
- เมื่อ user ถาม "เสร็จจริงหรือเปล่า?"

## Evidence Types (7 ประเภท)

| # | Type | วิธีเก็บ | Required When |
|---|------|---------|---------------|
| 1 | **build_success** | Run build command, capture output | Dev Done, Deploy |
| 2 | **test_pass** | Run test suite, capture pass/fail count | Dev Done, QA Pass |
| 3 | **lint_clean** | Run linter, capture 0 errors | Dev Done |
| 4 | **functionality_verified** | Manual/visual verification description | QA Pass, Deploy |
| 5 | **review_approved** | Code review verdict + reviewer identity | Dev Done, Handoff |
| 6 | **todo_complete** | Zero pending/in-progress tasks | Phase Gate |
| 7 | **error_free** | No unaddressed errors remain | Deploy |

## Evidence Record Format

```json
{
  "evidenceId": "EVD-{cardId}-{timestamp}",
  "cardId": "CARD-{module}-{N}",
  "collectedAt": "2026-04-16T10:30:00+07:00",
  "collectedBy": "agent|human",
  "tier": "LIGHT|STANDARD|THOROUGH",
  "checks": [
    {
      "type": "build_success",
      "status": "PASS|FAIL|SKIP|PENDING",
      "command": "npm run build",
      "output": "Build completed in 12.3s, 0 errors",
      "timestamp": "2026-04-16T10:30:05+07:00"
    },
    {
      "type": "test_pass",
      "status": "PASS",
      "command": "npm test",
      "output": "Tests: 45 passed, 0 failed",
      "details": {
        "total": 45,
        "passed": 45,
        "failed": 0,
        "skipped": 0,
        "coverage": {
          "line": 82,
          "branch": 71,
          "function": 90
        }
      },
      "timestamp": "2026-04-16T10:30:15+07:00"
    }
  ],
  "verdict": "APPROVED|REJECTED|INCOMPLETE",
  "notes": "Optional notes"
}
```

## Verification Tiers

ระดับความเข้มงวดตาม complexity ของงาน:

### LIGHT Tier
**เมื่อไหร่:** งานเล็ก (<5 files, <100 lines, มี test ครอบคลุมอยู่แล้ว)
**Evidence ที่ต้องการ:**
- ☐ lint_clean
- ☐ test_pass (เฉพาะ related tests)

### STANDARD Tier (Default)
**เมื่อไหร่:** งานทั่วไป
**Evidence ที่ต้องการ:**
- ☐ build_success
- ☐ test_pass (full suite)
- ☐ lint_clean
- ☐ functionality_verified

### THOROUGH Tier
**เมื่อไหร่:** งานใหญ่ (>20 files), security-related, architecture change, database migration
**Evidence ที่ต้องการ:**
- ☐ build_success
- ☐ test_pass (full suite + coverage check)
- ☐ lint_clean
- ☐ functionality_verified (detailed scenarios)
- ☐ review_approved (reviewer must be specified)
- ☐ error_free (full error scan)
- ☐ todo_complete

### Tier Auto-Selection

```
IF security-related files changed → THOROUGH
ELIF architecture files changed (config, schema, types) → THOROUGH
ELIF >20 files changed → THOROUGH
ELIF <5 files AND <100 lines → LIGHT
ELSE → STANDARD
```

## Verification Flow

```
Task Complete Claimed
       │
       ▼
┌──────────────┐
│ Select Tier  │ (auto or manual)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Collect      │ Run commands, capture output
│ Evidence     │ Per check type
└──────┬───────┘
       │
       ▼
┌──────────────┐     FAIL      ┌──────────────┐
│ Evaluate     │──────────────→│ Report Issues │
│ All Checks   │               │ + Continue    │
└──────┬───────┘               └───────┬───────┘
       │ ALL PASS                      │
       ▼                               ▼
┌──────────────┐               ┌──────────────┐
│ Generate     │               │ Fix & Re-run │
│ Evidence     │               │ (max 3 rounds)│
│ Record       │               └──────────────┘
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Log to       │
│ Traceability │
└──────┬───────┘
       │
       ▼
  Card Status Updated
```

## Verdict Rules

| Condition | Verdict |
|-----------|---------|
| ทุก required check = PASS | **APPROVED** ✅ |
| มี check ที่ FAIL | **REJECTED** ❌ |
| มี check ที่ PENDING (รอ manual) | **INCOMPLETE** ⏳ |
| FAIL + retry > 3 rounds | **ESCALATE** ⚠️ → แจ้ง user |

## Evidence Validation

หลักฐานต้องผ่าน validation:

1. **Freshness:** ต้องเก็บภายใน 5 นาที (>5 นาที = stale, ต้องเก็บใหม่)
2. **Completeness:** ทุก required check ต้องมี evidence
3. **Consistency:** ผล test ต้องตรงกับ build result
4. **Authenticity:** evidence ต้องมา command output จริง ไม่ใช่เขียนเอง

## Integration กับ PMO Skills ที่มี

### กับ pmo-quality-gate
- Quality Gate ตรวจ "output ดีไหม" (คะแนน 0-1)
- Evidence Protocol ตรวจ "มีหลักฐานครบไหม" (checklist)
- **ใช้ร่วมกัน:** Quality Gate PASS + Evidence APPROVED = ผ่านจริง

### กับ pmo-taskboard
- Card status "Dev Done" → ต้องมี Evidence Record (STANDARD tier ขึ้นไป)
- Card status "QA Passed" → ต้องมี Evidence Record + test_pass + functionality_verified
- Evidence Record บันทึกที่ `{project}/Evidence/EVD-{cardId}.json`

### กับ pmo-handoff-protocol
- ทุก handoff ต้องแนบ Evidence Record
- PM→Dev: ไม่ต้อง evidence (ยังไม่มีงาน)
- Dev→QA: ต้องมี build_success + test_pass + lint_clean
- QA→PM: ต้องมี test_pass + functionality_verified
- PM→DevOps: ต้องมี THOROUGH tier evidence ครบ

### กับ pmo-dev-report
- Dev report ต้องแนบ Evidence Record
- AI code review = review_approved evidence
- Coverage data = test_pass evidence details

### กับ pmo-phase-gate
- Phase transition ต้องมี Evidence Record tier THOROUGH
- ทุก card ใน phase ต้อง APPROVED ก่อนจะ advance

## Output: Evidence Summary

```markdown
## Evidence Summary — {Card ID}

**Tier:** STANDARD
**Verdict:** APPROVED ✅
**Collected:** 2026-04-16 10:30 ICT

| Check | Status | Details |
|-------|--------|---------|
| build_success | ✅ PASS | Build completed, 0 errors |
| test_pass | ✅ PASS | 45/45 passed, coverage: L82% B71% F90% |
| lint_clean | ✅ PASS | 0 errors, 0 warnings |
| functionality_verified | ✅ PASS | Login flow, dashboard, CRUD tested |

**Evidence ID:** EVD-CARD-AUTH-001-20260416
```

## Storage

```
{project}/
  Evidence/
    EVD-CARD-AUTH-001-20260416.json
    EVD-CARD-DASH-002-20260416.json
    ...
```
