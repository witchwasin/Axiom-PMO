# Try the Claude Code integration — 15 minutes

> **Status: CLOSED.** Independent review complete (ACCEPT WITH MINOR
> REVISIONS); Human Owner accepted and closed 2026-08-01 (`DEC-007`). Merged
> to `main` and tagged in `v1.3.0`; not published to a marketplace or npm.

You should not need to read `ROADMAP.md` to try this. Everything you need is
below.

**What you are evaluating:** an optional bridge that hands a verified work
package to Claude Code and then checks what comes back. Not a coding tool, and
not a replacement for your developers.

## Before you start (2 min)

You need:

- **Node.js 22+** — the engine and the `axiom` CLI run entirely in-process
- **Claude Code** with the `claude plugin` command (`claude plugin list`)
- **git**
- **A scratch git repository you do not mind changing.** Do not use real work
  for a first run.

## 1. Install the plugin (2 min)

```bash
git clone https://github.com/witchwasin/Axiom-PMO
```

```bash
claude plugin marketplace add ./Axiom-PMO
```

```bash
claude plugin install axiom-pmo@axiom-pmo
```

```bash
claude plugin details axiom-pmo
```

**Expected:** `Skills (7)`, `Hooks (1)`, and a projected always-on cost around
330 tokens.

✅ Nothing in any repository of yours has changed yet.

## 2. Make a sample project (3 min)

In your scratch repository:

```bash
node Axiom-PMO/cli/axiom.mjs init --code P01-TRY --mode Standard
```

If you would rather not use Node, copy `Axiom-PMO/templates/` by hand — the
init command does nothing else.

Then add a `SCOPE.json` declaring what may be touched:

```json
{
  "schema_version": "1.0",
  "project": "P01-TRY",
  "implementation_scope": { "include": ["src/**"], "exclude": [] }
}
```

## 3. Preview the repository change (2 min)

```bash
node Axiom-PMO/cli/axiom.mjs setup claude --project . --dry-run
```

**Expected:** it prints the exact block it would add, reports anything else it
found (`CLAUDE.md`, existing skills, Superpowers, BMAD) as *left untouched*,
and writes nothing.

✅ Confirm your files are unchanged: `git status`.

Now apply it:

```bash
node Axiom-PMO/cli/axiom.mjs setup claude --project .
```

**Expected:** one fenced block appended to `AGENTS.md`, and a backup file
beside it. `git diff` should show **only** that block.

Run it a second time. **Expected:** `already up to date`, and no second block.

## 4. Hand work to Claude Code (3 min)

Export a work item as a contract:

```bash
node Axiom-PMO/cli/axiom.mjs export --project . --work-item D-001 --grant commit
```

Then open Claude Code in that repository and ask it to implement `D-001`. The
block in `AGENTS.md` points it at `PROJECT.md`, `DELIVERY.md`, `SCOPE.json`,
and the exported contract.

**What to watch for:** it should read the governed context rather than invent
requirements. **What it will not do:** be prevented from editing outside
`SCOPE.json`. That is deliberate — the check happens next.

## 5. Verify what came back (2 min)

```bash
node Axiom-PMO/cli/axiom.mjs verify --project . --result .execution/D-001/EXECUTION-RESULT.json
```

**Expected:** a per-rule verdict. Deliberately try to make it lie — add an
authority claim to the result file:

```json
{ "type": "release-approval", "actor": "human", "claim": "approved", "decision_ref": "DEC-001" }
```

**Expected:** `EXEC-007` rejects it. An agent cannot approve its own work, and
the integration did not change that.

## 6. Try the optional hook (1 min)

```bash
mkdir -p .axiom && echo '{ "scope_advisory": true }' > .axiom/hooks.json
```

Ask Claude Code to edit a file outside `src/`. **Expected:** an advisory note.
**Expected:** the edit still happens — it reports, it does not block.

Remove `.axiom/hooks.json` to turn it off again.

## 7. Remove everything (1 min)

```bash
node Axiom-PMO/cli/axiom.mjs setup claude --project . --uninstall
```

```bash
claude plugin uninstall axiom-pmo
```

```bash
claude plugin marketplace remove axiom-pmo
```

✅ **The most important check of the whole walkthrough:** `git diff` on
`AGENTS.md` should be empty. Everything you had before should be exactly as it
was.

## Acceptance checklist

Tick what actually happened, not what was supposed to.

- [ ] The plugin installed and reported 7 skills
- [ ] `--dry-run` changed nothing on disk
- [ ] Setup added exactly one block and touched no other file
- [ ] Running setup twice did not duplicate anything
- [ ] My existing `CLAUDE.md` / skills / other frameworks were untouched
- [ ] Claude Code read the governed context instead of inventing requirements
- [ ] `verify` rejected an authority claim the agent was not entitled to
- [ ] The hook stayed silent until I opted in, and never blocked an edit
- [ ] Uninstall restored my repository exactly
- [ ] I understood what it does without reading `ROADMAP.md`

## Questions we would like answered

1. At which step, if any, did you have to guess what to do next?
2. Was it clear at all times what would be written to your repository *before*
   it was written?
3. Did anything surprise you about what setup or uninstall touched?
4. Did the distinction between "this gives the agent context" and "this
   enforces scope" come across, or did you expect it to prevent edits?
5. Was the hook's cost noticeable while it was enabled?
6. Would you install this into a repository you actually care about? If not,
   what would have to change first?
7. Did anything read as overclaiming — a promise the tool did not keep?

## If something went wrong

Please report it with:

```text
What I ran:            (exact command)
What I expected:       
What happened:         (exact output, including any error id such as SETUP-004)
Host:                  macOS / Linux / Windows, and `node --version`
Claude Code version:   `claude --version`
Repository shape:      did it already have AGENTS.md / CLAUDE.md / other frameworks?
Recoverable?           did the .axiom-backup-* file contain what you expected?
```

The last line matters most. If a backup did not hold what you expected, that is
the highest-severity report you can send.

Known limitations are listed in
[`claude-code-integration.md`](claude-code-integration.md#known-limitations) —
worth a glance before reporting, in case what you hit is already known.
