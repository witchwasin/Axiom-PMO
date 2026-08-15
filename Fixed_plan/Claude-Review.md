# Review — `Fixed_plan/master-plan.md` (Interpreter Migration to Node/TS)

**Reviewer:** Claude (Opus 5)
**Date:** 2026-08-15
**Reviewed at:** `28fcfbe` on `feat/migrate-interpreter-to-node-ts`
**Method:** every factual claim in the plan was checked against the repository on
disk. Reproduce commands are given with each finding.

---

## Verdict

**Do not execute Phases 1–10 as written.**

The document is well-constructed — clear invariants, an explicit rollback plan, an
accurate module inventory, and a self-correcting preamble. As a *handoff artifact* it
is above average.

As an *engineering decision* it is not yet justified, for five reasons, in order of
severity:

1. Its central premise — "the governance logic already lives in JSON, so the port is
   mechanical" — is wrong by roughly an order of magnitude. The real port surface is
   **24,181 lines of PowerShell**, not "machinery over a JSON rule engine."
2. The oracle it relies on covers **63 of 138 rules (46%)**. For the other 75, "the
   golden master proves equivalence" is simply not true.
3. `tests/` is described as "UNCHANGED … the oracle," but **9,636 of those lines are
   themselves PowerShell** — the thing being deleted.
4. The plan reverses a **decision already accepted on 2026-07-29** (ROADMAP Milestone
   3.5 non-goal: "Rewriting the validator in TypeScript or another language") without
   naming it, superseding it, or listing it in §13.
5. The cheaper option that removes the *entire* cited defect class — dropping Windows
   PowerShell 5.1 — is never evaluated, even though it is already scoped in the same
   ROADMAP.

A governance framework that bypasses its own decision record on its flagship change
loses the argument it is selling. Fix #4 before anything else, then re-decide.

---

## Evidence table

| Plan claim | Reality | Command |
|---|---|---|
| "very little governance logic outside the JSON" (§4.1) | 14,545 lines of PowerShell logic vs 2,733 lines of policy JSON, most of it English prose | `wc -l scripts/lib/*.ps1 scripts/*.ps1 pmo-config/*.json` |
| "~100 rules" (§4.1) | 138 rules | `python3 -c "import json;print(len(json.load(open('pmo-config/validation-rules.json',encoding='utf-8-sig'))['rules']))"` |
| "`pmo-config/` contains 17 files" (§4.1) | 16 | `ls pmo-config/ \| wc -l` |
| "`examples/` — 9 worked example projects" (§4.2) | 7 in `examples/` (+2 in `demo/`) | `ls examples/ \| wc -l` |
| "`tests/` UNCHANGED … the oracle" (§7) | 29 `.ps1` files, 9,636 lines | `find tests -name '*.ps1' -exec wc -l {} + \| tail -1` |
| "byte-for-byte identical" (§3, §8.1, §8.2, §10) | The golden comparator deliberately ignores BOM, indentation, EOL, `\uXXXX` escaping, path separators | `head -25 scripts/lib/golden-normalizer.ps1` |
| §6.3 module list (35 modules) | **Exact — 35/35, none invented, none missed** | `ls scripts/lib/*.ps1 \| wc -l` |
| §6.4 orchestrator list (12 named) | 25 exist under `scripts/` | `ls scripts/*.ps1 \| wc -l` |
| "validate-project.ps1 (219 lines)" | Correct | `wc -l scripts/validate-project.ps1` |
| Exit codes 0/1/2/64/127 | Correct | `head -20 cli/axiom.mjs` |

---

## Findings

### F1 — The load-bearing premise is false (§4.1, §6.2). Severity: critical

`validation-rules.json` is a **message-and-severity catalog**, not a rule engine.
Across all 138 rules the only fields that occur are:

```
severity: 138   description: 138   suggestion: 138   documentation: 70   lifecycle: 2
```

