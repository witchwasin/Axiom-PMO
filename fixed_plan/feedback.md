# Axiom-PMO — Consolidated Validation Feedback

> เก็บรวบรวมรายงานตรวจสอบจาก AI reviewers (GLM, Skywork) ที่ผู้ใช้ส่งมา
> พร้อมชั้น verify กับโค้ดจริงใน repo (อิง `file:line` ไม่ใช่คาดเดา)
> วันที่รวบรวม: 2026-07-27
> Commit ที่ตรวจ: `c539c3e` (HEAD ของ `main` ตอนที่รายงานเขียน)

ไฟล์นี้คือ **feedback archive** เท่านั้น แผนการปรับแก้อยู่ที่ (ใน repo เดียวกัน):
`fixed_plan/remediation-plan.md`

> หมายเหตุ: ในเอกสารนี้ใช้ placeholder `<HOME>` แทน absolute macOS home path
> (รูปแบบ home-dir-prefix + username + `/Documents/...`) เพื่อไม่ให้ไฟล์นี้เอง
> ชนกฎ `LOCAL-PATH-002` ของ public-hygiene check

---

## 0. Verdict Matrix (verify กับโค้ดจริงแล้ว)

| # | Finding | Verifier | สถานะ | Evidence |
|---|---|---|---|---|
| 1 | absolute macOS home path (`<HOME>/...`) ใน JSON validation report ทำ CI แดง | Skywork | ✅ CONFIRMED — **load-bearing** | 4 ไฟล์ใต้ `Slide Deck/.../validation/` (23 จุด) ชน `LOCAL-PATH-002` ที่ `scripts/check-public-hygiene.ps1:76` |
| A | external evidence (`URL:`/`ISSUE:`/`CI:`) ผ่านเป็น approval evidence | GLM | ✅ CONFIRMED | `approval-validator.ps1:44-50` ดูแค่ `Type`+`Resolved`; `ExternallyUnverified` (computed ที่ `reference-resolver.ps1:50-55`) เป็น dead code |
| B | generic approver ("Dev Team") ผ่าน approval แต่ตก handoff | GLM | ✅ CONFIRMED | `approval-validator.ps1:36` เรียกแค่ `Test-PlaceholderValue`; `Test-GenericOwner` (`handoff-validator.ps1:64-76`) ไม่ถูกเรียกจาก approval |
| C | `FILE:../../` escape project root | Skywork | ✅ CONFIRMED | `reference-resolver.ps1:63-66` ไม่มี canonicalization; regex `^FILE:.+$` รับ `..`/absolute |
| — | GLM: "Lite ทำ external evidence เป็น WARN-blocking" | (GLM sub-claim) | ❌ REFUTED | Lite block (`approval-validator.ps1:62-69`) ก็ผ่านเงียบ ๆ เหมือนกัน — fix ต้องเขียนใหม่ ไม่ copy |
| — | trailing whitespace / `check.sh` 0644 / `@v4` tags / Node 20 / ไม่มี `permissions:` | Skywork | ✅ CONFIRMED (จริง แต่ไม่ใช่ gate ที่ทำแดง) | repo ไม่มี trailing-ws gate ใน CI |
| — | `handoff-validator.ps1` 1229 บรรทัด / shared script scope | Skywork | ✅ CONFIRMED (structural, deferred) | natural split clusters ชัด |
| — | circular approval chain (D) | GLM | ✅ CONFIRMED (ข้อจำกัดทางธรรมชาติ ไม่ใช่ bug ที่แก้ใน code) | governed files agent-writable; validator พิสูจน์ internal consistency ไม่ใช่ authorization |

---

## 1. รายงาน GLM — Bypass Audit (เชิงลึก, verified จริง)

### ข้อ 1: ลง pwsh + รัน demo จริง
ติดตั้ง PowerShell 7.6.4 (portable) แล้วรันจริง — ทำงานได้ตรงตามที่โฆษณา:
- broken-project: 7 FAIL (HANDOFF-003/004×3/007/011/012) ออก exit code 1
- fixed-project: ผ่าน deterministic ทุกข้อ (36 PASS) แต่ "READY TO BUILD, NOT READY TO DEMO" (open blockers HF-005, OA-001) → Score 92/100 (Demo readiness 2/10)
- axiom check (self-check suite) บน macOS/pwsh ผ่านครบ: Lite/Standard/Strict/Handoff E2E + CLI tests 42/42
- meta-test พิสูจน์ว่า CLI ไม่มี validation logic ("CLI does not reimplement validation")

