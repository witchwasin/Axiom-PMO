# Round 2 Parallel Split: Claude + Codex (Phase 3-8)

> Companion to `reports/upgrade-plan-9plus.md` (v2 unified). Splits the remaining
> phases across two executors working in **separate git worktrees** so neither
> touches the other's files. Claude merges both tracks at the end — no direct
> push by either executor at any point.

## Why split this way

`validate-project.ps1` (the monolith) is the hot file for Phase 3 and Phase 4:
Phase 4's golden-master control explicitly requires behavior to be **finalized by
Phase 3** before the refactor baseline is captured, and the refactor output must
match that baseline byte-for-byte. Two agents editing the same script concurrently
would make the golden-master comparison meaningless. Phase 5 (tests) is written
against the Phase 4 module boundaries, so it stays in the same track.

Phase 6 (context-map + skills) and the documentation-only parts of Phase 7 touch
a disjoint file set (`context-map.yaml`, `.claude/skills/*`, `README.md`,
`LICENSE`, `reports/current-acceptance.md`) — safe to run concurrently.

## Track A — Claude (this session, branch `remediation/9plus-v2`)

Sequential, no parallelism inside the track (golden-master safety requires it):

1. **Phase 3** — Release enforcement: work-item completion (`RELEASE-STATUS-001`,
   `RELEASE-SCOPE-001`, `TEST-EVIDENCE-001`, `REVIEW-001`), structured QA/Security
   table parse, structured rollback rows.
2. **Phase 4** — Modular refactor. Golden master captured immediately after
   Phase 3 lands; refactor into `scripts/lib/*.ps1`; diff against golden master
   must be empty before proceeding.
3. **Phase 5** — Testing upgrade: 20+ new negative tests, generator-to-Release
   E2E rebuild (no example copy-over), PSScriptAnalyzer, CI gate wiring.
4. **Phase 7.1/7.2/7.3** — CHANGELOG factual-fix verification, `schema_version`
   stamping on config/RTM (coordinated with Track B's Phase 6 JSON conversion
   at merge time), VERSION bump deferred to Phase 8 per plan.
5. **Phase 8** — Final Acceptance Gate: merge Track B into this branch, run full
   check suite, resolve any conflicts, write the final executor report.

## Track B — Codex (separate worktree/branch)

```powershell
git worktree add ..\PMO-Template-Personal-codex remediation/9plus-v2-codex
```

Codex works only inside `..\PMO-Template-Personal-codex`, commits locally on
`remediation/9plus-v2-codex`, **never pushes, never touches `remediation/9plus-v2`
directly**. Scope:

1. **Phase 6** — Convert `context-map.yaml` → `context-map.json` (Mode × Intent
   structure; fix the standing Lite `qa_release` conflict: PROJECT.md required,
   DELIVERY conditional, RELEASE optional). Align the 7 active skills to
   reference the same config contracts as the validator — no hardcoded
   matrices/enums, no read-all-source-by-default, no auto-creating RTM/RELEASE.md
   for Lite without a trigger, no approving releases on a human's behalf.
2. **Phase 7.4** — Document the branch-protection platform constraint (owner
   already deferred the (A)/(B)/(C) decision on 2026-07-12 — record option (C)
   compensating controls: PR workflow + CI + per-push human confirmation).
3. **Phase 7.5** — LICENSE: **owner decision recorded (2026-07-12): no LICENSE
   for now, revisit later if needed.** Codex does not add a LICENSE file or a
   "Proprietary — all rights reserved" line; just note in `current-acceptance.md`
   that LICENSE was explicitly deferred by the owner, not omitted by accident,
   so `Floors` scoring doesn't misread it as a gap.

Same non-negotiable rules as every other executor round: never edit `source/`,
`MOM/`, `REQ/`, `Transcript/`, `Others/`; never weaken the validator; never
commit without a human diff review; never push under any circumstance.

## Merge protocol (Claude does this, per owner instruction)

1. Both tracks reach their local "ready to commit" state independently.
2. Claude reviews Track B's diff (via the worktree, before any merge).
3. `git merge remediation/9plus-v2-codex` into `remediation/9plus-v2` (or rebase
   if the diff is clean) — conflicts expected to be near-zero given the
   disjoint file set; the only shared surface is `pmo-config/*.json`
   `schema_version` fields, resolved by Claude at merge time.
4. Re-run `scripts/run-all-checks.ps1` on the merged branch before Phase 8
   sign-off.
5. Delete the Codex worktree/branch after a clean merge (per owner confirmation,
   not automatically).

## Open items to confirm with the owner before Track B starts

- ~~LICENSE choice for Phase 7.5~~ — decided 2026-07-12: no LICENSE for now,
  revisit later.
- Confirmation to create the second worktree/branch (local, reversible, no
  push — but flagging since it's a repo-structure change).
