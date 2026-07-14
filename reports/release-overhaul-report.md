# Axiom-PMO Public Release Overhaul Report

## 1. Executive summary

The repository formerly named `PMO-Template-Personal` has been overhauled into a
public-ready open-source project: **Axiom-PMO — The Anti-Hallucination Framework
for AI Agents**, positioned as a governance control plane that operates alongside
AI execution frameworks. The deterministic validation engine, anti-hallucination
controls, risk-adaptive modes, evidence model, and full test suite were preserved
without weakening. Version was set to a canonical `1.0.0`. Private material was
removed, sanitized, or archived. Community, license, documentation, and
interoperability materials were added. All enforced checks are green; no git
mutation was performed.

## 2. Baseline

- Branch: `main` (unchanged; no commits made).
- Framework version at start: `0.5.1`.
- Baseline enforced checks (pre-overhaul):
  - `pmo-doctor.ps1` — exit 0, PASS=52 WARN=0 FAIL=0.
  - `run-validation-tests.ps1 -VerifyGolden` — exit 0, PASS=95 FAIL=0, golden 90/90.
  - `run-all-checks.ps1` — exit 0, all pass incl. Lite/Standard/Strict E2E.
  - `capture-examples.ps1 -Verify` — exit 1 (pre-existing drift; not CI-enforced).
- Full detail: `reports/public-release-baseline.md`.

## 3. Rebranding

- Product identity → **Axiom-PMO** in: `README.md` title, `AGENTS.md` title,
  `CLAUDE.md` title, five user-facing script display strings
  (`result-writer.ps1`, `pmo-doctor.ps1`, `run-all-checks.ps1` x2,
  `run-validation-tests.ps1`), and the `docs/UserManual/*.puml` diagram labels.
- **Preserved as generic identifiers** (not renamed): the `pmo-` prefix on skill
  names, `pmo-config/`, script filenames, rule ids, and template/example names —
  renaming would break the doctor's hardcoded lists, the skill manifest, CI
  paths, and golden fixtures for no user benefit.
- Old-name exceptions (approved, retained): `docs/migration/from-pmo-template-personal.md`
  and the sanitized `CHANGELOG.md` history note.
- Verified: no title-case `PMO-Template-Personal` remains in any tracked or new
  file outside those two locations.

## 4. README and documentation

- `README.md` fully rewritten: hero + one-line value proposition, the problem,
  why execution frameworks still need governance, a case-study callout,
  Control-Plane vs Execution-Plane architecture (Mermaid + responsibility split),
  a capability comparison, the three modes, quick start, validation commands,
  repo layout, the skill system, the human-authority model, security,
  contributing, roadmap, license, and status.
- New docs: `docs/concepts/` (anti-hallucination, evidence-based-execution,
  human-authority, risk-modes), `docs/architecture/` (control-plane,
  validation-engine), `docs/governance/` (source-ownership, release-readiness),
  `docs/tutorials/` (first-project, using-with-an-ai-agent),
  `docs/integrations/` (overview + superpowers/bmad/spec-kit/openspec/
  claude-code-frameworks), `docs/migration/from-pmo-template-personal.md`,
  `docs/releases/v1.0.0.md`.
- Case study: `case-studies/unauthorized-git-mutation.md` — a sanitized,
  blame-free account of the unauthorized-git-mutation incident and the controls
  it produced.

## 5. Open-source cleanup

| Original path | Disposition | Reason |
|---|---|---|
| `reports/process-violation.md` | Source for `case-studies/unauthorized-git-mutation.md`; original sanitized + moved to `reports/archive/` | Extract the public lesson; retain sanitized history |
| `reports/current-acceptance.md`, `executor-brief.md`, `final-hardening-plan.md`, `pending-issues.md`, `remediation-plan.md`, `round2-final-gate.md`, `round2-parallel-split.md`, `upgrade-baseline.md`, `upgrade-manifest.md`, `upgrade-plan-9plus.md` | Sanitized + moved to `reports/archive/` | Internal remediation notes; kept as sanitized audit trail |
| `reports/archive/PMO-Template-Personal_Final-Review.md` | Renamed → `reports/archive/final-review.md`, sanitized | Filename carried the old product name |
| `reports/archive/{acceptance-0.4.0,baseline,final-acceptance,patch-manifest}.md` | Sanitized in place | Contained handles/paths/SHAs |
| `CHANGELOG.md` history | Sanitized; new `1.0.0` entry added on top | Strip private repo identifiers, PR#, SHAs, reviewer, owner-deferred wording |
| `.gitignore` | Thai comment translated to English; patterns unchanged | Public readability; keep all protections incl. tested `Quotation.xlsx` negation |
| `reports/` root | Now holds `public-release-baseline.md` + `README.md` only | One clean public baseline + archive framing |

Sanitization was scripted with explicit UTF-8 I/O (Thai text and em-dashes
preserved; verified no mojibake). Removed tokens: private repo URLs/PR links, the
owner handle, the local username, `D:\…`/`C:\Users\…` paths, CI runner paths,
commit SHAs, CI run ids, an independent-reviewer name, and "owner deferred"
phrasing.

