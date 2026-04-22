@AGENTS.md

# PMO Template -- Entry Point & Skill Router

> **All behavioral rules are in `AGENTS.md`** (auto-loaded via `@AGENTS.md` above)
> This file contains ONLY: Quick Start, Project Registry, Skill Routing, Hooks, and Project-Specific Decisions

---

## Quick Start for PMO

### First-Time Setup

1. **Clone repo:** `git clone <repo-url> && cd PMO-Template`
2. **Create new project:** `chmod +x init-project.sh && ./init-project.sh XYZ "Project Name"`
3. **Place MOM and REQ** files into the generated project folders
4. **Start with Claude:** "Create Activity Diagram for P01-XYZ"

### How Claude Works

- **Smart Router** auto-detects skill from natural language (no need to memorize skill names)
- **Quality Gates** auto-validate before and after every output
- **Phase Gates** prevent skipping pipeline steps
- **State Engine** tracks project progress across sessions
- **Auto Plan Mode** before tasks that need planning
- **Always asks** when uncertain -- never assumes
- **Sends Sub-agents** to research when data is unclear -- asks for confirmation before using
- **Organizes Agent teams** for large tasks
- **Every output passes MOM Validation** before becoming Final
- **Cost Tracking** logs token usage per project/skill

---

## Project Registry

> **Update this table whenever a new project is created or status changes.**

| Project Code | Full Name | Folder | Status | Notes |
|-------------|-----------|--------|--------|-------|
| *(add your projects here)* | | | | |

---

## Skills Reference (Load On-Demand)

> Skills live under `.claude/skills/` — each skill has `SKILL.md` + optional `references/` + `personas/`.

### PMO Skills (core methodology)

| Skill | When to load |
|-------|--------------|
| `pmo-smart-router` | Auto-route user intent to correct skill |
| `pmo-activity-diagram` | Create Activity / System Flow Swimlane (.puml) |
| `pmo-activity-diagram-workspace` | Workspace helper for activity diagram iteration |
| `pmo-use-case-diagram` | Create Use Case Diagram (.puml) |
| `pmo-review-diagram` | Run validation checklist on diagrams |
| `pmo-review-diagram-workspace` | Workspace helper for diagram review |
| `pmo-analyze-new-mom` | Analyze new MOM and assess impact |
| `pmo-analyze-new-mom-workspace` | Workspace helper for MOM analysis |
| `pmo-gap-analysis` | Compare REQ vs diagrams to find gaps |
| `pmo-task-breakdown` | Produce task breakdown + Gantt |
| `pmo-traceability` | Maintain Traceability Matrix (Change/Activity/Decision log) |
| `pmo-deep-interview` | Socratic interview for requirements |
| `pmo-proposal-writer` | Write project proposal documents |
| `pmo-lark-plantuml` | Lark-safe PlantUML rules (11 rules) |
| `pmo-wireframe-design` | Produce wireframes referenced to SystemFlow |
| `pmo-dev-handoff` | Assemble developer handoff package |
| `pmo-workflow-architect` | Design workflow structure |

### Quality / Execution Skills

| Skill | Purpose |
|-------|---------|
| `pmo-quality-gate` | Pre/Post/Phase gates with quality scoring |
| `pmo-state-engine` | `.state/` management (project state, audit trail, cost tracking) |
| `pmo-verification-evidence` | Evidence capture for validation |
| `pmo-hook-profiles` | Hook configuration profiles |
| `pmo-context-optimizer` | Context budget management |
| `pmo-blueprint` | Project blueprint generator |

### Collaboration Skills

| Skill | Purpose |
|-------|---------|
| `pmo-taskboard` | TaskBoard CRUD (Backlog → Done lifecycle) |
| `pmo-dev-report` | Validate Dev report against SystemFlow |
| `pmo-qa-report` | Log QA test results |
| `pmo-handoff-protocol` | PM→Dev / Dev→QA / QA→PM handoff docs |
| `pmo-standup` | Daily Standup summary |
| `pmo-retro` | Retrospective facilitation |
| `pmo-team-orchestrator` | Multi-agent team orchestration |
| `pmo-agent-orchestration` | Persona dispatch (Lead/Analyst/Architect/Writer/Reviewer/Security) |
| `pmo-dashboard` | Project dashboard rendering |

### Dev / QA / Infra Skills

| Skill | Purpose |
|-------|---------|
| `pmo-coding-standards` | Coding standards reference |
| `pmo-code-scaffold` | Generate code scaffolds from handoff package |
| `pmo-design-md` | Design documentation in Markdown |
| `pmo-infra-spec` | Infrastructure specification |
| `pmo-ci-cd-template` | CI/CD template |
| `pmo-deploy-checklist` | 30-item pre-deploy checklist |
| `pmo-security-scan` | Security review pass |
| `pmo-git-push` | Safe git commit and push workflow |
| `backend-code-review` | Backend code review |
| `frontend-testing` | Frontend testing patterns |
| `design-system-patterns` | Design system patterns |
| `senior-qa` | Senior-QA lens for test planning |
| `agent-sessions-architecture` | Multi-session agent architecture |
| `key-talking-point` | Key talking points for presentations |

