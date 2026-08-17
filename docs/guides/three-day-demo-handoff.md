# Guide: a three-day demo handoff

A walkthrough of the Handoff gate on a short, real-shaped engagement: a sponsor wants a working demonstration in three weeks, two engineers are available, and the demo runs on hardware the delivery team does not own.

The worked example is [`examples/HANDOFF-DEMO`](../../examples/HANDOFF-DEMO). Everything in it is synthetic.

---

## The situation

From the kickoff: a workshop team wants a tablet page to look up a part by scanning its label and adjust the on-hand count. Demonstration on 2026-08-05. The sponsor supplies the tablet. Roughly six person-days across two engineers. Photos of a part may be attached, and the sponsor asked that photos not leave the site network.

Four requirements, two engineers, three weeks. Small enough that nobody expects it to go wrong, which is exactly the size at which it does.

---

## Step 1 — Scope and design as usual

Nothing new here. `PROJECT.md` with sourced requirements, `DESIGN/FLOW.puml`, `DESIGN/WIREFRAME.md`, `DELIVERY.md` work items, `Scope Approved` and `Design Ready` rows.

```bash
node cli/axiom.mjs validate --project examples/HANDOFF-DEMO --mode Standard --gate Design --fail-on-warning
```

At this point the project passes every gate Axiom-PMO 1.0 could run. That is the state in which the failures below are invisible.

---

## Step 2 — Write the handoff

```bash
cp templates/HANDOFF.md examples/HANDOFF-DEMO/HANDOFF.md
cp templates/BUILD-SPEC.md examples/HANDOFF-DEMO/DESIGN/BUILD-SPEC.md
```

Or generate a project with them already in place:

```bash
node cli/axiom.mjs init --code P02-WORKSHOP --mode Standard --handoff --target demo --horizon-days 21
```

Three things in `HANDOFF.md` do most of the work.

### The target and horizon

```markdown
- Handoff Target: demo
- Horizon: 2026-08-05
- Named Integrator: R. Silva (Senior Engineer)
```

`demo` turns on the demo milestone requirements. Naming an integrator matters because two streams have to converge: without a named person, each stream owner reasonably assumes the other is handling the join.

### Build order, which is not work-item order

```markdown
| Step | Work Item Ref | Depends On | Owner | Notes |
|---|---|---|---|---|
| 1 | D-001 | none | R. Silva | Schema, part master, and the seed dataset |
| 2 | D-002 | D-001 | K. Owusu | Needs the part master to look anything up |
| 3 | D-003 | D-001 | R. Silva | Needs the stock tables and the transaction boundary |
| 4 | D-004 | D-001 | K. Owusu | Needs the part record to attach to |
```

`D-001` is not a feature anyone asked for. It is the shared prerequisite underneath three of them, and it has to be step 1. The first draft of this table had the scan flow first, because scanning is the interesting part — which would have meant two days of work against a table that did not exist. `HANDOFF-004` catches that from the step numbers alone.

### What would stop the demonstration

```markdown
| Action ID | Description | Owner | Blocking Point | Status |
|---|---|---|---|---|
| OA-001 | Install the site certificate authority on the demo tablet | R. Silva | before_demo | open |
| OA-002 | Confirm in writing that the sponsor supplies the tablet by 2026-08-01 | A. Nakamura | before_demo | open |
| OA-003 | Decide whether the pilot needs multi-site stock | A. Nakamura | non_blocking | open |
```

Both open items block the demonstration. Neither stops anyone writing code today. That distinction is the entire reason the blocking-point enum exists.

---

## Step 3 — Write the build spec

The section that changes the outcome most:

```markdown
### Target Devices and Runtime Capabilities

Status: specified

| Capability | Required By | Serving Model | Environment Decision |
|---|---|---|---|
| Rear camera | AC-001 scan flow | HTTPS from a local reverse proxy with a certificate trusted by the tablet | DEC-005 |
```

A browser will not open the camera for a page served over plain HTTP. Everything about the scan feature can be correct, reviewed, and tested on a developer laptop over `localhost`, and it will still do nothing on the tablet. `HANDOFF-012` will not let `Serving Model` stay `open`.

The data inventory does the same job for privacy:

```markdown
| Data Element | Contains Sensitive Data | Classification Decision | Retention Decision |
|---|---|---|---|
| Part photo file | yes | DEC-003 internal-only, stays on the site network | DEC-003 purged on demo reset |
| Photo EXIF metadata | yes | DEC-003 stripped on upload, never stored | DEC-003 never written to disk |
```

