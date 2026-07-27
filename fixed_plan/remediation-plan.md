# แผนปรับแก้ Axiom-PMO ตาม Feedback (PLAN — ยังไม่ได้ execute โค้ด)

> **ไฟล์นี้คือสำเนาใน repo** ของแผนที่ผลิตเมื่อ 2026-07-27
> (ต้นฉบับ session อยู่นอก repo ใน `~/.claude/plans/` — สำเนาใน repo นี้แหละที่ใช้ส่งต่อ)
> ข้อมูลเข้า: `fixed_plan/feedback.md` (feedback archive)
> สถานะโดยรวม: **เป็นแผนเท่านั้น ยังไม่ได้แก้โค้ด/CI ใด ๆ** — รอผู้ลงมือ
>
> หมายเหตุ: ใช้ placeholder `<HOME>` แทน absolute macOS home path เพื่อไม่ให้ไฟล์นี้เองชน `LOCAL-PATH-002`

---

## Context / เหตุผล

หลังจากให้ AI หลายตัว (GLM, Skywork) ตรวจสอบ Axiom-PMO แบบเชิงลึก พบปัญหา 2 ระดับ:

1. **`main` ปล่อยไม่ได้** — CI แดงเพราะ commit ล่าสุดนำ JSON validation report ที่ฝัง absolute macOS home path (`<HOME>/...`) เข้า repo ชนกฎ `LOCAL-PATH-002` ของ public-hygiene check
2. **ช่องโหว่จริง 3 จุดบน authority path** — จุดที่ framework อ้างว่าเข้มที่สุดกลับอ่อนที่สุด:
   - **A.** evidence แบบ external (`URL:`/`ISSUE:`/`CI:`) ผ่านเป็นหลักฐานอนุมัติ release โดยไม่มีใครตรวจ (flag `ExternallyUnverified` คำนวณไว้แต่เป็น dead code)
   - **B.** approver แบบกลุ่ม ("Dev Team", "Engineering") ผ่านที่ approval gate ทั้งที่ชื่อเดียวกันถูกห้ามที่ handoff
   - **C.** `FILE:../../...` อ้างไฟล์นอก project root ได้ (path traversal)

ทั้ง 3 จุด **verify กับของจริงในโค้ดแล้ว เป็นจริงทั้งหมด** (ไม่ใช่การคาดเดาจาก report)

ผลลัพธ์ที่ต้องการ: (1) เก็บ feedback ไว้เป็นหลักฐาน, (2) ทำให้ `main` ปล่อยได้, (3) ปิดช่องโหว่ A/B/C พร้อม regression test ตามรูปแบบเดิมของ repo — **โดยยังไม่ refactor ตัวใหญ่** เพื่อลด regression risk

---

## ขอบเขต (ตามที่เจ้าของ repo เลือก)

- ✅ **ในแผน:** ทำ CI เขียว + ปิด A/B/C + quick wins + regression tests
- ⏸️ **ผลักไว้ (deferred):** split `handoff-validator.ps1`, เปลี่ยน semantics external evidence เป็น `shape_valid`/`verification_state`, GitHub-native verification, ทำ Linux/pwsh เป็น blocking platform, แก้ circular-approval (ข้อจำกัดทางธรรมชาติที่ต้องแก้ที่ process ไม่ใช่ code)

---

## Deliverable 0 — เก็บ Feedback ✅ DONE

- `fixed_plan/feedback.md` — **สร้างแล้ว** (commit `108bc3b`) รวม: บทสรุปผู้รีวิว 2 ชุด, ตาราง verification verdict (`file:line`), หมายเหตุที่ REFUTED (เคลม "Lite WARN-blocking" ไม่จริง), รายการ deferred

---

## Phase 1 — ทำให้ CI เขียว / `main` ปล่อยได้

### 1.1 ล้าง absolute path (Root cause ที่ทำ CI แดง — verified)
- **4 ไฟล์** ใต้ `Slide Deck/axiom_pmo_overview_ppt169_20260726/validation/`:
  - `svg_quality_report.json` (15 จุด)
  - `svg_quality_first_page_report.json` (2 จุด)
  - `axiom_pmo_overview_20260726_164009.report.json` (3 จุด)
  - `axiom_pmo_overview_20260726_160620.report.json` (3 จุด)
