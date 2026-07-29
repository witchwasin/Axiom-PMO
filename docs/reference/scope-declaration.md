# Scope declaration (SCOPE-DIFF)

SCOPE-DIFF compares a pull request's actual changed files against a
project's pre-approved implementation scope. It answers exactly one
question, deterministically:

> **Did this change stay inside the file paths that were approved for it?**

It does **not** answer "is this code correct," "does this satisfy the
requirement," or "was this the right implementation." Those are separate
questions this check makes no attempt to judge — SCOPE-DIFF can pass on
code that is wrong, and fail on code that is excellent but touched the
wrong files. Keep both checks; they cover different risks.

Opt-in and gate-independent: SCOPE-DIFF only runs when both a base and a
head commit are supplied (`-ScopeDiffBase`/`-ScopeDiffHead` on
`scripts/validate-project.ps1`, or `enable-scope-diff: true` on the GitHub
Action). Every existing invocation that does not supply them is completely
unaffected — this is additive to the validator and the Action, not a
replacement for anything.

## `SCOPE.json`

One file per project, at the project root (sibling to `PROJECT.md`):

```json
{
  "schema_version": "1.0",
  "project": "P02-MYPROJECT",
  "implementation_scope": {
    "include": [
      "src/payments/**",
      "tests/payments/**"
    ],
    "exclude": [
      "src/payments/generated/**"
    ]
  }
}
```

Start from `templates/SCOPE.json`.

- **`include`** — required, at least one pattern. The approved implementation
  scope. A changed file that matches nothing here is `SCOPE-DIFF-001`.
- **`exclude`** — optional, defaults to empty. A carve-out *within* the
  approved area — a path that would otherwise match `include` but was
  deliberately called out as off-limits for this work. A changed file that
  matches `exclude` is `SCOPE-DIFF-005`, a distinct rule id from
  `SCOPE-DIFF-001` because the triage is different: an out-of-scope file
  usually means the change wandered somewhere unrelated; an excluded file
  usually means someone is touching something the team already decided,
  in this same scope declaration, not to touch as part of this work.

### Patterns are repo-root-relative, not project-relative

Every other `artifact` field in this framework's diagnostics is
project-relative. `implementation_scope` patterns are a deliberate
exception: they are relative to the **repository root**, because the files
`git diff` reports are always repository-root-relative, and because a PMO
project's own governance folder and the application source tree it governs
are frequently in different parts of the repository — `src/payments/**`
would not even be expressible as "relative to the project folder" in the
common case where `projects/P02-MYPROJECT/` holds the PMO artifacts and
`src/` holds the code.

### Pattern syntax

Deliberately small, matching this framework's "deterministic only, nothing
an LLM has to interpret" principle:

| Token | Meaning |
|---|---|
| `*` | any run of characters except `/` |
| `?` | any single character except `/` |
| `**` | zero or more path segments, including their separators |
| anything else | literal (regex-escaped) |

No character classes (`[abc]`), brace expansion (`{a,b}`), or extglob. A
smaller grammar is one that can be tested exhaustively — see
`tests/helpers/scope-diff-tests.ps1` — instead of approximately.

Examples:

| Pattern | Matches | Does not match |
|---|---|---|
| `src/payments/**` | `src/payments/foo.ts`, `src/payments/a/b.ts` | `src/auth/foo.ts` |
| `**/README.md` | `README.md`, `docs/README.md`, `a/b/README.md` | `README.md.bak` |
| `src/*.ts` | `src/foo.ts` | `src/sub/foo.ts` (one segment only) |
| `**` | everything | — |

Rejected as `SCOPE-DIFF-003` (invalid syntax), not silently accepted with a
guessed meaning:

- a pattern starting with `/` (patterns are already repo-root-relative)
- a pattern containing a backslash (git paths are always forward-slash,
  even on a Windows runner — see "Path normalization" below)
- a pattern containing a `..` segment
- a non-string entry, or an empty `include` list

### Precedence

For a given changed file, in order:

1. Matches `exclude` → **excluded** (`SCOPE-DIFF-005`). Wins even over a
   repo-wide exemption (below) — a project's own, more specific and more
   recently reviewed decision overrides a global default.
2. Matches a repo-wide exemption → **exempt**. Reported in the output with
   its reason, counted as clean (not a violation).
3. Matches `include` → **in scope**. Clean.
4. Otherwise → **out of scope** (`SCOPE-DIFF-001`).

## Repo-wide exemptions

