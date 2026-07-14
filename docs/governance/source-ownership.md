# Governance: Source Ownership

Source material is **user-owned**. The agent reads it to extract requirements,
but never edits, creates, or deletes it.

## What counts as source

`source/` and the legacy folders `MOM/`, `REQ/`, `Transcript/`, and `Others/`.
These hold the meeting notes, requirement documents, and transcripts the
client or team actually provided.

## The rule

- The agent must **read the relevant source before producing PMO output**.
- The agent must **not** edit, create, or delete source files unless the user
  explicitly asks.
- Requirements extracted from source carry a `source_ref` pointing back to the
  originating document and locator.
- A customer's `TODO` or placeholder inside a source note is *their* content — it
  does not fail a gate the way a placeholder in a governed artifact does. Broken
  links inside source folders are reported as information, never a hard failure.

## Why it matters

If an agent could rewrite the source, it could quietly make the evidence match
its own output — collapsing the very traceability the framework exists to
protect. Keeping source read-only means the trail from "what was actually asked
for" to "what was built" cannot be forged.

## Sensitive source

PII, financial data, and confidential customer data trigger [Strict
mode](../concepts/risk-modes.md). Such data stays local, is not sent to external
services, and is not copied into examples. See [`SECURITY.md`](../../SECURITY.md).

This boundary is enforced by the source validator in the
[validation engine](../architecture/validation-engine.md) and by
[`AGENTS.md`](../../AGENTS.md) Rule 9.
