# M5 Plan — Execution Contract Verification MVP

> เขียน 2026-07-30 สรุปจากการตอบกลับของ Independent AI Reviewer (คะแนน 9.1/10 ต่อร่างที่ Claude
> เสนอ พร้อมข้อปรับ 6 จุด + gap 2 เรื่อง) นี่คือ**เอกสารสำหรับพิจารณา ไม่ใช่
> คำสั่งให้เริ่มทำ** — รอ Human Owner ตัดสินใจก่อนเริ่ม M5.0 จริง ไม่มีโค้ด
> ถูกแก้จากเอกสารนี้

**สถานะ M4.5 ณ ตอนเขียน:** 2 MAJOR + 3 MINOR ที่ Independent AI Reviewer พบถูกแก้แล้วใน commit
`7d2358b89882871b1300d2c711315f2217a8ddbb` บน branch `m4.5-scope-diff`
(ยืนยันด้วย `git cat-file`, ไม่ใช่แค่เชื่อคำอ้างของ Independent AI Reviewer) — CI กำลังรันอยู่
(`dogfood-scope-diff`, `dogfood-github-action` เขียวแล้ว, อีก 4 jobs
in progress ตอนเขียนเอกสารนี้) หมายเหตุ: commit นี้เกิดจากอีก session หนึ่ง
ไม่ใช่ session นี้ — ต้องรอ CI เขียวครบก่อนถึงจะถือว่า M4.5 พร้อมปิดจริง

---

## 1. ชื่อ milestone ควรเปลี่ยน

Independent AI Reviewer เสนอ (และผมเห็นด้วย): เปลี่ยนจาก

```
Milestone 5 — Superpowers Runtime Bridge
```

เป็น

```
Milestone 5 — Execution Contract Verification MVP
```

เหตุผล: Superpowers ไม่มี native integration surface ที่ verify ได้ (ดู §2)
ถ้าตั้งชื่อ milestone ผูกกับ Superpowers จะทำให้เข้าใจผิดว่ามันคือ technical
bridge เฉพาะ ทั้งที่ของจริงคือ **contract verification engine ที่ใช้ได้กับ
execution workflow ไหนก็ได้ที่ยอมรับ JSON contract แบบเดียวกัน**
Superpowers เป็นแค่ *reference execution workflow* ตัวแรกที่เอามาทดสอบ
concept ไม่ใช่สิ่งที่ผูกทางเทคนิคกัน

ข้อควรระวังที่ Independent AI Reviewer เตือนไว้: การเปลี่ยนชื่อ **ต้องไม่กลายเป็นการสร้าง
normalized IR ใหญ่โต** ที่เคยตกลงกันแล้วว่าไม่ทำ — MVP ยังคงมี schema เดียว
integration เดียว ใช้คำว่า "Superpowers-compatible execution workflow"
ไม่ใช่ "Superpowers native runtime integration"

---

## 2. ปรับถ้อยคำเรื่อง Superpowers (จากที่ตรวจ repo จริง)

ข้อสรุปที่ผมเช็คจาก repo `superpowers` จริง (ไม่มี hook รับ/ส่ง JSON, มีแค่
`SessionStart`) **ถูกต้องทาง architecture** — Independent AI Reviewer ยืนยันตรงนี้ แต่ขอให้เปลี่ยน
คำพูดให้แม่นขึ้น เพราะประโยคเดิม "Superpowers รับไฟล์ไม่ได้เลย" แรงเกินจริง
และจะโดนแย้งง่ายด้วยคำว่า "Claude อ่าน JSON ได้อยู่แล้ว"

**คำที่แม่นกว่า:**

> Superpowers ไม่มี native, machine-verifiable contract ingestion/result
> emission surface ที่ Axiom สามารถพึ่งพาเป็น trusted integration boundary
> ได้

แยกสามชั้นให้ชัด:
- **อ่านไฟล์ได้** — เพราะ agent/tool environment (Claude Code) อ่านได้อยู่แล้ว
- **มี integration contract** — ไม่ได้แปลว่ามี แค่มี "agent ที่รู้จัก JSON"
- **ส่งผลลัพธ์ที่เชื่อถือได้** — ยิ่งไม่มี เพราะไม่มี protocol บังคับ

---

## 3. Core design: result = claim, ไม่ใช่ evidence (แกนหลักของแผน)

Independent AI Reviewer เห็นด้วยเต็มที่กับหลักการนี้ และเสนอโมเดลสามชั้นที่ชัดกว่าที่ผมเสนอไป:

```
Agent claim → Axiom-observed evidence → Human authority
```