- **วิธี (ตามที่เจ้าของเลือก):** เปลี่ยน `<HOME>/Documents/.../Axiom-PMO/<rest>` → `<rest>` (relative) ในฟิลด์ `target` / `path` / `backup_path` — **เก็บไฟล์ไว้** ไม่ untrack
- ผล: `LOCAL-PATH-002` (`scripts/check-public-hygiene.ps1:76`) จะไม่ trigger อีก

### 1.2 Quick wins (verified จริง แต่ไม่ใช่ gate ที่ทำแดง — แก้พร้อมกันไป)
- **Trailing whitespace** 5 บรรทัดใน SVG (verified):
  - `svg_final/04_prompt_is_not_a_control.svg:12`
  - `svg_final/09_human_authority.svg:31`
  - `svg_final/11_two_layers.svg:14` และ `:37`
  - `svg_final/13_readiness_and_score.svg:32`
- **`scripts/check.sh`**: `chmod +x` (ปัจจุบัน mode `0644`, shebang `#!/usr/bin/env bash` แสดงว่าตั้งใจให้ executable)

### 1.3 Workflow hardening (optional — ความเสี่ยงต่ำ แยก commit ได้)
- `.github/workflows/pmo-checks.yml`: ตั้ง `permissions:` block (least privilege), ยก `setup-node` จาก Node `20` (EOL เม.ย. 2026) เป็นเวอร์ชันที่รองรับ, พิจารณา pin action ด้วย commit SHA แทน `@v4`

---

## Phase 2 — ปิดช่องโหว่ Authority (A/B/C) พร้อม regression test

หลักการ: ทุก diagnostic ใหม่ต้องมี rule_id ใน `pmo-config/validation-rules.json` + `suggestion` + `docs/rules/<RULE>.md` (enforced โดย `diagnostics-contract-tests.ps1`, `DOCTOR-007/008/009`) และต้องมี negative fixture + golden

### Step 2.0 — Shared setup (ทำก่อน, ตอนที่ยังไม่มี emitter เพื่อให้ doctor ผ่าน)
เพิ่ม rule 3 ตัวใน `pmo-config/validation-rules.json` + สร้าง doc 3 ไฟล์:

| rule_id | severity | ความหมาย |
|---|---|---|
| `APPROVAL-004` | `fail` | external/unverified evidence ห้ามใช้เป็นหลักฐานอนุมัติ (Standard/Strict) |
| `APPROVAL-005` | ตาม `owner_policy.severity_by_mode` | approver เป็นกลุ่ม generic ("Dev Team" ฯลฯ) |
| `REF-002` | `fail` (หรือ `fail_release`) | `FILE:` reference ออกนอก project root (containment breach) |

ไฟล์ doc: `docs/rules/APPROVAL-004.md`, `APPROVAL-005.md`, `REF-002.md`

> หมายเหตุ: ยืนยัน severity token ตรงกับ enum ที่ใช้ในแคตตาล็อกเดิมตอน execute

### Step 2.1 — FIX C: ปิด `FILE:` path traversal
**ไฟล์:** `scripts/lib/reference-resolver.ps1` `"file"` branch (lines 63-66)
- เพิ่มฟิลด์ `PathEscaped = $false` ใน result object (~lines 36-41)
- ใน branch `file`:
  1. reject absolute path (`^[/\\]` หรือ `^[A-Za-z]:`) เลย
  2. `Join-Path $ProjectRoot $filePath`
  3. canonicalize ทั้ง resolved path และ project root ด้วย `[System.IO.Path]::GetFullPath` (รองรับ PS 5.1 + pwsh 7 เพราะ path ที่ join แล้วเป็น absolute ของ host ไม่มีปัญหา unix-on-Windows)
  4. containment check: resolved ต้องเท่ากับ root หรือขึ้นต้นด้วย root + separator
  5. escape → ตั้ง `PathEscaped = $true`, `Resolved = $false`
