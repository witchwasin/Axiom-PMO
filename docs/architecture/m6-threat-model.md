# Milestone 6 threat model

> Status: **independent review completed — REQUEST CHANGES.** Threats 3 and 6
> were the blocking findings. Both are now closed, and both are recorded here
> rather than quietly absorbed. Re-review pending; not accepted, not released.

Milestone 5's threat model asked "can an execution agent lie about what it
did?" This one asks a narrower and more physical question, because Milestone 6
introduced the first code in this framework that writes to a file somebody else
owns:

> **Can installing, running, or removing the Claude Code integration damage the
> user's repository, or manufacture authority that Milestones 1–5 would
> otherwise refuse?**

Residual risk is stated at the severity it actually has. Nothing below was
softened to make the milestone look finished.

## Attack surface

Three places, and it is worth being precise that most of the milestone is not
one of them:

| Surface | What it can touch |
|---|---|
| `scripts/setup-claude-integration.ps1` + `scripts/lib/marker-block.ps1` | One file in the user's repository. The only writer. |
| `hooks/scope-advisory.sh` + `scripts/hook-scope-advisory.ps1` | Nothing. Reads a payload and a project, writes stdout. |
| The plugin package (`.claude-plugin/`, `skills/`, `hooks/`) | Nothing at install time. Files on disk that Claude Code reads. |

## Threats

### 1. Unsafe path write

**Threat.** `-ProjectPath` is user-supplied and the command writes to it. A
traversing or crafted path writes outside the intended directory.

**Mitigation.** The path is resolved to an absolute real path *first*, then the
target's parent is compared against the resolved project root; a mismatch is
`SETUP-002`. Filtering `..` out of the input would be the weaker check —
resolution answers where the write lands, pattern-matching only answers what
the string looks like.

**Evidence.** `setup-integration-tests.ps1` — traversing path, non-existent
path, file-as-project-path.

**Residual.** A user who deliberately passes a path they should not have write
access to gets whatever the filesystem gives them. Out of scope: this is not a
privilege boundary.

**Non-blocking.**

### 2. Symlink attack

**Threat.** `AGENTS.md` is a symlink to something outside the project — a
dotfile, a shared config. Setup follows it and edits that instead.

**Mitigation.** Reparse points are detected and refused (`SETUP-003`). Not
followed, not resolved-and-continued.

**Evidence.** `setup-integration-tests.ps1` asserts refusal *and* that the
pointed-at file is byte-identical afterwards.

**Residual.** Not exercised on Windows, where creating a symlink needs
elevation and reparse-point semantics differ. The check reads
`FileAttributes.ReparsePoint`, which is the Windows-native mechanism, so it is
expected to hold — expected, not demonstrated.

**Non-blocking, with an untested platform.**

### 3. Forged ownership — an unkeyed digest is not provenance

**Threat.** The block's BEGIN marker records a SHA-256 of its own content. If
that is what decides ownership, anyone can write arbitrary content, compute the
matching digest, and have the framework treat the result as its own — then
replace or delete it without `-Force`.

**This was real, and it shipped.** Independent review found it; it was
reproduced before being fixed. A block containing a team's private deployment
notes, carrying a correctly computed digest, was removed by `-Uninstall` with
no warning and no `-Force`.

The mistake is one this framework has made before in a different costume. A
digest proves content has not changed since it was hashed. It proves nothing
about **who** hashed it, because computing a SHA-256 is exactly as easy as
writing the content it summarises. Milestone 5 learned that three times about
execution evidence; here it arrived as a marker describing itself.

**Mitigation.** Ownership is no longer decided by the self-declared digest. A
block is the framework's **only if its body matches a body the framework
generates** — the current canonical body, or one of the frozen historical
digests in `scripts/lib/marker-block.ps1`. The recorded digest is demoted to
what it can actually support: telling "edited after we wrote it" apart from
"never ours", so the message can be accurate about which.

Four states, and only the first permits an unforced change:

| State | Meaning |
|---|---|
| `owned` | body matches a canonical version |
| `edited` | not canonical, and does not match its own recorded digest |
| `foreign` | not canonical, but self-consistent — the forged case |
| `unknown` | not canonical, nothing to compare against |

The historical digests are frozen literals rather than computed, so that
editing the canonical body does not orphan every block already installed in
somebody's repository. A test asserts the current body's digest is in the list,
so changing the body without recording it fails the suite.

**Evidence.** `setup-integration-tests.ps1` — the forged case, with the digest
computed for real inside the test rather than hardcoded, asserting that neither
setup nor uninstall will touch it and that `-Force` is the only way through.
Also that stripping the digest from a *canonical* body does **not** make it
foreign, which pins down that the digest is not what proves ownership.

**Residual.** `-Force` still discards whatever is there — that is what it is
for, it is never implied by another flag, and a backup is taken first. A user
who copies the canonical body verbatim into their own file will have it
recognised as ours, which is correct: it is the framework's own text.

**Was FATAL. Now closed.**

### 4. Marker injection

**Threat.** A repository contains hostile text — forged markers, or
instructions aimed at the tool — to get authority-granting content written
into the block, or to have the block adopted as legitimate.

**Mitigation.** The block body is a constant in the framework's own source.
Nothing read from the repository reaches it. A forged block whose digest does
not match is not treated as framework-generated, so it is refused rather than
extended.

**Evidence.** `setup-integration-tests.ps1` (forged block granting itself
release authority: refused, then replaced under `--force` with the hostile text
gone). `clean-room-tests.ps1` case C: an `AGENTS.md` whose text instructs the
tool to record that the agent has human authority — the block written is
unchanged, and the user's hostile text is still preserved verbatim, because
preserving user content is not conditional on approving of it.

**Residual.** None identified for the written block. The user's own text
remains whatever they wrote, which is correct — this tool does not censor
repositories.

**Non-blocking.**

### 5. Partial write

**Threat.** An interrupted or failed write leaves a truncated `AGENTS.md`.

**Mitigation.** Written to a temporary file in the same directory, then moved
over the target. Same directory matters: a cross-filesystem move is a copy, and
a copy is not atomic. On failure the temporary file is removed.

**Evidence.** `setup-integration-tests.ps1` read-only case asserts the original
survives *and* that no `.axiom-write-*` residue is left.

**Residual.** `Move-Item -Force` is atomic on the platforms this targets;
that is a filesystem property, not one this repository verifies.

**Non-blocking.**

### 6. Rollback corruption / accidental deletion during uninstall

**Threat.** Uninstall removes more than it added — adjacent content, whitespace
the user owns, or a whole file it did not create.

**This was real too**, and independent review found it alongside the forged
digest. Removal reassembled the surrounding text with `TrimEnd`, `Trim`, and a
freshly chosen newline, so blank lines around the block were collapsed. The
user's *text* survived; their formatting did not. Whitespace is content.

**Mitigation.** Removal now takes the exact marker span, plus only what the
marker itself records as the framework's: `sep=N` characters before it and
`tail=N` after, and only when those exact characters are actually present.
Nothing else is read, trimmed, or rewritten. Insertion no longer trims the file
it appends to either — the original is a byte-exact prefix of the result.

Recording those amounts rather than inferring them is the whole mechanism: a
file that already ended with two blank lines is indistinguishable, after the
fact, from one where setup added them. If nothing remains after removal, the
file is removed *and the output says so*.

**Evidence.** `setup-integration-tests.ps1` asserts a byte-identical round trip
across ten file shapes — no trailing newline, one, three, five, leading blank
lines, trailing spaces, tabs, CRLF with and without a trailing newline, and a
single line — plus a block mid-file with content above and below, content
abutting the END marker with no blank line, and a BOM file with trailing blank
lines. Install is separately asserted to leave the original as an exact byte
prefix. `clean-room-tests.ps1` fingerprints every file in ten different
pre-existing repositories and asserts nothing outside `AGENTS.md` moved — this
is what caught the residue defect where an empty file was left behind.

