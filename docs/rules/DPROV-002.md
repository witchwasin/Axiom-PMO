# DPROV-002 — Design provider input manifest

A project that declares `UI delivery: claude_design` materializes
`DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json` from
`templates/DESIGN-PROVIDER-INPUT.json` and fills every field: project code,
provider, purpose, generated timestamp, input references, and combined digest.
The repository source name and the project manifest name never coexist. At
Handoff/Release the manifest is required; earlier gates tolerate the workflow
not having started yet.
