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

## Current session — product-handoff lessons (2026-08-11)

This section records mistakes made while applying Axiom-PMO to the separate
**Axiom Web** product handoff. They are not product defects and they do not
change a human decision retroactively. They are here because they are easy to
repeat when an agent is moving quickly from an idea to a polished document set.

### Resolved in this session

| ID | What went wrong | Why it mattered | Correction / rule for next time | Status |
|---|---|---|---|---|
| LL-20260811-01 | The canonical Axiom-PMO checkout was initially ambiguous because a second local path was mentioned. | Work, validation, or deletion against the wrong copy can make a correct repository look inconsistent. | Start every repository task with `git rev-parse --show-toplevel`, record the canonical path, and treat an untracked sibling folder as separate until the Human Owner explicitly resolves it. | resolved: canonical repository path recorded via `git rev-parse --show-toplevel` |
| LL-20260811-02 | We began with a broad PRD/technical handoff for a UI-heavy product before showing the project-native visual artifact the Human Owner expected. | The user reasonably expected to inspect an HTML design sheet/components before approving a developer handoff, and had to ask where `DESIGN-SYSTEM.html` was. | For a product with a material UI, do: **minimum scope → visual directions in `examples/` → human selection → canonical `DESIGN/VISUAL-DIRECTION.md` + `DESIGN-SYSTEM.md/.html` → detailed handoff**. A text-only PRD is not a substitute for the visual checkpoint. | corrected with the Atlas candidate/selection and canonical Axiom Web design contract |
| LL-20260811-03 | The initial implementation handoff described a broad v1 before the smallest useful Pilot had an explicit human scope choice. | RBAC, audit, uploads, HTML isolation, Visual Proof, and GitHub write can look like one feature list while actually forming a large product slice. | Create a human-readable `PILOT-SCOPE-REVIEW.md` before treating a broad PRD as implementation scope. State both what is in and what is deliberately deferred. | corrected: Axiom Web Private Team Pilot is `DEC-009` |
| LL-20260811-04 | Artifact completion was sometimes communicated as if the whole handoff were complete. | A visual page can be complete while Scope, Design, Handoff, or Release is still pending; the user then cannot tell what “done” means. | Always report a four-layer outcome: **artifact**, **human approval**, **validation gate**, and **release/deployment**. Never say “complete” without the layer. | process correction recorded here |
| LL-20260811-05 | The Design Ready role matrix did not initially match the small-team operating model: PO/PM acceptance could not satisfy the Strict role check. | A real human approval became an unexpected framework blocker late in the flow. | Ask who owns Scope/Design/Release authority during onboarding, before creating approval rows. If framework policy must change, record a framework decision and test the actual allowed roles. | resolved by Axiom-PMO `DEC-023`: Product Owner and Project Manager may approve Design Ready |
| LL-20260811-06 | We surfaced a raw count of many Handoff failures before grouping them into the few decisions that caused them. | A list such as “29 failures” sounds like 29 independent user choices and obscures the next action. | Report root-cause groups first: authority, owner/horizon, provider/auth, real-data policy, import contract, GitHub binding, framework pin, review evidence. Link individual rules only as supporting detail. | process correction recorded here |
| LL-20260811-07 | After new decisions, several downstream documents still carried earlier claims (single owner, vendor, synthetic-only data, an old stage model, unselected design). | Strict artifacts are a contract graph: one stale document is enough to mislead a developer or make a review digest stale. | After every meaningful decision, run a **decision-impact sweep** over `PROJECT.md`, `HANDOFF.md`, `BUILD-SPEC.md`, `DELIVERY.md`, `RAID-log.md`, `RTM.json`, architecture docs, visual artifacts, and review evidence. Refresh a digest only after that sweep. | corrected for the current Axiom Web handoff; use this checklist again on the next decision |
| LL-20260811-08 | We initially treated “use real data” and “the data policy is unresolved” as if one cancelled the other. | The safe default became a scope assumption instead of a transparent condition for the product the user actually wants. | Record both truths: real data can be an approved use case, while classification, retention, backup/restore, deletion, access review, export, and incident policy are hard blockers **before intake**, not vague release notes. | corrected by Axiom Web `DEC-013` |
| LL-20260811-09 | The creative artifact triple activates conditional Visual Proof at the Axiom-PMO Handoff gate, which is easy to discover only late if not surfaced first. | A project may be Design Ready yet still need current captures, hashes, and named human review evidence at Handoff. | When adding `VISUAL-DIRECTION.md`, `DESIGN-SYSTEM.md`, and `DESIGN-SYSTEM.html`, tell the user immediately that Handoff will require `VISUAL-REVIEW.json` and declared desktop/mobile captures. Do not imply an aesthetic validator exists. | framework behavior is intentional; early disclosure is the correction |
| LL-20260811-10 | We briefly conflated the **product-access persona** with the **handoff recipient**: “no vendor account” was read too broadly as “no developer/vendor may receive the handoff.” | It can put the wrong security boundary into the product and makes the actual implementation contract ambiguous. | Model three distinct identities in every web handoff: product user/account, implementation recipient, and Git publisher. An external developer/vendor may receive a package without receiving an Axiom Web account or publish authority. | corrected in the Axiom Web handoff and architecture documents |

