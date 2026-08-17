# SCOPE-DIFF-004 - Git base/head range unavailable

| | |
|---|---|
| Level | FAIL |
| Runs when | `-ScopeDiffBase` and `-ScopeDiffHead` are both supplied |
| Artifacts | none (this is a repository/checkout state problem, not a file-level finding) |

## What this rule checks

The base commit, the head commit, or the `git diff` between them could not be resolved in the current checkout.

## This is an infrastructure failure, not a governance violation

Every other SCOPE-DIFF rule reports on the *content* of a change. This one reports that the check could not run at all — the scope comparison never happened, so there is no verdict to soften. The GitHub Action wrapper treats a SCOPE-DIFF-004 result the same way it treats an infrastructure failure: it always propagates as a failure, even when `enforce: false` (report-only). Report-only exists to avoid blocking a pull request on a real governance finding nobody has reviewed yet; it does not exist to hide "the check silently didn't run."

## Most common cause: a shallow checkout

`actions/checkout` defaults to `fetch-depth: 1` — only the current commit, not its history. A scope-diff comparison needs the *base* commit to exist locally too. Fix it in the consumer workflow:

```yaml
- uses: actions/checkout@v7
  with:
    fetch-depth: 0   # or a depth that comfortably covers the PR's base
```

SCOPE-DIFF never runs `git fetch` on its own to work around this — see `docs/reference/scope-declaration.md`'s "Git range semantics" section for why: fetching arbitrary history automatically would need broader repository credentials than the check should ever hold.

## Privacy note

The raw `git` error text is written to the workflow run log (visible to whoever could already read that log), never to `axiom-report.json`, `axiom-report.md`, an annotation, or the Job Summary. The diagnostic `message` is always one of a small set of known, generic explanations.

## Related

`docs/reference/scope-declaration.md`, `docs/guides/github-action.md`.
