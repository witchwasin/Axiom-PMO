# Milestone 6 threat model

> Status: **independent review completed — REQUEST CHANGES, twice.** Threats 3,
> 6, 14 and 15 were blocking findings from those reviews. All are now closed,
> and all are recorded here rather than quietly absorbed. Re-review pending;
> not accepted, not released.
>
> Four of this document's fifteen threats were found by a reviewer rather than
> by the people who wrote the code. That ratio is the most useful number on
> the page.

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

**Mitigation.** Removal takes the exact marker span and nothing else. The
`sep=`/`tail=` accounting that was the first attempt at this is gone — see
threat 16, which is the defect that attempt became. Insertion writes nothing
outside the span at all, not even a bridging newline, so there is no
surrounding whitespace for removal to have an opinion about.

If nothing remains after removal, the file is **not** deleted — see threat 17.

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

### 13. Coexistence with existing hooks, and platform reach

**Threat.** The advisory hook breaks, reorders, or suppresses hooks the user or
another plugin already registered.

**Mitigation.** It registers one `PreToolUse` entry under its own plugin,
matched to `Write|Edit|NotebookEdit`, with a timeout so a wedged advisory
cannot hang an edit. It returns no decision, so it cannot suppress anything.

**Evidence.** `hook-advisory-tests.ps1` registration assertions.
`clean-room-tests.ps1` scenario 6 installs into a repository with a
Superpowers-style `hooks/hooks.json` and asserts it is byte-identical
afterwards.

**Residual, two of them.**

**Hook ordering across plugins is not verified.** Claude Code's ordering and
merge behaviour for multiple registered hooks was not inspected; what *is*
verified is that this hook returns nothing that could override another.

**The advisory requires a POSIX shell.** The registered command is
`sh "${CLAUDE_PLUGIN_ROOT}/hooks/scope-advisory.sh"`, so a PowerShell-only
Windows environment silently gets no advisory. This is a Human Owner decision
(2026-08-01), not an oversight: the alternative is invoking PowerShell from the
hook, which works everywhere and costs ~200 ms on every Write and Edit for
every user who installed the plugin and never enabled the feature. Paying that
for a default-off advisory was judged not worth it. Setup, uninstall, the CLI,
the validators and the advisory's own PowerShell logic are all supported on
PowerShell-only Windows. The boundary is documented and asserted in
`hook-advisory-tests.ps1` rather than skipped.

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

### 15. Unsupported file encoding

**Threat.** The instruction file is not UTF-8. A lenient decode turns its bytes
into replacement characters, and writing back re-encodes **the whole file** —
from a command whose entire promise is that it appends one block.

**This was real, and it shipped.** Independent review found it; reproduced on a
UTF-16LE `AGENTS.md` whose BOM (`ff fe`) came back as `ef bf bd ef bf bd`. Every
byte in the document was rewritten. The backup was the only reason it was
recoverable at all.

**Mitigation.** Decoding is strict (`UTF8Encoding($false, $true)` — throw on
invalid, never substitute). UTF-16LE/BE and UTF-32 BOMs are detected by
signature; anything that fails a strict UTF-8 decode is refused. `SETUP-008`
fails closed, **and takes no backup and leaves no temporary file** — there is
nothing to protect a file from when nothing is going to be written to it.

Converting the file automatically was rejected as a fix. A command that
promises to append one section must not silently re-encode the other 99% of the
document, even helpfully.

**Evidence.** `setup-integration-tests.ps1` — UTF-16LE, UTF-16BE and invalid
UTF-8, each across install, dry-run and uninstall: byte-identical file, no
backup, no residue, and the encoding named in the diagnostic. Plus valid
non-ASCII UTF-8 (Thai, Japanese, Greek, emoji) round-tripping byte-for-byte, so
the refusal is not a blanket rejection of high bytes.

**Residual.** Users of UTF-16 instruction files must convert them by hand. The
diagnostic gives the command.

**Was FATAL. Now closed.**

### 16. Mutable marker metadata widening a deletion

**Threat.** The v1 block recorded `sep=N` and `tail=N` — how much surrounding
whitespace setup had added — so removal could reclaim it. Those attributes sit
inside a marker anyone can edit, while ownership is decided by the *body*. So a
block stays perfectly `owned` while its `sep` is changed from 2 to 6.

**This was real.** Independent review found it; reproduced by editing `sep=2` to
`sep=6` on an untouched, genuinely framework-generated block. Uninstall deleted
four of the user's newlines.

**Mitigation.** Not a bound, not a sanity check on the number. The number is
gone. The v2 format writes **nothing outside the markers that it expects to take
back**, so no attribute can control a deletion:

- insertion appends the block to the text exactly as found, with **nothing** in
  between — no separator, no bridging newline;
- removal splices exactly the marker span;
- `sep=` and `tail=` are not read at all. A v1 block installed earlier may leave
  a blank line behind, which is the deliberate trade: residue the user can
  delete in a second beats deleting a byte they wanted.

A first version of this fix kept a single bridging newline for files that did
not end with one, so the BEGIN marker would not share a line with the user's
last sentence, and did not reclaim it. Review rejected that too, correctly: it
made the round trip lossy — two bytes on CRLF, not the "at most one" claimed —
and the cosmetic gain did not justify a permanent edit to somebody's file.

**Evidence.** `setup-integration-tests.ps1` — `sep`/`tail` set to 0, to the real
former values, to 999, duplicated, and set to negative and non-numeric values,
with content above and below the block. Every case asserts the bytes outside
the span are identical.

**Residual.** None identified. The attributes are inert.

**Was MAJOR. Now closed.**

### 17. Inferring file provenance from its contents

**Threat.** Uninstall deleted the instruction file when nothing was left in it,
reasoning that setup must have created it. A repository whose `AGENTS.md` held
two blank lines before installing is indistinguishable, afterwards, from one
setup created.

**This was real.** Independent review found it; reproduced with a pre-existing
whitespace-only `AGENTS.md`, deleted on uninstall.

**Mitigation.** The file is never deleted. A zero-byte file may be left behind
and the output says so. The mutable alternative — writing `created=true` into a
marker anyone can edit — was rejected: that is guessing with extra steps, and
threat 16 is what that class of metadata already cost.

**Evidence.** `setup-integration-tests.ps1` — zero-byte, spaces-only,
newlines-only and mixed-whitespace files, asserting both bytes and file
existence across a round trip.

**Residual.** A user who wanted the file gone must delete it. Stated in the
output.

**Was MAJOR. Now closed.**

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
| 15 | **Unsupported file encoding** | Was **FATAL** | **Closed.** UTF-16 users must convert by hand |
| 16 | **Mutable marker metadata widening a deletion** | Was **MAJOR** | **Closed.** v1 blocks may leave a blank line behind |
| 17 | **Provenance inferred from file contents** | Was **MAJOR** | **Closed.** An empty file may be left behind |

**3, 6, 15, 16 and 17 were all found by independent review, not by this
document.** Every one was reproduced before being fixed. Their presence here is
the honest record: earlier versions of this threat model listed none of them,
because the code they described looked correct to the person who wrote it.

Two of the five (16 and 17) were introduced *by the fixes for* 3 and 6 — a
mechanism added to make removal precise became a new way to widen a deletion.
That is worth stating plainly rather than presenting the current design as
having been reasoned out in one pass.

Of the remainder, three residuals are real enough to name for a reviewer rather
than bury: **12**, **13**, and **14**. All three are acknowledged by the Human
Owner and remain open.
