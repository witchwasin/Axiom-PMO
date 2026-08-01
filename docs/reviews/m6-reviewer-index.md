# Milestone 6 — reviewer index

> **This is a map, not evidence.** Every claim below points at a file and a
> line so it can be checked against the source. Where the index and the source
> disagree, the source is right.

**Status**

| | |
|---|---|
| Implementation | complete, remediation applied |
| Hardening | complete (before the review findings) |
| Human Owner testing | complete |
| Human Owner acceptance | accepted — `DEC-005`, 2026-08-01 |
| Independent review | **three rounds, all REQUEST CHANGES** |
| Blocking findings | **2 FATAL, 8 MAJOR, 2 MINOR across three rounds — all implemented, awaiting re-review** |
| Milestone closure | **blocked pending re-review** |
| Release / tag / publication / merge | **not authorized** |

### Review history

Three review rounds so far. Recorded in full because the sequence is the useful
part — twice a fix for one finding created the next one.

| Round | Verdict | Findings |
|---|---|---|
| 1 | REQUEST CHANGES | 1 FATAL (ownership by self-declared digest), 1 MAJOR (removal mutating content outside the markers) |
| 2 | REQUEST CHANGES | 1 FATAL (unsupported encodings mangled, not refused), 4 MAJOR (mutable `sep=`/`tail=` widening a deletion; file provenance inferred from contents; Windows hook boundary unverified; duplicate `DEC-003`) |
| 3 | REQUEST CHANGES | 3 MAJOR (bridging newline broke the exact round trip; Windows Git Bash hook never functionally verified; governance records stale), 2 MINOR (UTF-32 BOM ordering; ownership and DryRun wording) |

All findings from all three rounds are implemented. Round 3 is what this
commit addresses.

**Two of them were caused by earlier fixes**, which is worth a reviewer's
attention more than any individual defect:

- Round 2's `sep=`/`tail=` MAJOR existed because round 1's fix added that
  metadata to make removal precise. It became a way to widen a deletion.
- Round 3's bridging-newline MAJOR existed because round 2's fix removed the
  metadata and kept one newline outside the span for cosmetics.

The current design has neither. Insertion writes **nothing** outside the marker
span — no separator, no bridging newline — so removal has nothing outside the
span to reason about, and install-then-uninstall returns the original bytes in
every case tested.

### What changed for round 3

**Exact round trip.** `Set-AxiomBlock` appends the rendered block directly to
the text as found. A file with no final newline now gets
`...rules<!-- AXIOM-PMO:BEGIN ... -->` on one line — tight in raw text,
identical when rendered, and exactly reversible. Byte-identical round trips are
asserted for LF, CRLF, no-final-newline, empty, whitespace-only, BOM, mid-file
and abutting cases, with file existence asserted alongside.

**Windows hook, functionally verified.** The previous Windows assertion checked
only the exit code, and the hook returns 0 whether it advises or silently does
nothing — so it proved nothing. It now asserts the *message*. Doing that
exposed a real defect: the shim extracted `cwd` from JSON without un-escaping
it, so a Windows path arrived as `C:\\Users\\dev\\repo`, the opt-in file
was looked for at a path that does not exist, and the advisory **never fired on
Windows at all**. Fixed, and covered on every host by giving a test project a
literal backslash in its directory name.

**Governance records.** `DEC-004`'s product-boundary reference corrected to
`DEC-006`. Stale descriptions of `sep=`/`tail=`-based removal removed.

**UTF-32 before UTF-16.** The UTF-32LE BOM begins with UTF-16LE's, so
UTF-32 files were refused correctly but named wrongly.

**Ownership wording.** Canonical-body matching is content *recognition*, not
proof of authorship — a user may paste the framework's own text into their
file and be recognised, which is correct. The guarantee is narrower and is now
stated as it actually is: content the framework never generates is never
touched without `-Force`.

### What to look at first this round### What to look at first this round

