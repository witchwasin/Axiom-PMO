# DPROV-007 — Design provider findings route to Change Control

A review finding that affects the technical or scope contract
(`routes_to_change_control: true`) must have a corresponding entry in
`CHANGE-REQUESTS.json` whose summary names the finding id. The finding may not
silently widen the approved design baseline.