There is not one predicate, threshold, condition, or matcher in the file. `policy.json`
is 3.6 KB. Every question of *when a rule fires* — the actual governance semantics —
lives in PowerShell: 9,277 lines in `scripts/lib/` plus 5,268 in `scripts/`.

Two further data points against "the JSON is the source of truth":

- 15 rule ids are emitted by code with **no entry in the catalog at all**:
  `SECRET-001…006`, `BRANCH-001/002`, `COMMIT-001/002`, `LOCAL-PATH-001…003`,
  `OLD-NAME-001`, `OLD-URL-001` (from `scripts/check-public-hygiene.ps1`, which §6.4
  does not list as needing a port).
- 3 catalog rules are never referenced by any script: `DOCTOR-EXAMPLE`, `DOCTOR-HOOK`,
  `DOCTOR-STRUCT`.

**Why this matters:** §4.1 is the paragraph that makes the whole migration look
tractable. Remove it and the plan reads as "rewrite ~14.5k lines of behavioral code
whose specification exists only as that code." That may still be worth doing — but it
is a different decision, at a different cost, needing a different justification.

**Fix:** rewrite §4.1 honestly. The correct statement is: *rule identity, severity, and
remediation text are data; rule firing conditions are code and must be ported line by
line.* Then re-argue the decision on the true cost.

### F2 — The oracle covers 46% of the rule catalog (§4.2, §8.1). Severity: critical

63 of 138 rule ids appear in any golden master. 75 do not. Whole subsystems have
**zero** golden coverage:

| Subsystem | Rules with no golden | Backing PowerShell |
|---|---|---|
| Execution contract | `EXEC-001…008` (8) | 1,626 lines |
| Permission model | `PERMISSION-000…007` (8) | — |
| Adversarial review | `AREV-001…007` (7) | 570 lines |
| Guided research | `RESEARCH-001…007` (7) | 437 lines |
| Design provider | `DPROV-001…007` (7) | 410 lines |
| Doctor | all 17 `DOCTOR-*` | 758 lines |
| Scope diff | `SCOPE-DIFF-001…005` (5) | 504 lines (tests) |
| Externalization | `EXT-001…004` (4) | — |
| Change control | `CHANGE-001…003` (3) | — |
| Visual Proof | `VPROOF-001/002` (2) | 480 lines |

Reproduce:

```bash
python3 - <<'EOF'
import json,re,os
rules=set(json.load(open('pmo-config/validation-rules.json',encoding='utf-8-sig'))['rules'])
seen=set()
for r,_,fs in os.walk('tests/golden'):
    for f in fs:
        if f.endswith('.txt'):
            seen|=set(re.findall(r'\b[A-Z][A-Z-]*-\d{3}\b',open(os.path.join(r,f),encoding='utf-8',errors='replace').read()))
print(len(rules&seen),'of',len(rules),'covered')
EOF
```

Those 75 rules are not untested — they are covered by assertion-style PowerShell test
helpers (`tests/helpers/execution-contract-tests.ps1` alone is 2,060 lines). But that
means the oracle for more than half the catalog is *PowerShell test code*, not frozen
output. Phase 6's exit criterion ("zero differences across the full corpus") can go
green while half the governance surface has never been differentially compared.

**Fix:** make golden coverage a **Phase 0 prerequisite**, not an assumption. Capture
goldens for the uncovered 75 against the *current* PowerShell implementation before any
port begins. This is the single highest-value item in the entire plan — and it retains
its value if the migration is cancelled, because it hardens the shipped product.

### F3 — `tests/` cannot be both "unchanged" and PowerShell-free. Severity: high

§7 lists `tests/` as UNCHANGED and §9's Phase 9 deletes only `scripts/*.ps1` and
`scripts/lib/*.ps1`. But `tests/` is 9,636 lines of PowerShell across 29 files, plus
2 `.mjs`. After Phase 9 either:

- `pwsh` stays a hard dependency to run the test suite — the migration's stated goal is
  not achieved; or
