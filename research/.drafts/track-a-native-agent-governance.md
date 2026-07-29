# Track A — Native Agent Governance Features

Research question: what do the major AI coding agents ship *natively* for oversight, permissions, and governance of their own output — and where do the vendors themselves admit gaps? Every claim below is tagged **VENDOR-CLAIM** (marketing/blog copy, unverified independently) or **DOCUMENTED** (concrete technical/reference docs — still vendor-authored, but specific and testable). Dates noted where visible on the source. Current date context for this research: July 2026.

---

## 1. GitHub Copilot

### Repo-level instruction/policy mechanism
- **DOCUMENTED.** Repository custom instructions live in `.github/copilot-instructions.md`; the file "contains information describing how a cloud agent seeing it for the first time can work most efficiently," and works across VS Code, Visual Studio, and JetBrains IDEs. — [Adding repository custom instructions for GitHub Copilot](https://docs.github.com/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot)
- **DOCUMENTED.** Organization-wide custom instructions (first introduced April 2025) reached general availability in an April 2026 changelog entry, letting Copilot Business/Enterprise admins set org-wide default instructions. — [Copilot organization custom instructions are generally available (2026-04-02)](https://github.blog/changelog/2026-04-02-copilot-organization-custom-instructions-are-generally-available/)
- **DOCUMENTED.** Custom agent personas are defined in `.github/agents/*.agent.md`, specifying persona, instructions, allowed tools, and optional handoffs. — [Awesome GitHub Copilot — Custom Agents](https://awesome-copilot.github.com/agents/) (community-maintained but reflects the official schema; cross-checked against GitHub's own hooks/agents docs below)

### Permission / tool-allowlist model — can a user bypass it?
- **DOCUMENTED.** By default, Copilot cloud (coding) agent's outbound internet access is restricted by a firewall. A "recommended allowlist" of dependency-download hosts is on by default and can be toggled off, replaced (`COPILOT_AGENT_FIREWALL_ALLOW_LIST` — full replace) or extended (`COPILOT_AGENT_FIREWALL_ALLOW_LIST_ADDITIONS` — additive). Admins can also disable the firewall entirely. — [Customizing or disabling the firewall for GitHub Copilot cloud agent](https://docs.github.com/en/copilot/customizing-copilot/customizing-or-disabling-the-firewall-for-copilot-coding-agent); org-wide firewall settings reached availability per [2026-04-03 changelog](https://github.blog/changelog/2026-04-03-organization-firewall-settings-for-copilot-cloud-agent/)
- **DOCUMENTED — explicit gap.** "The firewall only applies to processes started by the agent via its Bash tool and does not apply to Model Context Protocol (MCP) servers or processes started in configured Copilot setup steps," and it "only operates within the GitHub Actions appliance environment." — same source as above.
- **DOCUMENTED.** The coding agent "can only push to branches prefixed with `copilot/`, never to `main` or `master`," works on one branch/one repo/one PR at a time, and repository rulesets can block it unless explicitly added as a bypass actor. — [About GitHub Copilot cloud agent](https://docs.github.com/copilot/concepts/agents/coding-agent/about-coding-agent)
- **DOCUMENTED.** Agent has a maximum execution time of 59 minutes per task — same source.

### Hooks / lifecycle events for external validation
- **DOCUMENTED.** Hooks are declared in `.github/hooks/*.json` and fire on lifecycle events: `sessionStart`, `sessionEnd`, `userPromptSubmitted`, `userPromptTransformed`, `preToolUse`, `postToolUse`, `postToolUseFailure`, `preCompact`, `agentStop`, `subagentStart`, `subagentStop`, `errorOccurred`, `notification`, `permissionRequest`. — [GitHub Copilot hooks reference](https://docs.github.com/en/copilot/reference/hooks-reference)
- **DOCUMENTED.** Only a subset can actually block/deny: `preToolUse` (allow/deny — described as "the most powerful hook as it can approve or deny tool executions"), `agentStop` (block/continue, but "after 8 consecutive `block` continuations, the CLI overrides the hook"), `subagentStop` (block/modify), and `permissionRequest` (Copilot CLI only, not cloud agent). Most other events are fire-and-forget/informational and explicitly **cannot** block the session (e.g. `userPromptSubmitted` "never blocks the session"). — same source
- **DOCUMENTED — important caveat.** "Command `preToolUse` hooks are fail-closed on errors" (a crash/non-zero exit denies the call even if stdout claimed `permissionDecision: "allow"`), **but** "timeouts are always fail-open, even for `preToolUse` and admin-deployed policy hooks" — meaning a hung validation hook silently lets the action through. — same source

### Traceability (requirement/issue → change)
- **DOCUMENTED.** Assigning Copilot to a GitHub Issue causes it to open a branch and a draft PR that is "automatically linked back to the work item for full traceability," with a timeline event on the issue linking to the PR. — [Assigning and completing issues with coding agent in GitHub Copilot](https://github.blog/ai-and-ml/github-copilot/assigning-and-completing-issues-with-coding-agent-in-github-copilot/)
- **DOCUMENTED.** As of a March 2026 change, every agent-authored commit includes an `Agent-Logs-Url` trailer linking the commit back to the full session log, "giving a permanent link from agent-authored commits back to the full session logs for understanding why changes were made during code review or for auditing purposes." — [Trace any Copilot coding agent commit to its session logs (2026-03-20)](https://github.blog/changelog/2026-03-20-trace-any-copilot-coding-agent-commit-to-its-session-logs/)

### Does it independently verify its own claims (e.g. "tests passed")?
- **DOCUMENTED — admitted gap.** GitHub Copilot code review "does not count toward required approvals for the pull request" and "will not block merging changes"; it "always leaves a 'Comment' review, not an 'Approve' review or a 'Request changes' review." — [Using GitHub Copilot code review](https://docs.github.com/copilot/using-github-copilot/code-review/using-copilot-code-review)
- **VENDOR-CLAIM (developer-guide framing, not official docs, but widely echoed by GitHub's own "comment-only" mechanic above):** "Not a replacement for human review: Copilot catches mechanical issues brilliantly but does not understand your business domain. It is a first pass, not the final word." Treated here as consistent with, not independent of, GitHub's own comment-only-review design.
- No official doc found stating Copilot independently re-executes or confirms test/CI results against ground truth before making claims in a PR description — not found in source reviewed.

### Gaps the vendor's own docs admit
- Firewall does not cover MCP servers or setup-step processes (explicit).
- Hook validation is fail-open on timeout, including for admin-deployed policy hooks (explicit).
- Code review is comment-only and never blocks merge — human/CI gates remain the actual enforcement layer (explicit).

---

## 2. Claude Code (Anthropic)

### Repo-level instruction/policy mechanism
- **DOCUMENTED.** `CLAUDE.md` files provide "persistent instructions" loaded at the start of every session; Claude Code "walks up the directory tree from your current working directory toward the repository root to collect every CLAUDE.md file encountered," and loading is additive, not overriding. A separate "Auto Memory" subsystem lets Claude write its own session-learned notes into a `MEMORY.md` index plus topic files (capped at 200 lines / 25KB for the index). — [How Claude remembers your project](https://code.claude.com/docs/en/memory)

### Permission / tool-allowlist model — can a user bypass it?
- **DOCUMENTED.** Tiered permission system with `allow`/`ask`/`deny` rules per tool, evaluated in strict precedence **deny → ask → allow** (first match wins regardless of specificity). Rules can target Bash commands (with glob/wildcard syntax and compound-command decomposition), file paths (`Read`/`Edit`, gitignore-style patterns), WebFetch domains, MCP servers/tools, and subagents. — [Configure permissions](https://code.claude.com/docs/en/permissions)
- **DOCUMENTED — explicit bypass mechanism, with vendor warning.** A `bypassPermissions` mode "skips permission prompts, including for writes to `.git`, `.config/git`, `.claude`, `.vscode`, `.idea`," etc. The docs carry an explicit `<Warning>`: *"Only use this mode in isolated environments like containers or VMs where Claude Code can't cause damage."* A few prompts still fire even in this mode (explicit `ask` rules, org-controlled connector tools, and `rm -rf /` / `rm -rf ~` as a "circuit breaker against model error"). Organizations can lock this out entirely via `permissions.disableBypassPermissionsMode` in managed settings, which cannot be overridden by users, and — notably — "a user can set it in their own settings to lock themselves out of bypass mode." — same source
- **DOCUMENTED — explicit note on the CLAUDE.md/permission boundary.** *"Permission rules are enforced by Claude Code, not by the model. Instructions in your prompt or `CLAUDE.md` shape what Claude tries to do, but they don't change what Claude Code allows."* This is a direct vendor statement that natural-language repo instructions are advisory, not enforcement — enforcement is the separate deterministic permission engine. — same source

### Hooks / lifecycle events for external validation
- **DOCUMENTED.** A large hook surface (~29 events across session/turn/tool-call cadences), including `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `Stop`, `SubagentStop`, `UserPromptSubmit`, etc. `PreToolUse` and `PermissionRequest` can deny a call outright via `permissionDecision`/`decision.behavior`; several others can block via `decision: "block"` (top-level) or exit code 2. — [Claude Code hooks](https://code.claude.com/docs/en/hooks)
- **DOCUMENTED — precedence caveat.** Hooks do not override the deterministic permission engine: *"Hook decisions don't bypass permission rules. Claude Code evaluates deny and ask rules regardless of what a PreToolUse hook returns."* Conversely, *"a blocking hook also takes precedence over allow rules"* — a hook that exits 2 stops the call even if an allow rule would have let it through. — [Configure permissions §Extend permissions with hooks](https://code.claude.com/docs/en/permissions)
- **DOCUMENTED — exit-code footgun.** *"Claude Code treats exit code 1 as a non-blocking error and proceeds with the action, even though 1 is the conventional Unix failure code. If your hook is meant to enforce a policy, use `exit 2`."* — [Claude Code hooks](https://code.claude.com/docs/en/hooks)
- **DOCUMENTED — best-effort disclaimer.** *"Because the `if` filter is best-effort, use the permission system rather than a hook to enforce a hard allow or deny."* — same source, reinforcing that hooks are for automation, and the permission system is the hard-enforcement layer.
- MCP-tool and HTTP hook types exist, so a hook can call out to an external validator (e.g., a security scanner or, in principle, a governance service) before a tool call proceeds.

### Traceability (requirement/issue → change)
- Not found in source: Claude Code's own docs do not describe a built-in mechanism that traces a code change back to an approved requirement or issue ticket. Traceability of that kind is left to the user's own CLAUDE.md conventions, external tools (e.g., GitHub Issues integration via `/install-github-app`), or a project's own process — not a native artifact Claude Code produces or verifies.

### Does it independently verify its own claims (e.g. "tests passed")?
- Not found in source: none of the fetched Claude Code docs (permissions, hooks, memory) describe Claude Code independently re-executing or cross-checking its own "tests passed" narration against actual CI state. The `sandboxing` docs (referenced but not fetched in depth here) describe OS-level enforcement of *what Claude can touch*, not verification of *what Claude claims happened*.
- **DOCUMENTED.** The permission engine is explicitly separated from the model's own narration/instructions (see CLAUDE.md quote above) — a structural acknowledgment that the model's stated intentions are not a trust boundary.

### Gaps the vendor's own docs admit
- CLAUDE.md/prompt instructions "shape what Claude tries to do" but do not constitute enforcement (explicit, repeated).
- `bypassPermissions` mode is explicitly flagged as unsafe outside isolated containers/VMs (explicit).
- Hook `if` filters are "best-effort," not a hard boundary (explicit).
- No documented native mechanism for verifying its own "it works" / "tests passed" claims against actual execution evidence, or for tracing a change back to an approved requirement — both **not found in source**.

---

## 3. Cursor

### Repo-level instruction/policy mechanism
- **DOCUMENTED.** Four-tier rules system: **Project Rules** (`.cursor/rules/*.mdc`, version-controlled, glob-scoped), **User Rules** (global, apply to Agent/Chat only — explicitly do **not** apply to Cursor Tab or Inline Edit), **Team Rules** (org-wide, managed via dashboard, Team/Enterprise plans), and **AGENTS.md** as an alternative plain-markdown format with nested-directory support. Rules apply via four activation modes: Always Apply, Intelligent (agent decides relevance), file-glob match, or manual `@`-mention. Precedence order when rules conflict: Team → Project → User. — [Cursor Docs — Rules](https://cursor.com/docs/context/rules)

### Permission / tool-allowlist model — can a user bypass it?
- **DOCUMENTED — explicit non-enforcement admission.** The docs state rules provide "persistent, reusable context at the prompt level" but do not guarantee compliance; "Apply Intelligently" rules depend on agent discretion "and the system cannot force application." The docs directly advise: *"AI guidance should not be your only security control."* — [Cursor Docs — Rules](https://cursor.com/docs/context/rules)
- **DOCUMENTED.** A separate enforcement layer exists via `.cursor/hooks.json` **hooks** (see below), which can deny shell execution — this is the actual technical control, distinct from rules.
- **VENDOR-CLAIM/DOCUMENTED (mixed).** Cursor Organizations (GA to Enterprise, announced 2026-06-03) gives a single admin dashboard to manage multiple teams, each with "its own security policies, data access rules, and model configurations," plus spend/token rollups. — [Cursor Organizations: Govern Enterprise AI Coding at Scale](https://www.digitalapplied.com/blog/cursor-organizations-enterprise-ai-coding-governance-2026); official enterprise docs at [cursor.com/docs/enterprise](https://cursor.com/docs/enterprise)
- **DOCUMENTED — admitted governance weakness.** "When a user belongs to multiple teams or groups, the higher-access setting applies, which favors velocity over least-privilege — the opposite of how enterprise policies usually cascade." (third-party analysis of Cursor's documented behavior, flagged here as worth independent confirmation rather than treated as a direct vendor quote.)

### Hooks / lifecycle events for external validation
- **DOCUMENTED.** Cursor Hooks (introduced v1.7, per third-party reporting cross-referenced against Cursor's own docs site) run at defined agent-loop stages via `.cursor/hooks.json`, receiving structured JSON over stdin. Six lifecycle hooks exist, including `beforeShellExecution` (can return JSON to allow/deny/ask before any shell command runs) and `afterFileEdit` (provides old/new file contents, e.g. for auto-formatting or auto-staging). — [Cursor Hooks deep dive](https://blog.gitbutler.com/cursor-hooks-deep-dive); [Cursor 1.7 Adds Hooks for Agent Lifecycle Control (InfoQ)](https://www.infoq.com/news/2025/10/cursor-hooks/)
- This is the closest Cursor gets to a pre-tool-use / pre-commit external validation gate; unlike Claude Code's hook docs, no official Cursor page was located in this pass with an explicit fail-open/fail-closed statement for hook timeouts or errors — **not found in source**.

### Traceability (requirement/issue → change)
- Not found in source: no official Cursor documentation located describing a native mechanism that links a code change back to an approved requirement/ticket with an auditable trail. Cursor's enterprise dashboard focuses on spend/policy/model governance, not requirement-to-commit traceability.

### Does it independently verify its own claims?
- Not found in source in this pass. No official Cursor doc located claiming independent verification of test/CI results against its own narration.

### Gaps the vendor's own docs admit
- Rules are context, not enforcement: *"AI guidance should not be your only security control"* (explicit, direct quote).
- "Apply Intelligently" rule application is agent-discretionary, not guaranteed (explicit).
- User Rules don't apply to Tab/Inline Edit — coverage gaps across surfaces (explicit).
- No traceability or self-verification claims found either affirmed or admitted as absent — treat as an open gap pending further Cursor docs review.

---

## 4. Devin (Cognition)

### Repo-level instruction/policy mechanism
- **VENDOR-CLAIM/DOCUMENTED.** "Playbooks" let a team specify not just the steps Devin should take for a recurring task but also "the success criteria and guardrails," and can be shared org-wide so one engineer's successful coaching transfers to others. — search-derived from Cognition's own materials (playbooks feature); primary reference: [ask-devin/PLAYBOOKS.md](https://github.com/brandonedley/ask-devin/blob/main/PLAYBOOKS.md) (third-party mirror of the concept — treat feature existence as vendor-claimed, not independently verified against a primary docs.devin.ai page in this pass).
- **DOCUMENTED.** A "Knowledge" feature lets teams share documentation, internal libraries, and tips that Devin automatically draws on within the org's environment. — search-derived, consistent across multiple sources; not independently fetched from a single primary URL in this pass.

### Permission / tool-allowlist model — can a user bypass it?
- **DOCUMENTED.** Via GitHub integration, "users can select which repositories Devin can access, with permissions adjustable through GitHub's App Settings." Via Slack, Devin "doesn't read, process or store any data in your Slack instance" beyond actively-tagged messages/threads. Secrets should be stored via a dedicated "Secrets" feature under Settings rather than exposed directly. — [Security at Cognition](https://docs.devin.ai/admin/security)
- **DOCUMENTED — guardrail is procedural, not technical.** The docs recommend organizations "implement code reviews, enabling branch protections to ensure checks are enforced before Devin can merge any changes" — i.e., Cognition's own security docs point back to standard GitHub branch-protection/CI as the actual enforcement mechanism, not a Devin-native gate. — same source

### Hooks / lifecycle events for external validation
- Not found in source: no official Devin documentation located in this pass describing a hook/lifecycle-event system analogous to Claude Code's or Cursor's (e.g., a documented `preToolUse`-equivalent that can programmatically deny an action before execution). Devin's API supports "automatic PR reviews" as an integration pattern, but this is CI-adjacent tooling rather than a documented in-session hook system. — [Devin 101: Automatic PR Reviews with the Devin API](https://cognition.com/blog/devin-101-automatic-pr-reviews-with-the-devin-api)

### Traceability (requirement/issue → change)
- **DOCUMENTED.** Jira integration: when Devin opens a PR, "the PR URL is automatically added as a remote link on the Jira issue and posted as a comment," plus a direct link back to the Devin session for real-time progress tracking. — [Jira — Devin Docs](https://docs.devin.ai/integrations/jira)
- **VENDOR-CLAIM.** Linear integration: "The Devin session and any PRs created within the session will be automatically linked to the Linear issue." — [Devin Integration – Linear](https://linear.app/integrations/devin)
- **VENDOR-CLAIM.** Devin can run in "scoping-only mode" against a ticket, posting a scoping comment with summary, implementation plan, and a confidence estimate before any code is written. — consistent with Devin 2.1 materials; [Devin 2.1 | Cognition](https://cognition.com/blog/devin-2-1)

### Does it independently verify its own claims (e.g. "tests passed")?
- This is Devin's strongest documented feature among the five tools researched. **DOCUMENTED/VENDOR-CLAIM (Cognition's own blog, 2026-05-29):** *"a clean review alone often isn't enough — engineers want to see the change tested end to end, the same way they would test it themselves."* Devin's stated approach: it "will spin up the app, click through it, and confirm its changes actually work, the same way an engineer would," producing "test reports with labeled screenshots," a "test video with a rich player UI" (with chapters), and results "annotated ... as passed, failed, or untested." — [Verifying Agentic Development at Scale (2026-05-29)](https://cognition.com/blog/testing-development)
- **DOCUMENTED — vendor-admitted limitation, same post:** timing/observation gaps — *"If Devin is testing a toast notification, a screenshot taken too early or too late can miss the toast entirely"* — and a documented risk that the model may "execute JavaScript in the browser to trigger states programmatically instead of clicking through the UI," i.e., it can shortcut the very verification it's supposed to be doing.
- **VENDOR-CLAIM.** Confidence scores (red/orange/green) are surfaced for Linear/Jira-linked tasks and are described as "highly correlated with task success, with green scores resulting in twice the likelihood of a merged PR compared to red scores" — a self-reported confidence signal, not independent proof.

### Gaps the vendor's own docs admit
- "Devin can still experience hallucinations, introduce bugs into code, or suggest insecure code or procedures" — direct admission in Cognition's own security docs. — [Security at Cognition](https://docs.devin.ai/admin/security)
- Enforcement of "Devin can't merge without review" is delegated to GitHub branch protections, not a Devin-native control (explicit, same doc).
- Its own testing/verification blog post admits the verification mechanism (screenshots/video) can miss timing-sensitive UI states and can be shortcut by the model itself (explicit).
- No documented native hook/lifecycle-event system for third-party pre-action validation — not found in source.

---

## 5. OpenAI Codex / ChatGPT coding agent

### Repo-level instruction/policy mechanism
- **DOCUMENTED.** `AGENTS.md` files ("think of it as a README for agents") placed in a repo tell Codex how to navigate the codebase, which test commands to run, and which conventions to follow. Codex "reads AGENTS.md files before doing any work" and "builds an instruction chain when it starts (once per run)"; in global scope it reads `AGENTS.override.md` if present, else `AGENTS.md`. — [Custom instructions with AGENTS.md](https://developers.openai.com/codex/guides/agents-md); reference implementation at [openai/codex AGENTS.md](https://github.com/openai/codex/blob/main/AGENTS.md)
- Note: `AGENTS.md` as a format is now vendor-neutral, stewarded by the Agentic AI Foundation under the Linux Foundation, and is also the format Cursor and others support (see above) — [agents.md](https://agents.md/)

### Permission / tool-allowlist model — can a user bypass it?
- **DOCUMENTED.** Two orthogonal policy axes: **Sandbox Policies** (filesystem/network access restrictions for shell commands) and **Approval Policies** (when the user must explicitly authorize an action). Documented approval levels: **on-request** (default — approval needed for sandbox escalations, network access, out-of-workspace ops), **untrusted** (auto-runs known-safe reads; state-mutating commands need approval), **never** (all approval prompts disabled), and a granular mode that keeps some categories interactive while auto-rejecting others. — [Agent approvals & security](https://learn.chatgpt.com/docs/agent-approvals-security)
- **DOCUMENTED — explicit bypass flag, vendor-flagged as risky.** `--dangerously-bypass-approvals-and-sandbox` (alias `--yolo`) removes both sandbox and approvals; the docs annotate it directly: *"No sandbox; no approvals (not recommended)."* `--sandbox workspace-write` loosens file-edit restrictions within the workspace; network access can be explicitly opted into via `network_access = true`. — same source
- **DOCUMENTED.** Codex Cloud runs in isolated OpenAI-managed containers using a two-phase runtime: a network-enabled "setup" phase to install dependencies, then an "agent" phase that runs offline by default unless internet access is explicitly enabled for that environment. — [Sandbox | ChatGPT Learn](https://developers.openai.com/codex/concepts/sandboxing)
- **DOCUMENTED — admitted security caveats.** *"Prompt injection can cause the agent to fetch and follow untrusted instructions"* when web search is enabled; DNS-rebinding protections are described as "best-effort" and don't fully eliminate the risk; protected paths (`.git`, `.agents`, `.codex`) are read-only by technical restriction rather than by a trust decision. — [Agent approvals & security](https://learn.chatgpt.com/docs/agent-approvals-security)

### Hooks / lifecycle events for external validation
- Not found in source in this pass: no dedicated hooks/lifecycle-event page analogous to Claude Code's or Copilot's was located for Codex CLI/Cloud. Codex does support a **Codex Code Review** feature that can run against custom review rules and integrates into GitHub PRs, and a Codex SDK that lets teams "build your own automated code review workflow in CI/CD environments," which is the closest analogue to a pre-merge external-validation hook — but this is a review/reporting integration, not a documented blocking pre-tool-use hook inside an interactive session. — [Codex code review in GitHub](https://developers.openai.com/codex/integrations/github); [Build Code Review with the Codex SDK](https://developers.openai.com/cookbook/examples/codex/build_code_review_with_codex_sdk)
- **DOCUMENTED — explicit non-enforcement admission for review rules:** *"Codex Code Review is still an additional reviewer; tests, branch protections, and required approvals continue to provide hard enforcement"* and "code review rules guide Codex; they don't replace tests, branch protections, or required approvals." — [Custom Code Review rules for Codex](https://developers.openai.com/blog/custom-code-review-rules-for-codex)

### Traceability (requirement/issue → change)
- Not found in source: no primary Codex documentation located in this pass describing a native mechanism that ties a code change to an approved requirement/issue with an audit trail (contrast with Copilot's issue-linked draft PR + `Agent-Logs-Url` commit trailer, or Devin's Jira/Linear PR-linking).

### Does it independently verify its own claims (e.g. "tests passed")?
- **DOCUMENTED (partial).** Codex "provides verifiable evidence of its actions through citations of terminal logs and test outputs, allowing you to trace each step taken during task completion" — this is evidence *surfacing* (showing the logs it produced), not independent *re-verification* against an external CI system. — search-derived summary of Codex materials; primary citation-of-terminal-logs behavior is documented generally across [developers.openai.com/codex](https://developers.openai.com/codex) but a single canonical URL for this exact claim was not isolated in this pass — treat as **VENDOR-CLAIM** pending a more targeted docs fetch.
- No official doc found stating Codex cross-checks its "tests passed" narration against actual CI pipeline results (e.g., polling a GitHub Actions run) rather than trusting its own local execution — **not found in source**.

### Gaps the vendor's own docs admit
- `--yolo` mode is explicitly flagged "(not recommended)" (explicit).
- DNS-rebinding protection is "best-effort" (explicit).
- Prompt injection can cause the agent to fetch and follow untrusted instructions when web search is on (explicit).
- Code review rules explicitly do not replace tests/branch-protections/required approvals — Codex's own review layer is advisory (explicit).
- No hook/lifecycle system or requirement-traceability mechanism found documented — not found in source.

---

## 6. Bonus: Windsurf (Cascade) — lighter coverage

- **DOCUMENTED (via Windsurf's own rules-authoring guide).** Rules live in `.windsurf/rules/` or a single `.windsurfrules` file, version-controlled, with activation modes (always/manual/glob) similar to Cursor's. Global + workspace rules together are capped at 12,000 characters; Cascade "prioritizes global rules, then fits as many workspace rules as possible" when the budget is exceeded. — [Creating & Modifying Rules — Windsurf University](https://windsurf.com/university/general-education/creating-modifying-rules)
- **VENDOR-CLAIM.** Permission policies can restrict Cascade from running "wild on the terminal or filesystem," and file-creation permissions can restrict Cascade to editing existing files only — consistent with the general Windsurf documentation ecosystem, though a single primary permissions-reference URL was not isolated in this pass.
- Hooks, traceability, and self-verification: **not found in source** in this pass — would need a dedicated follow-up to confirm whether Windsurf has anything analogous to Claude Code/Copilot hooks or Devin's test-evidence capture.

(Amazon Q Developer and Google Jules/Gemini Code Assist were searched briefly; no primary-source governance/hooks/traceability documentation specific to their *coding agent* products was found strong enough to report with confidence in the time available — flagging as **not covered** in this draft rather than guessing.)

---

## Gaps admitted or observed (cross-tool summary)

Every tool researched treats **enforcement** and **instruction** as separate layers, and every vendor that discusses the distinction explicitly says the instruction layer (CLAUDE.md / AGENTS.md / .cursor/rules / Copilot custom instructions) is *advisory*, not a guarantee:

- Claude Code: *"Instructions in your prompt or CLAUDE.md shape what Claude tries to do, but they don't change what Claude Code allows."* ([permissions docs](https://code.claude.com/docs/en/permissions))
- Cursor: *"AI guidance should not be your only security control"* and rule application under "Apply Intelligently" mode is agent-discretionary. ([rules docs](https://cursor.com/docs/context/rules))
- Codex: review rules "guide Codex; they don't replace tests, branch protections, or required approvals." ([review rules blog](https://developers.openai.com/blog/custom-code-review-rules-for-codex))
- Copilot: code review "will not block merging changes" and is comment-only. ([code review docs](https://docs.github.com/copilot/using-github-copilot/code-review/using-copilot-code-review))
- Devin/Cognition: recommends *external* branch protections as the actual merge gate, and admits Devin "can still experience hallucinations, introduce bugs into code, or suggest insecure code." ([security docs](https://docs.devin.ai/admin/security))

**Bypass paths exist everywhere and are vendor-flagged, not hidden:** Claude Code's `bypassPermissions` ("only use... in isolated environments... where Claude Code can't cause damage"), Codex's `--yolo` ("not recommended"), and Copilot's firewall-off / custom-allowlist-replace options are all one flag or one admin toggle away from full autonomy, with the safety burden pushed back onto the user/org.

**Independent, ground-truth verification of the agent's own claims is the weakest link across every tool researched.** The one partial exception is Devin, whose "Verifying Agentic Development at Scale" post is the single clearest vendor admission found in this research that "a clean review alone often isn't enough" and that agent-authored evidence (screenshots/video) can itself be gamed or miss the target state. No tool researched documents an *independent* (i.e., not self-reported, not self-executed) verification step against observed CI/test-runner state before a change is presented as done — Codex "cites" its own terminal logs, Copilot's review is comment-only and admits it doesn't block, and Cursor/Claude Code don't claim this capability at all in the docs reviewed.

**None of the five/six tools researched documents:**
1. An independent, third-party-style verification gate that re-executes or cross-checks tests/CI against the agent's own narration (all either self-report, or explicitly say the review layer doesn't block).
2. A hard, tool-native requirement-traceability contract equivalent to Axiom-PMO's `source_ref` + `evidence_status` model (Copilot and Devin get close via issue/ticket-linked PRs and session logs, but that's *linking*, not *evidence-status verification*).
3. A release/approval boundary that the AI agent itself cannot cross by design, independent of the org's own branch-protection configuration — every vendor's actual enforcement backstop is "configure your repo's branch protection / required reviewers," not something the agent's own governance layer refuses to do on principle.

This is consistent with Axiom-PMO's positioning hypothesis: scope/instruction files (CLAUDE.md-equivalents) and permission/hook systems are well-covered natively by all five mandatory tools, but **independent verification of agent claims, cross-tool evidence-trust status, and a release boundary the agent cannot itself bypass by design** are gaps every vendor either admits directly or leaves undocumented.

---

## Sources

- [Adding repository custom instructions for GitHub Copilot](https://docs.github.com/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot)
- [Copilot organization custom instructions are generally available (2026-04-02)](https://github.blog/changelog/2026-04-02-copilot-organization-custom-instructions-are-generally-available/)
- [Awesome GitHub Copilot — Custom Agents](https://awesome-copilot.github.com/agents/)
- [Customizing or disabling the firewall for GitHub Copilot cloud agent](https://docs.github.com/en/copilot/customizing-copilot/customizing-or-disabling-the-firewall-for-copilot-coding-agent)
- [Organization firewall settings for Copilot cloud agent (2026-04-03)](https://github.blog/changelog/2026-04-03-organization-firewall-settings-for-copilot-cloud-agent/)
- [Copilot allowlist reference](https://docs.github.com/en/copilot/reference/copilot-allowlist-reference)
- [About GitHub Copilot cloud agent](https://docs.github.com/copilot/concepts/agents/coding-agent/about-coding-agent)
- [GitHub Copilot hooks reference](https://docs.github.com/en/copilot/reference/hooks-reference)
- [Assigning and completing issues with coding agent in GitHub Copilot](https://github.blog/ai-and-ml/github-copilot/assigning-and-completing-issues-with-coding-agent-in-github-copilot/)
- [Trace any Copilot coding agent commit to its session logs (2026-03-20)](https://github.blog/changelog/2026-03-20-trace-any-copilot-coding-agent-commit-to-its-session-logs/)
- [Using GitHub Copilot code review](https://docs.github.com/copilot/using-github-copilot/code-review/using-copilot-code-review)
- [How Claude remembers your project](https://code.claude.com/docs/en/memory)
- [Configure permissions — Claude Code](https://code.claude.com/docs/en/permissions)
- [Claude Code hooks](https://code.claude.com/docs/en/hooks)
- [Cursor Docs — Rules](https://cursor.com/docs/context/rules)
- [Cursor Docs — Enterprise](https://cursor.com/docs/enterprise)
- [Cursor Organizations: Govern Enterprise AI Coding at Scale](https://www.digitalapplied.com/blog/cursor-organizations-enterprise-ai-coding-governance-2026)
- [Cursor Hooks deep dive — GitButler blog](https://blog.gitbutler.com/cursor-hooks-deep-dive)
- [Cursor 1.7 Adds Hooks for Agent Lifecycle Control — InfoQ](https://www.infoq.com/news/2025/10/cursor-hooks/)
- [Security at Cognition — Devin Docs](https://docs.devin.ai/admin/security)
- [Jira — Devin Docs](https://docs.devin.ai/integrations/jira)
- [Devin Integration – Linear](https://linear.app/integrations/devin)
- [Devin 2.1 | Cognition](https://cognition.com/blog/devin-2-1)
- [Devin 101: Automatic PR Reviews with the Devin API](https://cognition.com/blog/devin-101-automatic-pr-reviews-with-the-devin-api)
- [Verifying Agentic Development at Scale (2026-05-29)](https://cognition.com/blog/testing-development)
- [Custom instructions with AGENTS.md — ChatGPT Learn](https://developers.openai.com/codex/guides/agents-md)
- [openai/codex AGENTS.md (reference implementation)](https://github.com/openai/codex/blob/main/AGENTS.md)
- [agents.md (format home, Agentic AI Foundation / Linux Foundation)](https://agents.md/)
- [Agent approvals & security — ChatGPT Learn](https://learn.chatgpt.com/docs/agent-approvals-security)
- [Sandbox — ChatGPT Learn](https://developers.openai.com/codex/concepts/sandboxing)
- [Custom Code Review rules for Codex — OpenAI Developers](https://developers.openai.com/blog/custom-code-review-rules-for-codex)
- [Codex code review in GitHub — ChatGPT Learn](https://developers.openai.com/codex/integrations/github)
- [Build Code Review with the Codex SDK — OpenAI Developers cookbook](https://developers.openai.com/cookbook/examples/codex/build_code_review_with_codex_sdk)
- [Creating & Modifying Rules — Windsurf University](https://windsurf.com/university/general-education/creating-modifying-rules)