| ข้อมูล | สถานะ |
|---|---|
| Agent บอกว่ารัน test แล้ว | Claim |
| JUnit XML หรือเครื่องมือ test สร้าง artifact จริง | Observed evidence |
| CI job ที่ผูกกับ commit SHA ผ่าน | Stronger observed evidence |
| Human บอกว่ายอมรับงาน | Human authority |

`EXECUTION-RESULT.json` ที่ agent เขียนเองต้องเข้ามาพร้อม field ระบุสถานะ
ตัวเองตั้งแต่แรก ไม่ใช่ปล่อยให้ระบบสมมติว่ามันคือความจริง:

```json
{
  "evidence_origin": "agent-claimed",
  "verification_status": "unverified"
}
```

แล้ว Axiom ค่อย enrich ด้วยสิ่งที่ตรวจได้จริงจาก ground truth:

```json
{
  "evidence_origin": "git-observed",
  "verification_status": "verified",
  "observed_head_sha": "abc123..."
}
```

### 3.1 ข้อจำกัดสำคัญ — เรื่อง "ไม่ได้ push"

ข้อเสนอเดิมของผมที่ว่า "ตรวจ `git reflog` / remote-tracking ref เพื่อพิสูจน์
ว่าไม่ได้ push" **ต้องแก้** เพราะ Independent AI Reviewer ชี้ถูกว่า local repo state พิสูจน์การ
"ไม่มี push เกิดขึ้น" แบบสมบูรณ์ไม่ได้เลย — เหตุผล:

- push ไป remote อื่นที่ checkout ปัจจุบันไม่รู้จัก
- push แล้ว remote ref ถูก force-move
- push ไป branch แล้วลบ branch
- local remote-tracking refs ยังไม่ได้ fetch
- reflog เป็น local state ไม่ใช่ remote audit log
- runner อาจเริ่มทำงานหลังจาก push เกิดขึ้นแล้ว

**ถ้อยคำที่ต้องใช้ใน MVP:**

> Axiom verifies observable Git claims within the available repository and
> remote context. It does not prove the absence of all external Git side
> effects.

สิ่งที่ตรวจได้จริง: SHA resolve ได้, commit เป็น descendant ของ base หรือไม่,
head tree ตรงกับที่รายงานหรือไม่, changed paths ตรงกับ diff หรือไม่,
contract อนุญาต `commit` หรือไม่, result อ้าง `push` ทั้งที่ contract ห้าม
หรือไม่, remote ref ที่ระบุมี commit นั้นจริงหรือไม่ (ถ้ามี remote context
ให้เช็ค) — แต่ "push แน่นอนว่าไม่เกิดขึ้นเลย" ยังพิสูจน์ไม่ได้ ต้องเขียน
limitation นี้ไว้ตรงๆ ใน DoD ไม่ใช่ปล่อยให้อ่านแล้วเข้าใจผิดว่า verify ได้ 100%

---

## 4. Test evidence: หลายชนิด ไม่บังคับ JUnit อย่างเดียว

แนวคิดเดิมของผม (free-text ไม่น่าเชื่อถือ → ต้องมี artifact อ่านด้วยเครื่องได้)
ถูกทิศทาง แต่ Independent AI Reviewer เตือนว่า**อย่าล็อก MVP ไว้ที่ JUnit XML อย่างเดียว**
เพราะหลาย ecosystem ไม่มี JUnit output เป็นค่าเริ่มต้น

ออกแบบเป็น **machine-verifiable test evidence adapter** เล็กๆ แทน:

```json
{
  "test_evidence": [
    {
      "type": "ci-check",
      "name": "unit-tests",
      "commit_sha": "abc123",
      "conclusion": "success"
    },
    {
      "type": "artifact",
      "format": "junit",
      "path": "artifacts/junit.xml",
      "sha256": "..."
    }
  ]
}
```

MVP ควรรองรับแค่ 3 แบบ ไม่ต้องมากกว่านี้:

1. JUnit XML artifact (มี sha256 กันถูกแก้)
2. GitHub Actions check ที่ผูกกับ commit SHA ตรง (verify ผ่าน API ได้)
3. Explicit command exit record ที่ **Axiom runner เป็นผู้สร้างเอง** ไม่ใช่
   agent สร้าง (นี่คือ observed evidence ตัวเดียวที่แข็งแรงสุดใน MVP)

ข้อความจาก agent เอง เช่น `{"name": "unit tests", "result": "passed"}`
เก็บได้ แต่ต้องติดป้าย `agent-claimed / unverified` เสมอ และ**ห้ามนำไป
satisfy `required_tests` โดยลำพัง**

---

## 5. Approval claim: ต้องเป็น authority event ไม่ใช่ boolean เดียว

