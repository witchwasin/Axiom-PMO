# DPROV-005 — Design provider preflight and output placement

Candidate deliverables live only under `DESIGN/CLAUDE-DESIGN/OUTPUT/**`. The
deterministic preflight must run before any review decision is recorded, and a
recorded acceptance's `outputs_digest` must match the current OUTPUT/ file set
— changed output after review makes the acceptance stale.
