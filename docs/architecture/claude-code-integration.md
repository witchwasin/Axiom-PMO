# Claude Code Integration — Milestone 6.0 research

> Status: **research complete, decision recorded.** This document is Milestone
> 6.0's required output: an evaluation of the candidate integration shapes
> against primary evidence, and an explicit decision on which shape Milestone
> 6.1+ should build. It is design, not shipped code — nothing here installs
> anything, and no file outside this repository was modified to produce it.

## 1. Objective

`ROADMAP.md`'s Milestone 6 asks for Axiom-PMO to be natural for Claude Code
users "without damaging existing repository configuration," and explicitly
refuses to assume the answer is an installer:

> Do not assume the final shape is an installer. Prototype and evaluate:
> copyable integration block; Claude skill pack; command set; plugin; MCP
> command; hook; `axiom setup claude`.

Milestone 6.0's job is to pick one, with reasons, before any of it is built.

## 2. What was inspected, and how

Same discipline as Milestone 5.0: primary sources on this machine, not
recollection.

- **This repository's own Claude Code integration** — `.claude/skills/pmo-*`
  (7 skills), `.claude/settings.json`, `AGENTS.md`, `CLAUDE.md`,
  `CONTEXT-ROUTER.md`.
- **A real, current clone of `superpowers`** (`https://github.com/obra/superpowers`,
  commit `44c9b2d6`, plugin version `6.2.0`) — a mature, widely-used Claude Code
  skills library, inspected as a worked example of how this problem is solved in
  production. The same clone Milestone 5.0 used, re-read for a different question.

### 2.1 What a Claude Code plugin actually is

`.claude-plugin/plugin.json` is **metadata only**:

```json
{ "name": "superpowers", "description": "...", "version": "6.2.0",
  "author": {...}, "homepage": "...", "repository": "...",
  "license": "MIT", "keywords": [...] }
```

It declares no skills, no hooks, no commands. Those are discovered **by
convention** from the plugin root. The whole of what `superpowers` ships is:

```text
skills/<name>/SKILL.md      one directory per skill, frontmatter: name, description
hooks/hooks.json            event registration
hooks/<script>              the hook implementations
scripts/                    supporting scripts
```

`${CLAUDE_PLUGIN_ROOT}` is available to hook commands (`hooks.json` uses it to
locate its own scripts), so a plugin can carry and invoke executable content
from its own directory.

Distribution is a `marketplace.json`, and a repository can be its own
marketplace:

```json
{ "name": "superpowers-dev", "owner": {...},
  "plugins": [ { "name": "superpowers", "version": "6.2.0", "source": "./" } ] }
```

`superpowers` additionally ships `.codex-plugin/`, `.cursor-plugin/`, and
`.kimi-plugin/` manifests plus a cross-harness `.agents/plugins/marketplace.json`
— one content tree, several per-harness wrappers.

### 2.2 Axiom-PMO's skills are already the right shape

```text
.claude/skills/pmo-intake/SKILL.md
---
name: pmo-intake
description: Use when turning source material into scoped, source-referenced PMO requirements and intake decisions.
---
```

Byte-for-byte the same convention `superpowers` uses. **Packaging the seven
skills as a plugin is close to mechanical** — a directory move plus two small
manifests. That is a real finding: it removes "build a skill pack" from the
candidate list, because the skill pack already exists and already conforms.

### 2.3 Verified vs. not verified

Stated explicitly so a later reader does not mistake inference for evidence.

**Verified from primary source:** plugin manifest shape and that it is
metadata-only; convention-based discovery of `skills/` and `hooks/`;
`hooks.json` event registration format; `${CLAUDE_PLUGIN_ROOT}` availability;
marketplace manifest shape including `"source": "./"`; skill frontmatter
contract; that a mature plugin ships skills and hooks and nothing else.

**Not verified, and therefore not relied on by the decision below:** whether
plugins can carry slash `commands/` (the reference plugin has none); whether
an MCP server can be distributed through a plugin manifest; the exact install
UX and whether it requires a marketplace or accepts a direct repository
reference. Milestone 6.1 must confirm these against the current Claude Code
release before depending on any of them.

Also not verified, specifically about running *this* framework's own
multi-file PowerShell validator from inside a plugin -- `${CLAUDE_PLUGIN_ROOT}`
being available to a hook script (confirmed above) is a narrower fact than "a
skill can invoke an executable at that path and have it work end-to-end under
the current permission model." Before §8's directory move happens for real,
Milestone 6.1 needs a spike proving:

- a skill can actually invoke an executable at `${CLAUDE_PLUGIN_ROOT}` under
  the current Claude Code permission model;
- PowerShell host resolution (`scripts/lib/pwsh-host.ps1`'s
  `AXIOM_PWSH`/current-host/PATH fallback chain) still works when invoked
  from a plugin's install location, which is not necessarily a plain git
  checkout;
