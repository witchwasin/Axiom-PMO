# Research Plan: AI-Assisted Delivery Governance — Competitive Landscape

Status: awaiting user confirmation (not started)
Method: adapted from `feynman` (`/deepresearch`) protocol — plan, scale, gather, draft, cite, review, deliver
Owner: Claude, on branch `Improve_Plan`

## Why this research exists

Two prior planning rounds (ChatGPT/Independent AI Reviewer, then Claude) proposed roadmap changes for
Axiom-PMO based on reading the repo alone — no external market evidence. The user
wants to ground the next roadmap revision in what actually exists in the market
today: which problems are already solved, by whom, and which problem Axiom-PMO's
hypothesis ("independent verification layer for AI-generated code changes") is
still uniquely positioned to own. This is not a request to discard the prior
Claude/Independent AI Reviewer conclusions — it is a request to test them against evidence before
committing to them.

## Key Questions

1. What already exists for governing AI coding-agent output in the PR/CI path —
   scope control, evidence verification, approval gates, release authority?
2. What do the major AI coding agents themselves ship natively for oversight —
   GitHub Copilot (repo instructions, hooks), Claude Code (permissions,
   settings), Cursor, Devin/Cognition, OpenAI Codex — and where do their own
   docs admit a gap?
3. What adjacent PR-gate / policy-as-code tooling could overlap or compete —
   OPA/Conftest, Danger.js, CodeRabbit, Greptile, Graphite, Sourcegraph,
   Cortex, Port.io/Backstage scorecards, GitHub rulesets/branch protection?
4. What do "AI governance platform" vendors actually govern — Credo AI,
   Holistic AI, Aporia, Galileo, Arize, Guardrails AI, CalypsoAI, Lakera — is
   their scope model-output/safety governance (different market) or does any
   of them reach into code-change scope/evidence/approval (same market)?
5. Is "independent verification of AI-generated code changes" a named category
   anywhere yet? Any vendor or OSS project using comparable positioning
   language?
6. What do developers actually complain about — scope creep from coding
   agents, unverifiable AI claims, agents exceeding intended permissions —
   sourced from GitHub issues, HN/Reddit threads, vendor blog posts? This
   tests whether Axiom-PMO's founding incident (source references "the agent
   that shipped without permission") reflects a widespread pattern or an edge
   case.
7. Supply-chain/provenance angle: does anything in the SLSA/in-toto/Sigstore/
   artifact-attestation space already cover "prove this change came from an
   approved, evidenced source" for AI-authored commits specifically?
8. Net gap: what, if anything, is left uncovered that Axiom-PMO's SCOPE-DIFF +
   evidence-trust-level direction (per the Claude/Independent AI Reviewer converged plan) would be
   first to ship?

## Evidence Needed

- Product docs / feature pages for each named tool (primary source, not
  secondary blog summaries where avoidable)
- Recent (2025–2026) blog posts, changelogs, or launch announcements — this
  space moves monthly
- Real developer complaints: GitHub issues/discussions, HN/Reddit threads,
  X/Twitter threads from practitioners — not just vendor marketing
- Pricing/packaging pages where relevant to later positioning (not to copy,
  to know what "enterprise" already means in this market)

## Scale Decision

Broad, multi-faceted landscape survey → **use parallel research subagents**
(Feynman guidance: "broad survey or multi-faceted topic: 3–4 researcher
subagents"). Four tracks, each independent enough to parallelize cleanly:

| Track | Covers | Questions |
|---|---|---|
| A — Native agent governance | Copilot, Claude Code, Cursor, Devin, Codex oversight features | Q2 |
| B — PR/CI policy tooling | OPA/Conftest, Danger.js, CodeRabbit, Greptile, Graphite, Sourcegraph, Cortex, Port.io, GitHub rulesets | Q1, Q3, Q7 |
| C — AI governance platforms | Credo AI, Holistic AI, Aporia, Galileo, Arize, Guardrails AI, CalypsoAI, Lakera | Q4, Q5 |
| D — Developer pain evidence | GitHub issues, HN/Reddit, practitioner blog posts on agent scope creep / unverifiable claims | Q6, Q8 (grounding) |

Each track subagent gets a written brief, gathers evidence, and writes one
markdown file. I synthesize (draft), verify citations, and self-review
(FATAL/MAJOR/MINOR) — the roles Feynman assigns to `researcher` /
`verifier` / `reviewer` — since I do not have those as separate tool-level
agents here.

## Task Ledger

- [ ] Track A brief + research file
- [ ] Track B brief + research file
- [ ] Track C brief + research file
- [ ] Track D brief + research file
- [ ] Synthesis draft (`research/.drafts/landscape-draft.md`)
- [ ] Citation sweep — every claim mapped to a URL
- [ ] Self-review pass (FATAL/MAJOR/MINOR), fix FATAL
- [ ] Deliver `research/outputs/ai-delivery-governance-landscape.md` +
      `research/outputs/ai-delivery-governance-landscape.provenance.md`
- [ ] One-page "what this means for Axiom-PMO" summary — gaps confirmed,
      gaps closed, positioning implications — cross-checked against the
      Claude/Independent AI Reviewer converged plan from this conversation

## Verification Log

(filled in during execution — which claims were checked against a primary
source vs. inferred from secondary coverage)

## Decision Log

(filled in during execution — any scope changes made mid-research and why)

## Non-goals

- Not deciding the roadmap in this document — research informs the decision,
  it is not the decision.
- Not evaluating pricing to copy a business model — only to understand market
  norms.
- Not treating vendor marketing claims as verified fact — marked as vendor
  claim vs. independently observed.

---

**Proceed with this research plan? Reply "yes" to continue, or tell me what to
change** (add/remove a track, narrow the question set, or change the scale
decision to a smaller/larger investigation).