### ข้อ 2: handoff-validator (1230 บรรทัด) — 14 rule, 2 ชั้นชัดเจน
- Deterministic (ตรวจ declared contract) — ไม่ infer domain meaning
- Semantic review (HANDOFF-010) — candidate evidence ไม่ใช่ approval

กลไกเด่น 3 อย่าง:
1. Dual digest stale detection (Source Snapshot + governed artifacts)
2. Closure authority — AI reviewer ห้ามปิด finding ใน human-only lens; ยึด `DEC-###` ใน decision-log ที่มีชื่อคน
3. HANDOFF-004 build-sequence — พิสูจน์ dependency inversion จาก step number

### ข้อ 3: Bypass audit (empirical) — mutate examples/STANDARD-FEATURE แล้วรันจริง

| ทดสอบ | สิ่งที่ปลอม | ผล | ความรุนแรง |
|---|---|---|---|
| A | `URL:https://evil.example/fake` เป็น Release evidence | ✅ ผ่าน 27/27 | 🔴 สูง |
| B | ผู้อนุมัติ = Dev Team (generic) | ✅ ผ่าน 27/27 | 🔴 สูง |
| C (control) | DEC-999 ที่ไม่มีใน decision-log | ❌ FAIL evidence_not_found | (ยืนยัน ref check ทำงาน) |
| D | เพิ่ม DEC-999 ปลอมเข้า decision-log แล้วอ้าง | ✅ ผ่าน 27/27 | 🔴 สูง (circularity) |

**Tier 1 — actionable:**
1. **External reference ผ่านเป็น approval evidence โดยไม่ verify (A)** — `Resolve-Reference` คืน `Resolved=true` ให้ url/issue/ci ทันที; `Test-Approval` เช็คแค่ `$ref.Resolved` ไม่เคยดู `$ref.ExternallyUnverified` (dead code). → Fix: ที่ Release/Strict ให้ external evidence เป็น WARN-blocking และ surface flag ใน diagnostic
   > **verify note:** เคลม "เหมือนที่ Lite ทำ" — **REFUTED**; Lite ไม่ได้ทำ ดังนั้น fix ต้องเขียนใหม่ทุก mode
2. **Generic approver ผ่านที่ approval แต่ตก handoff (B)** — `Test-Approval` ตรวจ Approver แค่ผ่าน `Test-PlaceholderValue` ไม่ใช้ `Test-GenericOwner` เหมือน HANDOFF-003. → Fix: ส่ง approval Approver ผ่าน `Test-GenericOwner`

**Tier 2 — ขีดจำกัดทางโครงสร้าง (code ยอมรับเอง):**
3. Circular approval chain (D) — governed/agent-writable files; validator พิสูจน์ internal consistency ไม่ใช่ human authorization
4. `evidence_status`/`approval_status` เป็น enum ที่ self-declare
5. Mode downgrade ผ่านการแก้ governed files — `Resolve-EffectiveMode` กันแค่ flag `-Mode`

**Tier 3 — Robustness:** regex markdown/table parsing; sensitive scan เช็คชื่อไฟล์อย่างเดียว

**บทสรุป GLM:** รันจริงได้, demo ตรงโฆษณา, self-check ผ่าน, handoff-validator เด่น; ช่องโหว่จริง 2 จุด (A, B) แก้ได้ใน code; Tier-1 อยู่ที่ approval/authority path พอดี — จุดที่ framework อ้างว่าเข้มที่สุด. คะแนน 8.5/10

---

## 2. รายงาน Skywork — Source + CI/Release Readiness

### สถานะทั่วไป
- วิเคราะห์ repo ที่ `HEAD e17e2ca` โดยอ่านโค้ดจริงใน `cli/`, `scripts/`, `scripts/lib/`, `pmo-config/`, tests, CI, agent config — ไม่อาศัย README อย่างเดียว
- ข้อจำกัด runtime: environment นี้ไม่มี `pwsh` จึงรัน validators/test suite ไม่ได้; Node CLI ยืนยันได้ถึงขั้นแสดง help + ตรวจพบ PowerShell หาย (exit 127)

### สถาปัตยกรรม (policy-driven PMO control plane)
- Node CLI (`cli/axiom.mjs`) เป็น thin wrapper — **ไม่มี validation logic ใน JavaScript** (PowerShell เป็น source of truth, กัน implementation drift)
- Exit codes: `0` ผ่าน / `1` FAIL / `2` blocking warning + `-FailOnWarning` / `64` usage / `127` ไม่มี PowerShell
- Workflow: `Source → Requirement → Design → Delivery → Build Review → QA → Release`
- Gates: `Draft → Scope → Design → Handoff → Release`
- Effective mode: ยกระดับได้ ลดระดับเงียบ ๆ ไม่ได้
- Handoff: checking gate ไม่ใช่ approval gate; 2 ชั้น (deterministic + semantic); dual-digest freshness
- Release: rollback/waiver, test summary, RTM chain (Strict)

