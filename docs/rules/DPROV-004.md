# DPROV-004 — Design provider externalization citation

The input manifest must cite an approved `EXT-###` entry in
`EXTERNALIZATION.json` whenever provider content leaves the governed boundary.
Classification, scan result, and required Human evidence come from that entry
(EXT-002/EXT-003/EXT-004); the manifest cites it rather than duplicating it.