- relative paths and `. (Join-Path $PSScriptRoot ...)` dot-sourcing survive
  that location;
- `$FrameworkRoot` (framework config) and `$ProjectPath`/`$GitRepoRoot` (the
  user's own repo) stay correctly distinguished, the same distinction M4's
  GitHub Action already has to make between `github.action_path` and
  `GITHUB_WORKSPACE`;
- a plugin update does not silently drift a pinned version out from under a
  project mid-work;
- Windows path quoting behaves the same as it does today;
- `templates/` is readable from a plugin install without needing to be
  writable there.

This spike is Milestone 6.1's first deliverable, not an assumption 6.1 starts
from.

## 3. The thing being distributed is not one thing

This is the finding that decides the milestone. "Install Axiom-PMO" is
shorthand for six different kinds of content with different homes:

| # | Content | Must live in the user's repo? |
|---|---|---|
| 1 | Skills (`.claude/skills/pmo-*`) | No — behavioural guidance, reusable |
| 2 | Validator (`scripts/*.ps1`, `cli/axiom.mjs`) | No — executable machinery |
| 3 | Framework config (`pmo-config/*.json`) | No — versioned with the validator |
| 4 | Templates and examples | No — copied on demand |
| 5 | Agent behavioural rules (`AGENTS.md`, `CLAUDE.md`, `CONTEXT-ROUTER.md`) | **Yes** — see §4 |
| 6 | Governed artifacts (`PROJECT.md`, `DELIVERY.md`, `SCOPE.json`, `decision-log.md`) | **Yes** — this is the user's own content |

Items 1–4 are the framework. Items 5–6 are the user's project. Every candidate
shape in the roadmap's list is really a proposal about **where the line
between those two sits**, and most of the list collapses once the question is
put that way.

## 4. The constraint that rules out a plugin-only answer

`AGENTS.md` opens with:

> Shared rules for Claude, Codex, Cursor, Copilot, and other AI agents.

A Claude Code plugin serves Claude Code. It does nothing for a user running
Codex or Cursor against the same repository — and this framework's whole
premise is that *any* agent working in the repo obeys the same governance
rules. Shipping the behavioural rules only as a Claude Code plugin would
quietly narrow a multi-agent framework into a single-vendor one.

`superpowers` hits the same wall and answers it the same way: one content tree,
four per-harness manifests. It does not pick a harness; it wraps the content
per harness.

So item 5 (`AGENTS.md` / `CLAUDE.md`) has to reach the user's repository as
files, whatever else happens. That is the irreducible part — and it is exactly
the part the roadmap's installer constraints (detect, back up, append
namespaced, report conflicts, support uninstall) were written for.

## 5. Candidate evaluation

| Candidate | Verdict |
|---|---|
| **Plugin** | **Adopt** for items 1–4. Native distribution, installs and uninstalls without touching a single file in the user's repository, versioned independently, and the reference implementation proves it carries both skills and executable content. |
| **Claude skill pack** | Not a separate option — the skill pack *is* the plugin's `skills/` directory, and it already exists in conforming shape (§2.2). |
| **Copyable integration block** | **Adopt** for item 5, as the honest minimum. A short, namespaced block the user pastes (or a command appends) into the repository-level `AGENTS.md` (the intended cross-agent governance source), which harness-specific files such as `CLAUDE.md` may reference or supplement. Zero-risk and is the fallback when any automation is declined -- but see the caveat below before calling it universal. |
| **`axiom setup claude` installer** | **Adopt narrowly**, and only as a convenience wrapper around the copyable block plus `axiom init`. Its blast radius shrinks to one appended section once items 1–4 live in the plugin — which is the whole reason to sequence it this way rather than build a big installer first. |
| **Hook** | **Defer to a separate, opt-in milestone.** Genuinely new capability, not packaging (§6), and the riskiest thing on the list. |
| **Command set** | **Defer, unverified.** The reference plugin ships none, and plugin `commands/` support was not confirmed (§2.3). Revisit in 6.1 once verified. |
| **MCP command** | **Deferred -- no proven need for the M6 MVP**, not rejected outright. An MCP server today would be a running process wrapping a validator the CLI and GitHub Action already expose, which is a delivery mechanism, not a capability, and `docs/architecture/control-plane.md` already warns against surface area without a proven need. That could change: a structured diagnostics resource, a safe read-only contract lookup, or an exact schema-driven tool call could plausibly reduce prompt-parsing surface later. Revisit if a concrete need appears; do not treat this line as closing the door permanently. |

**Caveat on "works for every harness":** a file's mere presence in a repository does not prove every harness reads and obeys it -- `AGENTS.md` is written to be the shared cross-agent source, but each harness's own discovery and precedence rules (which files it looks for, in what order, how it merges them with a harness-specific file) are a separate, unverified question per harness. Compatibility with each one must be checked directly, not inferred from the file existing. This is exactly the kind of claim §2.3 already disciplines itself to separate from verified fact; the table entry above should be read with the same discipline.

