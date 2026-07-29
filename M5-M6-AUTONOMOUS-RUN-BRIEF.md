# Autonomous overnight run brief -- M5/M6, 2026-07-30

> Read this file first, completely, before doing anything else. It is the
> full authorization and plan for an unsupervised, multi-hour session. If
> anything here conflicts with a live instruction from the user in the
> current chat, the live instruction wins -- this file is what to do
> *absent* one.

## 0. Who authorized this and what exactly

Human Owner (Witchwasin K.) explicitly authorized, in chat on 2026-07-30,
full autonomous execution of Milestone 5 and Milestone 6 while unsupervised
overnight, **including merge to `main`, tagging/release, and starting M6
without asking first** -- a deliberate, explicit waiver of AGENTS.md's
normal per-instance human-confirmation and Sol-review-then-accept gate,
for this run only. The full reasoning is recorded in `decision-log.md`
(`DEC-001`) -- read it, it explains *why*, which matters for judgment calls
this brief doesn't anticipate.

**What stays authorized without asking:**
- Writing code, tests, docs on `m5.0-execution-contract-research` (or a
  follow-on branch you create for M6 -- your call).
- Committing and pushing to that branch/those branches, as often as you want.
- Merging to `main` (no PR, no Sol review required this time).
- Creating a version tag and GitHub Release.
- Starting Milestone 6 implementation.
- Making judgment calls on ambiguous *implementation* details, the same way
  M4/M4.5 were built -- this is not a request to ask about every choice.

**What stays off-limits regardless of the above** (this is not the part
that was waived):
- Force-push, rewriting or deleting shared branch history.
- Modifying CI/CD secrets, repo settings, or branch protection.
- Publishing to npm or any external service.
- Touching anything outside this git repository -- no edits to `~/.claude`
  global config, no touching other repos on this machine, no installing the
  M6 "installer" against a real environment (dogfood it via fixtures in
  `demo/` the same way M4/M4.5 did, never against this repo's own live
  Claude Code config or the user's).
- Entering credentials, API keys, or payment details anywhere.
- Fabricating test results, walkthrough evidence, or approvals -- if you
  didn't run it, it didn't pass.
- Weakening or skipping a test to make CI green.
- Contacting real external people (there is no external-user step tonight
  -- see §2 below, that part is explicitly *not* yours to do).

## 1. Where things stand right now

- `main` has M1 through M4.5 delivered (`ROADMAP.md`'s Milestone Status
  table is accurate as of commit `8e6ec87`). `git log --oneline -10` on
  `main` to get current reality -- do not trust this brief's SHAs once
  you've made new commits.
- Branch `m5.0-execution-contract-research` was just created off `main`
  and has no work on it yet besides catching up to `main`.
- `ROADMAP.md`'s "Milestone 5 - Execution Contract Verification MVP" and
  "Milestone 6 - Claude Code Integration Experience" sections are the
  canonical plan. Read both, completely, before writing any code.
- `integrations/superpowers/` has experimental schemas from earlier design
  work -- inspect them, but Milestone 5.0's job is to check them against
  the *real* `superpowers` plugin's actual surface, not assume they're
  still right.
- **No release newer than `v1.1.1` (2026-07-26) exists, and it predates M4
  entirely.** GitHub Action consumers writing `uses: witchwasin/Axiom-PMO@v1.2.0`
  today would get nothing -- the tag doesn't exist. This is a real gap, not
  a hypothetical one.
- Two scratch files sit untracked in the repo root:
  `PLAN-M5-execution-contract-verification.md` and `PLAN-post-sol.md`.
  They may or may not still be there by the time you read this (untracked
  files in a shared working directory are not guaranteed to survive). Their
  load-bearing content is folded into §2-§4 below so you don't depend on
  them existing -- but read them if they're still there, they have more
  detail than fits here.

## 2. Sequencing -- read this before jumping to M5 implementation

A parallel session's analysis (folded in here from `PLAN-post-sol.md`,
since the user has not explicitly overridden it) makes an argument worth
respecting even under tonight's broad authorization: **Milestone 5's exact
*shape* should be decided from real external-user data, not guessed.**
Milestone 6 similarly assumes people other than the framework's own author
will install this into their own repos.

That argument is sound, but it does not mean "do nothing tonight." It means
sequence the work so that what you build tonight is useful *regardless* of
whether the external-user step happens later:

1. **Cut a release first.** Bump `VERSION` (1.1.1 -> 1.2.0, minor: additive
   feature, no breaking change), write a `CHANGELOG.md` entry covering M4 +
   M4.5, confirm `pmo-config/*.json` version fields match (`DOCTOR-005`/`006`
   will fail loudly if not -- run `scripts/pmo-doctor.ps1` and trust it),
   then tag `v1.2.0` and push the tag. This alone unblocks the framework
   being usable by anyone outside this machine and is low-risk, mechanical
   work -- do it before anything else.
2. **Milestone 5.0 (research, not implementation) next.** Its job is a
   threat model, a schema, and an explicit `GO` / `GO WITH REFRAME` / `NO-GO`
   decision record (see `ROADMAP.md`'s Milestone 5.0 section for the exact
   required shape). This does not need external users -- it needs you to
   actually go read the real `superpowers` plugin's real hook/event surface
   (the experimental schemas in `integrations/superpowers/` recorded an
   earlier finding that it has a `SessionStart` hook only, no contract
   ingestion/result-emission surface -- verify that's still true rather
   than assuming it, if you have a way to check the current plugin; if you
   don't have network/tool access to re-verify, say so explicitly in the
   decision record rather than silently reusing the old finding as if it
   were freshly confirmed).