`pmo-config/scope-diff-policy.json`'s `repo_wide_exempt` list covers paths
that are reasonable to touch alongside *any* change, in *any* project,
without repeating them in every single `SCOPE.json` — lockfiles,
`CHANGELOG.md`. This is the framework's own runtime config (same status as
`policy.json`, `artifact-policy.json`), not something a project edits.

```json
{
  "repo_wide_exempt": [
    { "pattern": "package-lock.json", "reason": "Lockfile maintained automatically by dependency tooling." }
  ]
}
```

This is the **only** exception mechanism. There is no other implicit
allowlist anywhere in SCOPE-DIFF. Every entry:

- is **explicit** — a real line in a real, version-controlled file;
- is **reviewable** — a human sees it in a diff before it takes effect;
- is **deterministic** — the same glob grammar as `include`/`exclude`, no
  fuzzy matching;
- **appears in the report** — every exempt file is listed with its reason,
  never silently dropped;
- **has a test** — see `tests/helpers/scope-diff-tests.ps1`'s
  "repo-wide exempt" case, and the matching "non-exempt unrelated file
  still fails" case proving the exemption does not leak beyond what it
  actually lists.

If a project needs its *own* project-specific exception (its own governance
files updated alongside the code, generated files specific to that project,
etc.), add the path explicitly to that project's own `SCOPE.json` `include`
list. There is no automatic exemption for a project's own `PROJECT.md`,
`DELIVERY.md`, or similar — that would be exactly the kind of invisible
magic list this design avoids.

## Git range semantics

- **On a `pull_request` GitHub Actions event**, the Action resolves base and
  head automatically from the event context (`GITHUB_EVENT_PATH`'s
  `pull_request.base.sha` / `pull_request.head.sha`) — the PR's actual
  commits, not the moving branch names.
- **`scope-diff-base`/`scope-diff-head` Action inputs**, or
  `-ScopeDiffBase`/`-ScopeDiffHead` on the CLI/`validate-project.ps1`
  directly, override the event context when supplied. On any non-`pull_request`
  event (for example `push`), you must supply both explicitly — there is no
  event-derived base for those.
- If `enable-scope-diff: true` is set but neither an explicit override nor a
  usable `pull_request` event context is available, SCOPE-DIFF does **not**
  silently skip. It fails as `SCOPE-DIFF-004` with a clear reason — asking
  for the check and getting no answer is treated the same as any other
  configuration problem, not as an implicit "nothing to check."
- **Changed files come directly from `git diff --name-status -z base head`**
  — the `-z` (NUL-separated) form specifically, so a path containing a space
  or unusual character parses back exactly instead of being lossily
  quoted/escaped.
- **Added, modified, and deleted** files are each checked once, against
  their one path.
- **Renamed** (and copied) files are checked at **both** the old and the new
  path. The combined verdict is the *worse* of the two, ranked
  `excluded > out_of_scope > exempt > in_scope`: renaming an in-scope file
  to an out-of-scope location — or the reverse — is exactly the kind of
  scope drift this check exists to catch, regardless of which direction the
  rename went.
- **A shallow checkout, or a base/head that cannot be resolved**, produces
  `SCOPE-DIFF-004` with an actionable message (most commonly: increase
  `actions/checkout`'s `fetch-depth`), never a crash and never a guessed
  result.
- **SCOPE-DIFF never runs `git fetch`** to work around a missing commit.
  That would need broader repository credentials than a governance check
  should hold — fixing the checkout's `fetch-depth` is the consumer
  workflow's own responsibility, documented above rather than worked around
  automatically.

### Path normalization (Windows and Linux)

`ConvertTo-ScopeGlobRegex` (`scripts/lib/scope-diff-matcher.ps1`) never
calls an OS-aware path API (`Join-Path`, `Split-Path`) on a git-diff-derived
path — matching is pure string/regex comparison. `git diff` itself always
emits forward-slash paths, on every platform, including Windows. Combined
with rejecting any pattern containing a backslash as `SCOPE-DIFF-003`, this
means the exact same code path runs identically on Windows PowerShell 5.1,
PowerShell 7 on Windows, and PowerShell 7 on Linux/macOS — proven by
`tests/helpers/scope-diff-tests.ps1` running unchanged across all of them in
this repository's own CI matrix, not by separate OS-specific test code.

## What the report shows

`axiom-report.json`'s `scope_diff` object (present only when SCOPE-DIFF was
requested — omitted entirely otherwise, so a normal validation run's JSON
shape is unchanged):

