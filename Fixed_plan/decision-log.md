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

---

### DEC-030 — Waive the N=10 settling-window gate; proceed to Phase 8 at N=1

- **Status:** Approved
- **Approved by:** Witchwasin K. (Human Owner)
- **Date:** 2026-08-16

**Decision:** Phase 7's N requirement (10, per DEC-029) is waived. Phase 8 proceeds
with N=1 banked (`Fixed_plan/phase7/canary-log.md`, sha `0fda09e`), not 10.

**How this was reached, not just that it was:** the Human Owner asked to skip the wait
for N=10 to reach Phase 8. Before agreeing, this was clarified explicitly rather than
assumed: was "skip N" (1) a further numeric reduction (still some settling window,
just smaller) or (2) skipping the gate entirely and proceeding now? The Human Owner
confirmed (2) explicitly, after DEC-029's own reasoning was restated to them directly
— that N cannot be meaningfully reconstructed after Phase 8 removes
`AXIOM_ROLLBACK_PWSH`, so this is not a deferral, it is forgoing that evidence
permanently. Confirmed with that understood, not before it was raised a second time.

**What this does not change:** CR-017 sign-off (DEC-031) and the Phase 9 second-
reviewer gap (DEC-032) are separate requirements, addressed separately below — this
decision is scoped to the N number only.

---

### DEC-031 — CR-017 sign-off

- **Status:** Approved
- **Approved by:** Witchwasin K. (Human Owner), as the named CR-017 reviewer (DEC-027)
- **Date:** 2026-08-16

**Decision:** the Human Owner reviewed `Fixed_plan/phase8/CR-017-review-material.md`
(supply-chain and containment surface) and signed off. This is the actual review DEC-027
required — not the compiled material itself, which was only ever evidence for this.

**What was reviewed:** zero runtime dependencies; 23 dev-only packages from two
publishers (Microsoft/TypeScript team, Node.js project), all MIT/Apache-2.0, zero
lifecycle scripts found in any of them; `private: true`; committed lockfile with SRI on
every entry; containment tests covering symlink refusal, path-escape refusal,
install-root separation, read-only install, clean-room, case-sensitivity, and NTFS
junctions specifically (including the ancestor-escape gap found and fixed the same day
— see `Fixed_plan/phase8/CR-017-review-material.md` §5-6 for the full detail and the
codebase-wide audit that found no further instances).

---

### DEC-032 — Waive Phase 9's "separate Human reviewer" requirement

- **Status:** Approved
- **Approved by:** Witchwasin K. (Human Owner)
- **Date:** 2026-08-16

**Decision:** `master-plan.md`'s Definition of Done line — "a separate Human reviewed
the final diff" for the PowerShell deletion — is explicitly waived. This has been a
known, flagged gap since `Fixed_plan/phase9/PLAN.md` was first written (DEC-027):
this project has one Human Owner, not two, and the DoD line as written assumes a team
structure this project doesn't have.

**Why waived rather than worked around:** no external reviewer was sourced or asked to
review the deletion diff. The Human Owner chose to formally accept that gap for this
project rather than delay for one, or than have Claude (the same party that will write
and execute the deletion) stand in as if it were an independent second reviewer, which
it structurally cannot be.

**What this means going forward:** the Phase 9 deletion diff gets exactly one reviewer
— the Human Owner themself. This decision is the record of why that's considered
acceptable for this project, so it doesn't read as an oversight later.

---

### DEC-033 — Phase 8's "live for a period" precondition: proceed immediately

- **Status:** Approved
- **Approved by:** Witchwasin K. (Human Owner)
- **Date:** 2026-08-17

**Decision:** `Fixed_plan/phase9/PLAN.md`'s remaining Phase 9 precondition — "Phase 8
cutover has been live for a period the Human Owner decides at that time" — is
resolved as: no additional waiting period. Phase 9 proceeds immediately following
Phase 8 (`901035d`/`6e92b8b`, landed 2026-08-17).

**Context:** this was the one item explicitly left open across DEC-030/031/032 --
those three resolved N, CR-017, and the second-reviewer gap, but not this. Asked
directly rather than assumed; the Human Owner's answer was to start the remaining
phases now.

**What this completes:** every precondition DEC-027's original table listed for
Phase 9 is now resolved (Phase 8 live: this decision; second-reviewer gap: DEC-032).
Phase 9 execution follows.

---

### DEC-034 — Proceed with the CI/CD workflow rewrite discovered mid-Phase-9

- **Status:** Approved
- **Approved by:** Witchwasin K. (Human Owner)
- **Date:** 2026-08-17

**Decision:** while executing Phase 9's file-deletion step (Task 12), auditing
found `.github/workflows/pmo-checks.yml` directly invokes `pwsh`/`scripts/*.ps1`
in `determine-profile`, `fast-checks`, `targeted-checks`, all three
full-profile host jobs, and `dogfood-ci-check-evidence` -- none of which were
in the original file-deletion scope (`Fixed_plan/phase9/PLAN.md` only listed
the files themselves), but all of which would break CI on the next push once
those files were gone. Two new Node ports were also needed first
(`ci-profile-cli.ts` for `scripts/ci-profile.ps1`'s full CLI surface,
`run-ci-suite-cli.ts` for `scripts/run-ci-suite.ps1`'s execution half) since
neither had been ported beyond the differential-proof subset already used
elsewhere.

**Why this needed a decision, not just execution:** modifying live CI/CD
infrastructure is a hard-to-reverse action this project's own guardrails flag
for confirmation, and unlike the local code changes earlier in Phase 9, the
workflow rewrite cannot be fully verified without an actual push-triggered CI
run -- there is no local GitHub Actions runner to prove it against first.
Asked explicitly via AskUserQuestion rather than proceeding unilaterally;
offered doing the rewrite now, pausing Task 12 until CI is handled separately,
or deleting files anyway and letting CI fail. The Human Owner chose to
proceed with the rewrite now.

**What this does not change:** the rewrite keeps every job id unchanged
(`pmo-checks-windows-pwsh7` etc. still literally say "pwsh7" despite no
longer running PowerShell) specifically because branch protection's
required-status-checks setting references job ids by name in GitHub's own
repository settings, which this session cannot see or edit -- renaming would
risk silently unsatisfying that setting until a human fixes it separately.
Real correctness of the workflow changes is confirmed by the next CI run
after push, not by this decision.
