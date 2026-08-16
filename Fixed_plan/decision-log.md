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
| 8 (cutover) | `Fixed_plan/phase7/canary-log.md` shows N consecutive clean qualifying runs (5, per DEC-028 — was 30 when this row was written), zero unexplained resets (`Fixed_plan/phase7/PLAN.md` §6) **and** CR-017 sign-off has actually happened — the Human Owner is named as reviewer (see below) but has not yet reviewed the supply-chain/containment surface. Naming is not sign-off. |
| 9 (deletion) | Phase 8 cutover has been live for a period the Human Owner decides at that time (not fixed here) **and** the "separate Human reviewer" gap in `Fixed_plan/phase9/PLAN.md` is resolved one way or another — it is not resolved by this decision. |
| 10 (docs) | Phase 9 has actually completed — Phase 10's exit criteria ("no active surface invokes PowerShell") is false until then. |

**What this decision changes in practice:** when Phase 8's preconditions are met,
report the N evidence and ask the Human Owner specifically for the CR-017
review (a substantive review, not a rubber stamp) rather than re-asking "do you
approve moving to Phase 8 at all" — that part is already decided. Same pattern
for 9 and 10: surface the evidence and the specific remaining gap (if any) rather
than re-opening the phase-level go/no-go question this decision already answered.
Do not treat "N reached" alone as sufficient to execute Phase 8 without the CR-017
review actually happening.

---

### DEC-028 — Reduce Phase 7's N from 30 to 5, accepting reduced settling-window confidence

- **Status:** Approved
- **Approved by:** Witchwasin K. (Human Owner)
- **Date:** 2026-08-16

**Decision:** N (`Fixed_plan/phase7/PLAN.md` §6) is reduced from 30 to **5**
consecutive clean qualifying runs. The qualifying-run definition itself
(`PLAN.md` §4 — push-to-main full-profile only) is unchanged; `workflow_dispatch`
runs were offered as an option and explicitly not taken.

**Why:** the migration's active development has ended, so there is no ongoing
stream of ordinary pushes to main to accrue N against naturally — left as
originally specified, N=30 could take weeks or stall indefinitely rather than
the ~1 month of typical dev cadence it was sized for.

**What was explicitly given up, stated plainly rather than glossed over:** N=30
existed specifically to catch time/environment-dependent regressions that a
single point-in-time proof (Phase 6's 240 cases) cannot — this is not
theoretical, the first two real qualifying runs on this exact branch (commits
`b43dc94`, `3b468ba`) each surfaced a real bug Phase 6 had not caught (a missing
`dist/` copy in a test fixture, a CRLF/LF byte-comparison gap). N=5 gives the
mechanism meaningfully less chance to repeat that. The Human Owner was told this
directly, including that an N obtained by rapid back-to-back pushes in one
session (rather than spread over real time) would be worth even less than the
number implies, since it stops sampling different real-world conditions — and
confirmed 5 anyway with that understood, not before it was raised.

**What this does not change:** Phase 8/9/10's other preconditions (CR-017
sign-off, the Phase 9 "separate Human reviewer" gap, Phase 10 following Phase 9)
are all still exactly as DEC-027 left them. Only the N number moved.

---

### DEC-029 — Revise N from 5 to 10; parallelize CR-017 prep against the wait instead of shrinking it further

- **Status:** Approved
- **Approved by:** Witchwasin K. (Human Owner)
- **Date:** 2026-08-16

**Decision:** N is revised from 5 (DEC-028) to **10**. Superseded before any run
had actually landed at the N=5 setting, so this is a correction, not a rollback
of something already relied on.

**Why revised, not left at 5:** discussing DEC-028 further surfaced a real flaw
in the "get it low now, raise it again after Phase 8" idea that prompted this
review — N only means anything as a **pre-Phase-8** gate, because Phase 8
removes `AXIOM_ROLLBACK_PWSH` and Phase 9 deletes the PowerShell reference N is
measured against. Once Phase 8 happens there is nothing left to keep proving
stability against by accumulating more of the same log lines; raising N again
afterward would not recreate the protection retroactively. Since N can't be
cheaply topped up later, 10 was chosen over 5 as a better one-time number,
while still well short of the original 30.

**What actually changes to avoid the Human Owner sitting and waiting for CI:**
N does not block anything except the literal Phase 8 execution step. Everything
else can run in parallel while N accrues:
- CR-017 supply-chain/containment review prep begins now (Claude compiles the
  material; the Human Owner's actual review still has to happen, and still
  gates Phase 8 same as DEC-027 already established).
- The Phase 9 "separate Human reviewer" gap can be discussed and decided now
  too, ahead of when Phase 9 itself becomes relevant.

Nothing above shortens the wait for N=10 itself — it just means the wait is not
idle.
