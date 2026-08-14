# End-to-end workflow

Two choices are independent: who builds (`development_handoff` or
`governed_ai_execution`) and governance Mode (Lite, Standard, Strict).
Optional Research and UI delivery declarations select branches; they are
Human declarations, never detections. In the M0–M3 handoff these values are
vocabulary and routing only; provider/externalization/research enforcement is
reserved for M4–M6.

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

| Step | Executor | Human touchpoint | Governed output |
|---|---|---|---|
| Intake/research | AI-assisted intake | research focus remains a future optional track | `PROJECT.md` declaration |
| System/UI design | AI-assisted | UI choice; provider handoff is a future optional track | `DESIGN/BUILD-SPEC.md`, conditional flow/wireframe |
| Delivery/build | Developer or execution agent | controlled changes | `DELIVERY.md`, conditional `CHANGE-REQUESTS.json` |
| Verification/release | Deterministic checks + AI review | Release Approved | evidence and release artifacts |
