---
name: Agent Orchestration
description: กำหนด Auto Plan Mode, Research Agent workflow และโครงสร้าง multi-agent team สำหรับงานขนาดใหญ่
---

# PMO Skill: Agent Orchestration

> **Related Skills:** None (self-contained).

This skill covers Auto Plan Mode, Research Agent, and Agent Team structure for Claude Code PMO workflows.

---

## Auto Plan Mode

> **Every task that requires planning or creating output - Claude must enter Plan Mode automatically without waiting for the user to ask.**

### Tasks that REQUIRE Plan Mode

| Task Type | Examples |
|----------|----------|
| **Create new Diagram** | Activity Diagram, Use Case Diagram |
| **Create new Task Breakdown** | Task Breakdown, Gantt Chart |
| **Modify existing Diagram/Task** | Update flow, add cases, change timeline |
| **Analyze MOM/REQ to create output** | Read MOM then create diagram or task breakdown |
| **Multi-file impact tasks** | New feature requiring diagram + use case + task breakdown updates |

### Tasks that DO NOT require Plan Mode

| Task Type | Examples |
|----------|----------|
| **Simple Q&A** | Explain syntax, answer format questions |
| **Read and summarize** | Read MOM and summarize (no output created) |
| **Minor edits** | Fix typo, change color, fix syntax error |

### Procedure

1. **Evaluate immediately** whether the task requires Plan Mode
2. **If yes** - use `EnterPlanMode` immediately, announce: "Entering Plan Mode to plan before starting"
3. **In Plan Mode** - follow all rules (read REQ/MOM, ask Actor, analyze Cases, etc.) then present plan for user approval
4. **After user approves** - execute according to plan

---

## Research Agent

> **When unsure about requirement, business logic, terminology, or any information - send a Sub-agent to research from internet, but always let the user verify before using the data.**

### When to Send Research Sub-agent

| Situation | Examples |
|----------|----------|
| **Uncertain terminology** | Business terms, industry standards, unfamiliar abbreviations |
| **Business logic needs reference** | Related laws, compliance standards (PDPA, PCI-DSS), industry best practices |
| **Technical validation** | 3rd party API specs, standard formats (ISO date, currency code) |
| **Process reference** | Standard processes of similar systems, industry flows (KYC, payment) |
| **MOM/REQ unclear** | Requirement too broad, need reference to propose approach |

### Procedure

1. **Identify uncertainty** - inform user what needs verification
2. **Send Sub-agent** (Task tool, subagent_type: general-purpose) to research using WebSearch/WebFetch
3. **Compile results** - summarize findings with source references
4. **Present to user for verification** - never put internet data into diagram/task breakdown without confirmation:
   - Data found
   - Source (URL/source)
   - Recommendation whether to use or not
5. **User decides** - use / don't use / modify before using

> **Prohibition:** Never automatically include internet data in output - must wait for user confirmation every time.

---

## Agent Team (Sub-agent Team for Large Tasks)

> **For tasks requiring comprehensive work, create a team of related Agents and assign Sub-agents to write or research in parallel - 1 team has 1-10 members with PMO Lead (main Claude) as team leader.**
> **ทุก Sub-agent ต้องได้รับ Persona prompt** — ดูไฟล์ใน `personas/` folder

### Team Structure — Persona-Based

```
ลีด (Lead) — Main Claude, Team Leader
+-- อันนาลิส (Analyst)    -> ขุด MOM/REQ, หา gap, cross-check Transcription
+-- อาร์คิเทค (Architect)   -> ออกแบบ workflow, วาง flow structure
+-- ไรท์เตอร์ (Writer)      -> เขียน diagram, wireframe, task breakdown
+-- รีวิว (Reviewer)     -> ตรวจ output ด้วย checklist ครบทุกข้อ
+-- ซีเคียว (Security)   -> ตรวจ fraud, compliance, business logic risk
```

