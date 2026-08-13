# TEST-EVIDENCE-003 - Passed test row's FILE: evidence contradicts git ground truth

| | |
|---|---|
| Level | WARN (blocking) at Standard, FAIL at Strict; git infrastructure failures always FAIL |
| Runs when | `scripts/validate-project.ps1` is invoked at the Release gate with **both** `-ReleaseDiffBase` and `-ReleaseDiffHead` supplied |
| Artifacts | `RELEASE.md` (Test Summary table), the FILE: evidence it cites |

## What this rule checks

A `passed` Test Summary row whose `Evidence` is a `FILE:` reference must be
reconciled against git ground truth: if the evidence file is **tracked** but
was **not changed within the verified `base..head` commit range**, it cannot
be the output of a test run of this release's work. The diagnostic says so
explicitly:

> TEST-001 is passed but cites FILE:evidence 'tests/evidence/report.xml',
> which was not changed within the release's verified commit range
> base..head — a report that predates this release's work cannot prove the
> released code passes.

This is the same both-directions discipline as `EXEC-005`'s stale-evidence
reconciliation and `EXEC-008`'s `changed_files` check, applied to the
release-path Test Summary check: the claim "this test passed" is checked
against what the repository shows actually happened, not just against
"the file exists on disk" (`TEST-EVIDENCE-002` is the existence/resolution
bar; this rule is the freshness bar).

## Why it exists

`TEST-EVIDENCE-002` only requires a `passed` row's evidence to *resolve* —
`Resolve-Reference` checks `Test-Path` against the working tree. That is
true in all three cases this rule exists to catch:

1. **Stale** — a report file committed long before the release's work. It
   exists, it resolves, and it says nothing about the new code.
2. **Uncommitted** — a tracked file modified (or staged) in the working tree
   after the fact. Its current content was never part of any commit in the
   range.
3. **Retro-added** — a file added to the index after the head commit, so it
   is tracked (`git ls-files` sees it) but absent from `base..head`.

The working-tree state is surfaced in the message so the reason names the
actual defect: a clean file *predates* the release; a modified or staged
file has content that is *not part of the verified range*.

## Scope and limits (decided in feeback.md Round 3)

- **Severity mirrors `APPROVAL-003`:** WARN-blocking at Standard, FAIL at
  Strict. A Standard release that cannot prove its test evidence is fresh is
  flagged but does not hard-fail the run; a Strict release cannot ship with
  it.
- **No human-vouch escape hatch on this path.** The release gate is the last
  checkpoint before release, so it is deliberately stricter than the
  execution path's vouch-carrying evidence model (`EXEC-005`). If a real
  friction case appears later, it is a new decision then.
- **Tracked files only.** An untracked/gitignored `FILE:` reference is
  invisible to `git diff` regardless of how fresh it is, so flagging it as
  stale would be a false positive against a legitimate pattern (e.g. a
  deliberately gitignored CI report directory). Such evidence is **out of
  this check's scope entirely** — neither passed nor failed by it, same as
  before this rule existed.
- **Git infrastructure failures are always FAIL** (unresolvable base/head
  commit, the project not inside a git repository, `git diff` itself
  failing) — same precedent as `SCOPE-DIFF-004`. The caller asked for a
  range; an unresolvable one is a configuration error, not a pass.
- **Opt-in:** the rule only evaluates when the caller supplies both
  `-ReleaseDiffBase` and `-ReleaseDiffHead`. Every existing invocation of
  `validate-project.ps1` supplies neither, so behavior is byte-identical for
  them. The project's own repository is the git ground truth (evidence files
  and commit range live there), so no separate repo-root parameter is needed
  the way SCOPE-DIFF needs `-ScopeDiffRepoRoot`.
- **Only `FILE:` evidence is reconciled.** A `TEST-###` id, `DEC-###`,
  `ISSUE:n`, or `CI:` reference names no repository file, so git has nothing
  to say about it.

## How to fix

- Point the `passed` row's `Evidence` at a test report the release's own
  commits produced — a file changed within the verified commit range.
- Re-run the tests so the report is part of this release's change (and
  committed), or make the release's commit range cover it.
- Do not manufacture evidence: if the test genuinely did not run, the row
  must not say `passed`.

## Related

`TEST-EVIDENCE-002` (the existence/resolution bar this rule sits on top of),
`TEST-RESULT-001` (the row-level passed/skipped rule), `EXEC-005` (the
execution-path equivalent with the human-vouch escape hatch), `EXEC-008`
(git-observable claims), `SCOPE-DIFF-004` (the shared unresolvable-ref
failure mode).
