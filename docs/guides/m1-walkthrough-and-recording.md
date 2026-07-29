# M1 Walkthrough and Recording Evidence

Milestone 1 can close only with real evidence from a clean-room walkthrough and
a committed demo recording. This guide prepares the evidence packet; it does not
stand in for the walkthrough, the recording, or human acceptance.

Tracked issue: [#8](https://github.com/witchwasin/Axiom-PMO/issues/8)

## Authority

- Do not fabricate participant names, platforms, timings, findings, recording
  assets, or acceptance decisions.
- AI may prepare the environment and summarize observations, but must not
  impersonate the human participant.
- Branch or CI success is supporting evidence only. M1 acceptance requires a
  human decision after the walkthrough and recording evidence exists.

## Required Walkthroughs

Run at least these two walks:

| Walk | Required environment | Purpose |
|---|---|---|
| Windows reference | Clean Windows environment with Windows PowerShell 5.1 available | Proves the reference platform onboarding path |
| Clean macOS | Clean macOS environment with no repo-local state | Proves the portable `pwsh` onboarding path |

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
PowerShell host and version:
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
asciinema rec docs/assets/demo/axiom-pmo-demo.cast -c "pwsh -NoProfile -File scripts/demo.ps1 -Plain -NoPause"
```

Then generate a GIF from that cast and store it beside the cast:

```text
docs/assets/demo/axiom-pmo-demo.cast
docs/assets/demo/axiom-pmo-demo.gif
```

Do not link the GIF from `README.md` until the file exists and opens correctly.

## M1 Exit Checklist

M1 may be marked accepted only when:

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
