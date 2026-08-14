# Externalization Gate

`EXTERNALIZATION.json` is a registry, not a copy: each entry records what
leaves the governed project boundary, why, to which provider, what exact
artifacts (path + SHA-256), the declared classification, the minimization or
redaction applied, the deterministic scan result, whether network transfer
occurred, and the Human evidence when required.

## Classification and authority

| Classification | Human review |
|---|---|
| Public | Not required by policy |
| Internal | Follows the configured provider policy (no forced Human gate) |
| Confidential | Required |
| Restricted | Required |

The same Human evidence is required when a transfer's scan is not clean or the
transfer is being approved. AI may propose classification and redactions; it
may never declare Confidential/Restricted content safe on its own. The named
reviewer and a resolvable `DEC-###` with a named decider are the evidence.

## What the checks can and cannot detect

The deterministic checks re-scan the declared outgoing artifacts against the
configured secret patterns (`pmo-config/orchestration-policy.json`
`externalization.secret_patterns`) and the policy's sensitive path patterns,
and verify that a declared `clean` result agrees. That is deliberately narrow.
This is not an enterprise DLP system: it cannot detect semantic trade secrets,
cannot guarantee no data leaked through an undisclosed channel, does not
rotate credentials, and does not enforce provider-account or retention policy.
The registry is honest evidence about the transfer a project declares — it
cannot prove that no other transfer happened.

Research and Claude Design manifests cite an approved externalization entry
whenever they use an external provider (RESEARCH-007, DPROV-004). Local
provider execution is still external to the Axiom-PMO authority model; whether
network transfer actually occurs is recorded truthfully per entry and cannot
be verified by an offline validator.
