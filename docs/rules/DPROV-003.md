# DPROV-003 — Design provider input freshness

Each manifest input points at a canonical governed artifact (PROJECT.md,
SCOPE.json, DESIGN/BUILD-SPEC.md, selected Visual Direction, Acceptance Cases)
with a current SHA-256. The combined digest is the SHA-256 of the sorted
`path|sha256` lines. The `designProviderDigest` tool (`src/tools/digest-tools.ts`) recomputes both;
after any input change the manifest must be regenerated.