| Persona | Role | Persona File | subagent_type |
|---------|------|-------------|---------------|
| **ลีด (Lead)** | Team Leader — วางแผน, แบ่งงาน, review, merge | `personas/lead.md` | Main Claude (ไม่ spawn) |
| **อันนาลิส (Analyst)** | MOM/REQ Analyst — อ่าน source, หา gap/conflict | `personas/analyst.md` | `general-purpose` |
| **อาร์คิเทค (Architect)** | Workflow Architect — ออกแบบ flow structure | `personas/architect.md` | `general-purpose` |
| **ไรท์เตอร์ (Writer)** | Diagram/Wireframe Writer — สร้าง output | `personas/writer.md` | `general-purpose` |
| **รีวิว (Reviewer)** | Quality Reviewer — ตรวจ checklist 20+7+7 | `personas/reviewer.md` | `general-purpose` |
| **ซีเคียว (Security)** | Security Reviewer — ตรวจ fraud/compliance | `personas/security.md` | `general-purpose` |

> **Researcher** ไม่มี persona แยก — ใช้ persona ใดก็ได้ที่เหมาะกับงาน (เช่น อันนาลิส research MOM, อาร์คิเทค research workflow pattern)
> **Code Explorer** ใช้ subagent_type `Explore` — persona ตาม context

### Persona Prompt Template

**เมื่อ spawn sub-agent ต้องใส่ persona context ใน prompt:**

```
คุณคือ {ชื่อ} ({Role}) ในทีม PMO

{เนื้อหาจาก personas/{name}.md — บุคลิก + ความรับผิดชอบ + สิ่งที่ห้ามทำ}

## งานที่ได้รับ
{Task description จาก Lead}

## Context
{MOM/REQ data, findings จาก agent ก่อนหน้า, constraints}

## Expected Output
{รูปแบบ output ที่ต้องการ}

## Handoff Format
เมื่อทำเสร็จ ให้ส่งผลในรูปแบบ Handoff Report (ดูด้านล่าง)
```

### Handoff Protocol

> **ทุก sub-agent ต้อง return ผลในรูปแบบ Handoff Report** เพื่อให้ Lead ส่งต่อให้ agent ถัดไปได้

```markdown
## Handoff Report
- **จาก:** {ชื่อ persona} ({Role})
- **ถึง:** ลีด (Lead) → ส่งต่อให้ {ชื่อ persona ถัดไป}
- **งาน:** {สรุปสิ่งที่ทำ}
- **ผลลัพธ์:** {output / findings / ไฟล์ที่สร้าง}
- **REQ ที่เกี่ยว:** {REQ-XXX, REQ-XXX}
- **MOM# ที่อ้างอิง:** {MOM#X, MOM#X}
- **ข้อควรระวัง:** {conflicts, gaps, risks ที่เจอ — ถ้าไม่มีใส่ "ไม่มี"}
- **สถานะ:** {Done / Needs Clarification / Blocked}
```

**Lead ต้องทำเมื่อได้รับ Handoff:**
1. ตรวจ output — ถูกต้อง? ตรง MOM/REQ?
2. ตรวจ conflicts — ขัดแย้งกับ handoff จาก agent อื่นไหม?
3. ส่งต่อ — inject handoff summary เข้า prompt ของ agent ถัดไป

### Procedure

1. **ลีด (Lead) ประเมินงาน** — วิเคราะห์ scope, เลือก persona ที่ต้องใช้, จัด task order
2. **จัดทีมและแบ่งงาน** — TaskCreate สำหรับแต่ละ persona พร้อม dependency
3. **Spawn sub-agents พร้อม persona prompt** — งานที่ independent ส่งพร้อมกัน (parallel)
4. **ลีด review handoff** — ตรวจทุก Handoff Report:
   - ถูกต้อง? (matches MOM/REQ)
   - ไม่ขัดแย้ง? (consistent กับ agent อื่น)
   - Format ถูก? (follows rules)
5. **ส่งต่อให้ agent ถัดไป** — inject handoff summary จาก agent ก่อนหน้าเข้า prompt
6. **Merge output แล้ว present ให้ user** — รวม output สุดท้ายจากทุก persona

### Example Team Formation

**Task:** Create Activity Diagram + Use Case Diagram + Task Breakdown for new Module