### Cross-Skill Dependencies

- `pmo-activity-diagram` always loads `pmo-lark-plantuml` when producing `.puml`
- `pmo-dev-handoff` loads `pmo-traceability` + `pmo-gap-analysis`
- `pmo-taskboard` loads `pmo-traceability` + `pmo-handoff-protocol`
- `pmo-dev-report` loads `pmo-taskboard` + `pmo-coding-standards`
- `pmo-qa-report` loads `pmo-taskboard`
- `pmo-quality-gate` loads at every skill entry/exit
- `pmo-state-engine` loads on session start

---

## Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| `PMO-KEYWORD-DETECT` | UserPromptSubmit | Detect keywords from user prompt and route to skill |
| `PMO-PHASE-GATE` | PreToolUse | Block skipping of pipeline stages |
| `PMO-QUALITY-PRE` | PreToolUse | Pre-gate quality check |

See `.claude/settings.json` for the full hook configuration and `pmo-hook-profiles` skill for profile variants.

---

## SOP: Git Commit and Push Safety

Load `pmo-git-push` skill when committing / pushing.

### ไฟล์ที่ห้าม push (Sensitive Files)

- `.env`, `.env.*`
- API keys, tokens, credentials
- Audio / voice recordings (`*.wav`, `*.mp3`, `*.m4a`)
- MOM `.docx` ที่ลูกค้าไม่อนุญาต
- PII / customer data
- Internal / confidential PDF or image drops

### ขั้นตอนก่อน Commit

1. Run `git status` — ตรวจไฟล์ที่จะ commit
2. Run `git diff --cached` — ตรวจเนื้อหา diff
3. Grep สำหรับ secrets (API_KEY, password, token)
4. ใช้ commit format: `[PROJECT] Type: Summary [Ref: MOM#N]`
5. Push ตาม branch strategy (`main` / `dev` / `feat/*`)

### .gitignore Patterns (maintained)

```
.env
.env.*
*.log
.DS_Store
node_modules/
.vscode/
.idea/
__pycache__/
P*/confidential/
P*/SystemFlow/PDF_*/
```

---

## MCP Server Integrations

| Server | Purpose | When to use |
|--------|---------|-------------|
| **PlantUML** | Render `.puml` diagrams | All diagram output |
| **Refero** | Wireframe references / design patterns | `pmo-wireframe-design` |
| **TestSprite** | Automated test generation | See setup guide below |
| **Playwright** | Browser automation for E2E tests | QA workflow |

---

## PMO Collaboration Workflow Reference

> Workflow diagrams: `docs/UserManual/PMO-WF-{A,B,C,E}_*.puml`
> Skills: `pmo-taskboard`, `pmo-dev-report`, `pmo-qa-report`, `pmo-handoff-protocol`

**Status Flow:** Backlog → Assigned → In Progress → Dev Done → QA Testing → QA Passed → Client Review → Done

**PM-Dev-QA Loop:**
1. Dev asks AI: "งานรอบนี้ทำอะไร?" → AI reads TaskBoard, returns module + test cases + deadline
2. Dev completes → AI validates test coverage → if pass, update TaskBoard + Traceability → notify QA
3. QA tests → AI logs results → if pass, notify PM for Client Review; if fail, create revision note for Dev

---

## TestSprite MCP Setup Guide

> **API Key เป็นของส่วนตัว — ห้ามแชร์ข้ามคน ของใครของมัน**

### ขั้นตอนที่ 1: สร้าง API Key

1. ไปที่ https://www.testsprite.com/ แล้ว login/สมัคร
2. เข้า Dashboard แล้วกด **"Create a Key"**
3. Copy API Key ที่ได้มา (ขึ้นต้นด้วย `sk-user-...`)

### ขั้นตอนที่ 2: Install MCP ใน Claude Code

```bash
claude mcp add TestSprite --env API_KEY=YOUR_API_KEY -- npx @testsprite/testsprite-mcp@latest
```

### ขั้นตอนที่ 3: Restart Claude Code

พิมพ์ `/exit` แล้วเปิด Claude Code ใหม่

### ขั้นตอนที่ 4: ทดสอบ

พิมพ์: "Hey, help me to test this project with TestSprite."

---

## Project-Specific Decisions

> Log decisions here that affect agent behavior across sessions (new rules, terminology changes, business rules).
> Format: `| Date | Decision | Impact |`

| Date | Decision | Impact |
|------|----------|--------|
| *(add decisions here)* | | |
