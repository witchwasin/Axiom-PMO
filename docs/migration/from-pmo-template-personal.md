# Migration: PMO-Template-Personal → Axiom-PMO

This project was previously developed under the working name
**PMO-Template-Personal**. Version `1.0.0` publishes it as **Axiom-PMO — The
Anti-Hallucination Framework for AI Agents**. This note is for anyone who used
the project under its old name.

## What changed

- **Product identity.** The name is now Axiom-PMO. The README, user-facing script
  and diagram labels, and documentation reflect this.
- **Version.** `0.5.x` → `1.0.0` (canonical everywhere; git tag `v1.0.0`).
- **New files.** MIT `LICENSE`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, issue and
  pull-request templates, a `case-studies/` directory, `docs/` (concepts,
  architecture, governance, integrations, tutorials), experimental
  `integrations/` schemas, and cross-platform helpers (`Makefile`,
  `scripts/check.sh`, `scripts/check.cmd`).
- **Reports.** The internal remediation/acceptance reports were sanitized and
  moved under `reports/archive/`; a single public baseline remains at
  `reports/public-release-baseline.md`.

## What did NOT change (no action needed)

- **The `pmo-` prefix is preserved** as a stable, generic identifier: skill names
  (`pmo-intake`, …), the `pmo-config/` directory, script names
  (`pmo-doctor.ps1`, …), and every rule id (`STRUCT-001`, `RTM-010`, …). No
  automation, config, script path, or golden fixture that depends on these
  identifiers needs to change.
- **The validation engine, policy files, rule catalog, modes, and tests** are
  behaviorally unchanged. Projects validated under the old name validate
  identically under the new one.
- **Project artifact shapes** (`PROJECT.md`, `DELIVERY.md`, `RELEASE.md`,
  `RAID-log.md`, `decision-log.md`, `RTM.json`) are unchanged.

## If you have a local clone or fork

1. Pull the `1.0.0` changes.
2. If you renamed the GitHub repository, update your remote URL accordingly.
3. Nothing in your existing projects needs editing — the `pmo-` identifiers and
   the validator behavior are stable.

The old name is retained only in this migration note and in the sanitized
changelog history.
