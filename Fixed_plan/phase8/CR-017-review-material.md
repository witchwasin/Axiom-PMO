# CR-017 — Supply-chain / containment review material

**Purpose:** compiled by Claude ahead of time so the Human Owner's actual CR-017
review (required before Phase 8, per DEC-027/DEC-029) is a review, not a
from-scratch investigation. **This document is evidence, not the sign-off.** Per
`master-plan.md`'s Definition of Done, only the Human Owner reviewing this and
recording a decision constitutes CR-017 sign-off — nothing below does that on
its own.

Compiled 2026-08-16 against `main` at `177b348`. Re-verify the numbers below are
still current before actually signing off, if any time has passed.

---

## 1. Runtime dependency surface

```json
"dependencies": {}
```

Zero runtime dependencies. `dist/` is a committed, dependency-free bundle
(DEC-026 §3) — nothing is fetched or resolved when the shipped code actually
runs.

## 2. Dev dependency surface (build-time only, never ships)

| Package | Version | Publisher | License |
|---|---|---|---|
| `typescript` | 7.0.2 | Microsoft | Apache-2.0 |
| `@types/node` | 26.2.0 | DefinitelyTyped/Microsoft-adjacent | MIT |
| `undici-types` (transitive, via `@types/node`) | 8.3.0 | Node.js project | MIT |
| `@typescript/typescript-*` (13 platform-specific optional binaries, TS 7's native compiler) | 7.0.2 | Microsoft | Apache-2.0 |

**23 total resolved packages** (`package-lock.json`, `lockfileVersion: 3`). All
from two publishers (Microsoft/TypeScript team, Node.js project itself) — not a
sprawling transitive graph. All licenses permissive (MIT/Apache-2.0), no
copyleft, none unspecified.

## 3. Lifecycle-script check (the actual #1 npm supply-chain attack vector)

Checked every installed package's `package.json` for `preinstall`, `install`,
`postinstall`, `prepare`, `preprepare`, `postprepare`:

**Zero lifecycle scripts found in any of the 23 packages.** Nothing runs code
on `npm install` beyond npm's own binary-placement step for the platform
packages.

`package.json`'s own `scripts` block has no lifecycle hooks either — only
`build`, `clean`, `test`, `typecheck`, each invoked explicitly, never
automatically.

## 4. `package.json` posture

- `"private": true` — cannot be accidentally `npm publish`ed.
- `package-lock.json` is committed; `lockfileVersion: 3`; every non-symlink
  entry carries an integrity hash (no entries resolve without SRI
  verification).
- `"engines": { "node": ">=22.0.0" }` declared and matches the canary matrix's
  floor version.

## 5. Containment tests — what's covered, what isn't

| Surface | Covered by | Status |
|---|---|---|
| Symlinked instruction file (`AGENTS.md`/`CLAUDE.md`) refused | `SETUP-003` in `setup-claude-integration.ts`, exercised in `setup-integration.test.ts` | ✅ |
| Write path escaping the resolved project root refused | `SETUP-002` in `setup-claude-integration.ts` | ✅ |
| Framework install root vs. user project root kept separate; no writes leak into the install | `plugin-install-spike.test.ts` | ✅ |
| Read-only / non-writable install still functions | `plugin-install-spike.test.ts` (`chmodSync` case) | ✅ |
| Clean-room install touches only the one file it's supposed to (`AGENTS.md`), nothing else in a foreign repo | `clean-room.test.ts`, differentially probed by `tool-stateful-probe.js` | ✅ |
| Case-sensitivity (path matching doesn't silently widen on case-insensitive filesystems) | `scope-diff.test.ts`, `execution-contract.test.ts` | ✅ |
| **Windows NTFS junctions specifically** (a different reparse-point type than a symlink) | `src/probe/junction-probe.ts` (3 cases, runs on the canary-matrix Windows cells every qualifying push) + `setup-integration.test.ts` (POSIX symlink side) + `findAncestorReparsePoint` in `src/core/path-containment.ts` / `Find-AncestorReparsePoint` in `scripts/lib/path-containment.ps1` | ✅ **Verified — and the verification found two real gaps, both now fixed.** (1) First real-Windows run (`236a35e`) proved `lstat` *does* report a junction as a reparse point, but both TS and PS only checked the *instruction file* — a junctioned project **root** was not refused. Fixed in `6b132b0`. (2) Auditing for the same bug class found the *fix itself* only checked the project directory's own lstat, not any **ancestor** of it — reproduced directly with a POSIX symlink one level above an otherwise-ordinary project directory: exit 0, block written through it. Fixed in `1a4764e` by comparing physical vs. lexical resolution from the leaf backward (tolerant of OS-level prefix aliases like macOS's `/tmp` → `/private/tmp`, which is exactly what every test fixture in this suite sits under — a naive realpath diff would have false-positived on ordinary usage). Both fixes verified by direct reproduction (bug reproduced first, then the fix confirmed to close it) on TS and PS, not test-suite output alone. |

## 6. Codebase-wide audit for the same bug class (not just the one instance above)

Searched beyond the one file already known to have a finding: every `isSymbolicLink`/
`lstatSync` use in `src/tools/`, `src/exec/` (TS) and every `ReparsePoint`/`LinkType` use
in `scripts/*.ps1` (PS), plus a broader keyword sweep for `symlink`/`junction`/`reparse`
across both trees. Result: no second instance of the final-component-only pattern.
Everywhere else that does physical containment (`externalization-validator`,
`design-provider-validator`, `research-validator`, both TS and PS) already uses the
older, already-correct `testPhysicalContainment`/`Test-PhysicalContainment` helper, which
resolves both sides via realpath and was never susceptible to this gap in the first
place — confirmed by reading each call site, not just that the import exists. Stated
plainly since a negative result is still a result: **the two fixes in item 5 close this
gap class everywhere it currently exists in the codebase**, not just for the one
entrypoint that happened to surface it first.

## 7. Open item for the actual review

None outstanding for the containment surface specifically — see item 5's two fixes and
item 6's audit. The Human Owner's own review may still turn up items this compilation
missed; this section exists to be filled in by that review, not to assert there is
nothing to look for.

## 8. Named reviewer

Witchwasin K. (Human Owner) — named per DEC-027. This document is the input to
that review, not a substitute for it.