### ประเด็นคุณภาพ/ความเสี่ยง (จาก source)
- **Important — `FILE:` reference หลุดนอก project root** (`reference-resolver.ps1:63-66`): ไม่มี canonicalization, `FILE:../../...` resolve ได้. integrity/control bypass
- **Important — GitHub task board waived แต่ไม่มี native verification** (`TASK-003`): CI ไม่ได้เรียก GitHub API
- **Important — External evidence ตรวจเพียง syntax** (`Resolved=true` จาก regex match เท่านั้น)
- **Consider — `handoff-validator.ps1` ใหญ่** (~1229 บรรทัด, หลาย concern)
- **Consider — Shared mutable script scope** (dot-source ทุก module, implicit deps)
- **Consider — Platform portability**: Windows PS 5.1 reference; Linux/pwsh experimental (`continue-on-error`)

### CI / Release readiness — **main: NOT READY (4/10)**

ล่าสุด Run `#33` commit `e17e2ca` สถานะ **failure**:
- Windows: Full PMO framework checks ✅ / Public hygiene ❌ / Fault injection skipped (step ก่อนล้ม)
- Linux experimental (pwsh): ✅
- → **validation engine หลักผ่าน แต่ workflow แดงเพราะ repository hygiene**

**Root cause:** commit ล่าสุดเพิ่ม slide-deck validation reports ที่ฝัง absolute macOS home path (`<HOME>/...`):
- `Slide Deck/.../validation/*.json` ในฟิลด์ `target`/`path`/`backup_path`
- `check-public-hygiene.ps1:75-77` reject macOS local home path (home-dir prefix + username = rule `LOCAL-PATH-002`)
- `.gitignore` ไม่มี rule เก็บ `Slide Deck`/`validation/`

**main ยังไม่พร้อม release เพราะ:**
1. Windows required CI แดง
2. Public hygiene ล้ม (absolute local paths)
3. Fault-injection ไม่ได้รัน
4. `git diff --check` ล้ม (trailing whitespace 5 จุดใน SVG)
5. `scripts/check.sh` mode 644 ไม่ executable
6. action versions/runtime deprecation (Node 20 EOL)
7. ไม่มี explicit workflow `permissions:`

Release `v1.1.1` (commit `4b56408`) ผ่านทั้ง Windows + Linux CI ก่อนเผยแพร่ → 8/10

### คะแนน Skywork (static source review): 8.2/10
จุดแข็ง: policy-as-code, deterministic+semantic แยก, dual-digest, ไม่ให้ AI score แทน human approval, mode downgrade protection, test strategy จริงจัง
จุดที่ควรแก้ก่อน 9+: ปิด `FILE:` traversal, GitHub verification จริง, external evidence state ไม่ดูเหมือน verified, split handoff-validator, ลด implicit shared state, ทำ Linux blocking, แก้ absolute paths + whitespace ให้ CI เขียว

---

## 3. Verification layer (ที่เพิ่ม — verify กับโค้ดจริง)

หลักการ: ไม่เชื่อ report ทั้งสองแบบสุดตา ตรวจของจริงก่อนวางแผน

### ที่ CONFIRMED
- **A** (`approval-validator.ps1`): `Test-Approval` ตรวจ `$ref.Type` และ `$ref.Resolved` เท่านั้น (`:44-50`). `ExternallyUnverified` grep ทั้ง repo มีแค่ 2 จุด ใน `reference-resolver.ps1` เอง (`:40` init, `:52` assign) → **dead code จริง**
- **B** (`approval-validator.ps1:36`): ตรวจ approver ด้วย `Test-PlaceholderValue` อย่างเดียว. grep ยืนยัน `Test-GenericOwner` ไม่ถูกเรียกจาก `approval-validator.ps1` หรือ `release-validator.ps1` — มีแค่ใน `handoff-validator.ps1` (8 จุด)
- **C** (`reference-resolver.ps1:63-66`): `$trimmed.Substring(5)` → `Join-Path` → `Test-Path -LiteralPath` ไม่มี canonicalize. grep `GetFullPath`/`[System.IO.Path]`/`Normalize`/`StartsWith` = 0 hits. `-LiteralPath` แค่ suppress wildcard ไม่ได้ confine
- **CI red**: 4 ไฟล์ tracked ใต้ `Slide Deck/axiom_pmo_overview_ppt169_20260726/validation/` มี absolute macOS home path 23 จุด (svg_quality_report 15, first_page 2, 164009.report 3, 160620.report 3). Allowlist ไม่มี entry ปล่อย → `LOCAL-PATH-002` (`:76`) จะ fire + exit 1
- `.gitignore` (2041 bytes) ไม่มี rule `slide`/`validation`/`svg_final`/`svg_output`
- `scripts/check.sh` mode `0644` (ไม่ executable)
- workflow: `actions/checkout@v4`, `setup-node@v4`, Node `'20'`, ไม่มี `permissions:` block, hygiene+fault-injection มีแค่ Windows job

