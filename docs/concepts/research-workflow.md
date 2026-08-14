# Guided Research

Research is optional, happens before Scope approval, and is evidence, never
authority (binding decisions D1 and D2). A project declares
`Research mode: off | guided | auto`; `off` is silent and is the compatibility
default for legacy projects.

## Guided first

1. AI drafts a Research Brief from preliminary requirements and unknowns.
2. Externalization produces a sanitized/minimized brief for an external
   provider (RESEARCH-007 requires the approved entry).
3. A Human confirms focus/provider when policy requires.
4. The configured Research Provider produces candidate research.
5. The validator checks structure, provenance, and freshness
   (`RESEARCH/RESEARCH.md` + `RESEARCH/PROVENANCE.json`).
6. AI drafts the Impact Assessment.
7. A Human accepts or rejects proposed changes at Scope.

## Auto provider behavior

After Guided behavior is green, `auto` may orchestrate provider selection in
this order: explicit project/provider configuration; explicit CLI/session
Feyman path; `AXIOM_FEYMAN_PATH` or documented user config; approved governed
web fallback; actionable stop. The Feyman adapter is implemented only after
its real local interface is inspected and verified — never guessed, never
auto-cloned, never auto-installed. Until then, provider unavailability records
a truthful fallback or stop (`RESEARCH-006`).

## What the checks can and cannot detect

The validator proves the artifacts exist, every material claim maps to a
resolvable source, accepted proposals carry named-Human decisions, an
unresolved accepted-impact proposal blocks Scope, provider
availability/fallback is recorded consistently, and external providers cite
approved externalization evidence. It cannot verify that a source exists on
the web, that a retrieved date is truthful, or that a Human actually made the
decision — it checks the governed record the Human is accountable for. Dates
are ISO-8601 and deterministic; the checks never depend on the current date,
so results are host-independent.
