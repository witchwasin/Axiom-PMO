# Lessons learned: what cost us time, and what to do instead

> For anyone — human or agent — **debugging this repository**. Written to make
> the second occurrence fast, not to be complete.
>
> For the PowerShell constructs themselves, see
> [`powershell-portability.md`](powershell-portability.md). This document is
> about **method**: how the problem was found, what the wrong turns were, and
> what the first move should be next time.

Every entry is a real incident in this repository, with the real cost. Nothing
here is hypothetical, and nothing here is a style preference.

---

## The one-paragraph version

Two things cost the most time, repeatedly:

1. **Guessing at a failure on a host you cannot run.** The maintainer machine
   is macOS and cannot run Windows PowerShell 5.1 at all. Every guess costs a
   full CI round-trip, and a wrong guess costs one for nothing.
2. **Trusting a negative result from a tool you did not verify.** Ruling a
   hypothesis *out* incorrectly is more expensive than never having it, because
   it removes the right answer from consideration and sends the next hour
   somewhere else.

The fix for both is the same: **make the machine print the real state before
you theorise about it.**

---

## Incident 1 — a golden mismatch with no detail (issue #20)

**Symptom.** `example-standard-feature-handoff` passed on macOS pwsh 7, Linux
pwsh 7, and Windows pwsh 7, and failed on Windows PowerShell 5.1 with:

```text
[FAIL] example-standard-feature-handoff expected pass but got fail
  - example-standard-feature-handoff: output differs from golden master
```

**Cost.** The coverage was reverted (`ba75dae`) to get `main` green, leaving the
real gap open. Six hypotheses were investigated and correctly ruled out — CRLF
digest, property order, `Sort-Ordinal` stability, `Get-Sha256Hex`, the Handoff
path in general, the design-system change — and none of them was the cause,
because the log did not contain the information needed to find it.

**Root cause.** `Get-Content -Raw` with no `-Encoding`. Windows PowerShell 5.1
decodes a BOM-less file as ANSI, pwsh 7 as UTF-8, so a UTF-8 em dash produced a
different string and a different SHA-256 on the two hosts. Full write-up:
[`powershell-portability.md` §7](powershell-portability.md).

**What actually solved it.** Adding a diagnostic that printed the differing
lines, pushing once, and reading the output:

```text
line 439:  expected: "...is current against both digests..."
           actual:   "HANDOFF-REVIEW.json is stale: a governed artifact it reviewed has changed"
line 443:  expected: "field": null       actual: "field": "review_inputs.digest"
```

That was the whole diagnosis. One round-trip, no guessing. The diagnostic
(`Get-GoldenDiffReport`) is permanent, not scaffolding.

### The lesson

**A test that can fail must be able to say why it failed.** `-VerifyGolden`
comparing 153 goldens and reporting only "output differs" was the actual
defect being paid for here — the encoding bug was found in an afternoon once
the output was visible, and was undiagnosable for as long as it was not.

Before adding an assertion, ask what its failure message will contain on a
host you cannot attach a debugger to.

---

## Incident 2 — ruling out the right answer with a broken check

**What happened.** The encoding hypothesis was raised early and correctly,
then **discarded on bad evidence**. The scan used to check for non-ASCII bytes
was:

```bash
LC_ALL=C grep -c $'[\x80-\xff]' "$f"     # silently under-matches
```

It reported zero non-ASCII bytes in files that contain three em dashes. The
hypothesis was dropped, and the investigation moved on to comparing rule sets
between projects — which found nothing, because there was nothing to find.

A byte-level check told the truth immediately:

```bash
python3 -c "b=open(p,'rb').read(); print([x for x in b if x>127])"
```

### The lesson

**Verify a negative with a different mechanism than the one that produced it.**
A hypothesis you *reject* deserves more scrutiny than one you accept, because
accepting a wrong one fails loudly at the next step while rejecting a right one
fails silently for hours.

Concretely: when checking for the *absence* of something, prefer a tool that
reports the actual values (`python3`, `xxd`, `od -c`) over one that reports only
a count or a match/no-match.

---

## Incident 3 — CI fixtures pinned to commits that no longer exist

**Symptom.** `dogfood-scope-diff` failed on every `main` run for three
consecutive pushes over roughly eight hours:

```text
SCOPE-DIFF-004: The base commit (c9576a7...) could not be resolved in this
checkout. This is commonly a shallow checkout: actions/checkout defaults to
fetch-depth 1 ...
```

**The trap.** The job already had `fetch-depth: 0`, so the error message's
suggested cause was wrong for this case. The three fixture SHAs were authored
on milestone branches that were never pushed to `origin`; `origin` held only
`main` and the release tags. `fetch-depth: 0` fetches **all refs** — it cannot
fetch a commit that no ref points at.

**Fix.** The job now builds its delta commits in its own checkout at run time
and asserts each touches exactly the file its fixture documents. SCOPE-DIFF
still diffs real commits; the dependency on repository history is gone.

### The lessons

- **Never pin CI to a commit reachable only from a local branch.** Check with
  `git ls-remote --heads origin` — if the branch is not there, neither is the
  commit, whatever your local clone shows.
- **An error message names the *common* cause, not *your* cause.** This one
  says "commonly a shallow checkout" and was read as "you have a shallow
  checkout." Confirm the stated cause actually applies before acting on it.

---

## Working rules that came out of this

### On a host you cannot run locally

1. **Instrument first, hypothesise second.** One diagnostic push that prints
   the real state beats three guess-and-fix pushes, and usually beats one.
2. **Make the diagnostic permanent** when it is generally useful. The next
   person gets it for free, and it costs nothing when everything passes.
3. **Do not merge a change you know fails on a required host.** Use
   `workflow_dispatch` on a branch — `.github/workflows/pmo-checks.yml` has the
   trigger for exactly this — instead of turning `main` red to gather evidence.
4. **`gh run view --log` refuses to serve logs while a run is in progress.**
   A finished job inside a running workflow is readable through the API:
   `gh api /repos/<owner>/<repo>/actions/jobs/<job_id>/logs`. Useful when the
   fast job already failed and the slow legs have 15 minutes left.

### On digests and hashes

5. **Hash stored bytes when you can** (`Get-FileHash`), and pass an explicit
   `-Encoding` when you must decode first. `Get-VisualProofFileHash` never had
   the §7 bug for exactly this reason.
6. **Fix both sides together.** A digest has a recording side and a verifying
   side; fixing only one keeps them disagreeing. Issue #20's fix touched five
   reads, `handoff-digest.ps1` among them, for that reason.
7. **Prove a digest fix is a no-op on the working host** before shipping it —
   re-run the recorder and confirm it still prints the digests already stored
   in the review files. Otherwise the fix silently invalidates every recorded
   review.

### On regression coverage

8. **Know which fixture is the guard, and write it down.** After §7, the only
   project in the suite whose review inputs contain non-ASCII text is
   `examples/STANDARD-FEATURE`. It is therefore the only case that fails if the
   encoding regresses. That is recorded in §7, including the instruction not to
   edit those em dashes out — otherwise a future tidy-up removes the coverage
   without removing a test.
9. **A gate that never runs is not coverage.** `examples/STANDARD-FEATURE` ran
   at `-Gate Release` on every CI leg, where no `HANDOFF-###` rule evaluates,
   so a broken Handoff gate in the example that exists to demonstrate the
   Handoff gate shipped green.

---

## Symptom → first move

| Symptom | First move |
|---|---|
| Fails only on Windows PowerShell 5.1 | Read [`powershell-portability.md`](powershell-portability.md). If no section matches, push a diagnostic that prints the real state — do not guess. |
| Golden master mismatch | Read the differing lines the run now prints. They name the rule and the field. |
| A digest disagrees between hosts | Check how the file is **decoded**, before any normalization. §7. |
| `SCOPE-DIFF-004` unresolvable ref | `git ls-remote --heads origin`. Confirm the commit is reachable from a pushed ref before believing "shallow checkout". |
| A hypothesis was "ruled out" but nothing else fits | Re-check the ruling-out with a different tool. Incident 2. |
| Need a log from a job while the run is still going | `gh api /repos/<owner>/<repo>/actions/jobs/<job_id>/logs` |

---

## Related

- [`powershell-portability.md`](powershell-portability.md) — the constructs themselves, and `DOCTOR-010` / `DOCTOR-011` which enforce two of them
- [`validation-engine.md`](validation-engine.md) — how the engine defends itself
- [`../../AGENTS.md`](../../AGENTS.md) — the behavioural rules these lessons sit under
