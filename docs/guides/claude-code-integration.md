# Claude Code integration

> **Status: CLOSED.** Independent review complete (ACCEPT WITH MINOR
> REVISIONS, three rounds); Human Owner accepted and closed 2026-08-01
> (`DEC-007`). Nothing here is published to a marketplace, no
> release or tag exists, and it is not merged to `main`. The known limitations
> below are open and were not closed by that acceptance. See
> [`ROADMAP.md`](../../ROADMAP.md).

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

- refuses outright if `AGENTS.md` is not UTF-8 — a UTF-16 or invalid-UTF-8 file
  is left byte-identical and no backup is taken, because nothing is going to be
  written to it (`SETUP-008`);
- backs up `AGENTS.md` before touching it (`AGENTS.md.axiom-backup-<timestamp>`);
- appends one fenced block, and **nothing else** -- no separator, no blank
  line, not one byte outside the markers. Setup followed by uninstall returns
  your file to exactly the bytes it had;
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

Removes exactly the fenced block — the span between and including the markers,
and not one byte more. Content before and after it is untouched, whitespace
included.

The file itself is **never deleted**, even if the block was the only thing in
it. A command cannot tell a file it created from one that was already empty, so
it does not guess; you may be left with an empty `AGENTS.md`, and the output
says so. A backup is taken first.

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
decision at any input — there is no code in it that could. It applies the same
repo-wide exemptions as SCOPE-DIFF, so the advisory and the gate agree.

> **Platform boundary.** The advisory needs a POSIX shell (`sh`). On native
> Windows that means Git Bash or an equivalent; a **PowerShell-only Windows
> environment does not get the hook**, and no error is raised — it simply stays
> silent.
>
> This applies to the optional advisory *only*. Setup, uninstall, the CLI, the
> validators and the advisory's own PowerShell logic are all supported on
> PowerShell-only Windows.
>
> The alternative was to invoke PowerShell directly from the hook, which works
> everywhere but costs roughly 200 ms on *every* Write and Edit for every user
> who installed the plugin and never turned the advisory on. That was judged
> not worth it for a feature that is off by default.

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

**`SETUP-008 ... is UTF-16LE / UTF-16BE / not valid UTF-8`**
Axiom-PMO only edits UTF-8. Converting the file for you would re-encode every
byte in it, not just the block, so it refuses instead — your file is untouched
and no backup was taken. Convert it to UTF-8 yourself and re-run.

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
| **Update and version drift are untested** | Marketplace entries can pin a `sha`; that a plugin update cannot silently swap a pinned install mid-session has not been exercised. Open debt, acknowledged. |
| **Windows symlink and read-only cases are skipped** | Those tests run on macOS and Linux. Windows ACL semantics differ from `chmod`, and creating a symlink there needs elevation. |
| **The advisory hook needs a POSIX shell** | Native Windows requires Git Bash or equivalent. PowerShell-only Windows gets no advisory, silently. Deliberate — see above. Everything else works there. |
| **Non-UTF-8 instruction files are refused, not converted** | UTF-16 and invalid UTF-8 are rejected with `SETUP-008` and left untouched. Converting them is your call, not the tool's. |
| **A file may be left empty after uninstall** | The file is never deleted, because provenance cannot be inferred from its contents afterwards. |
| **Ownership is content recognition, not proof of authorship** | A block is treated as the framework's when its body matches text the framework generates. Paste that text into your own file and it will be recognised -- correctly, since it is the framework's text. The guarantee is that content the framework never generates is never touched without `--force`. |
| **No blank line before the block** | The block is appended directly so that nothing is written outside the markers. If your file did not end with a newline, the marker shares that line. It renders identically; HTML comments produce no output. |
| **No external-user validation** | The Human Owner has run the walkthrough. Nobody outside the team that built it has. |

## What Axiom-PMO still is

A governance and development-handoff framework. It prepares and verifies
development handoffs. It does not replace developers or execution frameworks,
and Milestone 6 does not change that — it moves no authority, evidence, or
approval logic out of Milestones 1–5.
