# Contributing to Axiom-PMO

Thank you for helping improve Axiom-PMO. This project is a **governance control
plane**: its value depends entirely on its checks being trustworthy. The single
most important contribution rule follows from that.

> **Do not weaken governance to make a test pass.**
> Do not turn a blocking failure into a warning, delete a rule, loosen a policy,
> or edit a user-owned source document just to get to green — unless the change
> is an intentional, documented policy decision with a clear risk rationale.
> Reviews will reject changes that reduce validation strictness without that
> justification.

## Project philosophy

- **Deterministic over persuasive.** Rules are enforced by validators that exit
  non-zero, not by asking an agent nicely.
- **Evidence over assertion.** Requirements, decisions, tests, and release
  claims must carry a source reference and an evidence status.
- **Human authority is non-negotiable.** No automation may commit, push, tag,
  deploy, or approve a release on its own.
- **Smallest process that controls the real risk.** Lite/Standard/Strict exist
  so governance scales down as well as up.

## Development environment

- **Node.js 18+.** The entire engine — validators, rules, tools, doctor — runs
  in-process. TypeScript in `src/` compiles to `dist/`; there are no runtime
dependencies (dev-only packages are listed in `package.json`).
- Optional: `make` for the convenience targets. Lint is not enforced by CI.

## Run every check

```bash
node cli/axiom.mjs doctor
node dist/tools/run-ci-suite-cli.js -Suite validation-fixtures -RepoPath .   # fixture matrix + golden verify
node cli/axiom.mjs check
```

Or, with `make`: `make check`. Everything must exit 0 before you open a PR.

## How to add a validation rule

1. **Emit it** from the relevant validator in `src/rules/**`, `src/exec/**`, or
   `src/doctor/pmo-doctor.ts` via `addResult(level, message, ruleId)` (or the
   equivalent accumulator). Levels: `PASS`, `INFO`, `WARN`, `FAIL` (and the
   release-only `fail_release` severity is expressed in the catalog).
2. **Register it** in `pmo-config/validation-rules.json` with a `severity`, a
   `description`, and a **`suggestion`**. `DOCTOR-007` reconciles emitted rule
   ids against the catalog in **both** directions — a rule you emit but don't
   register, or register but never emit, fails the doctor. `DOCTOR-008` fails
   any fail/warn rule with no suggestion: a diagnostic that says what broke but
   not what to do is the failure mode the diagnostics contract exists to
   prevent.
3. **Write a doc page** if the rule is actionable enough to deserve one, and
   point `documentation` at it (`docs/rules/<RULE-ID>.md`). `DOCTOR-009` fails
   when the path does not resolve, so a diagnostic can never advertise a dead
   link. A rule page answers four things: what is checked, why it blocks, **what
   the validator deliberately does not decide**, and how to fix it.
4. **Pass location context.** `addResult` accepts artifact, item id, and field
   context. Supply them wherever the check knows them; a
   consumer annotating a pull request needs the file and row, not just a
   message.
5. **Decide severity deliberately.** `info` never blocks; `warn` blocks only
   under `-FailOnWarning`; `fail` always blocks; `fail_release` blocks a Release
   gate. Prefer the least severe level that still controls the risk — but do not
   downgrade an existing blocking rule without a documented reason.

### Line endings are part of the contract

`.gitattributes` marks `*.md`, `*.puml`, `*.csv`, and `*.json` as text, so a
Windows checkout has CRLF and a Linux or macOS checkout has LF. Two consequences
that have already caused a red CI leg:

- **Never anchor `(?m)$` against raw file content** without tolerating a
  carriage return. .NET matches `$` immediately before `\n` and never before the
  `\r` of a `\r\n` pair, so `^<[^>\r\n]+>$` silently matches nothing on
  Windows. Write `\r?$`, or `\s*$`, or split on `"\r?\n"` first and match the
  lines.
- **Anything hashed must normalize line endings first**, or the same content
  produces different digests on different platforms.

`node --test dist/output/line-ending.test.js` asserts both properties. Run `make eol`.

### Rules must not guess

A rule may check that a declaration is present, complete, resolvable, and
internally consistent. It may **not** infer domain meaning — that a photograph is
personal data, that a stock feature needs a receive operation, that a scanner
needs a secure context. Those are true in some domains and wrong in others, and a
validator that guesses wrong teaches people to ignore it.

Judgement of that kind belongs to the semantic review layer, recorded in
`HANDOFF-REVIEW.json`. See
[handoff readiness](docs/concepts/handoff-readiness.md) for the boundary.

## How to add fixtures

