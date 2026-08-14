# Structured Change Control

Create `CHANGE-REQUESTS.json` only when implementation, review, or test evidence
reveals a real deviation. Each entry identifies the observed reason, declared
impact, affected references, owner, status, and Human decision when required.
Major, Scope, and emergency changes block Handoff/Release until implemented,
rejected, or superseded; Strict also treats `minor` as blocking. An implemented
change that affects Scope, acceptance, or Mode must record current downstream
artifact digests. Governed AI Execution additionally requires a current
execution-contract digest. AI may propose impacts; the registry never claims
automatic or exhaustive dependency discovery.
