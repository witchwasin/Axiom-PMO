# Risk-based CI (fast / targeted / full)

This document is the permanent source of reference for the risk-based CI in
`.github/workflows/pmo-checks.yml`. It replaces "run every suite on every host
on every change" with three profiles, chosen by the risk of the change rather
than by habit. The rule of thumb: **run the cheapest profile that still covers
the real risk, and never claim more evidence than that profile produced.**

---

## Why this exists

The old workflow ran the full multi-host matrix
(`pmo-checks-windows-pwsh7`, `pmo-checks-linux-pwsh7`, `pmo-checks-macos-pwsh7`,
plus a Windows PowerShell 5.1 `pmo-checks` job before the PowerShell reference
was deleted) plus three dogfood jobs on every pull request and every push. That is correct
but expensive, and it was tempting to skip or cancel it. Risk-based CI keeps the
same full gate for the moments that need it — merge/release and high-risk
changes — and trades the rest of the time for a cheaper, still-honest check.

Two hard boundaries, taken from the plan that introduced this:

1. **Never claim Definition of Done or cross-host compatibility without
   evidence from the host that claim needs.** A local run is not cross-host
   evidence, and a `targeted` run on one host is not `full`.
2. **Never let a path filter silently skip a validator or configuration
   change.** The classifier escalates anything it does not recognise one level
   up, and the high-risk set escalates straight to `full`.

---

## The three profiles

| Profile | When | Scope |
|---|---|---|
| `fast` | Ordinary work, docs, reports, small fixes | Doctor, hygiene, example goldens, plugin mirror drift, CLI — one Linux host |
| `targeted` | Code in a known area | `run-all-checks` + hygiene + fault injection on only the relevant host(s) |
| `full` | Merge/release gate, or a high-risk change | Every required host + the three dogfood jobs (unchanged from before) |

`full` runs the three OS legs — `pmo-checks-windows` (windows-2025),
`pmo-checks-linux` (ubuntu-24.04), `pmo-checks-macos` (macos-15) —
plus `dogfood-github-action`, `dogfood-scope-diff`, and
`dogfood-ci-check-evidence`. None of the legs runs PowerShell anymore (the
PowerShell reference was deleted in Phase 9 — each leg proves the Node engine
works end to end on its OS; the historical `pwsh7` job id suffix was dropped
in Phase 10). Risk-based CI did not widen or narrow `full`; it only changed
how often `full` is selected automatically.

---

## How the profile is chosen

One job, `determine-profile`, resolves the profile and hands it to every other
job through job outputs:

* **`workflow_dispatch`** — the caller names a profile explicitly via the
  `profile` input (plus optional `suite` and `host` for `targeted`).
* **`push` to `main`** — always `full`. A push to main is the merge/release
  gate.
* **`pull_request`** — classified from the changed paths by
  `dist/tools/ci-profile-cli.js` (`src/tools/ci-profile.ts`). If the diff
  cannot be resolved, the resolver fails safe to `full` rather than silently
  `fast`.

The path-to-profile mapping lives in **one place**: `src/tools/ci-profile.ts`,
and is covered by `node --test dist/tools/ci-profile.test.js`. Do not
reimplement the mapping in YAML or in prose; the classifier is the source of
truth and the test is what keeps it honest.

---

## Branch protection: what a "required check" means now

**GitHub reports a skipped job as success for required status checks.** Every
job below `determine-profile` is gated on the resolved profile, so on a `fast`
or `targeted` pull request the four host jobs never run — and branch protection
sees them as satisfied, not pending.

That is the trade this design makes deliberately, not a defect: the full matrix
moves off *every* pull request and onto the merge/release gate (`push` to
`main`, always `full`) plus high-risk pull requests (which classify as `full`
before merge). But it silently changes what a pre-existing required check
proves, so whoever administers the repository settings should know:

* Require **`determine-profile`**. It is the only job with no `if:` condition,
  so it runs on every event, cannot be vacuously satisfied, and reports its own
  failure directly — which is exactly why it, and not a downstream host job, is
  the check to require.
* Do **not** read `pmo-checks` (or any host job) as evidence that a pull request
  ran on that host. On a `fast` pull request it was skipped, and skipped reads
  as green.
* When a change must be proven on a host *before* merge, the mechanism is the
  high-risk set below — which forces `full` — not branch protection.

