# Decision Log — interpreter migration (Node/TS)

Continues the DEC numbering used inline in `master-plan.md` §12 (last: DEC-026).

---

### DEC-027 — Pre-authorize Phase 8/9/10 in principle, execution still gated on evidence

- **Status:** Approved
- **Approved by:** Witchwasin K. (Human Owner)
- **Date:** 2026-08-16

**Decision:** the Human Owner pre-authorizes proceeding through Phase 8 (cutover),
Phase 9 (PowerShell deletion), and Phase 10 (documentation reconciliation) *in
principle* — meaning no further "may I proceed" round is needed once each phase's
own preconditions are actually met. This is **not** authorization to execute any
of the three now; none of their preconditions are met yet.

**Why now, not immediate execution:** the Human Owner's first phrasing ("อนุมัติ
Phase 8/9/10") was ambiguous between "go do it now" and "I approve the direction,
proceed when ready." Given Phase 9 is an irreversible deletion, this was clarified
explicitly rather than guessed — see the conversation this decision was recorded
from. The Human Owner selected: approve in principle, wait for conditions.

**Preconditions that still gate each phase — unchanged by this decision:**

| Phase | Must be true before execution |
|---|---|
| 8 (cutover) | `Fixed_plan/phase7/canary-log.md` shows N=30 consecutive clean qualifying runs, zero unexplained resets (`Fixed_plan/phase7/PLAN.md` §6) **and** CR-017 sign-off has actually happened — the Human Owner is named as reviewer (see below) but has not yet reviewed the supply-chain/containment surface. Naming is not sign-off. |
| 9 (deletion) | Phase 8 cutover has been live for a period the Human Owner decides at that time (not fixed here) **and** the "separate Human reviewer" gap in `Fixed_plan/phase9/PLAN.md` is resolved one way or another — it is not resolved by this decision. |
| 10 (docs) | Phase 9 has actually completed — Phase 10's exit criteria ("no active surface invokes PowerShell") is false until then. |

**What this decision changes in practice:** when Phase 8's preconditions are met,
report the N=30 evidence and ask the Human Owner specifically for the CR-017
review (a substantive review, not a rubber stamp) rather than re-asking "do you
approve moving to Phase 8 at all" — that part is already decided. Same pattern
for 9 and 10: surface the evidence and the specific remaining gap (if any) rather
than re-opening the phase-level go/no-go question this decision already answered.
Do not treat "N reached" alone as sufficient to execute Phase 8 without the CR-017
review actually happening.
