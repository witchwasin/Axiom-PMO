# Plugin Packaging Spike — Milestone 6.1

> Status: **spike complete. Implementation stopped pending a Human Owner
> decision**, as authorized. This document is the spike's required output: what
> was tested, what is now known, what is still unknown, and a recommended
> integration shape. No packaging was built, no directory was moved, and no
> file outside this repository was modified.

## 1. What the spike was for

Milestone 6.0 decided a HYBRID shape — Claude Code plugin for the framework,
one namespaced section in the user's repository
([`claude-code-integration.md`](claude-code-integration.md) §7) — and listed
seven things it had **not** verified (§2.3). Building on those unverified
assumptions is what this spike exists to prevent.

The framing matters, because the failure mode here is the one Milestone 5 hit
four times: a check that is real, does work, and answers a question slightly
adjacent to the one that matters. So the two halves are kept apart throughout.

| | Question | How it was answered |
|---|---|---|
| **A** | What does a Claude Code plugin actually support? | Primary source: a real installed marketplace on this machine |
| **B** | Does *this framework* survive being installed like one? | Empirically: [`tests/helpers/plugin-install-spike-tests.ps1`](../../tests/helpers/plugin-install-spike-tests.ps1), 15 cases |

Neither half answers the other. B does not prove Claude Code will load us; A
does not prove our PowerShell runs from an install root.

## 2. Half A — what a plugin supports, from primary source

Inspected: `~/.claude/plugins/marketplaces/claude-plugins-official`, a real
installed marketplace with **273 plugin entries**, including Anthropic's own
`plugin-dev` plugin, which ships the manifest reference as a skill. This is
better evidence than the `superpowers` clone Milestone 6.0 used, because it is
the official distribution and it documents the contract rather than
demonstrating one instance of it.

### 2.1 Verified

| Finding | Evidence |
|---|---|
| `.claude-plugin/plugin.json` is **required** and must be at the plugin root | `plugin-dev` manifest reference, "File Location" |
| Its fields are metadata plus **component path overrides** | Field list: `name`, `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`, `commands`, `agents`, `hooks`, `mcpServers` |
| **`skills` is NOT a path-override field** | The reference documents `commands`, `agents`, `hooks`, `mcpServers` only |
| Skills are discovered **only** from `<plugin-root>/skills/` | Resolution order: "Scans `skills/` for subdirectories containing `SKILL.md`" |
| No official plugin uses `.claude/skills/` | 0 of 273; every skill-carrying plugin uses `skills/` |
| Custom paths **supplement**, never replace, defaults | Reference, "Custom paths supplement defaults" |
| Path rules: relative, must start with `./`, no `..`, no absolute, no backslash | Reference, "Relative Path Rules" |
| A plugin **can** live in a repository subdirectory | `source: {"source": "git-subdir", "url": …, "path": "plugins/<name>", "ref": …, "sha": …}` — used by 42Crunch, Adobe, Coursera and others |
| A marketplace entry can declare **explicit skill paths** | `"skills": ["./skills/box", …]` with `"strict": false` — used by `amd-skills`, `box`, `learn-with-coursera` |
| Plugins **can ship and execute** scripts | Hooks run `sh`/`bash`/`python3 "${CLAUDE_PLUGIN_ROOT}/…"`; `claude-security`, `hookify`, `ralph-loop` all do |
| Skills may bundle executable scripts | `skill-development` skill: `scripts/` for "deterministic reliability", "may be executed without loading into context" |
| `${CLAUDE_PLUGIN_ROOT}` is documented for use **inside skill markdown**, not only hooks | `plugin-structure` skill, "In component files (commands, agents, skills)" |
| Marketplace entries can pin a `sha` | 273/273 entries carry `source` and most pin `sha` |

### 2.2 Still not verified

Stated so a later reader does not mistake inference for evidence.

- Whether a marketplace `skills` array accepts a **dot-directory** path such
  as `./.claude/skills/pmo-intake`. Every observed example uses non-dotted
  paths. The documented path rules do not forbid it; that is not the same as
  it working.
- The **permission prompt behaviour** when a skill invokes a PowerShell
  executable. That it is possible is verified; whether the user is prompted,
  and how often, is a function of their own settings and was not exercised.
- Whether a plugin update **silently replaces** a pinned install mid-session.
  `sha` pinning exists in the marketplace entry, so the mechanism for
  stability is there; the update path itself was not exercised.
- Windows behaviour of any of the above. This machine is macOS
  ([`powershell-portability.md`](powershell-portability.md) records why that
  matters here).

## 3. Half B — does the framework survive a plugin install?

[`tests/helpers/plugin-install-spike-tests.ps1`](../../tests/helpers/plugin-install-spike-tests.ps1)
builds a simulated install and runs the real scripts as real child processes.
The install root is **not a git repository**, is **not the working directory**,
and its path deliberately **contains a space** — a real install root
(`~/.claude/plugins/marketplaces/<name>/plugins/<plugin>`) has both a space
risk and a dot-directory, and unquoted-path bugs are the classic Windows-only
failure. The user's project is a separate real git repository elsewhere.

**15 cases, all passing**, wired into `run-all-checks.ps1` so every supported
host runs them.

