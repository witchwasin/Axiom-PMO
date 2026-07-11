# Context Router - Token Discipline

Use this file before loading source files or skills. The goal is to answer the task with the smallest reliable context.

This file is guidance. The machine-readable map is `pmo-config/context-map.yaml`; runtime policy is in `pmo-config/policy.json`.

---

## Default Read Sets

| Task Type | Read These Files First | Read Source/MOM/REQ? | Do Not Load By Default |
|---|---|---|---|
| Intake / new project | `PROJECT.md`, `source/` inventory | Yes | all skills, old diagrams |
| Scope question | `PROJECT.md`, `decision-log.md` | Only if summary is missing or disputed | full MOM history |
| Flow / design | `PROJECT.md`, `DESIGN/` | Only for unclear source-backed logic | delivery/release docs |
| Wireframe | `PROJECT.md`, `DESIGN/FLOW.puml` | Only for missing UX rules | all MOM/transcripts |
| Handoff / task breakdown | `PROJECT.md`, `DESIGN/`, `DELIVERY.md` | Only for missing requirement detail | release docs |
| Dev report / review | `DELIVERY.md`, relevant design, user-provided dev note | No unless scope is disputed | all source docs |
| QA / bug | `DELIVERY.md`, `RAID-log.md`, `RELEASE.md` | Only if expected behavior is unclear | unrelated design docs |
| Release | `RELEASE.md`, `RAID-log.md`, `decision-log.md`, `DELIVERY.md` | Only for unresolved acceptance disputes | all skills |
| Impact from new source | New source file, `PROJECT.md`, affected `DESIGN/` or `DELIVERY.md` | Yes, targeted | unrelated project folders |

---

## Mode-Based Context Budget

| Mode | Max Initial Files | Source Policy | Verification Policy |
|---|---:|---|---|
| Lite | 3-5 | Use `PROJECT.md`; source only if needed | Acceptance criteria + test note |
| Standard | 5-8 | Use source references; open source slices when needed | Checklist + source-backed review |
| Strict | As needed | Source-backed traceability required | Human verification + RAID + decision log |

If context is growing, stop and summarize the current facts into `PROJECT.md` or the relevant output instead of loading more files.

---

## Source Reference Rules

Every important claim should point back to structured references:

```yaml
source_ref:
  - source_id: MOM-20260710
    locator: item-3.2
```

Use stable source IDs:

- MOM: `MOM-YYYYMMDD` with `locator: item/topic`
- Transcript: `TR-YYYYMMDD` with `locator: 00:18:35-00:19:20`
- Requirement file: `REQ-V1` or `REQ-YYYYMMDD` with `locator: row-4` or `section-4.1`
- Decision: `DEC-001`
- Issue/PR: `ISSUE-12` or `PR-8`

Use `evidence_status: missing` to flag a gap, never to justify a final requirement.

---

## Skill Loading Rules

- Load only the skill needed for the current task.
- Do not read every `.claude/skills/*/SKILL.md`.
- If a skill says to load another skill, load only that dependency.
- Prefer templates in `templates/` for normal work before using large reference files.
- Optional skills such as orchestration, CI/CD, code scaffold, proposal writing, and deep code review are off by default.

---

## When To Reopen Full Source

Reopen MOM/REQ/transcript only when:

- Starting intake or impact analysis
- User says the summary is wrong
- A requirement conflicts with another artifact
- An `inferred`, `missing`, or `conflict` evidence status affects scope, money, compliance, or release
- Strict mode requires full traceability

Otherwise use `PROJECT.md` as the working summary.