| | |
|---|---|
| Ownership model | `marker-block.ps1` — `Get-AxiomCanonicalBody`, `$AxiomKnownBodyDigests`, `Test-AxiomBlockOwnership`, `Get-AxiomOwnershipReason` |
| Exact-span removal | `marker-block.ps1` — `Remove-AxiomBlock` (span only, no whitespace accounting) and `Set-AxiomBlock` (appends with nothing in between) |
| Windows hook, functionally | `hooks/scope-advisory.sh` — JSON un-escaping of `cwd`; asserted in `hook-advisory-tests.ps1` by message, not exit code |
| Forged-digest regression | `setup-integration-tests.ps1` — the digest is computed for real inside the test, not hardcoded |
| Byte preservation | `setup-integration-tests.ps1` — ten file shapes, block mid-file, content abutting the END marker, BOM |
| Registry cannot silently orphan installs | `plugin-package-tests.ps1` — current canonical digest must be in the frozen list |

## Range

| | |
|---|---|
| Branch | `m6.1-plugin-packaging-spike` |
| Base commit | `6235e68` (`main` at the time the spike branched) |
| Diff range | `6235e68..HEAD` |
| Merged into it | `m6.0-claude-code-integration-research` (the 6.0 research, already reviewed) |

### Commits under review

| Commit | Phase | What it is |
|---|---|---|
| `445b2c7`, `6fb40e1` | 6.0 | Integration shape research and decision (HYBRID) — **already reviewed**, ACCEPT WITH MINOR REVISIONS |
| `86b5aa3` | 6.1 | Packaging spike — **already reviewed and accepted** by the Human Owner |
| `75d38cd` | 6.2 | Plugin packaging and drift gate |
| `7707bb8` | 6.3 | Setup, uninstall, rollback |
| `82de3ac` | 6.5 | Optional advisory hook |
| `9984158` | 6.4 | Clean-room compatibility and the real plugin-load transcript |

New review effort belongs on `75d38cd`, `7707bb8`, `82de3ac`, `9984158` and
the hardening commit that follows them.

## Where to start

If you read only three files, read these, in this order:

1. **[`scripts/lib/marker-block.ps1`](../../scripts/lib/marker-block.ps1)** —
   the only code in the milestone that writes to a file the user owns.
2. **[`scripts/hook-scope-advisory.ps1`](../../scripts/hook-scope-advisory.ps1)** —
   the only code that runs inside the user's editing loop.
3. **[`docs/architecture/m6-threat-model.md`](../architecture/m6-threat-model.md)** —
   thirteen threats with mitigation, evidence, and residual risk.

## Security-sensitive files

Ranked by what they can damage.

| File | Lines | Why it matters |
|---|---:|---|
| [`scripts/lib/marker-block.ps1`](../../scripts/lib/marker-block.ps1) | 371 | Reads, edits and removes content in the user's `AGENTS.md` |
| [`scripts/setup-claude-integration.ps1`](../../scripts/setup-claude-integration.ps1) | 304 | Path containment, symlink refusal, backup, orchestration |
| [`scripts/hook-scope-advisory.ps1`](../../scripts/hook-scope-advisory.ps1) | 163 | Runs on every Write/Edit when enabled; parses untrusted payloads |
| [`hooks/scope-advisory.sh`](../../hooks/scope-advisory.sh) | 41 | Shell, runs on every Write/Edit even when disabled |
| [`scripts/lib/framework-checkout.ps1`](../../scripts/lib/framework-checkout.ps1) | 86 | Decides maintainer-vs-user tooling |
| [`scripts/build-plugin-package.ps1`](../../scripts/build-plugin-package.ps1) | 117 | Generates packaged content; a drift here ships wrong guidance |

### Specific things worth your eyes

