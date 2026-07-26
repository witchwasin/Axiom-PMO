# HANDOFF-012 - Declared device or runtime capability lacks an environment decision

| | |
|---|---|
| Level | FAIL |
| Gate | Handoff |
| Applies to | Lite, Standard, Strict |
| Artifacts | `HANDOFF.md`, `DESIGN/BUILD-SPEC.md` |

## What this rule checks

Two tables, same idea:

- `HANDOFF.md` `## Environment and Device Matrix` - every environment declares a `Serving Model` and a `Decision Ref`.
- `DESIGN/BUILD-SPEC.md` `### Target Devices and Runtime Capabilities` - every capability declares a `Serving Model` and an `Environment Decision`.

A cell counts as unresolved when it is blank, a placeholder, or one of the tokens in `pmo-config/handoff-policy.json` `environment_capabilities.unresolved_tokens` (`open`, `undecided`, `tbd`, `unknown`, `not decided`).

## Why it blocks

Browser capabilities are gated on how a page is served, not on what the code does. A feature can be complete, correct, tested on a developer laptop over `localhost`, and simply not function when the same build is opened from a plain HTTP address on a borrowed tablet. Nothing in the code review catches it, because nothing in the code is wrong.

Recording the serving model per environment forces that decision before the device is in the room.

## What the validator never does

It does not infer capability requirements. It will not decide that a scanner needs a camera, that a camera needs a secure context, or that a file export needs filesystem access. It checks only the capabilities the author declared, and only whether each one has a resolved answer.

## How to fix

```markdown
### Target Devices and Runtime Capabilities

Status: specified

| Capability | Required By | Serving Model | Environment Decision |
|---|---|---|---|
| Rear camera | AC-002 scan flow | HTTPS via local reverse proxy with a trusted cert | DEC-009 |
| Offline read | AC-004 | Service worker cache, read-only | DEC-010 |
```

## Related

`HANDOFF-008` (demo device), `HANDOFF-005` (section completeness).