- those 9,636 lines are ported too — and a test suite ported by the same agent that
  ported the implementation is **not an independent oracle**; both drift together and
  the golden masters are the only thing left standing (see F2: they cover 46%).

**Fix:** state the true total (24,181 lines), decide explicitly which tests are ported
vs. re-derived from goldens, and add "port `tests/`" as its own phase with its own risk
entry. Do not let it arrive as a surprise at Phase 9.

### F4 — The plan reverses an accepted decision without saying so. Severity: high (governance)

`ROADMAP.md`, Milestone 3.5 — *status: **accepted on 2026-07-29***:

> Non-goals: Rewriting the validator in TypeScript or another language. Dropping
> Windows PowerShell 5.1 before compatibility evidence supports it.

And Milestone 3: *"Do not rewrite the core validator in TypeScript during this
milestone."*

The plan proposes exactly the first non-goal and does not cite, quote, or supersede it.
§13 lists four open decisions — toolchain, settling window, doctor-rule deletion, branch
strategy — and omits the only one that actually gates the work.

Under this repo's own rules (`AGENTS.md` §8, logging policy; `AGENTS.md` guardrail 11)
reversing an accepted milestone non-goal is a business/architecture decision that
requires a recorded `DEC-###` by the Human Owner, with `source_ref` and
`evidence_status`. A markdown plan in an untracked folder is not that.

**Fix:** before Phase 0, raise `DEC-###` — "Supersede Milestone 3.5 non-goal: authorize
a Node/TypeScript reimplementation of the validator" — with the cost figures from F1
and the coverage figures from F2 attached as evidence. If the Human Owner declines, the
plan stops there, cheaply. That is the system working.

### F5 — The cheap alternative is never evaluated. Severity: high

The plan gives two reasons (§2). Examine each:

**Reason 2 — the `DOCTOR-010`/`DOCTOR-011` defect class.** This class exists *only*
because the code must satisfy Windows PowerShell 5.1 **and** 7 simultaneously. Dropping
5.1 removes the class completely: one CI leg deleted, `pwsh-host.ps1` simplified, two
doctor rules retired, documentation updated. Roughly one day. Zero validator lines
rewritten. The ROADMAP already frames this as gated on compatibility evidence, so the
decision is pre-scoped. The plan spends 24k lines of rewrite to reach the same outcome.

**Reason 1 — adoption tax.** Narrower than stated:

- `README.md:198` documents a **Node-free** PowerShell path. §2.1's "every user already
  has Node installed" is false for that segment, and the migration *adds* a Node
  requirement for them. The migration does not remove a runtime universally; it swaps
  which one, and reverses the direction of the tax for Windows/enterprise users.
- `README.md:247`: GitHub-hosted runners already ship PowerShell, so the Action has
  **zero** install cost today.

The residual, real pain is local macOS/Linux development — one genuine friction point,
which is a **distribution** problem before it is an implementation-language problem.

**Fix:** add a §4.0 "Alternatives considered" with at least: (a) drop 5.1, keep
PowerShell 7 only; (b) ship a prebuilt binary / container / `npx` shim so no runtime is
installed by hand; (c) full port. Show why (c) beats (a) and (b) on the numbers from
F1. If it does not, the honest answer is (a) now and (c) never.

### F6 — Distribution and build model is undecided, and it outranks the toolchain question. Severity: high

There is **no `package.json` anywhere in the repository**. No `node_modules`, no build
step, no dependency manifest. Today `.ps1` runs from a bare checkout.

TypeScript requires compilation. §5 forbids publishing an npm package. So how does a
user run the validator from a fresh clone? The plan never says. The options are
materially different:

| Option | Consequence |
|---|---|
| Commit compiled JS | Review burden, generated-code diffs, drift between `src/` and `dist/` |
| `npm ci && npm run build` | Replaces `brew install powershell` with a build step — arguably a *worse* tax, and strictly worse for the GitHub Action, which needs nothing today |
| Plain `.mjs` + JSDoc types | No build, no packaging change — but then §4.4's TypeScript argument evaporates |