ข้อเสนอเดิม "ไม่เชื่อ `approval_claimed: false` — สแกน artifact จริง"
ทิศทางถูก แต่ Independent AI Reviewer ชี้ว่ายังไม่พอ เพราะ AI อาจ:

- แก้ไฟล์ approval โดยตรง
- ไม่แก้ไฟล์ แต่เขียนใน PR ว่า "Human Accepted"
- เพิ่ม commit message ที่อ้าง approval
- สร้าง result ที่ไม่อ้าง approval ตรงๆ แต่แก้ release artifact ให้ดูเหมือน
  accepted อยู่ดี

MVP ต้องตรวจอย่างน้อย 5 เรื่อง:

1. Agent result **ห้ามเป็น source ของ human acceptance** เด็ดขาด
2. การแก้ approval-controlled fields โดย agent ต้องกลายเป็น diagnostic ทันที
3. Approval ต้องมาจาก authority record ที่มี `actor type = human` เท่านั้น
4. Commit author อย่างเดียว**ไม่เพียงพอ**ที่จะพิสูจน์ว่าเป็น human (ปลอมได้)
5. Human acceptance ต้องอ้าง event/evidence ที่ framework ยอมรับได้จริง

แทนที่จะออกแบบเป็น boolean เดียว:

```json
"approval_claimed": false
```

ให้ออกแบบเป็น authority events ที่ validator ตัดสินสิทธิ์เอง:

```json
{
  "authority_claims": [
    { "type": "release-approval", "actor": "agent", "claim": "approved" }
  ]
}
```

แล้ว validator ปฏิเสธทันทีเมื่อ `actor` ประเภทนี้ไม่มีสิทธิ์ grant approval —
ไม่ว่า claim จะเขียนว่าอะไรก็ตาม

---

## 6. M5.0 ต้องจบด้วย Go/No-Go/Reframe decision จริง (ไม่ใช่แค่ research note)

เห็นด้วยเต็มที่กับ Independent AI Reviewer — M5.0 ไม่ควรเป็นเอกสาร research ที่เขียนเสร็จแล้ว
M5.1 เริ่มอัตโนมัติ ต้องจบด้วย decision record ที่เลือกหนึ่งในสาม:

```
GO             — Native verified integration surface exists
GO WITH REFRAME — ไม่มี native surface; เดินหน้าแบบ git-ground-truth
                   verification แทน
NO-GO          — ไม่สามารถตั้ง verification boundary ที่มีความหมายได้เลย
```

จากหลักฐานที่มีตอนนี้ (repo `superpowers` จริงไม่มี hook รับ/ส่ง)
มีแนวโน้มสูงว่าผลจะออกมาเป็น **GO WITH REFRAME** — ซึ่งไม่ใช่เรื่องแย่
มันแค่ทำให้ M5 เล็กลงและ defend ได้จริงกว่า

---

## 7. Gap ที่ Independent AI Reviewer เพิ่มมา และผมไม่เคยคิดถึง

### 7.1 Threat model (M5.0 ต้องมี ไม่ใช่ M5.1)

ต้องระบุ trust boundary ให้ชัดตั้งแต่ research phase:

```
Untrusted:
- Agent-generated execution result
- Agent-authored summaries
- Agent-declared test outcomes
- Agent-declared approval state

Observed but context-limited:
- Local Git repository
- Available remote refs
- CI artifacts
- Workflow check conclusions

Trusted only under explicit policy:
- Framework configuration
- Approved execution contract
- Human authority records
```

### 7.2 Contract immutability

ถ้า agent แก้ทั้ง `EXECUTION-CONTRACT.json` และ `EXECUTION-RESULT.json`
พร้อมกัน การตรวจแทบไม่มีความหมายเลย — agent แก้ contract ให้เข้ากับงาน
ตัวเองแล้วค่อย "ผ่าน" ตาม contract ที่ตัวเองแก้

Contract ต้องผูกกับ:
- content digest (`contract_sha256`)
- base SHA
- work item
- requirement version
- authorized actor
- (timestamp มีได้ แต่ไม่ควรเป็นตัวพิสูจน์หลัก)

Result ต้องอ้าง contract digest กลับมา:

```json
{
  "contract_sha256": "...",
  "base_sha": "...",
  "head_sha": "..."
}
```

Axiom ต้องตรวจว่า result กำลังตอบ contract **ฉบับเดิมที่อนุมัติไว้จริง**
ไม่ใช่ฉบับที่ agent แก้เพื่อให้ผ่านง่ายขึ้น

### 7.3 TOCTOU (Time-of-check to time-of-use)