3. **If M5.0 lands on GO or GO WITH REFRAME**, proceed into M5.1-5.4
   (contract export, result import, git-authority validation, integration
   tests) with the same engineering discipline M4/M4.5 used -- see §3.
   Tonight's authorization covers this; the "wait for external users" advice
   in §2's opening paragraph is about not over-investing in speculative
   *scope*, not about refusing to build the MVP the roadmap already
   specified in detail. Build the MVP; don't gold-plate it while no one's
   watching.
4. **If M5.0 lands on NO-GO**, write that up as clearly as a GO decision
   would be, update `ROADMAP.md` to reflect it, and move on to whatever
   independent work remains (M6 research, or stop and leave clear notes) --
   do not force a GO to have something to build.
5. **Milestone 6** after M5 (or after M5.0's decision, if M5.1-5.4 turns out
   to be large enough that M6 is a better use of remaining time/budget --
   use judgment, this is not required to run in strict lockstep). Prototype
   per `ROADMAP.md`'s M6 section; dogfood any installer logic against
   fixtures, never against a real environment.
6. **Finding real external users is explicitly not part of tonight's
   scope** -- that requires the Human Owner personally, it cannot be
   delegated to an autonomous session. Leave it for them in your final
   summary, don't attempt it.

## 3. Engineering discipline -- match M4/M4.5, don't relax it

Every existing check in this repo exists because dropping it caused a real
problem once. Keep them all:

- Deterministic only. No LLM-interpreted validation logic, same principle
  `scope-diff-matcher.ps1`'s own docstring states outright.
- Every new rule gets a `docs/rules/<RULE-ID>.md` page, a catalog entry in
  `pmo-config/validation-rules.json` with a `suggestion`, and a test.
- Every new JSON field is additive (see `docs/reference/diagnostics-contract.md`'s
  compatibility policy) -- never rename or repurpose an existing field.
- Sensitive-data discipline: never let raw file content, credentials, or
  local absolute paths reach a report, annotation, or Job Summary. M4's
  privacy fix and M4.5's `renames`/exempt-bucket work are the reference
  examples -- read them if you need a template.
- Before calling anything "done," run the full local suite and expect all
  of it green (use `AXIOM_PWSH=/Users/arm/tools/pwsh/pwsh` -- pwsh 7.6.4 is
  installed there):
  ```bash
  pwsh -NoProfile -ExecutionPolicy Bypass -File tests/helpers/scope-diff-tests.ps1
  pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run-validation-tests.ps1
  pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/pmo-doctor.ps1
  pwsh -NoProfile -ExecutionPolicy Bypass -File tests/helpers/diagnostics-contract-tests.ps1
  node tests/helpers/github-action-tests.mjs
  ```
  Add new test files/suites for M5/M6 as needed, following the existing
  ones' structure (disposable git fixtures, no reliance on this repo's own
  shifting history -- see `tests/helpers/scope-diff-tests.ps1`'s top-of-file
  comment for why).
- Update `ROADMAP.md` status as each milestone/sub-milestone actually
  completes -- don't let it go stale the way M4's status did before this
  session fixed it.

## 4. Process while working

- Commit early and often, with clear messages. Push after every meaningful
  commit -- if the session dies mid-work, whatever's pushed is not lost.
- Keep a running log of what you did and any judgment calls, appended to
  `decision-log.md` (new `DEC-###` rows) for anything a reasonable person
  would want to double-check later -- not every commit, but every non-obvious
  call (e.g. the M5.0 GO/NO-GO decision itself, any place you deviated from
  the roadmap's stated plan, any test you couldn't run and why).
- When you merge a milestone to `main`, write a real merge commit message
  (see commit `6b42643` on this repo for the M4.5 merge as a style
  reference) that names what shipped, and note in it that this was a
  Human-Owner-pre-authorized autonomous merge per `decision-log.md` `DEC-001`
  -- so anyone reading `git log` later understands why there was no PR.
- If you hit a genuine blocker -- a business/product decision only a human
  can make, not an implementation detail -- write it down clearly (a new
  section in this file, or a fresh `NOTES-FOR-HUMAN.md`, either is fine),
  commit it, and move to the next independently completable piece of work
  instead of stalling or guessing at business intent.
- When you run out of context/budget, stop cleanly: make sure the working
  tree is either clean or has an obviously-in-progress commit message, push
  everything, and leave a short final summary (in your last chat message,
  and/or appended to this file) of what's done, what's next, and anything
  the Human Owner should look at first when they wake up.

## 5. Quick reference

- Repo: `/Users/arm/Documents/GitHub/Axiom-PMO`, remote `witchwasin/Axiom-PMO`
  on GitHub, currently public.
- PowerShell 7 for local validation: `/Users/arm/tools/pwsh/pwsh` (portable
  install, not on PATH by default -- set `AXIOM_PWSH` or pass the full path).
- `gh` CLI is authenticated as the repo owner already.
- This repo's working directory may be shared with a parallel session --
  `git status` and `git fetch` before trusting any assumption about what's
  checked out, same caution this session learned the hard way tonight.