```
ลีด (Lead)
+-- อันนาลิส (Analyst)    -> อ่าน MOM + REQ + Transcription ของ Module นี้
+-- อาร์คิเทค (Architect)   -> ออกแบบ workflow spec จาก findings ของอันนาลิส
+-- ไรท์เตอร์ (Writer) x2   -> เขียน SystemFlow + UseCase จาก spec ของอาร์คิเทค
+-- รีวิว (Reviewer)     -> ตรวจ output ทั้งหมดด้วย checklist 20+7+7
+-- ซีเคียว (Security)   -> ตรวจ business logic risk ของ Module นี้
```

**Handoff Chain:**
```
อันนาลิส → ลีด(review) → อาร์คิเทค → ลีด(review) → ไรท์เตอร์ → ลีด(review) → รีวิว + ซีเคียว → ลีด(merge) → User
```

### Key Requirements

- **ทุก sub-agent ต้องได้รับ persona prompt** — อ่าน persona file แล้ว inject เข้า prompt ตอน spawn
- **ทุก sub-agent ต้อง return Handoff Report** — ห้ามส่งผลแบบ free-form
- **Sub-agents ไม่ approve แทน user** — decisions สำคัญต้องผ่าน Lead → user
- **Team size ต้องเหมาะกับงาน** — งานเล็กใช้ 1-2 คน, งานใหญ่ถึง 6 คน (max 10)
- **Rules ไม่ซ้ำ** — persona บอกแค่ "คนนี้เป็นใคร ถนัดอะไร" ส่วน behavioral rules ยังอยู่ที่ AGENTS.md

---

## Critic Agent Pattern — Devil's Advocate ก่อน Finalize

> **อ้างอิง OMC critic agent** — เพิ่มการตรวจสอบจาก "มุมมองที่ท้าทาย" ก่อน finalize output สำคัญ
> ใช้กับ: project ที่มี stakeholders หลายฝ่าย, complex business logic, หรือก่อน Dev Handoff

### เมื่อไหร่ใช้ Critic

| สถานการณ์ | ใช้ Critic? |
|----------|:---:|
| สร้าง diagram ปกติ | ไม่ (ใช้ Reviewer ตามปกติ) |
| Diagram ที่เกี่ยวกับ Payment/KYC/Compliance | **ใช่** |
| ก่อน Dev Handoff ของ project ซับซ้อน | **ใช่** |
| Stakeholders > 3 ฝ่ายที่อาจขัดแย้ง | **ใช่** |
| Plan ที่กระทบ > 5 modules | **ใช่** |
| PM ขอ "review ให้ละเอียดหน่อย" | **ใช่** |

### Critic Checklist

Critic ต้องตรวจ 5 มุมมอง:

| # | มุมมอง | คำถามที่ต้องตอบ |
|---|--------|---------------|
| 1 | **Executor View** | "ถ้าเป็น Dev ที่ได้ spec นี้ จะเขียน code ได้เลยไหม? มีอะไรคลุมเครือ?" |
| 2 | **Stakeholder View** | "ลูกค้า/PM/QA จะมีข้อโต้แย้งอะไรกับ output นี้?" |
| 3 | **Skeptic View** | "อะไรอาจผิดพลาดได้? มี assumption ที่อาจไม่จริง?" |
| 4 | **Completeness View** | "มี requirement ไหนที่ขาดไป? มี edge case ที่ไม่ได้คิด?" |
| 5 | **Consistency View** | "output นี้ขัดแย้งกับ output อื่นใน project ไหม?" |

### Pre-mortem Analysis (3-7 Failure Scenarios)

Critic ต้องคิด failure scenarios ก่อน finalize:

```markdown
## Pre-mortem Analysis
**Module:** {Module Name} | **Critic:** AI

| # | Failure Scenario | Likelihood | Impact | ป้องกันอย่างไร | มีใน flow แล้ว? |
|---|-----------------|:---:|:---:|-------------|:---:|
| 1 | User กรอกข้อมูลไม่ครบแล้วกด submit | H | M | Frontend validation + Backend validation | Y/N |
| 2 | Server timeout ระหว่าง payment processing | M | H | Idempotency key + retry mechanism | Y/N |
| 3 | Admin approve ซ้ำ 2 ครั้ง (race condition) | L | H | Optimistic locking | Y/N |
```

**Critic Verdict:**

