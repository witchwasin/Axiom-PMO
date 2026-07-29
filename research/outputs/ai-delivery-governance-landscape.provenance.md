# Provenance: AI-Assisted Delivery Governance — Competitive Landscape

- **Date:** 2026-07-29
- **Method:** Plan → user confirmation → 4 parallel research tracks → hand synthesis →
  self-review (FATAL/MAJOR/MINOR) → delivery. Adapted from an external local copy of the
  Feynman deep-research protocol (`feynman`'s `/deepresearch` command, not part of this
  repository); executed with this session's own WebSearch/WebFetch tools and the `Agent` tool
  in place of Feynman's `researcher`/`verifier`/`reviewer` subagent roles, since the Feynman CLI
  itself was not installed and had no configured search-provider API key on this machine.
- **Rounds:** 1 planning round (user-approved), 4 parallel research tracks, 1 synthesis pass, 1
  self-review pass (1 correction applied: Track D date-range overstatement), 1 external review
  by a second reviewer ("Independent AI Reviewer," a separate AI collaborator) with a verdict of ACCEPT WITH MAJOR
  CORRECTIONS, and 1 correction round applied in response (2026-08) — see "Correction round"
  below.
- **Sources consulted:** 145 distinct URLs across the 4 tracks, before cross-track
  deduplication — see the `## Sources` section of each `research/.drafts/track-*.md` file for
  the full per-track lists. **This is a URL count, not an independent-confirmation count.**
  Source families represented: vendor documentation and product pages, vendor marketing/blog
  copy, GitHub issue reports (several from the same repository), academic preprints,
  practitioner forum/blog discussion, news coverage, and secondary aggregators. Multiple URLs
  frequently describe the same underlying vendor, feature, or incident — the 145 figure must
  not be read as "145 independently corroborating sources" or "145 people/organizations
  confirming a claim." Independent claims/events were not separately counted in this pass.
- **Sources accepted:** All sources cited in the delivered brief are used as either
  **VENDOR-CLAIM** (marketing/docs copy, presented as the vendor's claim, not independently
  verified) or **DOCUMENTED** (a concrete technical/API/config reference). No source was
  presented as independently verified fact beyond what a primary-source fetch actually showed.
- **Sources rejected/flagged, not treated as confirmed:**
  - Panto AI's "requirements-alignment" claim (Track C) — third-party blog description
    contradicted by a direct fetch of the live product (mobile QA testing); flagged as
    unverified, not counted as a competitor.
  - 5 of the original 8 Claude Code GitHub issues (Track D) — found via search but not
    individually fetched; moved to an unverified appendix and no longer counted as confirmed
    incidents (2026-08 correction round).
  - A third-party blog's claim that GitHub shipped a "kill switch for AI-generated PRs" (Track
    D, item 11) — could not be corroborated against GitHub's own documentation; downgraded to
    unverified (2026-08 correction round).
- **Verification:** PASS WITH NOTES.
  - One correction applied during self-review (2026-07-29): the delivered brief originally
    stated all 8 Claude Code GitHub issues (section 6) fell within "February–April 2026." On
    review, only 3 of 8 have a confirmed date within that window. The brief was corrected to
    state this precisely rather than imply a tightly-dated cluster.
  - Not independently re-verified: exact wording of paraphrased forum/comment content in Track
    D (methodology note in that track states paraphrase, not verbatim, except where the source
    article itself presents a direct named quote).
  - Not covered by this research pass at all: the supply-chain/provenance question (original
    research plan Q7) — flagged as an open question in the delivered brief rather than answered
    with unverified inference.
- **Correction round (2026-08), in response to Independent AI Reviewer's external review (verdict: ACCEPT WITH
  MAJOR CORRECTIONS):**
  - **FATAL, fixed:** removed an absolute local filesystem path that had been recorded in this
    file's Method line, pointing at a directory on the researcher's own machine; replaced with
    a description that does not expose local machine structure, per this repo's local-path
    hygiene rule (`LOCAL-PATH-002`).
  - **MAJOR, fixed:** the "Sources consulted" line was strengthened to state explicitly that
    145 is a URL count, not an independent-confirmation count, and to list the source families
    represented, per Independent AI Reviewer's specific wording concern.
  - **MAJOR, fixed:** the delivered brief's claim that "no tool does SCOPE-DIFF" was rescoped in
    the executive summary and section 8 to "no off-the-shelf tool was found in this survey" —
    explicitly acknowledging this cannot rule out unindexed internal tools, private enterprise
    features, or custom OPA/Rego policies.
  - **MAJOR, fixed:** the Track D claim that GitHub shipped a "kill switch for AI-generated
    PRs" (sourced from one independent blog) was downgraded to unverified after Independent AI Reviewer
    fetched GitHub's own documentation directly and found three narrower, real, but
    non-AI-source-aware capabilities instead (disabling PRs repo-wide, disabling the Copilot
    cloud agent per repo, requiring approval before bot-created PR workflows run). The
    delivered brief's Open Questions section now states this as resolved-unverified rather than
    an open question, and adds Independent AI Reviewer's framing that Axiom-PMO answers a different question
    (per-change verification) than these GitHub access controls (can-this-agent-run-here).
  - **Track C, upgraded:** IBM watsonx.governance and CalypsoAI entries were upgraded from
    secondary/press sourcing (their marketing pages returned HTTP 403) to first-party
    documentation/support-page sourcing, found by Independent AI Reviewer. Conclusions for both (different category
    from Axiom-PMO) were unchanged by the stronger sourcing.
  - **Track D, regraded:** of the original 8 Claude Code GitHub issues, only 3 were
    individually fetched with a confirmed date; those 3 remain as cited evidence, and the other
    5 (title-only, search leads) were moved to an explicit unverified appendix and are no
    longer counted toward any incident total. "Closed as duplicate" is no longer treated as
    implying a second corroborating incident unless the duplicate target itself was opened and
    read.
  - **MINOR, fixed:** the claim that "no agent product independently verifies CI" was narrowed
    to state precisely what's missing — a structured evidence-trust record that unifies
    observed CI state with requirement traceability and scope — rather than implying no CI
    verification of any kind exists (GitHub's own commit-SHA-bound status checks are a real,
    cited counter-example to an unscoped version of this claim).
  - **MINOR, fixed:** `evidence_origin: ci-observed` is now explicitly defined as proving only
    that a named CI check produced a stated conclusion for a specific commit — not that the
    requirement is correctly implemented, coverage is adequate, scope was respected, or a human
    has approved the change.
  - All corrections were verified on-disk via `grep`/targeted reads confirming the corrected
    wording is present and the superseded wording is gone before this provenance entry was
    written.
- **Plan:** [research/PLAN.md](../PLAN.md)
- **Research files:**
  - [research/.drafts/track-a-native-agent-governance.md](../.drafts/track-a-native-agent-governance.md)
  - [research/.drafts/track-b-pr-ci-policy-tooling.md](../.drafts/track-b-pr-ci-policy-tooling.md)
  - [research/.drafts/track-c-ai-governance-platforms.md](../.drafts/track-c-ai-governance-platforms.md)
  - [research/.drafts/track-d-developer-pain-evidence.md](../.drafts/track-d-developer-pain-evidence.md)
- **Delivered brief:** [research/outputs/ai-delivery-governance-landscape.md](ai-delivery-governance-landscape.md)
