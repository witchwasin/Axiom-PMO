# Reports

This directory holds Axiom-PMO's own engineering evidence — the framework
applying its "show the evidence" principle to itself.

- **[`public-release-baseline.md`](public-release-baseline.md)** — the verified
  state of the validation suite around the public release, used as before/after
  evidence that the overhaul preserved every enforced check.

- **[`archive/`](archive)** — the framework's development and hardening history
  (baselines, remediation rounds, acceptance gates, and the original
  process-violation record). These are historical working notes, **sanitized**
  of private repository identifiers, personal handles, local machine paths,
  commit hashes, and stale pre-release status claims where they would confuse
  public readers. They are kept for transparency and as an audit trail of how
  the governance model evolved; they are not part of the normal user journey.

The polished, public-facing version of the most important lesson from this
history lives in [`../case-studies/unauthorized-git-mutation.md`](../case-studies/unauthorized-git-mutation.md).