| Verdict | ความหมาย | Action |
|---------|---------|--------|
| **ACCEPT** | Output ดี ไม่มีปัญหาสำคัญ | Proceed to finalize |
| **ACCEPT-WITH-RESERVATIONS** | OK แต่มีจุดที่ควรระวัง | Proceed + log reservations |
| **REVISE** | มีจุดที่ต้องแก้ก่อน finalize | แก้แล้ว run Critic อีกรอบ |
| **REJECT** | ปัญหาร้ายแรง ต้อง rethink approach | กลับไป plan ใหม่ |

### Implementation

**Spawn Critic เป็น sub-agent (Opus model):**

```
คุณคือ Critic ในทีม PMO — หน้าที่คือท้าทายและตรวจสอบ output ก่อน finalize

ห้ามให้ feedback แบบอ่อน ต้อง critical challenge:
- ตรวจ 5 มุมมอง (Executor/Stakeholder/Skeptic/Completeness/Consistency)
- ทำ Pre-mortem Analysis (3-7 scenarios)
- ให้ Verdict (ACCEPT/ACCEPT-WITH-RESERVATIONS/REVISE/REJECT)

Output ที่ต้อง review:
{แนบ output ที่ต้อง review}

Context:
{MOM/REQ references, SystemFlow ที่เกี่ยวข้อง}
```

---

## Ralplan — Consensus Planning Loop

> **อ้างอิง OMC ralplan skill** — iterative planning loop สำหรับ decisions ที่มีผลกระทบสูง
> ใช้กับ: architectural decisions, flow structure ที่กระทบหลาย modules, ก่อนเริ่ม project ใหม่ที่ซับซ้อน

### เมื่อไหร่ใช้ Ralplan

| สถานการณ์ | Planning แบบปกติ | Ralplan |
|----------|:---:|:---:|
| สร้าง diagram ใหม่ 1 module | Y | - |
| สร้าง diagram ที่กระทบ > 5 modules | - | **Y** |
| เลือก architecture pattern | - | **Y** |
| เปลี่ยน flow structure ที่มีอยู่ | - | **Y** |
| Project ใหม่ที่ซับซ้อน (> 10 modules) | - | **Y** |
| PM พูดว่า "วางแผนให้ละเอียดหน่อย" | - | **Y** |

### Consensus Loop: Planner → Architect → Critic

```
   อันนาลิส (ดู MOM/REQ)
        ↓
   อาร์คิเทค (สร้าง Plan + ADR)
        ↓
   Critic (ท้าทาย + Pre-mortem)
        ↓
   [ผ่าน?] → YES → Present to User → Execute
        ↓ NO
   อาร์คิเทค (ปรับ Plan ตาม Critic feedback)
        ↓
   Critic (review อีกรอบ)
        ↓
   ... (loop max 3 รอบ ถ้ายัง REJECT → escalate ให้ PM ตัดสินใจ)
```

### Ralplan Output: Decision Record

เมื่อ consensus สำเร็จ สร้าง Decision Record:

```markdown
## Ralplan Decision — {Topic}
**Date:** YYYY-MM-DD | **Consensus Rounds:** {N}/3

### Principles (สิ่งที่ยึด)
1. {หลักการ 1 — เช่น "source-driven, ห้าม Gold Plate"}
2. {หลักการ 2 — เช่น "minimal impact ต่อ modules ที่ finalize แล้ว"}
3. {หลักการ 3}

### Decision Drivers (ปัจจัยตัดสินใจ)
1. {ปัจจัย 1 — เช่น "Timeline 2.5 เดือน"}
2. {ปัจจัย 2 — เช่น "ลูกค้า confirm 3 phase"}
3. {ปัจจัย 3}

### Options Considered

| # | Option | Pros | Cons | Effort |
|---|--------|------|------|:---:|
| 1 | {ทางเลือก A} | {ข้อดี} | {ข้อเสีย} | S/M/L |
| 2 | {ทางเลือก B} | {ข้อดี} | {ข้อเสีย} | S/M/L |

### Decision
{สิ่งที่เลือก + เหตุผล}

### Critic Findings
{สิ่งที่ Critic ท้าทาย + วิธีที่ตอบ}

### Follow-up Actions
1. {Action 1}
2. {Action 2}
```