| Question from 6.0 §2.3 | Answer |
|---|---|
| Executable invocation from the install root | **Yes** — every script runs as a child process from a non-checkout path |
| `pwsh` host resolution from an install location | **Yes** — the `AXIOM_PWSH` → current-host → PATH chain is location-independent |
| Dot-sourcing and `$PSScriptRoot` survival | **Yes** — `$PSScriptRoot/..` resolves the framework root correctly wherever it sits |
| Framework root vs project root kept distinct | **Yes** — validation targets the user's project; the framework's own files are never confused for it |
| `templates/` readable without being writable | **Yes** |
| Windows path quoting | **Partly** — a space in the install path is exercised and passes on macOS/Linux; Windows is covered by CI, not by this machine |
| Update / version drift | **Not tested** — needs a real install, see §2.2 |

Two further things were tested that 6.0 did not ask for, and both matter:

- **Validation writes nothing into the install root.** A plugin directory can
  be shared, replaced on update, or read-only. Any write there would be a
  defect even where it succeeds. It writes none.
- **The full M5 loop reaches a real verdict from an install root.** A contract
  is exported into the *user's* repo, `axiom run` seals a record, a human
  vouch is recorded, and `verify` returns `Verdict: pass` — with the framework
  never inside the user's repository. This is the milestone's objective,
  demonstrated end to end rather than argued.

### 3.1 The finding the spike actually produced

The first run failed, and the reason is the useful part.

`pmo-doctor.ps1` reads `VERSION` from the framework root. `VERSION` is not in
the content set Milestone 6.0 §7 proposed (`scripts/`, `cli/`, `pmo-config/`,
`templates/`, skills). Tracing it out gave a clean split that had not been
articulated before:

| | Scripts | Reads outside the plugin content set | Works from an install? |
|---|---|---|---|
| **User-facing** | `validate-project`, `assess-handoff`, `export-execution-contract`, `run-execution-command`, `verify-execution-result`, `cli/axiom.mjs` | Nothing | **Yes** |
| **Maintainer** | `pmo-doctor`, `check-public-hygiene`, `measure-context`, `prepare-public-release`, `run-validation-tests`, `run-all-checks`, `demo` | `VERSION`, `AGENTS.md`, `CLAUDE.md`, `CHANGELOG.md`, `.gitignore`, `.claude/`, `demo/`, `examples/` | **No, correctly** |

The maintainer scripts audit the framework's *own* repository. A plugin user
has no checkout to audit, so this is not a bug to fix by shipping more files —
it is a packaging boundary that was previously implicit.

**It is a real defect in one respect:** today those scripts fail with a raw
PowerShell exception rather than a diagnostic saying "this tool audits an
Axiom-PMO checkout and is not available from a plugin install." That is
recorded as an M6.2 item and asserted in the spike test, so it cannot be
forgotten and cannot be silently "fixed" without the test noticing.

## 4. Directory moves: not needed

The Human Owner's authorization required stopping and reporting before moving
any directory. **No move is required**, and there are two independent routes:

1. **`git-subdir` source** (verified, widely used): the plugin root is a new
   subdirectory of this repository. `scripts/`, `cli/`, `pmo-config/`,
   `templates/` and `.claude/skills/` all stay exactly where they are.
2. **Marketplace `skills` array** (mechanism verified, dotted paths not):
   declare `.claude/skills/pmo-*` explicitly.

Route 1 is recommended because every part of it is verified. It does mean the
plugin root needs a `skills/` directory whose content matches `.claude/skills/`
— which is a **content-duplication** problem, not a move. The right answer to
that is the same one this repository uses everywhere else: a deterministic
check that fails CI if the two ever drift, rather than a convention that they
should not.

## 5. Recommended shape

Unchanged from Milestone 6.0's HYBRID decision, now with the layout resolved:

```text
Axiom-PMO repository (unchanged)
  scripts/  cli/  pmo-config/  templates/  .claude/skills/   <- nothing moves
  .claude-plugin/marketplace.json                            <- new: self-marketplace
  plugin/                                                    <- new: plugin root
    .claude-plugin/plugin.json
    skills/            <- synced from .claude/skills, drift-checked in CI

User's repository
  AGENTS.md            <- one fenced, namespaced Axiom-PMO section
  PROJECT.md, DELIVERY.md, SCOPE.json, decision-log.md, .execution/
```

**The approved fallback was not needed.** Native invocation of the multi-file
PowerShell validator from an install root works, so the plugin can carry the
validator rather than deferring to the CLI or GitHub Action. The fallback
remains recorded as the answer if Windows CI or a real install contradicts
this.

## 6. What this does and does not claim

M6.1 hands Claude Code the approved scope and authority **as governed
context**. It does not, and will not, prevent an out-of-scope edit:

> Claude Code receives the approved scope and authority as governed context.
> Axiom-PMO verifies afterwards whether the implementation remained within
> them. Nothing in M6.1 prevents an out-of-scope edit.

Detection stays where it already is — `SCOPE-DIFF` and the `EXEC-*` rules,
after execution. Preventive enforcement is the M6.5 hook, deliberately
separate, opt-in, and report-only by default, exactly as SCOPE-DIFF and the
GitHub Action shipped.

No authority, evidence, or approval logic moves out of Milestones 1–5. The
spike added no rule, no claim type, no approval path, and no config that
weakens one.

## 7. Limits

- Nothing here launched Claude Code or loaded an actual plugin. §3 proves a
  necessary condition, not a sufficient one.
- The read-only install case runs on macOS/Linux only; Windows ACL semantics
  differ from `chmod` and are not equivalent.
- Update and version-drift behaviour is untested (§2.2).
- Compatibility with a repository that already has Superpowers, BMAD, or its
  own `CLAUDE.md` is **not** addressed here. That is M6.4 and cannot be
  satisfied by unit tests.
