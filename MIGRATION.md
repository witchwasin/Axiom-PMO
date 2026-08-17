# Migration

## From Legacy PMO Structure

Legacy folders can be mapped into the lightweight structure:

| Legacy | Current |
|---|---|
| `MOM/`, `REQ/`, `Others/` | `source/` |
| `UserFlow/`, `SystemFlow/`, `UseCase/` | `DESIGN/` |
| `Wireframe/` | `DESIGN/WIREFRAME.md` or `.html` |
| `TaskBreakdown/` | `DELIVERY.md` or GitHub Issues |
| *(no legacy equivalent)* | `HANDOFF.md`, `DESIGN/BUILD-SPEC.md` |

The last row is the point of 1.1: no legacy artifact answered "can a developer
start on Monday?", which is why that question kept being answered in a meeting
instead of in a document. See [artifact map](docs/guides/artifact-map.md).

## Skill Runtime Migration

Old skills were archived instead of deleted:

- `.claude-archive/optional-skills/`
- `.claude-archive/legacy-skills/`

The active runtime now uses only the 7 skills listed in `pmo-config/skill-manifest.json`.

## V2.1 declaration compatibility (M0–M3)

Existing projects do not need a bulk migration. If `PROJECT.md` omits the new
declarations, validators use these compatibility defaults silently:

| Declaration | Effective default |
|---|---|
| `Execution path` | `development_handoff` |
| `Research mode` | `off` |
| `Research depth` | `standard` |
| `Research provider` | `none` |
| `UI delivery` | `legacy` |

New Standard/Strict projects may declare `UI delivery` and receive the early
`DESIGN/BUILD-SPEC.md` Test Strategy contract.

## V2.1 optional tracks (M4–M6)

Existing projects still need no bulk migration. The optional tracks activate
only when declared or materialized, and a legacy project that declares none of
them is byte-for-byte silent:

| Track | Activates when | Default when absent |
|---|---|---|
| Research | `Research mode:` is `guided` or `auto` | `off` (silent) |
| Externalization | `EXTERNALIZATION.json` exists | no registry (silent) |
| Claude Design | `UI delivery: claude_design` at Handoff/Release, or `INPUT-MANIFEST.json` exists | `not_applicable` / `legacy` (silent) |

To adopt a track on an existing project:

1. **Research** — declare `Research mode`, `Research depth`, and `Research
   provider` in `PROJECT.md`, then complete `templates/RESEARCH.md` and
   `templates/RESEARCH-PROVENANCE.json`. External providers must cite an
   approved `EXTERNALIZATION.json` entry.
2. **Externalization** — copy `templates/EXTERNALIZATION.json` and record each
   transfer with exact artifact digests, classification, scan result, and
   Human evidence for Confidential/Restricted.
3. **Claude Design** — declare `UI delivery: claude_design`; the generator
   materializes `DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json` and
   `DESIGN/CLAUDE-DESIGN/REVIEW.json`. Compute digests with the
   `designProviderDigest` tool (`src/tools/digest-tools.ts`).

Missing optional declarations never fail a legacy project; the compatibility
defaults above apply silently.

## Project Migration Steps

1. Create or update `PROJECT.md`.
2. Declare the task source of truth.
3. Move delivery work into `DELIVERY.md` or GitHub Issues.
4. Add `source_ref`, `evidence_status`, and `approval_status`.
5. Validate with:

```bash
node cli/axiom.mjs validate --project <project-path> --mode Standard --gate Release
```

## From 1.0 to 1.1

**Nothing is required.** A project that does not request the `Handoff` gate
validates exactly as it did in 1.0, and the only change a JSON consumer sees is
additive fields on each diagnostic.

To adopt the gate on an existing project:

1. Copy `templates/HANDOFF.md` into the project root and fill the metadata block
   (target, horizon, handoff owner, named integrator).
2. For Standard/Strict, copy `templates/BUILD-SPEC.md` to
   `DESIGN/BUILD-SPEC.md`. Each section declares `Status: specified` or
   `not_required` with a written rationale — a blank section is never valid.
3. Record a semantic review in `HANDOFF-REVIEW.json`. Get the freshness digest
   with the `handoffDigest` tool (`src/tools/digest-tools.ts`).
4. Run the gate and the assessment:

```bash
node cli/axiom.mjs validate --project <project-path> --mode Standard --gate Handoff
node cli/axiom.mjs handoff --project <project-path> --mode Standard
```

The gate adds no new human approval — it reuses the `Design Ready` row already in
`PROJECT.md`. See [handoff readiness](docs/concepts/handoff-readiness.md).

### For consumers of the JSON output

`level`, `rule_id`, `message`, and `blocking` are unchanged. Six fields were
added; ignore the ones you do not use. Fields that do not apply are `null`, never
absent. The contract and its deprecation policy are in
[`docs/reference/diagnostics-contract.md`](docs/reference/diagnostics-contract.md).