| Concern | Location |
|---|---|
| Path containment (resolve-then-compare, not pattern matching) | `setup-claude-integration.ps1:78-95` (`SETUP-001`, `SETUP-002`) |
| Symlink refusal | `setup-claude-integration.ps1:97-107` (`SETUP-003`) |
| Malformed-marker refusal | `marker-block.ps1:114-166` (`Find-AxiomBlock`), surfaced at `setup-claude-integration.ps1:144-152` (`SETUP-004`) |
| Ownership digest — the thing that stops a hand-edited block being destroyed | `marker-block.ps1:26-45` (`Get-AxiomBlockDigest`), `marker-block.ps1:168-187` (`Test-AxiomBlockOwnership`) |
| Refusal to replace or remove a non-owned block | `marker-block.ps1:212-265` (`Set-AxiomBlock`), `marker-block.ps1:267-316` (`Remove-AxiomBlock`); `SETUP-005`, `SETUP-006` |
| Atomic write | `marker-block.ps1:79-112` (`Write-TextFileAtomic`) |
| Backup, collision handling, invariant-culture timestamp | `marker-block.ps1:318-354` (`New-AxiomBackup`) |
| Encoding preservation (CRLF, BOM) | `marker-block.ps1:47-77` (`Read-TextFileState`) |
| The generated block's text — what it grants (nothing) | `setup-claude-integration.ps1:159-191` |
| The hook cannot emit a permission decision | `hook-scope-advisory.ps1` — no such field anywhere; asserted at `tests/helpers/hook-advisory-tests.ps1` |
| Opt-in checked before PowerShell is started | `hooks/scope-advisory.sh:24-27` |

## File inventory by phase

### 6.2 — packaging

| File | |
|---|---|
| `.claude-plugin/plugin.json` | new — plugin manifest |
| `.claude-plugin/marketplace.json` | new — self-marketplace, `source: "./"` |
| `skills/pmo-*/SKILL.md` (7) | new — **generated** mirror of `.claude/skills/` |
| `scripts/build-plugin-package.ps1` | new — generator and `-Check` drift gate |
| `scripts/lib/framework-checkout.ps1` | new — `FRAMEWORK-001` |
| `scripts/pmo-doctor.ps1`, `check-public-hygiene.ps1`, `measure-context.ps1`, `prepare-public-release.ps1`, `run-validation-tests.ps1`, `run-all-checks.ps1` | modified — guarded |

### 6.3 — setup and uninstall

| File | |
|---|---|
| `scripts/lib/marker-block.ps1` | new |
| `scripts/setup-claude-integration.ps1` | new |
| `cli/axiom.mjs` | modified — `setup` verb (`buildSetup`) |

### 6.4 — clean-room

| File | |
|---|---|
| `scripts/capture-plugin-load-evidence.ps1` | new — drives the real `claude` CLI |
| `docs/evidence/plugin-load-transcript.md` | new — captured transcript |

### 6.5 — hook

| File | |
|---|---|
| `hooks/hooks.json` | new — registration |
| `hooks/scope-advisory.sh` | new — shim |
| `scripts/hook-scope-advisory.ps1` | new — advisory |

### Documentation

`docs/guides/claude-code-integration.md`,
`docs/guides/claude-code-walkthrough.md`,
`docs/architecture/m6-threat-model.md`,
`docs/architecture/plugin-packaging-spike.md`, this file, plus `README.md`,
`ROADMAP.md`, `CHANGELOG.md`.

## Tests

| Suite | Cases | Covers |
|---|---:|---|
| [`plugin-install-spike-tests.ps1`](../../tests/helpers/plugin-install-spike-tests.ps1) | 17 | Framework runs from a non-checkout, non-cwd, read-only install root |
| [`plugin-package-tests.ps1`](../../tests/helpers/plugin-package-tests.ps1) | 38 | Manifests, mirror completeness, four drift directions, `FRAMEWORK-001`, **canonical-body digest registry** |
| [`setup-integration-tests.ps1`](../../tests/helpers/setup-integration-tests.ps1) | 122 | Malformed markers, hand edits, CRLF, BOM, symlink, read-only, traversal, backup collision, forged blocks, **correctly forged digest**, **byte preservation across ten file shapes** |
| [`clean-room-tests.ps1`](../../tests/helpers/clean-room-tests.ps1) | 61 | Ten repository shapes, fingerprinted; governance assertions |
| [`hook-advisory-tests.ps1`](../../tests/helpers/hook-advisory-tests.ps1) | 46 | Off by default, no decision, never breaks a tool call |
| `cli-tests.mjs` | 50 | Includes 8 new `setup` cases |