## 6. License and community files

- `LICENSE` — MIT, `Copyright (c) 2026 WITCHWASIN K.` (owner-supplied name).
- `CONTRIBUTING.md` — philosophy, environment, running checks, adding rules +
  reconciling `DOCTOR-007`, fixtures, safe golden updates, modes/policies, the
  "do not weaken governance" rule, PR/commit expectations, security reporting,
  human-approval requirement, and AI-assistance disclosure.
- `CODE_OF_CONDUCT.md` — original wording, Contributor-Covenant in spirit.
- `.github/ISSUE_TEMPLATE/{bug_report,feature_request,validation_rule,integration_request}.yml`
  and `.github/PULL_REQUEST_TEMPLATE.md` with the required governance checkboxes.

## 7. Cross-platform improvements

- `Makefile` (`doctor validate test golden mutation e2e check`).
- `scripts/check.sh` and `scripts/check.cmd` — detect `pwsh`/`powershell`, print
  an install hint if missing, forward args, preserve exit codes; no second
  validator. Verified: exit 127 when PowerShell is absent.
- Linux/macOS via `pwsh` is documented as **experimental** (wrappers run; the
  suite is not verified there).
- `scripts/prepare-public-release.ps1` — non-destructive readiness check
  (version consistency, old-name audit, privacy audit, optional suite run) that
  prints — never runs — the release git commands.

## 8. Interoperability

- **Implemented today:** Level 0 (coexistence) and Level 1 (policy awareness),
  achievable by convention against readable artifacts.
- **Documented + experimental schemas:** Level 2–3 shapes shipped under
  `integrations/superpowers/` (`EXECUTION-CONTRACT.template.json`,
  `EXECUTION-RESULT.schema.json`, `integration-policy.json`) — clearly labeled
  experimental and **not wired into the validator runtime**.
- **Roadmap:** automated Level 3 consumption and Level 4 (automated bridge).
- Authority-precedence order and the "execution framework may / may not" rules
  are documented in `docs/integrations/overview.md`. No unsupported compatibility
  claim is made; framework-specific docs describe interop at the contract level
  and do not invent install/behavior details.

## 9. Version and release preparation

- Canonical version `1.0.0` set in `VERSION`, the `CHANGELOG.md` top heading, and
  all six `pmo-config/*.json` `version` fields; `schema_version` stays `1.0`.
  `DOCTOR-005`/`DOCTOR-006` pass.
- Chosen tag format: `v1.0.0`; release name "Axiom-PMO 1.0.0". Used consistently
  in release notes, the changelog, and the printed release commands.
- Release notes: `docs/releases/v1.0.0.md`.

## 10. Validation results

| Command | Exit | PASS | WARN | FAIL |
|---|---|---|---|---|
| `scripts/pmo-doctor.ps1` | 0 | 52 | 0 | 0 |
| `scripts/run-validation-tests.ps1 -VerifyGolden` | 0 | 95 | 0 | 0 (golden 90/90) |
| `scripts/run-all-checks.ps1` | 0 | all (incl. E2E) | 0 | 0 |
| `tests/golden/capture-examples.ps1 -Verify` | 0 | 3/3 match | — | 0 |
| `scripts/prepare-public-release.ps1` | 0 | — | — | 0 |
| `scripts/check.sh` (no PowerShell) | 127 | — | — | — (correct hint + exit code) |

The only runtime code change was adding `<REPO_ROOT>` normalization to
`tests/golden/capture-examples.ps1` (portability fix). No rule, severity, or
policy was weakened; no golden was auto-updated to hide a behavioral change.

## 11. Security and privacy audit

- Full working-tree scan for the old product name, owner handle, local username,
  and machine paths. The only remaining hits are in
  `.claude/settings.local.json`, which is **gitignored and untracked** — it does
  not ship. The intended MIT copyright name (`WITCHWASIN K.`) appears only in
  `LICENSE` and `README.md`.
- No secrets, tokens, or API keys were found in tracked files. No credential
  values are reproduced in this report.

## 12. Known limitations

- Cross-platform execution via `pwsh` is experimental and not yet verified by the
  suite.
- Interoperability Levels 3–4 are specified (docs + schemas) but not automated.
- The framework performs a sensitive-file pre-check, not a full secret scan.

## 13. Human actions required

1. Review the full working-tree diff.
2. Confirm the repository description and topics.
3. Create the public repository / rename it on the hosting platform.
4. Configure branch protection on the default branch.
5. Run the release commands printed by `scripts/prepare-public-release.ps1`
   (review each): stage, commit `release: publish Axiom-PMO 1.0.0`, tag
   `v1.0.0`, and push branch + tag.
6. Publish the release using `docs/releases/v1.0.0.md`.

## 14. Git status

- Branch: `main`. **No commit, push, tag, merge, branch deletion, or release was
  executed.**
- Working tree: 29 modified, 12 moved (shown as delete + new for the report
  relocation into `reports/archive/`), 32 new files.
- All changes are staged for the human to review and commit.
