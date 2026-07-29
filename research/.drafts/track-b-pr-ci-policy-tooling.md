# Track B — PR/CI-Native Policy and Governance Tooling

Research date: 2026-07-29. Scope: does any existing PR/CI-native tool compare a PR's changed
files against a declared/approved implementation scope (per requirement/ticket) and fail the
PR if it's out of bounds — the core mechanic behind Axiom-PMO's planned SCOPE-DIFF feature?
Secondary questions per tool: what it actually gates on, whether it verifies evidence
(CI run ID / commit SHA) rather than trusting self-reported claims, agent-agnosticism, and
pricing model.

Every claim below is tagged **[VENDOR-CLAIM]** (marketing/docs, unverified) or
**[DOCUMENTED]** (concrete technical/API reference, e.g. exact config keys, rule names,
behavior descriptions from primary docs).

---

## 1. Open Policy Agent (OPA) / Conftest

- OPA's own docs describe a pattern for CI: fetch a PR's changed files via the GitHub API,
  evaluate a Rego policy against that file list, and set workflow outputs to conditionally
  run/skip jobs — e.g. `startswith(file.filename, "frontend/")` or
  `file.filename in shared_build_files`. **[DOCUMENTED]**
  (https://www.openpolicyagent.org/docs/cicd/pr-checks)
- This is explicitly framed as *"control which checks run"* based on file paths — a routing/
  gating mechanism, not a scope-enforcement mechanism tied to a requirement's declared scope.
  Nothing in the docs ties the path list to a per-requirement/per-ticket "approved scope"
  object; the path patterns are hand-written into the Rego policy by the platform team.
  **[DOCUMENTED]**
- Conftest (companion tool) matches changed Terraform/config files against Rego policy
  directories (e.g. a change to `foo/bar/main.tf` is checked against `foo/bar/policy/`) and
  fails with non-zero exit if a policy is violated — again structural/config policy, not
  scope-vs-requirement comparison. **[DOCUMENTED]** (https://github.com/open-policy-agent/conftest/blob/master/docs/options.md)
- Evidence verification: not found — OPA/Conftest evaluate whatever input JSON/file list you
  feed them; they don't independently pull CI run IDs or verify self-reported test claims.
- Agnostic: yes, fully agent/tool-agnostic; it's a generic policy engine usable from any CI.
- Pricing: OPA and Conftest are Apache-2.0 open source, free. Styra (OPA's founding company)
  sells a hosted management layer, Styra DAS, with a free tier (up to 2 clusters/10 nodes or
  ~100 rules/4 systems depending on source) and a paid Enterprise tier (unlimited
  rules/systems/nodes, more policy packs). **[VENDOR-CLAIM]**
  (https://www.businesswire.com/news/home/20201117005818/en/Styra-Expands-Declarative-Authorization-Service-with-Free-and-Mid-tier-Offerings-to-Manage-Open-Policy-Agent-at-Scale)

## 2. Danger.js

- Provides `danger.git.modified_files` / `created_files` / `deleted_files` in a JS/TS runtime
  that executes after CI, letting teams write arbitrary rules (e.g. "PR too big," "CHANGELOG.md
  must be touched if package.json changed"). **[DOCUMENTED]**
  (https://danger.systems/js/reference.html, https://github.com/danger/danger-js)
- No built-in concept of a "declared approved scope" tied to a requirement/ticket — any
  scope-vs-changed-files comparison would have to be hand-written by the adopting team as a
  custom Dangerfile rule. It's a scripting substrate, not a scope-enforcement product.
- Evidence verification: not found; Danger reports on GitHub PR state as it sees it, no
  independent CI-run/commit-SHA cross-check mechanism described in the reference docs.
- Agnostic: yes, general-purpose, no AI-tool tie-in.
- Pricing: MIT-licensed, fully open source, free. **[DOCUMENTED]**
  (https://github.com/danger/danger-js/blob/main/LICENSE)

## 3. CodeRabbit

- AI PR-review SaaS with **Pre-Merge Checks**, four built-in checks: Docstring Coverage, PR
  Title, PR Description, and **Issue Assessment**. Issue Assessment is described as verifying
  PRs "address linked issues without containing out-of-scope changes," i.e. it semantically
  compares the PR diff against the linked issue's free-text description and flags drift.
  **[VENDOR-CLAIM]** (https://docs.coderabbit.ai/pr-reviews/pre-merge-checks,
  https://www.coderabbit.ai/blog/pre-merge-checks-built-in-and-custom-pr-enforced, blog dated
  2026-03-11)
- Each check has three modes: `off`, `warning` (default — shown but doesn't block), and
  `error`, which — combined with CodeRabbit's "Request Changes Workflow" — **blocks the merge**
  until resolved or manually overridden. **[VENDOR-CLAIM — from docs, not independently
  verified against a live repo]**
- This is the single closest built-in "fail-the-PR-for-scope-drift" mechanic found in this
  survey that ships as a documented, named, general-availability feature.
- Important gap vs. SCOPE-DIFF: the "scope" being checked is the *linked issue's free-text
  description*, interpreted by an LLM, not a structured, declared "approved implementation
  scope" (e.g. an explicit file/path allowlist recorded against a requirement at approval
  time). It's semantic judgment on prose, not deterministic path-list comparison.
- Evidence verification: no mention found of tying test-passed claims to a specific CI run
  ID/commit SHA; docs describe LLM analysis of the diff and linked-issue text, not
  cross-referencing CI systems.
- Agnostic: works across GitHub/GitLab/Azure DevOps/Bitbucket, and is not tied to any single
  AI coding agent — it reviews any PR regardless of how the code was produced. **[VENDOR-CLAIM]**
- Pricing: Free for public/open-source repos (unlimited, full Pro feature set). Paid Pro plan
  for private repos (adds pre-merge checks, autofix, integrations, analytics). **[VENDOR-CLAIM]**
  (https://www.coderabbit.ai/pricing)

## 4. Greptile

- Repo-indexing AI reviewer that builds a "code graph" and does multi-hop investigation across
  files/dependencies/git history per PR; recent additions include long-term memory and
  "highly scoped rules" to apply custom review logic to specific parts of the codebase.
  **[VENDOR-CLAIM]** (https://www.greptile.com/blog/greptile-update,
  https://www.greptile.com/blog/greptile-v4)
- No evidence found of a feature that compares changed files against a declared
  requirement/ticket scope and fails the PR; "scoped rules" here means custom review
  instructions per path/area, similar to CodeRabbit's path_instructions, not scope
  enforcement against an approved file list.
- Evidence verification: not found.
- Agnostic: yes, general PR reviewer, not tied to one AI coding tool.
- Pricing: moved to per-review credit pricing — roughly $30/seat/month including 50 credits,
  $1/extra credit; open-source repos may get free usage; custom annual pricing available.
  **[VENDOR-CLAIM]** (https://www.agent-wars.com/news/2026-05-01-greptile-per-review-pricing,
  https://costbench.com/software/ai-code-review/greptile/)

## 5. Qodo Merge / PR-Agent (bonus discovery — not on the original list, highly relevant)

- Qodo Merge (SaaS layer on top of the open-source `qodo-ai/pr-agent`) has a **Compliance**
  tool and a related **PR-to-Ticket** capability. The Compliance tool supports a config flag
  `check_pr_additional_content` (default `false`): when enabled, "Qodo will check that all
  code changes are related to the ticket, and if unrelated content is found, the PR will be
  downgraded [e.g. to 'PR Code Verified'] and a comment will indicate the extra content."
  **[DOCUMENTED — exact config key and default confirmed via docs.qodo.ai custom-compliance
  page]** (https://docs.qodo.ai/qodo-documentation/code-review/qodo-merge/features/custom-compliance)
- Ticket compliance labels PRs as Fully Compliant / Partially Compliant / Not Compliant / PR
  Code Verified, based on comparing the PR's code changes to the linked Jira/GitHub-issue
  ticket's requirements. **[VENDOR-CLAIM]**
  (https://www.qodo.ai/blog/qodo-merge-jira-ensuring-code-quality-through-ticket-compliance/,
  dated 2024-11-26; https://www.qodo.ai/blog/compliance-in-code-reviews-automating-security-standards-and-ticket-checks/,
  dated 2025-09-09)
- Like CodeRabbit, the underlying mechanism is LLM semantic comparison of the diff against the
  ticket's free-text description/requirements — not a deterministic file-path allowlist
  declared at requirement-approval time.
- Blocking behavior: documented behavior is a **label downgrade + comment**, not a hard
  merge-block; no explicit "fail the check / block merge" behavior was found for the ticket
  scope check specifically (unlike CodeRabbit's `error` mode). It defaults to off
  (`check_pr_additional_content: false`).
- Agnostic: PR-Agent (the open-source core) is agent-agnostic and works on any PR; ticketing
  integrations cover Jira and GitHub Issues. **[VENDOR-CLAIM]**
- Pricing: PR-Agent core is open source (Apache-2.0-style OSS project on GitHub,
  `qodo-ai/pr-agent`); Qodo Merge adds a hosted Pro/Enterprise layer with the ticket-compliance
  and custom-compliance features — exact tier gating for compliance features was not
  confirmed from public docs during this research. **[UNCONFIRMED — marked "not found"]**

## 6. Graphite (merge queue + AI reviews)

- Graphite is primarily a stacked-PR workflow tool with a merge queue (batches/tests PRs in
  parallel before merge, stack-aware) and, more recently, "Graphite Agent" AI code review.
  **[VENDOR-CLAIM]** (https://graphite.com/docs/graphite-merge-queue,
  https://graphite.com/blog/introducing-graphite-agent-and-pricing)
- No evidence found of scope-vs-requirement enforcement, path-based policy, or evidence
  verification tied to CI run IDs. Its "policy" surface is enforcement of the merge queue
  itself (can be made mandatory per repo) and one-click CI-failure fixes.
- Agnostic: works with any AI coding tool producing the PR; its own AI reviewer is one option
  among several.
- Pricing: Free/Hobby tier (stacking CLI, VS Code extension, limited AI reviews); Team tier
  $40/user/month (unlimited AI reviews, merge queue); Enterprise custom. Anysphere (Cursor's
  parent) acquired Graphite in December 2025. **[VENDOR-CLAIM]**
  (https://graphite.com/docs/pricing-faq)

## 7. Sourcegraph / Cody

- Sourcegraph terminated Cody Free and Cody Pro plans in July 2025 and pivoted Cody to an
  enterprise-only offering integrated with Sourcegraph Code Search. **[VENDOR-CLAIM — via
  third-party review aggregation, not independently confirmed against Sourcegraph's own
  changelog in this pass]**
- No evidence found of scope-diff/path-allowlist enforcement or evidence-verification
  features in what's publicly documented; Cody's core value proposition is code
  search/context retrieval and AI pair-programming, not a PR policy gate.
- Not verified further given lack of a clear primary-source feature page on this specific
  capability; marked "not found" for scope-diff and evidence-verification.

## 8. Cortex.io (software catalog + scorecards)

- Cortex Scorecards check catalog-entity properties and repo metadata — e.g. rules like
  `git.fileContents("circleci/config.yml").matches(".*npm test.*")` to confirm a CI/test step
  exists, or checks for README/lockfile/ownership presence. **[VENDOR-CLAIM]**
  (https://docs.cortex.io/standardize/scorecards/scorecard-examples,
  https://docs.cortex.io/standardize/scorecards-as-code)
- This is service/repo-level maturity grading (does the repo have X), not per-PR scope
  enforcement against a requirement's declared file list. No PR-blocking, changed-files-vs-
  scope mechanism found.
- Evidence verification: Scorecards read repo state directly (file contents, config), which is
  closer to "verify the artifact exists" than "verify a claimed CI run occurred," and it
  operates at the catalog/repo level, not the per-PR level.
- Agnostic: yes, general IDP/catalog tool.
- Pricing: no fully public pricing; third-party aggregators report a free tier up to ~20
  services, paid tiers from ~$25-30/developer/month, and enterprise contracts commonly cited
  in the $30k-$250k/year range for larger orgs. **[VENDOR-CLAIM / third-party, not confirmed
  on cortex.io's own pricing page]**

## 9. Port.io / Backstage software catalogs and scorecards

- Port Scorecards define rules against catalog-entity properties (including PR-standard
  metrics like merged-PR counts) to grade services/teams; used for tracking working
  agreements, not per-PR scope gating. **[VENDOR-CLAIM]**
  (https://docs.port.io/guides/all/working_agreements_and_measuring_pr_standards/,
  https://docs.port.io/scorecards/overview/)
- Backstage's own core has no built-in scorecard system; scorecard/grading functionality comes
  from third-party plugins (Cortex's Backstage plugin, Roadie, Spotify Soundcheck). A common
  Backstage CI pattern is running `backstage-cli repo lint` against `catalog-info.yaml` to
  reject PRs with invalid catalog files — a schema-validation gate, not scope enforcement.
  **[VENDOR-CLAIM / community pattern, not official Backstage core docs]**
- No scope-diff or evidence-verification (CI-run-ID-tied) capability found in either.
- Agnostic: yes.
- Pricing: Port — Free tier (15 seats, 10K entities, 500 automation runs, no time limit), paid
  Team/Business tiers per contributing user, Enterprise custom (SSO, RBAC, audit depth).
  **[VENDOR-CLAIM]** (third-party aggregation; Port's own pricing page at
  https://www.port.io/pricing was referenced but not directly fetched in this pass).
  Backstage itself is open source (CNCF project), free to self-host.

## 10. GitHub branch protection rules / rulesets

- Modern **rulesets** (superset of legacy branch protection) support, among other rule types:
  Require a pull request before merging, Require status checks to pass, Require code scanning
  results, Require signed commits, Block force pushes, Require linear history, Require
  deployments to succeed, Restrict creations/updates/deletions (by branch/tag name pattern),
  and Metadata restrictions (commit message/author format). **[DOCUMENTED]**
  (https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
- Separately, **Push rulesets** add **file-path-based rules**: "Restrict file paths" ("Prevent
  commits that include changes in specified file paths from being pushed... Limit is 200
  entries and up to 200 characters in each entry"), "Restrict file path length," "Restrict
  file extensions," and "Restrict file size." Patterns use `fnmatch` syntax (e.g.
  `test/demo/**/*`, `test/docs/pushrules.md`). **[DOCUMENTED]**
  (https://docs.github.com/en/organizations/managing-organization-settings/creating-rulesets-for-repositories-in-your-organization,
  https://github.blog/changelog/2024-09-10-push-rules-are-now-generally-available-and-updates-to-custom-properties/)
- **This is the closest thing to deterministic, GitHub-native path-based policy** found in
  this survey — but it is a **static, repo/org-level allow/block list**, not a **per-PR,
  per-requirement declared scope**. It can say "no one may ever touch `secrets/**`"; it cannot
  express "PR #482, which implements REQ-014, may only touch `src/billing/**` and
  `tests/billing/**`, and no other PR-specific scope." There is no linkage to an issue,
  requirement, or ticket-declared scope — the allow/block list is fixed configuration, not
  dynamic per-change-request policy.
- Required status checks are tied to the exact head commit SHA of the PR by design — a check
  from an earlier commit does not satisfy the requirement, which is a form of built-in evidence
  binding (the "tests passed" status is cryptographically/structurally tied to a specific SHA,
  not a free-text claim). **[DOCUMENTED]**
  (https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks)
- Agnostic: yes, purely GitHub-platform-native, no AI-tool tie-in.
- Pricing: Rulesets (including push rules with file-path restrictions) are available on GitHub
  Team ($4/user/month) and Enterprise ($21/user/month) plans; org-level rulesets were extended
  from Enterprise-only to Team plans in June 2025. **[DOCUMENTED]**
  (https://github.blog/changelog/2025-06-16-organization-rulesets-now-available-for-github-team-plans/,
  https://github.com/pricing)

## 11. GitLab compliance frameworks / policies

- GitLab's **Compliance Frameworks** (Premium+, with pipeline/security-policy enforcement in
  Ultimate) let you label projects and attach **Security Policies**: Scan Execution Policies
  (enforce security scans on a schedule/in-pipeline), Merge Request Approval Policies (enforce
  approval rules based on scan results or other conditions), and Pipeline Execution Policies
  (newer, consolidates scan/pipeline enforcement, replacing deprecated Compliance Pipelines as
  of GitLab 17.3, removal planned by 19.0). **[DOCUMENTED]**
  (https://docs.gitlab.com/user/compliance/compliance_overview_dashboard/,
  https://docs.gitlab.com/user/application_security/policies/merge_request_approval_policies/)
- File-path protection in GitLab is handled separately via **CODEOWNERS + protected
  branches**: entries in `CODEOWNERS` can require specific reviewers for specific paths, and
  "Restrict pushing to certain files" via Code Owners means non-owners can't push to matched
  paths on protected branches. **[VENDOR-CLAIM/DOCUMENTED — GitLab docs describe this pattern
  but exact page wording wasn't independently re-confirmed beyond search snippets]**
  (https://docs.gitlab.com/user/project/repository/branches/protected/)
- No evidence found of a feature comparing a PR/MR's changed files against a
  requirement-declared "approved scope" and failing the MR — Compliance Frameworks operate at
  the *policy/security-control* level (which scans ran, which approvals occurred), not at the
  *file-path-vs-requirement* level. CODEOWNERS-based path restriction is reviewer-routing,
  same limitation as GitHub's CODEOWNERS/policy-bot pattern (see below): it requires the right
  people to approve, it doesn't reject the change for being out of an approved scope.
- Evidence verification: Merge Request Approval Policies can key off actual scan results
  (SAST/DAST/dependency-scan findings), which is a real evidence tie-in for *security* claims,
  but nothing was found tying a "tests passed" claim generally to a specific CI run ID for
  arbitrary (non-security) requirement/test claims.
- Agnostic: yes, GitLab-native, no AI-tool tie-in.
- Pricing: Compliance Frameworks available Premium+; policy enforcement (scan execution,
  pipeline execution policies) requires Ultimate. GitLab Ultimate list price ~$99/user/month
  (GitLab no longer lists a fixed public price broadly; contact sales). **[VENDOR-CLAIM]**
  (https://costbench.com/software/developer-tools/gitlab/)

## 12. Palantir policy-bot (bonus discovery)

- Open-source (Apache 2.0) GitHub App for approval policies beyond native CODEOWNERS. Supports
  path-based predicates: `changed_files` (true if *any* changed file matches a path/glob) and
  `only_changed_files` (true only if *all* changed files match), used to conditionally trigger
  required-approval rules (e.g. skip extra review if only `staging/**` changed).
  **[DOCUMENTED]** (https://github.com/palantir/policy-bot/blob/develop/README.md)
- Critically, policy-bot's path rules **gate who must approve**, not **whether the PR is
  allowed to touch those paths at all**. If files fall outside every rule's path predicate,
  the rule simply doesn't trigger — there's no fail/reject behavior for "this PR touched files
  outside its approved scope." Functionally the same limitation as GitHub CODEOWNERS and the
  "Enforce Path-Based Approvals with GitHub Actions" pattern (third-party, DevToolHub,
  2025-10-08) which does the same thing: assigns/blocks-on-required-reviewers per path, not
  scope rejection. **[DOCUMENTED / third-party blog for the DevToolHub pattern]**
  (https://devtoolhub.com/enforce-path-based-approvals-github-actions/)
- Evidence verification: not found.
- Agnostic: yes, no AI-tool tie-in.
- Pricing: free, self-hosted open-source GitHub App.

---

## Closest existing analogue to SCOPE-DIFF

**CodeRabbit's "Issue Assessment" Pre-Merge Check** (with Qodo Merge's `check_pr_additional_content`
ticket-compliance check a close second) is the closest thing found to SCOPE-DIFF, and neither
is a full substitute.

What they do that overlaps: both compare a PR's actual changes against a linked
requirement/ticket and flag (CodeRabbit) or downgrade-and-comment (Qodo) content judged
unrelated to that ticket's stated intent. CodeRabbit's check additionally supports an `error`
enforcement mode that, combined with its "Request Changes Workflow," can block the merge —
making it the only tool surveyed that both (a) compares changes to a declared requirement and
(b) can hard-fail the PR for drifting outside it.
(https://docs.coderabbit.ai/pr-reviews/pre-merge-checks)

The gap versus full SCOPE-DIFF as specified for Axiom-PMO:

1. **Scope source is free text, not a structured declaration.** Both tools infer "scope" by
   having an LLM read the linked issue/ticket's prose description and judge whether the diff
   drifted from it. SCOPE-DIFF's design compares changed files against a requirement's
   **declared "approved implementation scope"** — implicitly a structured, explicit artifact
   (e.g. a path list recorded at approval time), not an LLM's semantic read of a ticket
   description. This is a meaningful reliability difference: a structured allowlist is
   deterministic and auditable; an LLM's "is this related to the ticket" judgment is not.
2. **Neither is a pure GitHub Action / CI-native, framework-agnostic policy gate.** Both are
   proprietary SaaS review bots that happen to include this as one feature among many
   (docstring coverage, PR title/description checks, security findings, etc.), not a
   dedicated, independent scope-verification layer decoupled from a full AI-review product.
3. **No tool found ties the "approved scope" to an explicit human-approval event.** SCOPE-DIFF's
   framing implies the scope was itself approved (e.g. as part of a requirement/PROJECT.md
   approval gate) before implementation starts. CodeRabbit/Qodo derive scope live from
   whatever the linked ticket currently says, with no notion of "this scope was approved and
   is now immutable/authoritative for this PR."
4. **GitHub push rulesets and Palantir policy-bot supply the deterministic file-path matching
   primitive** (fnmatch/glob path lists, hard block on GitHub's side; reviewer-routing on
   policy-bot's side) that SCOPE-DIFF would need, but neither ties that primitive to a
   per-requirement/per-PR dynamic scope — GitHub's is static org/repo config, and policy-bot's
   only routes approvals rather than rejecting the PR.

No tool surveyed combines all three of: (a) deterministic path-list comparison, (b) a scope
declared and approved per-requirement/per-ticket (not inferred from free text), and (c) hard
PR failure on violation. That combination is the specific gap SCOPE-DIFF would fill.

Separately, on evidence verification (tying a "tests passed" claim to an actual CI run
ID/commit SHA rather than trusting a self-report): no dedicated third-party tool doing this
generally was found. The closest native primitive is GitHub's required-status-checks system,
which structurally binds a check's pass/fail state to an exact commit SHA (so a stale or
different-commit "passed" status cannot satisfy the requirement) — this is a platform-native
guarantee, not a separate governance product, and it only covers CI-integrated checks, not
arbitrary claims embedded in PR descriptions or agent output.

---

## Sources

- https://www.openpolicyagent.org/docs/cicd/pr-checks
- https://www.openpolicyagent.org/docs/cicd
- https://github.com/open-policy-agent/conftest/blob/master/docs/options.md
- https://www.businesswire.com/news/home/20201117005818/en/Styra-Expands-Declarative-Authorization-Service-with-Free-and-Mid-tier-Offerings-to-Manage-Open-Policy-Agent-at-Scale
- https://danger.systems/js/reference.html
- https://danger.systems/js/plugins/danger-plugin-pull-request.html
- https://github.com/danger/danger-js
- https://github.com/danger/danger-js/blob/main/LICENSE
- https://docs.coderabbit.ai/pr-reviews/pre-merge-checks
- https://www.coderabbit.ai/blog/pre-merge-checks-built-in-and-custom-pr-enforced
- https://docs.coderabbit.ai/configuration/path-instructions
- https://www.coderabbit.ai/pricing
- https://www.greptile.com/blog/greptile-update
- https://www.greptile.com/blog/greptile-v4
- https://www.agent-wars.com/news/2026-05-01-greptile-per-review-pricing
- https://costbench.com/software/ai-code-review/greptile/
- https://docs.qodo.ai/qodo-documentation/code-review/qodo-merge/features/custom-compliance
- https://qodo-merge-docs.qodo.ai/tools/compliance/
- https://qodo-merge-docs.qodo.ai/tools/pr_to_ticket/
- https://www.qodo.ai/blog/qodo-merge-jira-ensuring-code-quality-through-ticket-compliance/
- https://www.qodo.ai/blog/compliance-in-code-reviews-automating-security-standards-and-ticket-checks/
- https://graphite.com/docs/graphite-merge-queue
- https://graphite.com/blog/introducing-graphite-agent-and-pricing
- https://graphite.com/docs/pricing-faq
- https://docs.cortex.io/standardize/scorecards/scorecard-examples
- https://docs.cortex.io/standardize/scorecards-as-code
- https://docs.cortex.io/guides/security/scorecard
- https://docs.port.io/guides/all/working_agreements_and_measuring_pr_standards/
- https://docs.port.io/scorecards/overview/
- https://docs.port.io/scorecards/concepts-and-structure/
- https://backstage.io/docs/features/software-catalog/
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets
- https://docs.github.com/en/organizations/managing-organization-settings/creating-rulesets-for-repositories-in-your-organization
- https://github.blog/changelog/2024-09-10-push-rules-are-now-generally-available-and-updates-to-custom-properties/
- https://github.blog/changelog/2025-06-16-organization-rulesets-now-available-for-github-team-plans/
- https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks
- https://github.blog/enterprise-software/governance-and-compliance/demonstrating-end-to-end-traceability-with-pull-requests/
- https://github.com/pricing
- https://docs.gitlab.com/user/compliance/compliance_overview_dashboard/
- https://docs.gitlab.com/user/application_security/policies/merge_request_approval_policies/
- https://docs.gitlab.com/user/project/repository/branches/protected/
- https://costbench.com/software/developer-tools/gitlab/
- https://github.com/palantir/policy-bot/blob/develop/README.md
- https://devtoolhub.com/enforce-path-based-approvals-github-actions/
