# Plugin version = cache/update identity — evidence

> Closes the M6 "plugin update/version drift" debt to the level actually
> demonstrated. Captured 2026-08-02 against the real `claude` CLI, same
> discipline as [`plugin-load-transcript.md`](plugin-load-transcript.md) and
> [`hook-coexistence-transcript.md`](hook-coexistence-transcript.md):
> temporary install, capture, full uninstall and marketplace removal,
> restoration verified.

## What was observed

Installing `axiom-pmo` from this repository (a `source: "./"`
directory-source marketplace) and inspecting Claude Code's own install
records directly, not inferred from documentation:

**`~/.claude/plugins/installed_plugins.json`** records exactly one active
entry per plugin source, keyed by `<plugin>@<marketplace>`, carrying the
plugin's declared `version`, its resolved `installPath`, and — for a
directory-source install — the `gitCommitSha` of the checkout it was
installed from:

```json
"axiom-pmo@axiom-pmo": [{
  "scope": "user",
  "installPath": ".../plugins/cache/axiom-pmo/axiom-pmo/1.3.0",
  "version": "1.3.0",
  "installedAt": "2026-08-02T14:52:49.328Z",
  "gitCommitSha": "54b0066ee8c3855ab3f560ca6a4ebe50e9bf8f31"
}]
```

**`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`** is keyed on
the version string, and directories from prior versions are not silently
reused or overwritten. An earlier capture in this same environment (before
this repository's plugin manifest was bumped to `1.3.0`) left a `1.2.0`
directory in place, found sitting unmodified alongside the new `1.3.0` one:

```text
~/.claude/plugins/cache/axiom-pmo/axiom-pmo/1.2.0/   (from an earlier capture)
~/.claude/plugins/cache/axiom-pmo/axiom-pmo/1.3.0/   (current)
```

## What this proves, and what it does not

**Proves:** the declared `version` in `.claude-plugin/plugin.json` is the
identity Claude Code resolves an install and its cache against. A plugin
whose manifest disagrees with the release it ships in is, from Claude Code's
side, a different cached object under a different key — not the same
install silently updated in place.

**Does not prove:**

- That `claude plugin marketplace update` followed by a reinstall replaces
  an *already-loaded* plugin's content inside a session already running
  against the old cache directory, without a restart. Not exercised here.
- That a GitHub-hosted marketplace source (rather than the local-directory
  source used throughout this repository's own testing) behaves identically.
  Not exercised here.

Both are stated as open rather than closed. Closing them would need a
scripted update-and-reinstall sequence against a real remote marketplace,
which was judged out of scope for this release-candidate pass.

## Why real, not synthetic

`~/.claude/plugins/` has no isolated or sandboxed mode exposed by the
`claude` CLI (`claude plugin --help`, `claude --help`, and the process
environment were all checked; no `--config-dir` or equivalent exists).
Testing this without touching the real user-level configuration was not
possible with the tooling available, so the same temporary
install-capture-restore discipline already used and accepted for
`plugin-load-transcript.md` was applied here instead of skipping the
evidence entirely. Fabricating a synthetic version-drift scenario without a
real cache to inspect would have proven nothing about what Claude Code
actually does.

## Cleanup

Plugin uninstalled, marketplace removed, `installed_plugins.json` and
`known_marketplaces.json` restored to their pre-test state, verified by
reading both before and after. The `1.2.0` and `1.3.0` cache directories
under `~/.claude/plugins/cache/axiom-pmo/` are not purged by
`claude plugin uninstall` — this is the tool's own behaviour, disclosed
rather than worked around, and is itself part of what this evidence
observed.