**กฎ:** Ralplan Decision ต้อง log ใน Decision Log (Traceability Matrix) ด้วย โดยใส่ ADR Note แนบ

---

## Team Pipeline — Staged Execution with Handoff Documents

> **อ้างอิง OMC team skill** — staged pipeline สำหรับงานขนาดใหญ่ที่ต้องการ formal handoff ระหว่าง stage
> ใช้กับ: สร้าง diagrams ทั้ง project, Dev Handoff Package, multi-module review

### 5-Stage Pipeline

```
Stage 1: PLAN     → อันนาลิส + อาร์คิเทค สร้าง plan
    ↓ [Handoff: plan-handoff.md]
Stage 2: SPEC     → อันนาลิส สร้าง requirement spec
    ↓ [Handoff: spec-handoff.md]
Stage 3: EXECUTE  → ไรท์เตอร์ สร้าง output (diagrams/wireframes/handoff)
    ↓ [Handoff: exec-handoff.md]
Stage 4: VERIFY   → รีวิว + ซีเคียว ตรวจ output (Verification Tiers)
    ↓ [Handoff: verify-handoff.md]
Stage 5: FIX      → ไรท์เตอร์ แก้ไขตาม feedback (loop กับ Stage 4)
    ↓ [max 3 fix loops]
    → Present to User
```

### Stage Handoff Document Format

**ทุก stage transition ต้องสร้าง Handoff Document:**

```markdown
## Stage Handoff: {Stage Name}
**Date:** YYYY-MM-DD | **From:** {Persona} | **To:** {Next Persona}

### Decided
- {สิ่งที่ตัดสินใจแล้วใน stage นี้}

### Rejected
- {สิ่งที่พิจารณาแล้วตัดออก + เหตุผล}

### Risks
- {ความเสี่ยงที่เจอ + mitigation}

### Files Created/Modified
| File | Action | Status |
|------|--------|--------|
| {filename} | Created/Updated | Draft/Final |

### Remaining Work
- {สิ่งที่ stage ถัดไปต้องทำ}

### Blockers (ถ้ามี)
- {สิ่งที่ block ต้องรอ user/ลูกค้า}
```

### Fix Loop Rules

| รอบ | Action |
|:---:|---|
| Fix 1 | แก้ตาม Reviewer feedback ทั้งหมด |
| Fix 2 | แก้ issues ที่เหลือ + Critic review |
| Fix 3 | แก้ครั้งสุดท้าย — ถ้ายัง FAIL → **escalate ให้ PM ตัดสินใจ** |

> **ห้าม loop เกิน 3 รอบ** — ถ้าแก้ 3 รอบแล้วยังไม่ผ่าน แสดงว่า plan มีปัญหา ต้องกลับไป Stage 1

### เมื่อไหร่ใช้ Team Pipeline vs ทำปกติ

| งาน | วิธี |
|-----|------|
| สร้าง 1 diagram | ทำปกติ (ไม่ต้อง pipeline) |
| สร้าง 2-3 diagrams ใน module เดียว | ทำปกติ + review |
| สร้าง diagrams ทั้ง project (> 5 modules) | **Team Pipeline** |
| Dev Handoff Package | **Team Pipeline** |
| Impact Analysis จาก MOM ใหม่ที่กระทบ > 5 modules | **Team Pipeline** |
| PM ขอ "ทำให้ครบทั้ง project" | **Team Pipeline** |

### Pipeline State Tracking

**Lead ต้อง track state ของ pipeline:**

```markdown
## Pipeline Status — P{XX}-{CODE}
| Stage | Status | Persona | Started | Completed | Handoff |
|-------|:---:|---------|---------|-----------|---------|
| PLAN | Done | อาร์คิเทค | HH:MM | HH:MM | plan-handoff.md |
| SPEC | Done | อันนาลิส | HH:MM | HH:MM | spec-handoff.md |
| EXECUTE | In Progress | ไรท์เตอร์ | HH:MM | — | — |
| VERIFY | Pending | รีวิว | — | — | — |
| FIX | Pending | ไรท์เตอร์ | — | — | — |
```

> Pipeline state ไม่ต้อง persist ข้าม session — ใช้ activity log ใน Traceability Matrix ดูย้อนหลังได้
