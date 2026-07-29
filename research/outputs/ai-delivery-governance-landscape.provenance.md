# Provenance: AI-Assisted Delivery Governance — Competitive Landscape

- **Date:** 2026-07-29
- **Method:** Plan → user confirmation → 4 parallel research tracks → hand synthesis →
  self-review (FATAL/MAJOR/MINOR) → delivery. Adapted from the `feynman` `/deepresearch`
  protocol (`<user-home>/Documents/GitHub/feynman/prompts/deepresearch.md`); executed with this
  session's own WebSearch/WebFetch tools and the `Agent` tool in place of Feynman's
  `researcher`/`verifier`/`reviewer` subagent roles, since the Feynman CLI itself was not
  installed and had no configured search-provider API key on this machine.
- **Rounds:** 1 planning round (user-approved), 4 parallel research tracks, 1 synthesis pass, 1
  self-review pass with 1 correction applied (Track D date-range overstatement, corrected in
  the delivered brief).
- **Sources consulted:** 145 distinct URLs across the 4 tracks (before cross-track
  deduplication) — see the `## Sources` section of each `research/.drafts/track-*.md` file for
  the full per-track lists.
- **Sources accepted:** All sources cited in the delivered brief are used as either
  **VENDOR-CLAIM** (marketing/docs copy, presented as the vendor's claim, not independently
  verified) or **DOCUMENTED** (a concrete technical/API/config reference). No source was
  presented as independently verified fact beyond what a primary-source fetch actually showed.
- **Sources rejected/flagged, not treated as confirmed:**
  - Panto AI's "requirements-alignment" claim (Track C) — third-party blog description
    contradicted by a direct fetch of the live product (mobile QA testing); flagged as
    unverified, not counted as a competitor.
  - IBM watsonx.governance and CalypsoAI product pages (Track C) — returned HTTP 403 to direct
    fetch; entries rest on search-summary/press coverage instead, flagged as lower-confidence.
  - 5 of 8 Claude Code GitHub issues (Track D) — found via search but not individually fetched
    for exact date/engagement figures; date-range claim about them was corrected during review
    (see below).
- **Verification:** PASS WITH NOTES.
  - One correction applied during self-review: the delivered brief originally stated all 8
    Claude Code GitHub issues (section 6) fell within "February–April 2026." On review, only 3
    of 8 have a confirmed date within that window, and 2 have issue numbers lower than the
    earliest dated issue, suggesting they may predate the window. The brief was corrected to
    state this precisely rather than imply a tightly-dated cluster.
  - Not independently re-verified: exact wording of paraphrased forum/comment content in Track
    D (methodology note in that track states paraphrase, not verbatim, except where the source
    article itself presents a direct named quote).
  - Not covered by this research pass at all: the supply-chain/provenance question (original
    research plan Q7) — flagged as an open question in the delivered brief rather than answered
    with unverified inference.
- **Plan:** [research/PLAN.md](../PLAN.md)
- **Research files:**
  - [research/.drafts/track-a-native-agent-governance.md](../.drafts/track-a-native-agent-governance.md)
  - [research/.drafts/track-b-pr-ci-policy-tooling.md](../.drafts/track-b-pr-ci-policy-tooling.md)
  - [research/.drafts/track-c-ai-governance-platforms.md](../.drafts/track-c-ai-governance-platforms.md)
  - [research/.drafts/track-d-developer-pain-evidence.md](../.drafts/track-d-developer-pain-evidence.md)
- **Delivered brief:** [research/outputs/ai-delivery-governance-landscape.md](ai-delivery-governance-landscape.md)