The validator does not decide that a photo is sensitive — the author declares it, and the validator then requires the decisions. The EXIF row is the kind of thing that only appears once someone is forced to enumerate the elements.

Sections that genuinely do not apply are waived, with a reason:

```markdown
### Retention, Backup and Restore

Status: not_required
Rationale: The demo dataset is regenerated from seed on every reset, so nothing in this slice has a retention or restore obligation before pilot.
```

A blank section is ambiguous in the worst way: the reader cannot tell whether you decided it did not apply or never got to it.

---

## Step 4 — Review for sense

The validator has now proven the contract is complete. It cannot prove it is sensible.

```bash
node -e "import('./dist/tools/digest-tools.js').then(m=>process.stdout.write(m.handoffDigest('.', 'examples/HANDOFF-DEMO').output))"
# source_snapshot.digest : fba5dc44...   <- the material the requirements came from
# review_inputs.digest   : 44eda5d0...   <- the artifacts the reviewer actually read
```

Both go into `HANDOFF-REVIEW.json`. The second is the one people forget:
rewriting the build sequence after a review leaves the source snapshot
untouched, so without it the review would keep reporting as current.

Run the `pmo-delivery` skill with the `handoff_review` intent, or write `HANDOFF-REVIEW.json` from the template. In this example the review found six things. The one no rule could have caught:

```json
{
  "finding_id": "HF-001",
  "lens": "capability_lifecycle",
  "severity": "major",
  "description": "The first draft scoped stock consumption only. A count that can go down but never up cannot be demonstrated twice from the same seed, and the source states both directions are needed.",
  "blocking_point": "before_build",
  "status": "resolved"
}
```

Nothing structural was wrong with the original scope. One requirement, sourced, approved, complete. It simply could not survive a second run of the demonstration.

The one that stays open:

```json
{
  "finding_id": "HF-005",
  "lens": "demo_startup_reset_and_recovery",
  "severity": "major",
  "description": "The demonstration runs on hardware the delivery team does not own, and its availability before demo day is not yet confirmed in writing.",
  "blocking_point": "before_demo",
  "owner": "A. Nakamura",
  "status": "open"
}
```

An AI reviewer must not close that one. It needs a person to obtain a commitment.

---

## Step 5 — Ask the question

```bash
node cli/axiom.mjs handoff --project examples/HANDOFF-DEMO --mode Standard
```

```text
Verdict: READY TO BUILD, NOT READY TO DEMO

  YES  Contract Valid               no deterministic failures
  YES  Ready to Start Development   no recorded blocker
  YES  Ready to Integrate           no recorded blocker
  NO   Ready to Demo                blocked by HF-005, OA-001
  NO   Ready for UAT                blocked by HF-005, OA-001
  NO   Ready for Release            blocked by HF-005, OA-001

Open blockers by blocking point:
  before_demo
    - HF-005 [major] owner: A. Nakamura  (review finding)
    - OA-001 [action] owner: R. Silva  (HANDOFF.md open action)
  non_blocking
    - OA-003 [action] owner: A. Nakamura  (HANDOFF.md open action)

Score: 92 / 100
```

Two things worth noticing. The demo blockers come from **both** documents — the
review found one, the handoff sheet declares the other — and the score is not
100, because a project that blocks its own demonstration should not read as
perfect.

Both engineers start on step 1 today. The demonstration is achievable but contingent, and the contingency has a name and an owner and a date.

That sentence is the deliverable. Not the score.

---

## What to do with the answer

| Verdict | What it means on Monday |
|---|---|
| `BLOCKED` | A deterministic rule failed. Fix the contract before anyone starts. |
| `NOT READY TO BUILD` | An open critical finding blocks `before_build`. Resolve it first; starting now wastes the work. |
| `READY TO BUILD, NOT READY TO DEMO` | Start building. Assign the demo blockers to named people with dates, and re-check before you promise the date. |
| `CONTRACT VALID, NOT REVIEWED` | The structure is complete and nobody has read it for sense. Do that before treating it as ready. |
| `READY` | Contract complete, reviewed, nothing open. |

Re-run the gate whenever the sources change. The review goes stale with them, and `HANDOFF-010` will say so.

---

## Related

- [Handoff readiness](../concepts/handoff-readiness.md) — why the gate is shaped this way
- [Artifact map](artifact-map.md) — which document plays which role
- [Rule reference](../rules/) — `HANDOFF-001` to `HANDOFF-014`
