# Security

## Reporting a Vulnerability

Please **do not** open a public GitHub issue for a suspected security
vulnerability in Axiom-PMO itself (the validator, CLI, GitHub Action, or
Claude Code plugin).

Instead, report it privately using
[GitHub's private vulnerability reporting](https://github.com/witchwasin/Axiom-PMO/security/advisories/new)
for this repository, or open an issue asking to be contacted privately if
that form is unavailable to you.

Include, if known: the affected version (see `VERSION` and the badge in
`README.md`), the component (validator script, CLI, GitHub Action, or
plugin), reproduction steps, and the impact you believe it has.

There is no funded security team and no guaranteed SLA. As a best-effort
target, expect an initial response within 7 days. Fixes are prioritized by
real impact, not by report order.

## Supported Versions

Only the latest tagged release receives security fixes. Milestones merged
to `main` but not yet tagged (see `ROADMAP.md`'s minimum publishable
baseline) are pre-release and unsupported until tagged.

## Scope

Axiom-PMO is a deterministic governance and validation layer, not a network
service or a system that executes untrusted input from the internet. Its
security model is documented in
[`docs/concepts/human-authority.md`](docs/concepts/human-authority.md) and
[`docs/architecture/control-plane.md`](docs/architecture/control-plane.md):
source/inference/evidence separation, fail-closed validation, and a human
authority boundary an AI cannot self-authorize past. Reports about that
boundary (for example, a way for an AI-authored artifact to be accepted as
human-approved evidence) are explicitly in scope and treated as high
severity.

## Sensitive Data

Do not commit:

- `.env` files
- private keys
- credentials
- tokens
- customer confidential source
- raw PII
- pricing or quotation files unless explicitly approved

## AI Handling

Strict mode is required for:

- payment
- financial calculation
- PII
- sensitive customer data
- authentication
- authorization
- permission
- external integration
- compliance
- production migration

AI must not:

- push
- tag
- deploy
- approve production
- approve business scope

These actions require explicit human confirmation.

## Validation Scope

`validate-project.ps1` includes a sensitive file pre-check, not a full security scan.

Strict projects still need separate manual security/privacy review.

