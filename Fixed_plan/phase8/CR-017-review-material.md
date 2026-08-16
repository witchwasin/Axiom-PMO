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
| **Windows NTFS junctions specifically** (a different reparse-point type than a symlink — `lstatSync(...).isSymbolicLink()` is not guaranteed to catch every junction the same way it catches a symlink) | `src/probe/junction-probe.ts` (runs on the canary-matrix Windows cells every qualifying push) + `setup-integration.test.ts` (POSIX symlink side) + project-root reparse check in `setup-claude-integration.ts` / `setup-claude-integration.ps1` | ✅ **Verified — and the verification found a real gap, now fixed.** First real-Windows run (`commit 236a35e`) proved `lstat` *does* report a junction as a reparse point, but both TS and PS only checked the *instruction file* — a **junctioned project root** was not refused (exit 0) and setup wrote through the junction into the target file. Both implementations now refuse a reparse-point project root with SETUP-003 (same rule, project-path subject), asserted by the probe (6/6 PASS on Windows) and the new POSIX unit cases. |

## 6. Open item for the actual review

Item 5's junction gap is the one thing this compilation could not close by
reading code — it needs to either be tested on a real Windows host (the
`canary-matrix`'s `windows-ps51`/`windows-ps7` cells already run there; a
junction-containment case could be added to `tool-stateful-probe.js` before
Phase 8, if the Human Owner wants it closed rather than accepted as a known
gap) or explicitly accepted as residual risk in the sign-off.

## 7. Named reviewer

Witchwasin K. (Human Owner) — named per DEC-027. This document is the input to
that review, not a substitute for it.
