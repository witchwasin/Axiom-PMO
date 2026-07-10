# Strict Process

Use Strict when failure has business, compliance, financial, privacy, production, or external integration risk.

Triggers:

- Payment or financial calculation
- PII or confidential customer data
- Authentication, authorization, permission, or audit log
- External integration or migration
- Production release
- Gov-style acceptance, formal UAT, penalty, warranty, or contract milestone

## Flow

```text
Source-backed Intake -> Risk Review -> Design + Acceptance Criteria -> Separate Review/Test -> Release Approval
```

## Required Artifacts

- `PROJECT.md` with full `source_ref`
- `DESIGN/FLOW.puml` and any required UI/API/design notes
- `DELIVERY.md` or GitHub Issues with acceptance criteria and test checklist
- `RAID-log.md`
- `decision-log.md`
- `RELEASE.md` with rollback notes

## AI Guardrails

- Every requirement, business rule, acceptance criterion, and release claim needs `source_ref`.
- Inferred, missing, or conflicting evidence must show `evidence_status` and be reviewed by a human.
- If the source does not support a claim, mark it as open question or gap.
- AI must not approve scope, release, deployment, or production readiness.

## Human Verification

Check at minimum:

- Scope and out-of-scope
- Acceptance criteria
- Security/privacy impact
- Rollback plan
- UAT evidence
- Open blocker and high-risk issues

## Exit Criteria

- No unresolved blocker before release.
- Release approval is logged in `decision-log.md`.
- `scripts/validate-project.ps1 -Release` passes.