**Fix:** promote this to §13 decision #1, above the `tsc`/`vitest` question. Until it is
answered, "adoption tax removed" is unproven — and it is the plan's primary benefit.

### F7 — "Byte-for-byte" is not what the oracle checks (§3, §8.1, §8.2, §10). Severity: medium

`scripts/lib/golden-normalizer.ps1` exists precisely because byte comparison was
unusable across hosts. It deliberately ignores: UTF-8 BOM, indentation, CRLF/LF,
`\uXXXX` escaping of `' < &`, and path separators. What it *does* compare: ordered
result sequence, every `rule_id`, `level`, `blocking` flag, message text, every summary
counter, and the child exit code.

So the achievable and correct claim is **canonical-form equivalence**, not byte
equivalence. Leaving "byte-for-byte" in place sends the next agent chasing formatting
parity the repo already decided is not part of the contract.

Related: every golden is a JSON dump. There is **no `-Format Text` golden**. §8.2's
text comparison must be built by the harness, not reused — so §4.2's "the oracle
already exists" is only half true.

### F8 — Persisted digests are a frozen contract the plan omits. Severity: medium–high

`scripts/lib/artifact-hash.ps1` defines a canonical SHA-256: decode strict UTF-8, strip
one BOM, normalize CRLF/CR to LF, re-encode without BOM, hash — with an extension
allowlist and raw-byte hashing for anything else.

Those digests are **persisted in user artifacts** already shipped in `examples/`:
`HANDOFF-REVIEW.json`, `DESIGN/VISUAL-REVIEW.json`, `INPUT-MANIFEST.json`, `REVIEW.json`
— fields `digest`, `combined_digest`, `manifest_digest`, `outputs_digest`.

If the Node port computes any of these even slightly differently — extension list,
combined-digest ordering (which routes through `ordinal-sort`), the join separator —
then **every existing project's recorded review evidence goes stale on upgrade**. And
the rules that verify them (`DPROV-*`, `VPROOF-*`) are in the 75 with no golden (F2).

§8.4's invariant list omits digests entirely. §6.4 omits `design-provider-digest.ps1`,
`handoff-digest.ps1`, and `visual-proof-digest.ps1` from the port scope.

**Fix:** add digest canonicalization to §8.4 as a named invariant, with a dedicated
fixture set (LF vs CRLF, BOM vs no BOM, binary, unknown extension, multi-file combined
digest) verified before Phase 4.

### F9 — §6.4 covers 12 of 25 orchestrators. Severity: medium

Missing from the port scope: `aggregate-diagnostics`, `build-plugin-package`,
`capture-plugin-load-evidence`, `check-public-hygiene`, `ci-profile`,
`design-provider-digest`, `handoff-digest`, `hook-scope-advisory`, `measure-context`,
`prepare-public-release`, `run-ci-suite`, `update-source-snapshot`,
`visual-proof-digest`.

Several are load-bearing: `run-ci-suite` and `ci-profile` are what CI actually invokes;
`check-public-hygiene` owns 15 rule ids that exist nowhere else; the three digest
scripts own F8. The §6.3 module inventory is exact — §6.4 should be brought to the same
standard.

### F10 — No sizing, and the phase shape is a big-bang rewrite. Severity: medium

Ten phases, zero estimates, against 24,181 lines. Phase 6 — the hard gate — cannot be
reached until Phases 2–5 are essentially complete, so **no value ships until ~80% of the
work is done**.

§2.3 pre-empts the "two implementations drift" objection, but that is not the real risk.
The real risk is **abandonment at 60%**, leaving a half-ported `src/` that nobody trusts
and a PowerShell implementation nobody maintains. The §11 mitigation for exactly this
row is "phases are gated," which does not mitigate it — gating makes a stall more
likely, not less.

