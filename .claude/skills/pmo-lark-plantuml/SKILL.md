---
name: Lark PlantUML Standards
description: 11 กฎ mandatory สำหรับเขียน .puml ให้ render ผ่าน Lark Docs + layout สวย — ต้อง load ทุกครั้งที่เขียน/แก้ .puml
---

# PMO Skill: PlantUML Coding Standards for Lark (Strict Mode)

> **Related Skills:** Load this skill whenever writing/editing any `.puml` file.
> Often loaded alongside: `pmo-activity-diagram`, `pmo-use-case-diagram`

> **11 rules below are MANDATORY for every `.puml` file** (SystemFlow, UserFlow, UseCase).
> Rule 1-7: Lark Docs rendering compatibility (strict parser).
> Rule 8-11: Layout quality (ป้องกันเส้นทับกัน, กล่องล้น lane, diagram กว้างเกิน).

---

## Rule 1: FLAT CODE 100% (No Leading Whitespace)

Every line must start at column 0 - no space, tab, or NBSP prefix allowed.

```
' WRONG
    :1. ทำงานแรก;
      note right
        **รายละเอียด**
      end note

' CORRECT
:1. ทำงานแรก;
note right
**รายละเอียด**
end note
```

**Verify:** `grep -c '^[[:space:]]' FILE` must return 0

---

## Rule 2: NO AMPERSAND (`&` -> `and`)

Never use `&` anywhere in the file - PlantUML uses `&` as a parallel operator, causing Lark parser crash when found in text.

```
' WRONG
:2. ตรวจสอบ Session & Authorization;

' CORRECT
:2. ตรวจสอบ Session and Authorization;
```

**Verify:** `grep -c '&' FILE` must return 0

---

## Rule 3: START KEYWORD

Must have `start` after the first Swimlane declaration.

```
' WRONG
|#FCE4EC|Customer|
:1. เข้าหน้า Profile;

' CORRECT
|#FCE4EC|Customer|
start
:1. เข้าหน้า Profile;
```

**Verify:** `grep -c '^start$' FILE` must return >= 1

---

## Rule 4: SINGLE-LINE ACTION (No multi-line `:...;` blocks)

Action block (`:...;`) must not have newlines - use `\n` for wrapping within a single line.

```
' WRONG
:13e. แสดง "กรุณาลองใหม่"
(เหลืออีก {N} ครั้ง);

' CORRECT
:13e. แสดง "กรุณาลองใหม่\n(เหลืออีก {N} ครั้ง)";
```

**Verify:** `grep '^:' FILE | grep -vc ';$'` must return 0

---

## Rule 5: ELSEIF WITH LABEL

Every `elseif` must have a label in `()` after `then`.

```
' WRONG
elseif (แก้ไขที่อยู่) then

' CORRECT
elseif (ต้องการทำอะไร?) then (แก้ไขที่อยู่)
```

**Verify:** `grep -c 'elseif.*then$' FILE` must return 0

---

## Rule 6: NO LEGEND BLOCK (`legend`/`end legend` -> comments)

Do not use `legend right` ... `end legend` - Lark does not support it in Swimlane Activity Diagrams. Convert to comment blocks instead.

```
' WRONG
legend right
  **Cases Covered:**
  ✓ Happy Case: ...
end legend

' CORRECT - place between last stop/endif and @enduml
' ==========================================
' SUMMARY AND TRACEABILITY (Lark-safe comments)
' ==========================================
' Cases Covered (XX-X):
' + Happy Case: ...
' + Alt Case: ...
' + Exception: ...
' ----
' MOM Validation Result (XX-X):
' - Ref: MOM#X - ...
' - Validated Date: YYYY-MM-DD
' - Checklist Result:
' + 1. Requirement Coverage - ...
' + 2. Business Rule - ...
' + 3. Actor ครบ - ...
' + 4. Case ครบ - ...
' + 5. ไม่มีของเกิน - ...
' + 6. Terminology ตรง - ...
' + 7. Phase ถูกต้อง - ...
' - Status: VALIDATED
' ==========================================
```

**Verify:** `grep -c '^legend' FILE` must return 0; `grep -c '^end legend' FILE` must return 0

---

## Rule 7: SAFE ASCII (No special Unicode characters)

Replace Unicode special characters with ASCII equivalents.

**Character Replacement Map:**