**Residual.** A user whose `AGENTS.md` was deliberately empty before installing
loses an empty file on uninstall. Narrow, announced in the output, and
recoverable from the backup.

**Non-blocking.**

### 7. Backup substitution

**Threat.** A second run overwrites the backup from the first, so the "restore"
path restores the wrong content.

**Mitigation.** Timestamped to the second, with a counter appended on
collision. The timestamp is rendered in invariant culture — on a `th-TH`
machine `yyyy` renders the Buddhist year `2569`, so backups from two
differently-configured machines in one repository would not sort against each
other and "newest" would silently mean the wrong file.

**Evidence.** `setup-integration-tests.ps1` — three runs inside the same
second, each keeping a distinct backup.

**Residual.** Backups accumulate; nothing prunes them. Deliberate — a tool that
deletes its own backups to stay tidy is a tool that deletes the thing you
needed.

**Non-blocking.**

### 8. Command injection

**Threat.** A crafted path or payload becomes shell input.

**Mitigation.** No user input is interpolated into a shell command. PowerShell
receives arguments as an argument array. The shell shim quotes every expansion
and passes the payload on stdin rather than as an argument.

**Evidence.** `hook-advisory-tests.ps1` malformed-payload cases (not JSON, not
an object, null fields, unexpected fields) all exit 0 with no output.

**Residual.** The shim extracts `cwd` with `sed` rather than a JSON parser,
because `/bin/sh` has none. A crafted `cwd` yields a wrong or empty directory —
which produces silence, since the opt-in file will not be found there. It
cannot produce execution.

**Non-blocking.**

### 9. Malicious repository instructions

**Threat.** Repository content tries to instruct the agent that it has
authority it does not have.

**Mitigation.** Out of scope for this milestone, and deliberately so — this is
what Milestone 5 exists for. What Milestone 6 must guarantee is that it does
not *help*: the block it writes grants nothing, and no authority claim is
believed because a file said so.

**Evidence.** `clean-room-tests.ps1` — an execution result claiming
`release-approval` is still rejected by `EXEC-007` after the integration is
installed; an `agent-assertion` still fails to satisfy a required test
(`EXEC-005`); the out-of-scope file is still reported.

**Residual.** An agent that ignores its instructions is not constrained by
them. That is the whole reason verification happens afterwards.

**Non-blocking.**

### 10. Authority escalation through the integration

**Threat.** The integration becomes a new path to an approval — a hook that
"confirms" scope, a block that grants a claim type, a setup flag that waives a
rule.

**Mitigation.** No new authority path exists. The hook emits `systemMessage`
and nothing else; there is no code in it that could emit a permission decision,
which is asserted against the source with comments stripped. No `EXEC-*` rule,
claim type, actor, or policy default was changed by this milestone.

**Evidence.** `hook-advisory-tests.ps1` (source-level assertion, plus output
assertions on every case that speaks). `clean-room-tests.ps1` governance
section. `git diff` over the milestone touches no file under
`pmo-config/execution-contract-policy.json` except the hygiene allowlist.

**Residual.** None identified.

**Non-blocking.**

### 11. Plugin content drift

**Threat.** `skills/` is a generated mirror of `.claude/skills/`. They diverge,
and users run different guidance than the framework's own tests exercise.

**Mitigation.** `scripts/build-plugin-package.ps1 -Check` is a CI job. It
compares file set and bytes, with normalised path separators so a mirror built
on Windows and checked on Linux compares equal.

**Evidence.** `plugin-package-tests.ps1` exercises four drift directions
separately: source edited after packaging, new source skill never packaged,
packaged skill whose source was deleted, and an edit made to the package
instead of the source. Generation is reproducible — building twice, and
building in a fresh clone, produce the same digest.

**Residual.** The gate protects the repository. A user who edits the mirror
inside their own plugin install is beyond its reach.

**Non-blocking.**

### 12. Plugin update / version mismatch