## 6. The hook, considered separately

A `PreToolUse` hook that blocked edits to files outside `SCOPE.json` would turn
Axiom-PMO from **detective** (report a violation after the fact) into
**preventive** (stop the edit happening). That is a real capability gain and
the most interesting item on the roadmap's list.

It is also the one that can make a user's editor feel broken. A false positive
does not produce a report a human triages later — it blocks work, right now,
and the natural response is to disable the hook and stop trusting the tool.

The precedent for how to introduce it already exists in this repository: SCOPE-DIFF
and the GitHub Action both default to `enforce: false`, report fully, and block
nothing until a human opts in. A governance hook must ship the same way, and it
should be its own milestone with its own acceptance — not a rider on packaging
work.

## 7. Decision

**HYBRID: plugin for the framework, minimal namespaced files for the project.**

```text
Claude Code plugin  (installed once, outside the user's repo)
  skills/pmo-*            the 7 existing skills, unchanged
  scripts/, cli/          the validator, invoked via ${CLAUDE_PLUGIN_ROOT}
  pmo-config/*.json       framework runtime config
  templates/              scaffolding source

User's repository  (created or appended, always reviewably)
  CLAUDE.md / AGENTS.md   one short namespaced Axiom-PMO section
  PROJECT.md, DELIVERY.md, SCOPE.json, ...   the user's governed artifacts
```

Rationale, in the order that decided it:

1. **The safest way to satisfy "without damaging existing repository
   configuration" is to not write to the user's configuration.** Items 1–4 are
   the bulk of Axiom-PMO and none of them need to be in the user's repo. Moving
   them out of scope for the installer removes most of the risk the roadmap's
   constraints were guarding against, rather than mitigating it.
2. **The remainder cannot be avoided.** `AGENTS.md`/`CLAUDE.md` must be files in
   the repo to reach non-Claude agents (§4), and governed artifacts are the
   user's own content by definition. So a small, careful append is required —
   and *only* a small, careful append.
3. **It matches the one worked example available.** `superpowers` ships one
   content tree with per-harness manifests and touches no user files. Copying a
   proven distribution shape beats inventing one.
4. **It degrades safely.** Every automated step has a documented manual
   equivalent: install the plugin by hand, paste the block by hand, run
   `axiom init` or copy `templates/` by hand. A user who declines all automation
   still ends up with a working setup.

## 8. What Milestone 6.1+ would build

Not authorized by this document; recorded so the scope is visible before
anyone approves it. Sequenced as separately acceptable steps rather than one
milestone, so a spike finding (§2.3) can change later steps without having
already built on top of a wrong assumption:

1. **Plugin packaging** (M6.1): the §2.3 spike first, then, only once it
   passes, `.claude-plugin/plugin.json`, `marketplace.json`, and whatever
   restructuring lets the plugin root carry `skills/` — decided against the
   constraint that this repository's own CI, tests, and layout keep working
   unchanged.
2. **Namespaced repo integration** (M6.2): the copyable `AGENTS.md` block --
   fenced Axiom-PMO markers, idempotent append, backup before touching an
   existing file, conflict report.
3. **Setup/uninstall safety** (M6.3): `axiom setup claude` as a convenience
   wrapper over 1 and 2, with a `--dry-run` that prints what it would do and
   changes nothing, refusal to proceed on an unclean working tree, and
   uninstall that removes exactly what was added and nothing else.
4. **Clean-room compatibility** (M6.4): install into a repository that
   already has its own `CLAUDE.md`, its own skills, and Superpowers
   installed, and prove nothing of theirs was lost. This is the packaging
   work's definition of done and it cannot be satisfied by unit tests.
5. **Human acceptance of the integration MVP**, then, only after that:
6. **Optional preventive hook pilot** (M6.5): the §6 hook, opt-in and
   report-only by default like SCOPE-DIFF and the GitHub Action, with its
   own separate acceptance and a transparent bypass/disable path. Not
   bundled into 1–4 -- it is new capability, not packaging, and ships only
   once the packaging MVP itself is accepted.

## 9. What this does not change

- No file outside this repository was read for configuration purposes or
  modified. This research inspected a local clone of a public project and this
  repository's own files, nothing else.
- The seven skills, `AGENTS.md`, `CLAUDE.md`, and `CONTEXT-ROUTER.md` are
  unmodified. Restructuring for plugin packaging is 6.1 work, deliberately not
  done here.
- Milestone 6 remains **gated on separate human approval** per `ROADMAP.md`.
  This decision records which shape to build; it is not permission to build it.
- The hook (§6) is explicitly carved out as a separate, later, opt-in milestone
  rather than folded into packaging.
