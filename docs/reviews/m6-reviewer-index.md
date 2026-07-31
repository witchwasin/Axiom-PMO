# Milestone 6 — reviewer index

> **This is a map, not evidence.** Every claim below points at a file and a
> line so it can be checked against the source. Where the index and the source
> disagree, the source is right.

**Status: implemented, under review.** Not accepted, not delivered, not
released, not tagged, not published, not merged to `main`.

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
| [`plugin-package-tests.ps1`](../../tests/helpers/plugin-package-tests.ps1) | 33 | Manifests, mirror completeness, four drift directions, `FRAMEWORK-001` |
| [`setup-integration-tests.ps1`](../../tests/helpers/setup-integration-tests.ps1) | 90 | Malformed markers, hand edits, CRLF, BOM, symlink, read-only, traversal, backup collision, forged blocks |
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
   input.
2. The ownership digest genuinely prevents a hand-edited block being destroyed
   without `-Force`, and cannot be trivially forged into a false "owned".
3. The advisory hook cannot, at any input, cause an edit to be blocked.
4. Nothing in Milestone 6 creates a new approval path or weakens an `EXEC-*`
   rule.
5. The setup command cannot be induced by repository content to write
   authority-granting text.
6. The documentation does not overclaim — specifically that nothing says or
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

The three worth your time:

| | |
|---|---|
| **Update / version drift** | Untested. Marketplace `sha` pinning exists; that it prevents a mid-session swap is not demonstrated. |
| **Cross-plugin hook ordering** | Unverified. What *is* verified is that this hook returns nothing that could override another. |
| **Git install carries the whole repository** | ~10 MB, ~6.7 MB of it `tests/`. Only `skills/`, `hooks/` and the manifests are loaded. Slimming it would mean duplicating the validator, which this milestone forbids. |

## Confirmations

- No merge to `main`.
- No tag created.
- No GitHub Release.
- No marketplace publication.
- No version bump to a final release.
- The hook ships **off**, and report-only when on.
- No `EXEC-*` rule, claim type, actor, or policy default changed.
- The maintainer's machine was restored: the plugin and marketplace added
  during evidence capture were removed again.