### Active follow-up queue — do not silently close these

| Area | What remains | Who must decide or do it | Blocking point |
|---|---|---|---|
| Axiom-PMO framework | Review/commit the current PO/PM Design Ready policy correction and this lessons entry when the Human Owner wants the shared repository baseline changed. The local policy/test work is verified; no new commit is implied by this note. | Human Owner | before another repository/user relies on the changed policy |
| Axiom Web implementation | Name the internal implementation lead/team and a delivery horizon. | Human Owner | before implementation commitment |
| Axiom Web private boundary | Choose private URL hosting, authentication, database/object storage, region, and account bootstrap after the implementation team proposes options. | Human Owner + implementation lead | before private deployment/team-account enablement |
| Axiom Web real data | Record the data operating policy: classification, retention, backup/restore, deletion, access review, export, and incident expectations. | Human Owner | before real-data intake or real-user Pilot |
| Axiom Web artifact intake | Approve the controlled import manifest/allowlist, size/type limits, scanning, and recovery behavior for Markdown, self-contained HTML, files, and Axiom-PMO folders. | Human Owner + implementation lead | before controlled import enablement |
| Axiom Web GitHub Publish | Configure the least-privilege GitHub App, private repository/branch allowlist, rotation/revocation, and Owner-only publish behavior. | Human Owner + implementation lead | before GitHub Publish integration |
| Axiom Web compatibility | Pin the exact **committed** Axiom-PMO version/commit and choose how the Web product validates/exports the compatible pack. `v1.5.0` / `71fb1a7` is only the current reference baseline. | Framework owner + implementation lead | before claiming compatibility / production handoff |
| Axiom Web Handoff | Refresh semantic handoff review after its artifacts stabilize, then provide the conditional Visual Proof captures/review required by the Handoff gate. | Product Owner + implementation lead | before Axiom-PMO Handoff validation |

### Re-entry checklist

When resuming either repository, first read the table above, then run these
checks before declaring a milestone or handoff complete:

1. Confirm the repository root and the intended product path.
2. Read the latest decision log entries and list their impacted artifacts.
3. State the intended completion layer: artifact, approval, Handoff validation,
   or release.
4. Run the smallest relevant validator and group failures by human decision,
   not by raw rule count.
5. For any web/product handoff with a visual contract, open the canonical HTML
   sheet before asking for Design Ready.

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

### The wider problem it exposed, and the `archive/*` refs

Chasing the fixture commits turned up something larger: this repository's
history was **rebuilt** at some point before 1.5.0. The current `main` shares
no common ancestor with the pre-rebuild line — every commit was replayed onto
a new root with a different SHA. The content survived; the object ids did not.

That left the closure evidence in `ROADMAP.md`, `CHANGELOG.md`,
`decision-log.md`, and `docs/architecture/adversarial-review.md` citing commit
SHAs that existed on one laptop and nowhere else — including `f10b608`, the
declared *minimum publishable baseline*, and `1235034`, the M7/8.0/8.1/9 merge.
For a repository whose whole claim is traceable evidence, a citation nobody
else can resolve is not a small thing.

The pre-rebuild history is therefore published under an `archive/` namespace:

| Ref | What it holds |
|---|---|
| `archive/pre-rebuild-main` (tag) | Tip of the old `main` line. Covers every cited SHA, including the four reachable from no branch at all: `1235034`, `4ae5f35`, `1309cb6`, `f10b608`. |
| `archive/m5.0-…`, `archive/m5.5-…`, `archive/m6.0-…`, `archive/m6.1-…`, `archive/v1.3.0-prep` | The milestone lines, kept under their own names so it stays clear which work was which. |

**These refs are archive, not build targets.** Nothing in CI may reference a
commit under `archive/*` — doing so re-creates Incident 3 exactly, and this
time the commits *are* on the remote, so it would fail later and less
obviously. Build fixtures at run time. The `archive/pre-rebuild-main` tag
message says the same thing, so it travels with the ref.