### ที่ REFUTED
- **GLM เคลม "Lite ทำ external evidence เป็น WARN-blocking"** → **ไม่จริง**. Lite branch (`approval-validator.ps1:62-69`) ใช้ `Resolve-Reference` + check เดียวกัน; url/issue/ci ผ่านเงียบ ๆ เหมือนกัน. WARN-blocking ใน Lite ติดแค่ prose/empty evidence ไม่ใช่ external refs

### ที่ปรับขอบเขต (สำคัญต่อการวางแผน)
- **FIX A ต้องเป็น Standard/Strict เท่านั้น**: เพราะ positive fixture `examples/LITE-BUGFIX` และ `tests/fixtures/valid-lite-release-light-approval` ใช้ `ISSUE:` เป็น approval evidence และ `run-all-checks.ps1:67` รัน Lite ด้วย `-FailOnWarning` → ถ้า FAIL ทุก mode จะทำ Lite พัง
- **FIX B ไม่ต้องย้าย module**: `validate-project.ps1:48` dot-source `handoff-validator.ps1` ตลอด (มีแค่การ *call* `Test-HandoffReadiness` ที่ gate-gated) + `$script:handoffPolicy` โหลดที่ `:59` → `Test-GenericOwner` อยู่ใน scope ตอน approval อยู่แล้ว

---

## 4. Findings ที่ผลักไว้ (deferred) + เหตุผล

| Finding | เหตุผลที่ผลัก |
|---|---|
| split `handoff-validator.ps1` | refactor ตัวใหญ่, regression risk สูง, ไม่ใช่ช่องโหว่ |
| เปลี่ยน semantics external reference (`Resolved`→`shape_valid`/`verification_state`) | กระทบ contract กว้าง, ต้องเปลี่ยนหลายจุดพร้อมกัน |
| GitHub-native verification (`TASK-003`) | ต้องมี provider artifact / GitHub API; scope ใหญ่กว่า code fix |
| ทำ Linux/pwsh เป็น blocking platform | ต้อง evidence เพียงพอก่อนเลื่อนจาก experimental |
| Circular approval chain (D) | ข้อจำกัดทางธรรมชาติ — validator พิสูจน์ internal consistency ไม่ใช่ authorization; แก้ที่ process (human-owned source + human commit + release authorization) ไม่ใช่ code |
| `evidence_status`/`approval_status` self-declare enum | เป็น by-design; human review เป็น enforcement จริง |
| Mode downgrade ผ่าน governed file edits | mitigate ด้วย git review |

---

## อ้างอิง helper functions (สำหรับคนทำ fix)

| Function | File:Line | บทบาท |
|---|---|---|
| `Resolve-Reference` | `scripts/lib/reference-resolver.ps1:21-71` | คำนวณ `ExternallyUnverified` + มี bug `FILE:` ที่ `:63-66` |
| `Test-Approval` | `scripts/lib/approval-validator.ps1:12-85` | approval gate; ไม่ดู `ExternallyUnverified` (`:44-50`); approver check ที่ `:36` |
| `Test-GenericOwner` | `scripts/lib/handoff-validator.ps1:64-76` | reject generic owner tokens + placeholder |
| `Test-PlaceholderValue` | `scripts/lib/config-loader.ps1:54-64` | regex-only placeholder check |
| `Test-ReviewRow` (optional companion) | `scripts/lib/release-validator.ps1:22-69` | blind spot external-evidence เหมือนกัน (guard Standard/Strict ที่ `:163`) |

---

*ไฟล์นี้เป็น feedback archive. การปรับแก้ตามรายงานนี้อยู่ในแผนแยกต่างหาก และยังไม่ได้ execute.*
