# Testing

Everything runs on the Node engine in-process (`node cli/axiom.mjs`, TypeScript
compiled to `dist/`). There is no separate runtime and no host to select — the
same suite runs identically on Windows, Linux, and macOS, which is what the CI
matrix proves.

## Main Commands

Run all checks (doctor, fixture matrix + golden masters, plugin mirror drift,
example validations, CLI tests, GitHub Action tests, unit suite):

```bash
node cli/axiom.mjs check
```

Run framework doctor only:

```bash
node cli/axiom.mjs doctor
```

Run project validator:

```bash
node cli/axiom.mjs validate --project examples/STANDARD-FEATURE --mode Standard --gate Release --fail-on-warning
```

Run fixture tests (positive/negative matrix + golden master):

```bash
node dist/tools/run-ci-suite-cli.js -Suite validation-fixtures -RepoPath .
```

Run the Handoff gate and readiness assessment on the worked example:

```bash
node cli/axiom.mjs validate --project examples/HANDOFF-DEMO --mode Standard --gate Handoff --fail-on-warning
node cli/axiom.mjs handoff --project examples/HANDOFF-DEMO --mode Standard
```

`make check` runs the same aggregate pass, and the individual `make` targets
(`test`, `validate`, `mutation`, `contract`, `eol`, `assess`, `e2e`, `cli`) map
one-to-one onto the commands below.

## Cross-platform behavior

The engine is pure Node.js, so there is no host-resolution step and no
PowerShell compatibility matrix. CI still runs the full profile on Windows,
Linux, and macOS (`pmo-checks-windows`, `pmo-checks-linux`,
`pmo-checks-macos` in `.github/workflows/pmo-checks.yml`), and a test that
cannot run on a given host must say so rather than passing
silently.

## Validation Rules

Rules are cataloged in `pmo-config/validation-rules.json`.

Each validator output includes:

- `schema_version`, `level`, `rule_id`, `message`, `blocking`
- `artifact`, `item_id`, `field` — where the finding is
- `suggestion`, `documentation_url` — what to do about it

The full contract, its compatibility policy, and the sensitive-data rules are in
[`docs/reference/diagnostics-contract.md`](docs/reference/diagnostics-contract.md).
`node --test dist/output/diagnostics-contract.test.js` (`make contract`) asserts
the shape of every row the validator emits, independently of which findings any
particular fixture produces.

JSON output:

```bash
node cli/axiom.mjs validate --project examples/STANDARD-FEATURE --mode Standard --gate Release --fail-on-warning --json
```

## Fixture Policy

Positive examples must pass.

Negative fixtures must fail with the expected rule ID and expected level. The
runner prints the current positive/negative/doctor-negative matrix on every run;
read it from there rather than from this page, which will drift.

A negative fixture must isolate its rule. When a mutation trips a second,
unrelated rule, either narrow the mutation or list the extra rule in
`AllowedSecondaryRules` — never leave it implicit.

## Golden Master

The fixture matrix (`node dist/tools/run-ci-suite-cli.js -Suite validation-fixtures -RepoPath .`)
always verifies every case's stdout against its committed golden master under
`tests/golden/`. Run it before and after any change to `src/rules/**`,
`src/exec/**`, or `pmo-config/*.json` — any diff is a behavior change and must be
reviewed, not silently re-captured.

`node cli/axiom.mjs check` already passes `-VerifyGolden` for the fixture matrix
and separately verifies the example and probe goldens. Both happen inside the
single fixture pass on purpose: running the matrix is the most expensive thing
this suite does, and verifying goldens re-executes every case, so doing it as a
second step doubles the cost for no extra coverage.

Comparison is canonical, not byte-exact: `src/output/canonical-normalizer.ts`
folds away the UTF-8 BOM, line endings, JSON indentation, numeric character
escapes, and path separators, because none of those are part of the diagnostic
contract. Rule ids, levels, blocking flags, message text, summary counters, and
exit codes are still compared exactly. Golden files are stored in that canonical
form, so a capture on any OS produces identical bytes.

## Config Mutation Tests

```bash
node --test dist/tools/config-mutation.test.js
```

Proves `pmo-config/*.json` is the real source of truth (not a hardcoded fallback) by
mutating each config file and asserting the validator/doctor fails on the *specific*
expected rule ID, not just a non-zero exit code.

## End-to-End Tests

```bash
node --test dist/tools/e2e.test.js
```

Each generates a real project with `axiom init` (`src/tools/new-project.ts`),
fills it in deterministically (`src/tools/e2e.test.ts` — not by copying an example
project over the generator's output), and validates it through every gate. The
suite covers Lite, Standard, Strict, and Handoff runs.

The Handoff case additionally asserts two things the others cannot: that a freshly
generated, unfilled handoff scaffold **fails** the Handoff gate (a generator that
emitted a passing handoff would be manufacturing evidence), and that changing the
sources changes the Source Snapshot digest so the recorded review is reported as
stale.

## Other Suites

```bash
node --test dist/markdown/files.test.js          # doctor-markdown: discovery, encoding, local links
node --test dist/tools/config-mutation.test.js   # config is source of truth
node --test dist/output/diagnostics-contract.test.js
node --test dist/output/line-ending.test.js
node --test dist/tools/assess-handoff.test.js
node --test dist/tools/visual-proof.test.js
node --test dist/tools/demo-smoke.test.js
node --test dist/tools/scope-diff.test.js
```

```bash
node tests/helpers/cli-tests.mjs
node tests/helpers/github-action-tests.mjs
```

| Suite | Proves |
|---|---|
| doctor-markdown | Markdown discovery excludes binary files, reads UTF-8 consistently, resolves encoded paths, and reports invalid local targets without terminating |
| diagnostics-contract | Every emitted diagnostic matches `pmo-config/diagnostics-schema.json`, carries remediation on WARN/FAIL, and does not echo artifact content |
| line-endings | Regexes, digests, and golden comparison behave identically on a CRLF (Windows) and an LF checkout |
| cli | Exit codes propagate unchanged, `handoff --json` is one parseable document, and no validation logic has leaked into JavaScript |
| handoff-assessment | Stage verdicts stay separate, and every score cap actually binds |
| visual-proof | Visual Proof stays conditional for legacy handoffs and, when activated, requires current human-review evidence, correct capture paths/hashes, and a named decision owner |
| demo-smoke | The demo's narration matches its real output, and it finishes well inside three minutes |
| github-action | The Action wrapper's annotation escaping, path-outside-workspace fallback, exit-code-to-outcome mapping, and report-only-vs-enforce behavior all hold, including against a missing runtime and malformed validator output. Also covers SCOPE-DIFF's Action-layer behavior: ref resolution precedence (explicit input > pull_request event > unresolved), infra-class SCOPE-DIFF-003/004 always propagating regardless of enforce, and output plumbing |
| scope-diff | SCOPE-DIFF's core matching logic against small disposable git fixtures: include/exclude precedence, added/modified/deleted/renamed files, path normalization, missing/invalid scope declarations, unresolvable git refs, empty diffs, and repo-wide exemptions -- run through `node cli/axiom.mjs validate` exactly as a real caller would, not by calling internals directly |

All of these run as part of `node cli/axiom.mjs check`.