```json
{
  "scope_diff": {
    "base_sha": "d09e0ee...",
    "head_sha": "824300e...",
    "approved_include": ["src/payments/**"],
    "approved_exclude": ["src/payments/generated/**"],
    "changed_in_scope": ["src/payments/checkout.ts"],
    "changed_out_of_scope": ["src/auth/permissions.ts"],
    "changed_excluded": ["src/payments/generated/client.ts"],
    "exempt": [{ "path": "package-lock.json", "reason": "Lockfile maintained automatically by dependency tooling." }],
    "verdict": "fail"
  }
}
```

`verdict` is one of `pass`, `fail`, `scope_missing`, `invalid_scope`, or
`git_error`. The same information renders into `axiom-report.md`, the GitHub
Job Summary (path lists capped at 10 with a "...and N more" note, same cap
as the FAIL/WARN sections), and the `scope-diff-verdict` Action output.

## Report-only vs. enforce

Identical semantics to the rest of the GitHub Action: `enforce` defaults to
`false`. A SCOPE-DIFF violation (`SCOPE-DIFF-001`/`002`/`005`) is fully
reported — Job Summary, annotations, JSON/Markdown report — but does not
fail the workflow step unless `enforce: true`.

`SCOPE-DIFF-003` (invalid declaration) and `SCOPE-DIFF-004` (git range
unavailable) are different: they mean the comparison itself could not run,
which is an infrastructure/configuration failure, not a governance verdict.
Report-only cannot hide those either — the same principle as a missing
PowerShell host always failing the step regardless of `enforce`.

## Security and privacy

- SCOPE-DIFF reads file **paths** only, from `git diff --name-status`. It
  never opens, reads, or transmits a source file's contents.
- A failed `git` command's raw stderr goes to the workflow run log only,
  never into `axiom-report.json`, `axiom-report.md`, an annotation, or the
  Job Summary — `SCOPE-DIFF-004`'s message is always one of a small set of
  known, generic explanations. Same standard as the privacy fix M4 shipped
  for malformed validator output.
- No credential, environment value, or arbitrary command output is ever
  persisted into a report or artifact.
- Annotations for `SCOPE-DIFF-*` rows go through the same field allowlist
  and escaping as every other rule (`docs/guides/github-action.md`).

## Known limitations

- **One scope declaration per project, not per work item.** If a project
  has several work items in flight with genuinely different approved
  scopes, `SCOPE.json` currently expresses one combined scope for the whole
  project, not a scope per `D-###` row. Widen `include` to cover the union,
  or validate the narrower work item as its own project.
- **Rename detection depends on git's own default similarity threshold**
  (`git diff`'s implicit `-M`, roughly 50% by default). A file rewritten
  heavily enough that git reports it as a plain delete + add, rather than a
  rename, is evaluated as two independent changes -- each checked against
  its own single path -- rather than one rename with the combined
  old-path/new-path verdict described above. SCOPE-DIFF does not pass a
  custom similarity threshold to `git diff`.
- **Copies (`git diff`'s `C` status) are not specially detected.** `git diff
  --name-status` without `-C` (which SCOPE-DIFF does not pass, to keep the
  invocation simple and its output predictable) reports a copied-then-kept
  file as a plain addition, not a copy with an old-path reference. A
  genuine copy is therefore evaluated the same as a new file: only its own
  path matters.
- **A shared `pmo-config/scope-diff-policy.json`, not a per-repo
  override for external consumers.** Repo-wide exemptions are part of the
  Axiom-PMO framework's own runtime config, loaded from the framework's
  checkout (`github.action_path` when running as the Action) regardless of
  which repository is being validated. A consumer repository cannot
  currently add its own repo-wide exemptions without a project-level
  `SCOPE.json` `include` entry for each path.
- **`dogfood-scope-diff`'s own CI job runs on Ubuntu only** in this
  repository's workflow, matching the same limitation already noted for
  M4's `dogfood-github-action` job. Windows and macOS coverage for
  SCOPE-DIFF's own logic comes from `tests/helpers/scope-diff-tests.ps1`
  running across this repository's full CI matrix (Windows PowerShell 5.1,
  Windows pwsh 7, Ubuntu, macOS), not from a Windows/macOS run of the
  composite Action definition itself via `uses: ./`.

## Related

`docs/rules/SCOPE-DIFF-001.md` through `SCOPE-DIFF-005.md`,
`docs/guides/github-action.md`, `docs/reference/diagnostics-contract.md`.
