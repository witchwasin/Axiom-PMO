# Advisory hook coexistence — evidence

> Closes the M6 "cross-plugin hook ordering" debt to the level actually
> demonstrated. Captured 2026-08-02 against the real `claude` CLI, following
> the same discipline as
> [`plugin-load-transcript.md`](plugin-load-transcript.md): temporary install,
> capture, full uninstall and marketplace removal, verified restored.
> `~/.claude/plugins/` has no isolated/sandboxed mode to test against instead
> — this is disclosed rather than worked around.

## Primary source

Claude Code's own plugin-development documentation
(`plugin-dev` skill, `hook-development/SKILL.md`, shipped in the official
marketplace `anthropics/claude-plugins-official`), quoted exactly:

> "Plugin hooks merge with user's hooks and run in parallel."
>
> "All matching hooks run **in parallel** ... Hooks don't see each other's
> output ... Non-deterministic ordering ... Design for independence."
>
> DON'T: "Rely on hook execution order."

This is the authoritative statement of the contract: multiple hooks matching
the same event and tool run independently and in parallel, with no
guaranteed order and no visibility into each other's output or result.

## What was tested

A second, independent plugin (`sibling-probe`) was built with its own
`PreToolUse` hook matching the identical tools Axiom-PMO's advisory matches
(`Write|Edit|NotebookEdit`), and installed alongside `axiom-pmo` via real
`claude plugin marketplace add` / `claude plugin install` commands — not
simulated.

| Check | Result |
|---|---|
| Both plugins install without conflict | Yes |
| `claude plugin details axiom-pmo` after sibling install | `Hooks (1) PreToolUse` — unchanged |
| `claude plugin details sibling-probe` | `Hooks (1) PreToolUse` — its own, independent |
| Axiom-PMO's cached `hooks/hooks.json` | Byte-identical to the source, matcher `Write\|Edit\|NotebookEdit` intact |
| Sibling's cached `hooks/hooks.json` | Present, independent, same matcher |
| Uninstalling the sibling | Axiom-PMO's registration and cached hook file unaffected |

Claude Code caches each plugin's hook configuration in its own directory
(`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/hooks/hooks.json`).
Installing a second plugin with a colliding matcher did not overwrite,
truncate, or merge-corrupt Axiom-PMO's file. Neither plugin's registration
disappeared when the other was installed or removed.

## What this proves, and what it does not

**Proves:** Axiom-PMO's hook remains independently registered when another
plugin declares a matching `PreToolUse` hook; installing or removing a sibling
does not touch Axiom-PMO's own hook file or registration; both plugins'
hook definitions coexist on disk exactly as each declared them.

**Does not prove:** that both hooks actually *fire* for the same live tool
call inside a running session (that requires driving the agent loop itself,
which this evidence capture does not do), or anything about relative timing
between two hooks that did fire. Per the primary source above, the contract
provides no ordering guarantee to prove in the first place — a test that
asserted one would be asserting a property Claude Code does not offer.

## Why Axiom-PMO's hook needs neither

`scripts/hook-scope-advisory.ps1` never reads another hook's output, never
depends on having run before or after anything else, and never emits
anything but a `systemMessage` — no field that could be interpreted as a
permission decision exists anywhere in its source (asserted at the source
level, comments stripped, in `tests/helpers/hook-advisory-tests.ps1`). A
hook with no side effect and no dependency on order has nothing for parallel,
unordered execution to break.

## Cleanup

Both plugins uninstalled, both marketplaces removed. `known_marketplaces.json`
and `installed_plugins.json` restored to their pre-test state (empty of both
entries), verified by reading them before and after. Cache directories under
`~/.claude/plugins/cache/` are not purged by `claude plugin uninstall` /
`marketplace remove` — this is the tool's own behaviour, not a residue this
capture left beyond what the CLI itself does, and matches what
`plugin-load-transcript.md`'s capture already leaves behind.
