# RESEARCH-003 — Research provenance integrity

Every material claim maps to at least one source with a resolvable reference
(an http(s) URL, a `FILE:` path inside the project, or a declared source
reference), a title/issuer, a boolean primary classification, a verification
status, and a valid evidence status
(verified/supported/inferred/missing/conflict). A claim without a source is an
opinion, not research. When `freshness.model` is `cutoff`, `cutoff` is the
minimum acceptable source date: every cited source needs an ISO `YYYY-MM-DD`
date on or after it. `none` explicitly declines a date-freshness claim.