| Original | Replacement | Name |
|----------|-------------|------|
| `->` (U+2192) | `->` | Right arrow |
| `--` (U+2014) | `-` | Em dash |
| checkmark (U+2713) | `+` | Check mark |
| ballot X (U+2717) | `x` | Ballot X |
| warning (U+26A0) | `[!]` | Warning sign |
| cross mark (U+274C) | `[X]` | Cross mark |

```
' WRONG
' ✓ 1. Requirement Coverage — ครบทุก FR
' → ปุ่มดำเนินการ

' CORRECT
' + 1. Requirement Coverage - ครบทุก FR
' -> ปุ่มดำเนินการ
```

**Verify:** Each command must return 0:
- `grep -cP '\x{2192}' FILE` (right arrow)
- `grep -cP '\x{2014}' FILE` (em dash)
- `grep -cP '\x{2713}' FILE` (check mark)
- `grep -cP '\x{2717}' FILE` (ballot X)
- `grep -cP '\x{26a0}' FILE` (warning sign)
- `grep -cP '\x{274c}' FILE` (cross mark)

---

## Rule 8: SKINPARAM LAYOUT BLOCK

ทุกไฟล์ `.puml` ต้องมี 3 บรรทัดนี้หลัง `@startuml` เสมอ

```
' CORRECT — ใส่ทันทีหลัง @startuml (ก่อน title)
@startuml
skinparam conditionStyle inside
skinparam ActivityPadding 10
skinparam ActivityFontSize 13
title Module ...
```

**ทำไม:**
- `conditionStyle inside` — เปลี่ยน diamond เป็นกล่องสี่เหลี่ยม ลดพื้นที่แนวนอน ลดเส้นตัดกัน
- `ActivityPadding 10` — เพิ่มระยะห่างระหว่าง elements ไม่ชิดกันเกิน
- `ActivityFontSize 13` — ขนาดอ่านง่ายเมื่อ export PDF

**Verify:** `grep -c 'skinparam conditionStyle inside' FILE` must return >= 1

---

## Rule 9: DETACH FOR DEAD-END BRANCH

ใช้ `detach` แทน `stop` สำหรับ branch ที่จบกลางทาง — ให้ `stop` มีแค่ **1 ตัวสุดท้าย** (happy path end ก่อน `@enduml`)

```
' WRONG — stop กลาง flow ลากเส้นกลับไป merge = เส้นทับกล่อง
if (เงื่อนไข?) then (ผ่าน)
:ทำงานต่อ;
else (ไม่ผ่าน)
:แสดง Error;
stop
endif

' CORRECT — detach ตัดเส้นเลย ไม่ลากกลับ
if (เงื่อนไข?) then (ผ่าน)
:ทำงานต่อ;
else (ไม่ผ่าน)
:แสดง Error;
detach
endif
```