- **เหตุผล severity:** ใช้ rule ใหม่ `REF-002` ไม่ใช่ `evidence_not_found` เพราะ path มีอยู่จริงแต่อยู่นอกขอบเขต เป็น containment breach ไม่ใช่ not-found

### Step 2.2 — FIX A: external evidence ห้ามผ่าน approval
**ไฟล์:** `scripts/lib/approval-validator.ps1` ใน `Test-Approval` (block Standard/Strict, หลัง check PathEscaped ~line 44)
- เพิ่ม: `if ($ref.ExternallyUnverified) { Add-Result FAIL "APPROVAL-004"; return }`
- **สำคัญ:** ทำเฉพาะ block Standard/Strict เท่านั้น — **ห้ามแตะ Lite block** (`approval-validator.ps1:62-69`) เพราะ positive fixture `examples/LITE-BUGFIX` และ `tests/fixtures/valid-lite-release-light-approval` ใช้ `ISSUE:` เป็น approval evidence (และ `run-all-checks.ps1:67` รัน Lite ด้วย `-FailOnWarning`)

### Step 2.3 — FIX B: generic approver ห้ามผ่าน approval
**ไฟล์:** `scripts/lib/approval-validator.ps1` (~line 36, หลัง check `Test-PlaceholderValue`)
- เพิ่ม: ถ้าผ่าน placeholder แล้ว ให้ routing ผ่าน `Test-GenericOwner -Value $approver -OwnerPolicy $script:handoffPolicy.owner_policy`
- **ไม่ต้องย้าย module** — verify แล้วว่า `validate-project.ps1:48` dot-source `handoff-validator.ps1` ตลอด (มีแค่การ *call* `Test-HandoffReadiness` เท่านั้นที่ gate-gated) และ `$script:handoffPolicy` โหลดที่ `validate-project.ps1:59`
- severity ตาม `owner_policy.severity_by_mode` (เหมือน `HANDOFF-003` ที่ใช้ generic_tokens ชุดเดียวกัน) — WARN-blocking ที่ Lite, FAIL ที่ Standard/Strict

### Step 2.4 (optional companion) — `Test-ReviewRow`
`scripts/lib/release-validator.ps1:22-69` มี blind spot external-evidence เหมือนกัน (มี guard Standard/Strict ที่ line 163) → เพิ่ม check เดียวกัน (`APPROVAL-004`) เป็น optional ในแผนนี้

### Step 2.5 — Regression tests (ตามรูปแบบเดิมของ repo)
- **Negative fixtures** (full project tree ใต้ `tests/fixtures/`):
  - `invalid-approval-external-evidence/` — Evidence = `URL:https://evil.example/...` → expect `APPROVAL-004` FAIL
  - `invalid-approval-generic-approver/` — Approver = `Dev Team` → expect `APPROVAL-005`
  - `invalid-approval-file-ref-escape/` — Evidence = `FILE:../../<ไฟล์ที่มีอยู่จริง>` → expect `REF-002`
- **Golden cases:** เพิ่ม 3 แถวใน `$cases` ของ `scripts/run-validation-tests.ps1` (`Type=negative`, `ShouldPass=$false`, `Rule=...`, `ExpectedLevel=FAIL`, กำหนด `AllowedSecondaryRules`) แล้ว capture ด้วย `-CaptureGolden` → commit `tests/golden/<Name>.txt`
- **(optional) config-mutation test** ใน `tests/helpers/config-mutation-tests.ps1` สำหรับ generic_tokens

---

## ลำดับการทำ (lowest regression risk first)

1. ✅ Deliverable 0: `fixed_plan/feedback.md` (done)
2. Phase 1.1 + 1.2 (CI green)
3. Phase 2.0 (register rules + docs — ทำให้ doctor ผ่านก่อนมี emitter)
4. Phase 2.1 FIX C → re-capture goldens
5. Phase 2.2 FIX A → re-capture goldens
6. Phase 2.3 FIX B → re-capture goldens (+ optional mutation test)
7. Phase 1.3 workflow hardening (แยก commit)

