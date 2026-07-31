# Claude Code integration

> **Status: implemented, under review. Not accepted, not released.**
> Milestone 6 has not been reviewed by an independent reviewer or accepted by
> the Human Owner. Nothing here is published to a marketplace and no release
> exists. See [`ROADMAP.md`](../../ROADMAP.md).

**Optional.** Milestones 1–5 are the Axiom-PMO product. Everything on this page
is a bridge for teams who choose to continue implementation in Claude Code
after a handoff is verified. You can run every gate, hand work to a developer,
and verify what comes back without installing any of it.

## What it is, in one paragraph

The framework — skills, validators, config, templates — installs as a Claude
Code plugin, outside your repository. One short fenced block goes into your
repository's `AGENTS.md`, because that file is read by Codex and Cursor too and
a Claude-only plugin would not reach them. That block tells an agent where the
governed context is. It does not enforce anything.

```text
Axiom-PMO verified handoff
  -> Claude Code receives the approved scope and authority as governed context
  -> Claude Code implements
  -> execution result and evidence come back
  -> Axiom-PMO (Milestone 5) verifies them
```

> **Claude Code receives the approved scope and authority as governed context.
> Axiom-PMO verifies afterwards whether the implementation remained within
> them. Nothing in Milestone 6 prevents an out-of-scope edit.**

## Prerequisites

| | |
|---|---|
| Claude Code | any version with `claude plugin` (verified against the CLI shipped alongside this work) |
| PowerShell | Windows PowerShell 5.1, or PowerShell 7 on Windows, Linux or macOS |
| Node.js | only for the `axiom` CLI wrapper; the PowerShell scripts run without it |

## Install the plugin

```bash
claude plugin marketplace add witchwasin/Axiom-PMO
```

```bash
claude plugin install axiom-pmo@axiom-pmo
```

Confirm what was loaded:

```bash
claude plugin details axiom-pmo
```

Expect `Skills (7)` and `Hooks (1)`. A captured transcript of a real install is
committed at
[`docs/evidence/plugin-load-transcript.md`](../evidence/plugin-load-transcript.md).

The hook is registered but **inert** until a project opts in — see
[The advisory hook](#the-advisory-hook-optional-report-only).

Nothing in your repository has changed at this point.

## Add the instruction block to a repository

Preview first. This writes nothing:

```bash
node cli/axiom.mjs setup claude --project . --dry-run
```

Then apply it:

```bash
node cli/axiom.mjs setup claude --project .
```

Or run the script directly, without Node:

```bash
pwsh -File scripts/setup-claude-integration.ps1 -ProjectPath .
```

What it does:

- backs up `AGENTS.md` before touching it (`AGENTS.md.axiom-backup-<timestamp>`);
- appends one fenced block, and nothing else;
- writes atomically — an interrupted run leaves the old file or the new one,
  never half of each;
- keeps your line endings and byte-order mark exactly as they were;
- reports any other framework it finds (`CLAUDE.md`, `.claude/skills`,
  Superpowers, BMAD) and leaves all of it alone;
- is idempotent — running it again reports "already up to date".

To target `CLAUDE.md` instead:

```bash
node cli/axiom.mjs setup claude --project . --file CLAUDE.md
```

## Remove it

```bash
node cli/axiom.mjs setup claude --project . --uninstall
```

Removes exactly the fenced block. Content before and after it is untouched. If
the block was the only thing in the file, the file is removed too, and the
output says so. A backup is taken first either way.

Then remove the plugin:

```bash
claude plugin uninstall axiom-pmo
```

## The advisory hook (optional, report-only)

Off by default. Installing the plugin does not enable it.

To turn it on for one project, create `.axiom/hooks.json`:

```json
{ "scope_advisory": true }
```

Once enabled, editing a file outside `SCOPE.json`'s `implementation_scope`
produces a note. It **never** blocks the edit, and it emits no permission
decision at any input — there is no code in it that could.

| | Cost per Write/Edit |
|---|---|
| Disabled (default) | ~9 ms — the opt-in is checked in shell, before PowerShell is started |
| Enabled | ~230 ms — a PowerShell process runs the real scope matcher |

Measured on the maintainer's macOS machine with PowerShell 7; your numbers will
differ. The enabled cost is real, and it buys a note rather than a guarantee.

To disable it, delete `.axiom/hooks.json` or set `scope_advisory` to `false`.

## Troubleshooting

**`SETUP-004 The Axiom-PMO markers ... are malformed`**
The file has a `BEGIN` with no `END`, two of one, or a reversed pair. Nothing
was changed. Repair the markers by hand — guessing which belongs to which is
how a tool eats half a document.

**`SETUP-005` / `SETUP-006 ... has been edited by hand`**
Someone edited inside the fenced block. The recorded digest no longer matches,
so removing or replacing it would discard their work. Move the edits outside
the markers and re-run, or pass `--force` to overwrite them deliberately.

**`SETUP-003 ... is a symbolic link`**
The instruction file points elsewhere. Following it would edit a file outside
the project without saying so. Edit the real file, or replace the link.

**`SETUP-007 Could not write`**
The directory is not writable. Nothing was modified.

**`FRAMEWORK-001 ... needs an Axiom-PMO source checkout`**
You ran a maintainer tool (`pmo-doctor`, `check-public-hygiene`, the test
runners) from a plugin install. Those audit the framework's own repository and
a plugin does not carry one. For your project, use `validate-project.ps1`.

**The hook says nothing**
That is the default. It needs `.axiom/hooks.json` with `scope_advisory: true`,
a valid `SCOPE.json`, and PowerShell on `PATH`. Any of those missing means
silence rather than an error — a governance advisory that breaks an editing
session has done more harm than the deviation it was watching for.

## Known limitations

Stated rather than discovered later.

| Limitation | Detail |
|---|---|
| **It does not prevent anything** | The block is context, not enforcement. Out-of-scope edits are detected afterwards by SCOPE-DIFF and the `EXEC-*` rules, not stopped as they happen. |
| **A git install carries the whole repository** | The plugin root is the repository root, so a git-source install fetches ~10 MB, of which ~6.7 MB is `tests/`. Only `skills/`, `hooks/` and the manifests are loaded; the rest is inert. Slimming it would mean duplicating the validator into a subdirectory, which the milestone forbids. |
| **Skill invocation is not verified end to end** | The captured transcript proves the plugin loads and its skills are *discovered*. Whether a skill then behaves correctly is the skills' own content, unchanged by packaging. |
| **Permission-prompt behaviour is not characterised** | Whether invoking the validator from a skill prompts, and how often, depends on your own permission settings. Not measured. |
| **Update and version drift are untested** | Marketplace entries can pin a `sha`; that a plugin update cannot silently swap a pinned install mid-session has not been exercised. |
| **Windows symlink and read-only cases are skipped** | Those tests run on macOS and Linux. Windows ACL semantics differ from `chmod`, and creating a symlink there needs elevation. |
| **No external-user validation** | Everything here was tested by the people who built it. |

## What Axiom-PMO still is

A governance and development-handoff framework. It prepares and verifies
development handoffs. It does not replace developers or execution frameworks,
and Milestone 6 does not change that — it moves no authority, evidence, or
approval logic out of Milestones 1–5.
