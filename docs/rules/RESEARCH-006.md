# RESEARCH-006 — Truthful provider availability

`RESEARCH/PROVENANCE.json` records the provider actually used, its
availability, and whether a fallback ran. A fallback requires an unavailable
primary; an unavailable primary with neither fallback nor stop is a fabricated
claim of research output. A concrete project provider must match
`provider_used`; `auto` must resolve to a concrete allowed provider. The
retrieval timestamp is required as ISO-8601 UTC (`...Z`). No automatic clone or
install is ever performed.