CI found two Windows defects the maintainer's machine could not: the advisory
hook compared paths case-sensitively against a differently-normalised prefix
(so an in-project file read as outside the project and was silently ignored),
and three suites branched on a bare `$IsWindows`, which is `$null` on Windows
PowerShell 5.1 and therefore ran "Unix only" cases on Windows. The second is now
enforced by [`DOCTOR-011`](../rules/DOCTOR-011.md) across `scripts/` and
`tests/`.

All wired into `scripts/run-all-checks.ps1`, so every supported host runs them.

## Evidence that is not a test

- **[`docs/evidence/plugin-load-transcript.md`](../evidence/plugin-load-transcript.md)** —
  a real `claude plugin marketplace add` / `install` / `details` run. 7 skills
  discovered, 1 hook registered. Regenerate with
  `pwsh -File scripts/capture-plugin-load-evidence.ps1`. Home-directory paths
  are redacted inside the capture script, so re-running it cannot leak them.
- **Reproducibility** — building the package twice, and building it in a fresh
  clone, produce byte-identical `skills/`. Installing from that fresh clone
  loads 7 skills and 1 hook.

## Claims I am asking you to confirm

1. `marker-block.ps1` never modifies content outside its own markers, on any
   input — including whitespace.
2. Ownership cannot be forged: no body the framework did not generate can be
   made to read as `owned`, by any digest, marker attribute, or encoding.
3. Install followed by uninstall returns the original bytes, for every file
   shape, with no residue and no permanent addition.
4. The advisory hook cannot, at any input, cause an edit to be blocked.
5. Nothing in Milestone 6 creates a new approval path or weakens an `EXEC-*`
   rule.
6. The setup command cannot be induced by repository content to write
   authority-granting text.
7. The documentation does not overclaim — specifically that nothing says or
   implies Milestone 6 prevents an out-of-scope edit.

## Claims I am deliberately not making

- That the plugin was loaded and its skills *invoked* end to end. Discovery is
  proven; invocation behaviour is the skills' own content, unchanged here.
- That permission-prompt behaviour was characterised. It depends on the user's
  own settings and was not measured.
- Any Windows-specific symlink or read-only behaviour. Those cases skip there.
- Any external-user validation. None has happened.
- That a plugin update cannot swap a pinned install mid-session. Untested.
- That cross-plugin hook ordering is safe. Unverified.

## Known limitations and residual risks

Full list: [`m6-threat-model.md`](../architecture/m6-threat-model.md) §Summary
and [`claude-code-integration.md`](../guides/claude-code-integration.md#known-limitations).

The three worth your time. All three are acknowledged by the Human Owner,
explicitly **not** closed by his acceptance, and recorded under Deferred
technical debt in `ROADMAP.md`:

| | |
|---|---|
| **Update / version drift** | Untested. Marketplace `sha` pinning exists; that it prevents a mid-session swap is not demonstrated. |
| **Cross-plugin hook ordering** | Unverified. What *is* verified is that this hook returns nothing that could override another. |
| **Git install carries the whole repository** | ~10 MB, ~6.7 MB of it `tests/`. Only `skills/`, `hooks/` and the manifests are loaded. Slimming it would mean duplicating the validator, which this milestone forbids. |

## Confirmations

- Human Owner acceptance recorded as `DEC-005`; it is offered as one half of
  acceptance, never as review evidence.
- No known debt was closed by that acceptance.
- No merge to `main`.
- No tag created.
- No GitHub Release.
- No marketplace publication.
- No version bump to a final release.
- The hook ships **off**, and report-only when on.
- No `EXEC-*` rule, claim type, actor, or policy default changed.
- The maintainer's machine was restored: the plugin and marketplace added
  during evidence capture were removed again.