**Threat.** A plugin update swaps the framework out from under a project
mid-work, so a contract exported by one version is verified by another.

**Mitigation.** Partial. Marketplace entries can pin a `sha`, and the plugin
version is asserted equal to the repository's `VERSION`. The execution contract
carries its own digest, so a *contract* cannot be silently swapped.

**Evidence.** `plugin-package-tests.ps1` version-consistency assertion. The
`sha`-pinning mechanism is observed in the official marketplace, not exercised
here.

**Residual.** **Real and untested.** Nothing verifies that an update cannot
replace a pinned install during a session. Milestone 6.1's spike flagged this
and it remains open.

**Non-blocking for review, and it should be named in the review.**

### 13. Coexistence with existing hooks

**Threat.** The advisory hook breaks, reorders, or suppresses hooks the user or
another plugin already registered.

**Mitigation.** It registers one `PreToolUse` entry under its own plugin,
matched to `Write|Edit|NotebookEdit`, with a timeout so a wedged advisory
cannot hang an edit. It returns no decision, so it cannot suppress anything.

**Evidence.** `hook-advisory-tests.ps1` registration assertions.
`clean-room-tests.ps1` scenario 6 installs into a repository with a
Superpowers-style `hooks/hooks.json` and asserts it is byte-identical
afterwards.

**Residual.** **Hook ordering across plugins is not verified.** Claude Code's
ordering and merge behaviour for multiple registered hooks was not inspected;
what is verified is that this hook returns nothing that could override another.

**Non-blocking, with an unverified interaction.**

### 14. Maintainer content shipped to users

**Threat.** The package carries files a user should not have, or that let a
maintainer command appear to work when it cannot.

**Mitigation.** The maintainer/user split is explicit and enforced:
maintainer-only tools fail with `FRAMEWORK-001` outside a checkout rather than
being made to work by shipping `VERSION` and friends into the package — which
would have them report a clean result for a copy they never inspected.

**Evidence.** `plugin-package-tests.ps1` and `plugin-install-spike-tests.ps1`.

**Residual.** **A git-source install carries the entire repository** — ~10 MB,
of which ~6.7 MB is `tests/`. Only `skills/`, `hooks/` and the manifests are
loaded; the rest is inert. Reducing it means moving the plugin root into a
subdirectory, which would require duplicating the validator there — forbidden
by this milestone's own constraints. Recorded as a limitation rather than
resolved.

**Non-blocking.**

## Summary

| # | Threat | Blocking? | Residual |
|---|---|---|---|
| 1 | Unsafe path write | No | Out of scope by design |
| 2 | Symlink attack | No | Untested on Windows |
| 3 | **Forged ownership (unkeyed digest)** | Was **FATAL** | **Closed.** `-Force` still overrides, by design |
| 4 | Marker injection | No | None identified |
| 5 | Partial write | No | Relies on filesystem move semantics |
| 6 | **Rollback corruption / whitespace loss** | Was **MAJOR** | **Closed.** Empty pre-existing file is still removed |
| 7 | Backup substitution | No | Backups accumulate, deliberately |
| 8 | Command injection | No | `sed`-based `cwd` extraction degrades to silence |
| 9 | Malicious repository instructions | No | M5's problem, not made worse |
| 10 | Authority escalation | No | None identified |
| 11 | Plugin content drift | No | Gate covers the repo, not a user's install |
| 12 | **Update / version mismatch** | No | **Real and untested** |
| 13 | Coexistence with existing hooks | No | **Cross-plugin ordering unverified** |
| 14 | Maintainer content shipped | No | **Whole repository ships on a git install** |

**3 and 6 were found by independent review, not by this document.** Both were
reproduced before being fixed. Their presence here is the honest record: the
first version of this threat model listed neither, because the code it was
describing looked correct to the person who wrote it.

Of the remainder, three residuals are real enough to name for a reviewer rather
than bury: **12**, **13**, and **14**. All three are acknowledged by the Human
Owner and remain open.
