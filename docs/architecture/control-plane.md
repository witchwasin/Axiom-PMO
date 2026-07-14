# Architecture: The Control Plane

Axiom-PMO is a **governance control plane**. It sits between the human who owns
the work and the AI execution framework that builds it, and it validates the
result before anything is considered release-ready.

```
Human / PM / Product Owner
        │
        ▼
┌────────────────────────────────────┐
│ Axiom-PMO — Governance Control Plane│
│  • Source-of-truth protection       │
│  • Requirement traceability         │
│  • Lite / Standard / Strict modes   │
│  • Scope & design approval          │
│  • Evidence requirements            │
│  • QA / security / release gates    │
│  • Human authority boundaries       │
└───────────────┬────────────────────┘
                │ approved execution contract
                ▼
┌────────────────────────────────────┐
│ AI Execution Framework              │
│  Superpowers / BMAD / spec-kit /    │
│  OpenSpec / custom Claude Code      │
│  Planning · TDD · Implementation ·  │
│  Code review · Verification         │
└───────────────┬────────────────────┘
                │ candidate result + evidence
                ▼
┌────────────────────────────────────┐
│ Axiom-PMO Validation                │
│  • Scope compliance                 │
│  • Evidence verification            │
│  • Traceability update              │
│  • QA / security review             │
│  • Human release approval           │
└────────────────────────────────────┘
```

## Two planes, one direction of authority

- The **control plane** (Axiom-PMO) owns *what may be built, why, with what
  evidence, under whose authority, and when it is safe to release*.
- The **execution plane** (any AI framework) owns *how it gets built*.
- Authority flows downward as an approved contract; results flow back up as
  candidate evidence. The execution plane cannot override the control plane's
  approvals or policies.

## Where each responsibility lives

| Concern | Artifact / mechanism |
|---|---|
| Scope, requirements, approvals | `PROJECT.md`, approval tables |
| Task source of truth | `DELIVERY.md` **or** GitHub Issues (declared, never both) |
| Design | `DESIGN/` (flow, wireframe) |
| Risk, decisions | `RAID-log.md`, `decision-log.md` |
| Traceability | `RTM.json` (Strict) |
| Release | `RELEASE.md` (scope, tests, QA/security, rollback, approval) |
| Enforcement | `scripts/validate-project.ps1` + `scripts/lib/*` + `pmo-config/*` |

See [the validation engine](validation-engine.md) for how enforcement works, and
[the interoperability overview](../integrations/overview.md) for the plane
boundary in practice.