ต้องระวังช่วง: export contract → agent execute → head เปลี่ยน → validate →
head เปลี่ยนอีกรอบก่อน merge

M5 ต้อง validate ค่า **exact** เท่านั้น: `contract base SHA` เทียบกับ
`result head SHA` — **ห้าม validate branch name** ที่เคลื่อนที่ได้ตลอดเวลา
(หลักการเดียวกับที่ M4.5 ใช้ PR event's base/head SHA แทน branch name อยู่แล้ว
— reuse ได้ตรงๆ)

---

## 8. External users + tag: ลำดับที่ Independent AI Reviewer เสนอ (ผมเห็นด้วย)

```
ปิด M4.5
→ merge main
→ ออก version/tag ที่ external user ใช้ได้ (v1.2.0)
→ เริ่ม M5.0 research
→ ทดลอง external users 1–2 คน ควบคู่กัน (ไม่ต้องรอ M5.0 เสร็จก่อน)
→ ใช้ผลทั้งสองส่วนตัดสิน M5.1
```

เหตุผลที่ดีกว่าสองทางสุดโต่ง:
- **หยุด M5 ทั้งหมดจนกว่าจะมี user** — ช้าเกิน เพราะ M5.0 เป็น research
  ไม่มี production commitment มาก ไม่จำเป็นต้องรอ
- **ทำ M5.1–M5.4 ทั้งชุดโดยไม่มี user signal เลย** — เสี่ยงลงทุนบน workflow
  ที่คนอาจไม่ maintain (ตรงกับความเสี่ยงข้อ 7.1 ที่เขียนไว้ในแผนก่อนหน้า)

**คำถามที่ต้องถามคนนอกให้เจาะจง** (ไม่ใช่แค่ "ชอบไหม"):
- เข้าใจ `SCOPE.json` ภายในกี่นาที
- สร้าง scope ได้เองโดยไม่ถามผู้พัฒนาหรือไม่
- Scope แคบเกินจน false positive หรือกว้างเกินจนไม่มีค่า
- เมื่อ requirement เปลี่ยน จำอัปเดต scope หรือไม่
- Out-of-scope diagnostic ช่วยแก้ scope หรือทำให้ปิด Action ทิ้งไปเลย
- Report-only กี่รอบก่อนพร้อมเปิด `enforce`
- ยอมรับ maintenance cost ของ scope declaration หรือไม่

**Tag:** ไม่ควรออกก่อน M4.5 accepted → merged main → main CI green →
docs/version consistency checked (DOCTOR-005/006 จะเช็คให้อัตโนมัติ)
หลังจากนั้นค่อยออก tag เพื่อให้คนนอก pin ได้จริงแบบ
`uses: witchwasin/Axiom-PMO@v1.2.0` — **ห้ามให้ external user ใช้
`@main`** เพราะไม่ reproducible และเสี่ยง behavior เปลี่ยนกลางที่ทดสอบ
Independent AI Reviewer เห็นด้วยว่า minor release (`v1.2.0`) เหมาะกว่า patch เพราะเปลี่ยนจาก
validator/CLI เป็น GitHub Action + SCOPE-DIFF

---

## 9. สิ่งที่ยัง "ยังไม่ทำ" เหมือนเดิม (ย้ำ)

repo restructure, normalized IR ขนาดใหญ่, generic multi-agent protocol,
dashboard, RBAC, Jira/ADO integration, validator rewrite, Claude Code
installer (M6, ต้องอนุมัติแยกหลัง M5), semantic/LLM source-code review

---

## 10. ขั้นถัดไปที่แนะนำ (รอคุณตัดสินใจ ไม่ได้ทำเอง)

1. รอ CI ของ commit `7d2358b` เขียวครบ 6 jobs
2. คุณอ่าน diff ของ 2 MAJOR + 3 MINOR เอง หรือจะให้ผมสรุปให้เป็น review guide
   สั้นๆ แบบเดียวกับที่ทำให้ M4.5 รอบแรกก็ได้
3. ตัดสินใจ Human Accept + merge (ผมไม่ merge เอง)
4. ตัดสินใจว่าจะออก `v1.2.0` ตอนไหน (แนะนำ: ทันทีหลัง merge)
5. ตัดสินใจว่าจะเริ่ม M5.0 research พร้อมกับหา external user เลยไหม
   หรือจะรอให้ M4.5 นิ่งก่อน

เอกสารนี้เป็นแค่การรวบยอดสิ่งที่ Independent AI Reviewer แนะนำให้อ่านง่ายขึ้น ไม่ใช่คำสั่งให้เริ่ม
งานใดๆ — ผมจะไม่ทำอะไรต่อจากที่เขียนในนี้จนกว่าคุณจะสั่ง