**Fix:** re-order by *value delivered*, not by dependency depth. Pick one leaf validator
(`scope-diff-validator`, ~5 rules, self-contained, git-backed), port it end to end —
implementation, tests, differential check, CI — and land it green with both
implementations live for that one validator. Then the next. If the effort stops after
three, three validators are in Node, nothing is broken, and no revert is needed. That
also converts §12's rollback from "revert the branch" to "there is nothing to roll
back."

---

## Smaller corrections

- §4.1 "~100 rules" → **138**.
- §4.1 "`pmo-config/` contains 17 files" → **16**.
- §4.2 "9 worked example projects" → **7** in `examples/`, plus 2 in `demo/`.
- §6.3 contains a phantom row, "`markdown-table-parser` deps", which is not a module.
- §8.4 says exit code `2` is "`-FailOnWarning` with blocking WARN" — correct, but note
  the catalog carries a distinct `fail_release` severity on 10 rules; confirm the port
  reproduces its gate-conditional behavior, which is not a plain FAIL.

---

## What the plan gets right

Stated plainly, because it should survive the rewrite:

1. **§6.3 is exact.** All 35 modules, correctly named, sensibly grouped, nothing
   invented. Most plans of this kind fail here.
2. **"Never edit a golden master to make the port pass"** (§11, §14) is the correct
   prime directive and is stated twice.
3. **§8.4's invariant list** (exit codes, BOM handling, ordinal collation, path
   containment) names the real silent-breakage sites. It is incomplete (F8) but the
   instinct is right.
4. **§12's rollback plan** is genuinely thought through, including the
   after-deletion case.
5. **The preamble** — "if this conflicts with the repository on disk, the code on disk
   wins" — is exactly the right instruction to give a downstream agent.

---

## Recommended path

1. **Record the decision.** Raise `DEC-###` superseding ROADMAP Milestone 3.5's
   non-goal, with F1's cost figures and F2's coverage figures as evidence. Human Owner
   decides. Nothing else starts first. *(Cost: hours. Removes F4.)*
2. **Take the cheap win regardless.** Drop Windows PowerShell 5.1 → the entire
   `DOCTOR-010`/`DOCTOR-011` class disappears. Then measure whether the residual pain
   still justifies a 24k-line rewrite. *(Cost: ~1 day. Addresses the plan's reason #2 in
   full.)*
3. **Raise the oracle to ~100% coverage** against the *current* implementation, before
   any port. Valuable whether or not the migration proceeds. *(Cost: days. Removes F2,
   and is the prerequisite that makes any future port provable.)*
4. **Decide distribution** (F6) — compiled artifact, container, or `npx` shim. This, not
   the language, is what determines whether the adoption tax actually falls.
5. **Only then**, if the numbers still favor it, restructure the port as an incremental
   strangler per F10 — one validator at a time, each landing green.

Steps 2–4 deliver most of the stated benefit at a small fraction of the cost, and each
one is independently useful if step 5 never happens. That is the test a migration plan
of this size has to pass, and the current draft does not pose it.

---

## Scorecard

| Dimension | Score | Note |
|---|---|---|
| Document quality / handoff clarity | 8/10 | Well-structured, self-contained, correctly instructs the next agent |
| Factual accuracy about the codebase | 4/10 | Module inventory exact; premise, oracle strength, and scope totals materially wrong |
| Governance compliance (this repo's own rules) | 2/10 | Reverses an accepted decision silently; no `DEC-###`, no `source_ref`, no `evidence_status`, no RAID entry |
| Risk analysis | 5/10 | Right instincts, misses digests, test-suite port, and distribution; the top risk is mis-mitigated |
| Execution plan realism | 3/10 | No sizing against 24k lines; big-bang shape with no value delivered before ~80% |
| **Overall as a decision to execute** | **Not approved** | Fix F4 first, then re-decide on true numbers |
