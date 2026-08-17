# M1 Walkthrough and Recording Evidence

This guide prepares optional trust evidence from a clean-room walkthrough and a
committed demo recording. On 2026-07-29, a human decision deferred this evidence
and removed it as a blocker before Milestone 4. The guide remains here so the
evidence can be captured later without fabrication.

Tracked issue: [#8](https://github.com/witchwasin/Axiom-PMO/issues/8)

## Authority

- Do not fabricate participant names, platforms, timings, findings, recording
  assets, or acceptance decisions.
- AI may prepare the environment and summarize observations, but must not
  impersonate the human participant.
- Branch or CI success is supporting evidence only. If this optional evidence is
  used later for an acceptance claim, a human decision is still required.

## Recommended Walkthroughs

If this evidence is picked up later, these two walks give the most useful
coverage:

| Walk | Required environment | Purpose |
|---|---|---|
| Windows reference | Clean Windows environment | Proves the reference platform onboarding path |
| Clean macOS | Clean macOS environment with no repo-local state | Proves the portable onboarding path |

The Linux clean-room container in `clean-room/` is useful extra evidence, but it
does not replace either required walk.

## Walkthrough Path

The participant should start without repo-specific coaching:

1. Clone the repository from the public GitHub URL.
2. Follow `README.md` from the top.
3. Run the three-minute demo.
4. Initialize a Standard project with handoff scaffolding.
5. Run the Handoff gate and readiness assessment.
6. Explain what Axiom-PMO does in their own words.

The observer may answer environment questions, but each intervention must be
recorded as a finding.

## Evidence Template

Copy one block per platform into Issue #8 or a follow-up evidence file after
the walkthrough is actually performed.

```text
Walk ID:
Date:
Observer:
Participant role:
Participant familiarity with Axiom-PMO:
Platform:
Shell:
Node version:
Repository commit:

Start time:
Time to first command:
Time to first meaningful failure:
Time to demo completion:
Time to Handoff result:

Path completed:
- Clone repository:
- Follow README from the top:
- Run three-minute demo:
- Initialize Standard project with handoff scaffolding:
- Run Handoff gate:
- Run readiness assessment:
- Participant can explain the value:

Findings:
1. Step:
   Expected:
   Got:
   Evidence:
   Gap:
   Severity:
   Proposed fix:
   Owner:
   Status:

Observer notes:

Participant summary in their own words:

Acceptance recommendation:
```

## Recording Package

Record the deterministic demo only after walkthrough findings are fixed or
tracked as non-blocking.

Use:

```bash
asciinema rec docs/assets/demo/axiom-pmo-demo.cast -c "node cli/axiom.mjs demo -Plain -NoPause"
```

Then generate a GIF from that cast and store it beside the cast:

```text
docs/assets/demo/axiom-pmo-demo.cast
docs/assets/demo/axiom-pmo-demo.gif
```

Do not link the GIF from `README.md` until the file exists and opens correctly.

## Optional Evidence Checklist

If this optional evidence is used later, a complete package should include:

- Windows walkthrough evidence identifies participant role, platform, timing,
  findings, and whether the participant understood the value.
- macOS walkthrough evidence identifies participant role, platform, timing,
  findings, and whether the participant understood the value.
- Confirmed documentation findings are fixed or tracked in open issues with
  owners.
- `docs/assets/demo/axiom-pmo-demo.cast` exists and replays.
- `docs/assets/demo/axiom-pmo-demo.gif` exists and opens.
- `README.md` links to the GIF and source cast.
- Required CI checks pass on the acceptance commit.
- A human records the M1 acceptance decision.
