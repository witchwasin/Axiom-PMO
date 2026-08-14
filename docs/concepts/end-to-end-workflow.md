# End-to-end workflow

Two choices are independent: who builds (`development_handoff` or
`governed_ai_execution`) and governance Mode (Lite, Standard, Strict).
Optional Research and UI delivery declarations select branches; they are
Human declarations, never detections. Each branch has its own governed
artifacts and validators (see `research-workflow.md`, `externalization.md`,
and `claude-design-workflow.md`), and every branch stays silent until
declared.

```text
[H-IN] Source -> [AI-R] Intake -> optional Research/Externalization
  -> [SYS] Scope validation -> [HG] Scope Approved
  -> [AI-A] System Design + Test Strategy in BUILD-SPEC
  -> UI: not_applicable | dev_guided | Claude Design provider handoff
  -> [AI-R/SYS] Final Handoff validation -> [HG] Design Ready
  -> Developer build | Governed AI execution
  -> Controlled Change loop when reality differs
  -> [SYS] evidence/release validation -> [HG] Release Approved
```

Humans own ambiguity and approvals. AI drafts and reconciles candidate output.
Deterministic validators check shape, references, digests, Git evidence, and
freshness. `auto` never means automatic Scope, Design, risk, or Release approval.

| Step | Executor | Accountable | Human touchpoint | Governed output |
|---|---|---|---|---|
| Intake | AI-assisted intake | PM/PO | declares Mode, Execution path, Research, UI delivery | `PROJECT.md` declarations |
| Research (optional) | AI drafts brief/impact; provider produces candidate research | Research owner | confirms focus/provider; accepts/rejects Change Proposals at Scope | `RESEARCH/RESEARCH.md`, `RESEARCH/PROVENANCE.json` |
| Externalization (when data leaves) | AI proposes classification/redaction | Named reviewer | reviews and approves Confidential/Restricted transfers | `EXTERNALIZATION.json` |
| System design | AI-assisted | Tech Lead | none beyond Design Ready | `DESIGN/BUILD-SPEC.md` + mode-aware Test Strategy |
| UI: dev-guided | AI-assisted | Developer | UI delivery choice | conditional flow/wireframe |
| UI: Claude Design (optional) | AI prepares manifest + preflight + reconciliation | Named reviewer | operates provider; reviews and accepts/rejects output | `DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json`, `OUTPUT/**`, `REVIEW.json` |
| Delivery/build | Developer or execution agent | Work item owner | controlled changes | `DELIVERY.md`, conditional `CHANGE-REQUESTS.json` |
| Verification/release | Deterministic checks + AI review | Release approver | Release Approved | evidence and release artifacts |