---

## รายการไฟล์ทั้งหมด (create / modify)

**Create:**
- `docs/rules/APPROVAL-004.md`, `docs/rules/APPROVAL-005.md`, `docs/rules/REF-002.md`
- `tests/fixtures/invalid-approval-external-evidence/` (project tree)
- `tests/fixtures/invalid-approval-generic-approver/` (project tree)
- `tests/fixtures/invalid-approval-file-ref-escape/` (project tree)
- `tests/golden/<3 ไฟล์>.txt` (จาก -CaptureGolden)

**Modify:**
- 4 ไฟล์ JSON ใต้ `Slide Deck/.../validation/` (ล้าง path)
- 5 บรรทัด SVG (trailing ws)
- `scripts/check.sh` (chmod — เป็น git mode change)
- `scripts/lib/reference-resolver.ps1` (FIX C)
- `scripts/lib/approval-validator.ps1` (FIX A + B)
- `pmo-config/validation-rules.json` (เพิ่ม 3 rules)
- `scripts/run-validation-tests.ps1` (เพิ่ม 3 cases)
- `.github/workflows/pmo-checks.yml` (optional hardening)
- *(optional)* `scripts/lib/release-validator.ps1` (`Test-ReviewRow`)

**อ้างอิง (read-only):** `scripts/lib/handoff-validator.ps1:64-76` (`Test-GenericOwner` + `owner_policy`), `scripts/lib/config-loader.ps1:54-64` (`Test-PlaceholderValue`)

---

## Verification (หลัง execute — ต้องมี `pwsh` บน PATH)

1. `pwsh -File scripts/pmo-doctor.ps1 -RepoPath .` — catalog/doc แข็งแรง (หลัง Step 2.0)
2. `pwsh -File scripts/check-public-hygiene.ps1 -RepoPath .` — `LOCAL-PATH-002` ไม่ trigger อีก
3. `pwsh -File scripts/run-validation-tests.ps1 -RepoPath . -VerifyGolden` — golden ครบ
4. `pwsh -File scripts/run-all-checks.ps1 -RepoPath .` — suite เต็ม (config-mutation, diagnostics-contract, examples ด้วย `-FailOnWarning`)
5. `git diff --check` — ไม่มี trailing whitespace
6. **Manual bypass-audit re-run** (ทำซ้ำการทดสอบของ GLM): ใน temp copy ของ `examples/STANDARD-FEATURE` mutate Release Approved row เป็น `URL:https://...` (expect `APPROVAL-004`), `Dev Team` (expect `APPROVAL-005`), `FILE:../../<exists>` (expect `REF-002`) — ทั้งสามต้อง FAIL
7. ยืนยัน `examples/LITE-BUGFIX` ยังผ่าน (FIX A ไม่กระทบ Lite)
8. เปิด CI บน `main` ดู Windows required job เขียว + fault-injection step รัน

> ถ้าเครื่องไม่มี `pwsh`: CLI จะคืน exit `127` (เหมือนที่ Skywork/GLM เจอ) — ต้องติดตั้ง PowerShell 7 (GLM ยืนยันว่า portable tar.gz บน macOS ใช้ได้) ก่อนรัน

---

## สิ่งที่ผลักไว้ (deferred — นอกขอบเขตที่เลือก)

- split `handoff-validator.ps1` (1229 บรรทัด, 27 functions) เป็น modules ย่อย
- เปลี่ยน semantics external reference จาก `Resolved=true` เป็น `shape_valid`/`verification_state=external_unverified`
- GitHub-native verification สำหรับ task source (ปัจจุบัน waive `DELIVERY.md` ด้วย `TASK-003` non-blocking)
- ทำ Linux/pwsh เป็น blocking platform (ปัจจุบัน `continue-on-error: true`)
- circular approval chain (D) — ข้อจำกัดทางธรรมชาติ: validator พิสูจน์ internal consistency ไม่ใช่ human authorization; ต้องแก้ที่ process (human-owned source + human commit + release authorization) ไม่ใช่ที่ code