Fixtures live in `tests/fixtures/` (`valid-*` = positive, `invalid-*` =
negative), with doctor negatives in `tests/doctor-fixtures/`. Every new rule
needs **both** a positive fixture (the rule passes when it should) and a
**negative fixture** (the rule fires when it should).

1. Create the fixture project directory with the minimal files to exercise the
   rule.
2. Add a case row to the fixture matrix (or `DOCTOR_CASES`) in
   `src/tools/validation-fixtures.ts`: `Name`, `Path`, `Mode`, `Gate`,
   `ShouldPass`, `Rule`, `ExpectedLevel`, `Type`, plus optional `FailOnWarning`,
   `AllowedSecondaryRules`, `ForbiddenRules`.
3. **Isolate the rule.** A negative fixture should fire the rule under test and
   nothing else. When a mutation trips an unrelated rule too, either narrow the
   mutation or list the extra rule in `AllowedSecondaryRules` — never leave it
   implicit.
4. A negative fixture that must not ship a real secret still needs its sensitive
   file — see the scoped `.gitignore` negation for the synthetic `Quotation.xlsx`
   placeholder as the pattern to follow.

## How to update golden outputs safely

Golden masters make behavior changes visible. Only regenerate them when the
behavioral change is **intentional and reviewed**.

- Fixture-matrix goldens live under `tests/golden/` and are verified on every
  run — `node dist/tools/run-ci-suite-cli.js -Suite validation-fixtures -RepoPath .`
  (the PS-era one-shot `-CaptureGolden` switch is intentionally not ported:
  goldens are updated deliberately, in a reviewed diff, not re-captured).
  Paths are normalized to `<REPO_ROOT>` for portability.
- Example and probe goldens (`tests/golden/probes/*.json`, `tests/golden/*.txt`)
  are verified the same way from `node cli/axiom.mjs check` and the probe
  binaries (`node dist/probe/*.js`).
- Comparison is canonical, not byte-exact: `src/output/canonical-normalizer.ts`
  folds away the BOM, line endings, JSON indentation, numeric character escapes,
  and path separators, because those are not part of the diagnostic contract.
  Rule ids, levels, blocking flags, messages, counters, and exit codes are still
  compared exactly.
- **Review before you capture.** Diff the current output against the stored
  golden and confirm every change is the one you intended. The useful question is
  narrower than "did anything change": *did any FAIL or WARN row change?* A diff
  confined to PASS rows is a reporting change; a changed FAIL row is a behavior
  change and needs its own justification.
- In your PR, **explain the diff**: which rule changed, why, and confirm no rule
  was silently downgraded. A golden diff with no rationale is a red flag.

## How to add a mode or policy

Modes, gates, statuses, evidence statuses, strict triggers, approval roles,
approval checkpoints, table schemas, and git-authority live in
`pmo-config/policy.json`; the Mode×Gate artifact matrix in
`pmo-config/artifact-policy.json`; handoff artifacts, review lenses, blocking
points, owner tokens, build-spec sections, and readiness scoring in
`pmo-config/handoff-policy.json`.

Because these files are load-bearing, add or extend a scenario in
`src/tools/config-mutation.test.ts` proving that mutating your new policy
actually changes validator behavior — a policy no test can move is decoration.

No hardcoded fallbacks. If a config file is missing or malformed the validator
must fail, not guess.

## Pull-request expectations

Use the PR template. In particular:

- Tests added, including a **negative** fixture for any new rule.
- A `suggestion` for any new fail/warn rule, and a `docs/rules/` page where the
  rule is actionable.
- Golden diffs reviewed and explained, with FAIL/WARN changes called out
  separately from PASS-only changes.
- No validation weakening (or an explicit, justified policy decision).
- Docs updated when behavior or configuration changed.
- No private data (paths, handles, secrets, customer material).
- Compatibility with the interoperability model considered where relevant.

Keep commits focused and messages descriptive. This project does not accept
pushes or merges performed by automation without a human in the loop.

## AI-assisted contributions

AI-assisted changes are welcome, but:

- **Disclose them.** Note in the PR that the change was AI-assisted and which
  parts.
- **A human must review them.** Do not submit unreviewed generated output.
- **Generated evidence is not automatically trusted.** Test results, approvals,
  and release claims produced by an agent are candidate evidence until verified —
  the same rule the framework applies to project work applies to its own code.

## Security

Please report vulnerabilities privately as described in
[`SECURITY.md`](SECURITY.md). Do not open a public issue for a security problem.

## License

By contributing, you agree that your contributions are licensed under the
project's [MIT License](LICENSE).