**ทำไม:** `stop` กลาง flow บังคับให้ PlantUML ลากเส้นกลับไปจุด merge → เส้นทับกล่อง/เส้นอื่น (known bug: PlantUML Issue #1040, #2161)

**Verify:** `grep -c '^stop' FILE` must return exactly 1 (the final stop)

---

## Rule 10: MAX 2 ELSEIF PER CHAIN

ถ้า `elseif` มากกว่า 2 ทาง (รวมแล้ว 3+ branches ข้างกัน) → **ต้องเปลี่ยนเป็น sequential if/endif เรียงแนวตั้ง**

```
' WRONG — 4 branches ข้างกันแนวนอน = diagram กว้างยับ อ่านไม่ได้
if (action?) then (A)
:...;
elseif (B) then (B)
:...;
elseif (C) then (C)
:...;
else (D)
:...;
endif

' CORRECT — เรียงแนวตั้ง แต่ละ scenario จบด้วย detach
if (Scenario A?) then (Yes)
:...;
detach
else (No)
endif

if (Scenario B?) then (Yes)
:...;
detach
else (No)
endif

if (Scenario C?) then (Yes)
:...;
detach
else (No)
endif
```

**ทำไม:** PlantUML วาง elseif ทุก branch **ข้างกันแนวนอน** → diagram กว้างจนอ่านไม่ได้เมื่อ export PDF, sequential if เรียงลงล่างแทน

**หมายเหตุ:** `elseif` 1-2 ทาง (2-3 branches) ยังใช้ได้ถ้าแต่ละ branch สั้น (1-3 activities)

---

## Rule 11: TEXT WIDTH MAX 35 CHARS

ข้อความในกล่อง activity ต้องไม่เกิน **~35 ตัวอักษรต่อบรรทัด** — ถ้ายาวกว่าให้ตัดด้วย `\n`

```
' WRONG — กล่องกว้างล้น lane ข้างๆ
:ระบบตรวจสอบข้อมูลและบันทึกผลการทำรายการลงฐานข้อมูล;

' CORRECT — กล่องแคบ สูงขึ้นแต่ไม่ล้น lane
:ระบบตรวจสอบข้อมูล\nและบันทึกผลการทำรายการ\nลงฐานข้อมูล;
```

**ทำไม:** กล่องที่กว้างเกินจะขยายทับ swimlane ข้างเคียง โดยเฉพาะเมื่อ if/else วาง 2 กล่องข้างกัน ตัดเป็นบรรทัดสั้นๆ ทำให้กล่องสูงขึ้นแต่อยู่ใน lane ตัวเอง

---

## Quick Verification Script (All 11 Rules)

```bash
FILE="path/to/file.puml"

echo "=== Lark Rendering (Rule 1-7) ==="
echo "Rule 1 (Flat Code):"          && grep -c '^[[:space:]]' "$FILE" || echo "0"
echo "Rule 2 (No Ampersand):"       && grep -c '&' "$FILE" || echo "0"
echo "Rule 3 (Start Keyword):"      && grep -c '^start$' "$FILE"
echo "Rule 4 (Single-line Action):" && grep '^:' "$FILE" | grep -vc ';$' || echo "0"
echo "Rule 5 (Elseif Label):"       && grep -c 'elseif.*then$' "$FILE" || echo "0"
echo "Rule 6 (No Legend):"          && grep -c '^legend\|^end legend' "$FILE" || echo "0"
echo "Rule 7 (Safe ASCII):"         && grep -cP '[\x{2192}\x{2014}\x{2713}\x{2717}\x{26a0}\x{274c}]' "$FILE" || echo "0"

echo "=== Layout Quality (Rule 8-11) ==="
echo "Rule 8 (Skinparam Block):"     && grep -c 'skinparam conditionStyle inside' "$FILE"
echo "Rule 9 (Stop Count):"         && grep -c '^stop' "$FILE"
echo "Rule 10 (Elseif Chain):"      && awk '/^if /{n=0} /^elseif/{n++} /^endif/{if(n>2)print FILENAME": "n" elseif chain"; n=0}' "$FILE"
```

**Expected:**
- Rule 1,2,4,5,6,7 = 0
- Rule 3 >= 1
- Rule 8 >= 1
- Rule 9 = 1 (exactly one final stop)
- Rule 10 = no output (no chain with 3+ elseif)

---

## Summary Table

| # | Rule | Summary | Applies to | Category |
|---|------|---------|------------|----------|
| 1 | **FLAT CODE 100%** | Every line at column 0 | All lines | Lark Rendering |
| 2 | **NO AMPERSAND** | `&` -> `and` | All lines | Lark Rendering |
| 3 | **START KEYWORD** | Must have `start` after first swimlane | After `\|#...\|Actor\|` | Lark Rendering |
| 4 | **SINGLE-LINE ACTION** | `:...;` on one line, use `\n` | Action blocks | Lark Rendering |
| 5 | **ELSEIF WITH LABEL** | `elseif (cond) then (label)` | `elseif` statements | Lark Rendering |
| 6 | **NO LEGEND BLOCK** | `legend`/`end legend` -> `'` comments | Legend sections | Lark Rendering |
| 7 | **SAFE ASCII** | Replace Unicode with ASCII | All lines | Lark Rendering |
| 8 | **SKINPARAM LAYOUT BLOCK** | 3 skinparam lines after `@startuml` | File header | Layout Quality |
| 9 | **DETACH FOR DEAD-END** | `detach` mid-flow, `stop` only 1 ตัวสุดท้าย | Branch endings | Layout Quality |
| 10 | **MAX 2 ELSEIF** | 3+ branches -> sequential if/endif แนวตั้ง | `elseif` chains | Layout Quality |
| 11 | **TEXT WIDTH MAX 35** | ตัดด้วย `\n` ทุก ~35 ตัวอักษร | Action text | Layout Quality |

> **Origin:**
> - Rule 1-7: Discovered debugging Lark PlantUML rendering failures of 14 SystemFlow files in P01-PROJECT (2026-02-24/25) - Lark uses a stricter parser than standard PlantUML server.
> - Rule 8-11: Discovered fixing layout issues (เส้นทับกล่อง, กล่องล้น lane, diagram กว้างเกิน) in P07-PROJECT 33 SystemFlow files (2026-04-01) - PlantUML Activity Beta has known arrow-crossing bugs (Issue #1040, #2161, #2340).