**The general rule:** if a document cites a commit as evidence, that commit
must be reachable from a pushed ref. Verify it the way a reader would —
`git merge-base --is-ancestor <sha> origin/main`, from a fresh clone, not from
the working copy that happens to still have the object.

---

## Incident 4 — one skipped suite hid four Windows PowerShell 5.1 defects

**Symptom.** The V2.1 handoff reported M4-M6 targeted checks as green, but the
full-suite runner had two `Invoke-Check` calls accidentally joined on one line.
The M4-M6 suite therefore existed and passed when run directly, while
`run-all-checks.ps1` never executed it. Once the runner was fixed and the
branch workflow was dispatched, Windows PowerShell 5.1 exposed four separate
host defects in sequence.

| Failure | Root cause | Permanent correction |
|---|---|---|
| Every validator exited before producing JSON | A UTF-8 em dash inside a BOM-less `.ps1` string decoded through the Windows ANSI code page; one byte became a smart quote and ended the string during parsing. | PowerShell source under `scripts/` and `tests/` is ASCII-safe; `line-ending-tests.ps1` scans the bytes and fails on non-ASCII source. |
| The M4-M6 containment test crashed after its assertions passed | Windows PowerShell 5.1 `Remove-Item` threw `NullReferenceException` while removing a junction. | Remove the directory link with `[System.IO.Directory]::Delete(path, $false)`, which deletes the link and never recurses into its external target. |
| The LF-to-CRLF digest mutation failed only on 5.1 | The test read BOM-less UTF-8 with `Get-Content -Raw` and no encoding, corrupted non-ASCII characters, and then wrote those changed characters back. It was no longer a line-ending-only mutation. | Every text mutation reads with `-Encoding UTF8`; canonical hashing still decodes strictly, strips BOM, and normalizes line endings. |
| Release-evidence tests died on a harmless Git CRLF notice | Native `git add` ran under `$ErrorActionPreference = "Stop"`; 5.1 promoted stderr to a terminating error despite `2>$null`. | Test-native Git calls use a save/`Continue`/restore wrapper, the same pattern required for product scripts. |

**Cost.** Each defect appeared only after the previous one was fixed, so a
single required-host run became several CI round-trips. The first run was
initially undiagnosable because the validation harness discarded child stderr.

**What made the later rounds fast.** The child diagnostic was kept as a
permanent harness improvement. A completed job inside a still-running workflow
was downloaded through the Actions job-log API, and each fix followed the
exact exception and line number rather than a host guess.

### The lessons

- A test file existing is not evidence that the full runner calls it. Print a
  stable `[CHECK]`/`[PASS]` name and assert that required suites were executed.
- Portability rules apply to test harnesses too. A host-only crash in tests can
  prevent the product code from being exercised at all.
- PowerShell source encoding is different from content-file encoding: a parser
  failure happens before code can pass `-Encoding UTF8`. Keep executable source
  ASCII-safe unless the repository deliberately adopts BOM-bearing source.
- A cross-host matrix is discovery evidence until every required job is green;
  partial host success is not completion.

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
10. **The CI profile mapping is code, not prose.** `scripts/ci-profile.ps1`
    decides `fast`/`targeted`/`full` from changed paths; a path filter that
    silently widens or narrows coverage is a code change, and
    `tests/helpers/ci-profile-tests.ps1` is the regression test that fails on
    it. When a new directory is added, update the classifier and its test
    together — see [`ci-risk-based.md`](ci-risk-based.md).

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
| Every validator exits with no JSON on Windows 5.1 | Preserve child stderr, then inspect source-parser diagnostics; check BOM-less `.ps1` files for non-ASCII bytes. |
| `Remove-Item` fails while cleaning a Windows junction | Use `Directory.Delete(path, false)` so cleanup deletes the link, not its target. |
| A line-ending mutation changes a digest only on 5.1 | Verify the test itself reads with `-Encoding UTF8` before rewriting line endings. |

---

## Related

- [`powershell-portability.md`](powershell-portability.md) — the constructs themselves, and `DOCTOR-010` / `DOCTOR-011` which enforce two of them
- [`ci-risk-based.md`](ci-risk-based.md) — the fast/targeted/full profiles and the path→suite/host mapping
- [`validation-engine.md`](validation-engine.md) — how the engine defends itself
- [`../../AGENTS.md`](../../AGENTS.md) — the behavioural rules these lessons sit under
