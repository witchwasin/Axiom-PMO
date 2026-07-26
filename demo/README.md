# Three-minute demo

```bash
node cli/axiom.mjs demo
# or, without Node:
pwsh -NoProfile -File scripts/demo.ps1
# or:
make demo
```

Runs in a couple of seconds. Everything it prints is real validator output.

## What it shows

Two synthetic projects. Both have a `PROJECT.md`, a design, a work-item board, and an approved Design Ready gate. Both pass every gate Axiom-PMO 1.0 could run.

One of them cannot be built on Monday morning.

| | |
|---|---|
| [`broken-project/`](broken-project) | Fails the Handoff gate on five findings |
| [`fixed-project/`](fixed-project) | Passes, and still reports that it is not ready to demonstrate |

## The five findings

Each one is drawn from a real handoff failure pattern, and each is provable from the documents alone.

| Rule | What is wrong | What it costs |
|---|---|---|
| [HANDOFF-004](../docs/rules/HANDOFF-004.md) | The shared schema every other item reads from is scheduled last | Two engineers spend day one building against a table that does not exist |
| [HANDOFF-012](../docs/rules/HANDOFF-012.md) | The scan flow needs the rear camera and the serving model is still `open` | Works on the developer laptop, fails on the demo tablet, and no code review catches it |
| [HANDOFF-011](../docs/rules/HANDOFF-011.md) | A data element the author marked sensitive has no classification decision | A privacy commitment in one document contradicts a feature in another |
| [HANDOFF-007](../docs/rules/HANDOFF-007.md) | An acceptance case has no seed data | The case cannot be reached from the demo dataset, so it is never actually run |
| [HANDOFF-003](../docs/rules/HANDOFF-003.md) | A work item is owned by "Dev Team" | Nobody starts it |

## The part people miss

The fixed project passes every deterministic check and still reports:

```text
Verdict: READY TO BUILD, NOT READY TO DEMO

  YES  Contract Valid
  YES  Ready to Start Development
  YES  Ready to Integrate
  NO   Ready to Demo
  NO   Ready for UAT
  NO   Ready for Release
```

Its semantic review has an open finding about a demo device the delivery team does not own. That blocks the demonstration. It does not stop anyone writing code today, so the gate does not pretend it does.

A single pass/fail answer would have to choose between stalling a team that could be working and promising a demonstration that will not happen.

## Sources

Everything under `broken-project/source/` and `fixed-project/source/` is synthetic. No real customer, person, system, or meeting.

## Recording a terminal cast

`scripts/demo.ps1 -Plain -NoPause` prints the same transcript with no pauses and no timing, which is the form to record:

```bash
asciinema rec demo.cast -c "pwsh -NoProfile -File scripts/demo.ps1 -Plain -NoPause"
```

No recording is committed to this repository. The command above is the reproducible way to make one; nothing here claims an asset that does not exist.