Configuring required checks is a repository setting and therefore a human
action; this document does not claim it has been done.

---

## Path → suite / host mapping

The minimum for each area (the classifier escalates when in doubt — it never
escalates down):

| Area changed | Minimum suite | Minimum host |
|---|---|---|
| `cli/**`, `tests/helpers/cli-tests.mjs`, `tests/helpers/github-action-tests.mjs` | CLI tests | Linux |
| `scripts/**` (except the high-risk set below) | relevant suite + doctor | Windows |
| `tests/**` (except the CLI tests above) | relevant mutation suite | Windows |
| `pmo-config/**`, `templates/**`, generator | config mutation + generator/E2E | Windows |
| `examples/**`, `demo/**` | validation fixtures | Linux |
| `.claude/**`, `skills/**`, `hooks/**` | plugin mirror drift | Linux |
| `docs/**`, top-level `*.md` | markdown / public hygiene | no cross-host by default |

The **high-risk set → `full`**, always:

* `.github/workflows/**`
* `action.yml`
* `src/**`, `dist/**` (the Node engine and its ports)
* `scripts/**` (the remaining CI control plane: wrappers, canary baseline, Action)
* `package.json`, `package-lock.json`, `tsconfig*` (the Node interpreter/runtime surface)

The first classifier entry closes a loop that would otherwise be open. A
`pull_request` classifies its own diff with the **merge commit's** copy of the
classifier (`src/tools/ci-profile.ts`), so an edit to the classifier classifies
itself. Were it merely `targeted`, a change that weakened the mapping — sending
`src/**` to `fast`, for instance — would select `fast` for itself, skip the
full checks, and so skip `node --test dist/tools/ci-profile.test.js`, the one
test that guards the mapping. At `full` the guard always runs.

Encoding, line-ending, path, junction, and native-command code usually lives in
`src/**` (→ `full`) or in `src/output/line-ending.test.ts` (→ `targeted` on
Windows). When a change is in a shared library that every host depends on, it
is high risk regardless of which file the diff happened to touch.

---

## Fast checks (run before dispatching CI)

An executor should run these cheap local-equivalent checks before dispatching
CI, and record the command, result, and commit SHA — never just the word
"passed":

| Check | Command |
|---|---|
| Framework doctor | `node cli/axiom.mjs doctor` |
| Public hygiene | `node dist/tools/run-ci-suite-cli.js -Suite hygiene -RepoPath .` |
| Example + fixture goldens | `node dist/tools/run-ci-suite-cli.js -Suite validation-fixtures -RepoPath .` |
| Plugin mirror drift | `node dist/tools/run-ci-suite-cli.js -Suite plugin-drift -RepoPath .` |
| CLI | `node tests/helpers/cli-tests.mjs` |

`node dist/tools/run-ci-suite-cli.js` runs any one of these (and more) by name
for a `targeted` dispatch; its whitelist is closed — an unknown suite name is
an error, never a silent no-op.

---

## Dispatch rules

1. Do not re-dispatch `full` just because a job is slow; check first whether the
   failure is a code failure, an environment failure, a timeout, or a runner
   issue.
2. If a job hangs or runs long, stop and record the status — do not loop
   automatically.
3. Start with `targeted` on the relevant host before escalating.
4. Use `full` only when `targeted` has passed **and** the change is in the
   high-risk set, or it is a release gate.
5. If a host cannot be run, record the host and the reason as **pending
   evidence** rather than silently omitting it.

---

## Evidence split

Every report must keep these three tiers separate:

1. **Local verified** — ran on the executor's machine.
2. **Targeted CI verified** — ran on the selected host/suite.
3. **Full cross-host verified** — ran the required matrix on the same commit.

Tier 1 or 2 is never evidence for tier 3. CR-021 (cross-host CI evidence) cannot
be closed with a local run. A cancelled or partial run is not a pass.

---

## Keeping this correct

* The mapping is implemented in `src/tools/ci-profile.ts` and guarded by
  `node --test dist/tools/ci-profile.test.js`. A silent edit that widens or
  narrows the mapping fails the suite.
* Fault injection is still asserted on `full` and `targeted` — a run that
  swallows a child failure cannot go green.
* When in doubt about a path, escalate one level. Prefer a slightly more
  expensive profile over a claim the evidence does not support.
