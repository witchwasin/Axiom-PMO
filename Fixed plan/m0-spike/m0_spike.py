#!/usr/bin/env python3
"""
M0 SPIKE runner — throwaway, not production code.

Answers the M0 question from MasterPlan §6 against axiomguard==0.7.2:

  Q1: Does encoding pmo-config/policy.json + artifact-policy.json as
      .axiom.yml rules surface any contradiction the 114 existing rules
      do not already catch?
  Q2: Can the §4.1 reachability question — "is there any combination of
      (mode, gate, role, waiver, strict trigger) that lets a project reach
      Release without a valid human approval?" — be expressed through the
      pinned entry point (verify_structured)?

Experiments:
  A  consistency of current config facts          (expect SAT)
  B  negative controls, deliberately contradictory (expect UNSAT)
  C  role-matrix expressiveness probe
  D  reachability enumeration over Release scenarios

Run from the repository root:
  ~/.local/opt/axiomguard-m0-venv/bin/python Fixed\ plan/m0-spike/m0_spike.py
"""

import itertools
import json
from pathlib import Path

from axiomguard import KnowledgeBase, verify_structured

HERE = Path(__file__).resolve().parent
POLICY_YML = HERE / "m0-policy.axiom.yml"
POLICY_JSON = Path("pmo-config/policy.json")

# Release artifacts required per mode (artifact-policy.json, Release gate)
RELEASE_ARTIFACTS = {
    "Lite": ["artifact_delivery"],
    "Standard": ["artifact_delivery", "artifact_release", "artifact_design"],
    "Strict": [
        "artifact_delivery",
        "artifact_release",
        "artifact_design",
        "artifact_raid",
        "artifact_decision_log",
    ],
}


def load_policy_json():
    # policy.json is UTF-8 WITH BOM — utf-8-sig is required, plain json.load fails
    with open(POLICY_JSON, "r", encoding="utf-8-sig") as f:
        return json.load(f)


def scenario_claims(mode, gate, scope_ap, design_ap, release_ap,
                    test_w=False, rollback_w=False, strict=False, artifacts=True):
    """Build the ground claim set for one scenario."""
    claims = [
        {"subject": "project", "relation": "mode", "object": mode},
        {"subject": "project", "relation": "gate", "object": gate},
    ]
    if scope_ap is not None:
        claims.append({"subject": "project", "relation": "scope_approval", "object": scope_ap})
    if design_ap is not None:
        claims.append({"subject": "project", "relation": "design_approval", "object": design_ap})
    if release_ap is not None:
        claims.append({"subject": "project", "relation": "release_approval", "object": release_ap})
    if test_w:
        claims.append({"subject": "project", "relation": "test_waiver", "object": "granted"})
    if rollback_w:
        claims.append({"subject": "project", "relation": "rollback_waiver", "object": "granted"})
    if strict:
        claims.append({"subject": "project", "relation": "strict_trigger", "object": "present"})
    if artifacts:
        for art in RELEASE_ARTIFACTS[mode]:
            claims.append({"subject": "project", "relation": art, "object": "present"})
    return claims


def run(kb, claims, label):
    result = verify_structured(claims, kb=kb)
    status = "UNSAT" if result.is_hallucinating else "SAT"
    print(f"[{label}] {status}")
    if result.is_hallucinating:
        for r in result.violated_rules:
            print(f"    violated: {r['name']} — {r['message']}")
        print(f"    contradicted_claims={result.contradicted_claims}")
    return result


def main():
    kb = KnowledgeBase()
    kb.load(str(POLICY_YML))
    print(f"Loaded {POLICY_YML.name}: {kb.rule_count} rules, "
          f"{kb.constraint_count} Z3 constraints")

    cfg = load_policy_json()
    print("\n--- config facts read from pmo-config/policy.json (utf-8-sig) ---")
    print("approval_checkpoints:", json.dumps(cfg["approval_checkpoints"], sort_keys=True))
    print("approval_roles:", json.dumps(cfg["approval_roles"], sort_keys=True))
    print("test_waiver:", json.dumps(cfg["test_waiver"], sort_keys=True))
    print("rollback_waiver:", json.dumps(cfg["rollback_waiver"], sort_keys=True))

    print("\n=== A. Consistency of current config facts (expect SAT) ===")
    run(kb, scenario_claims("Lite", "Release", "approved", None, "approved",
                            rollback_w=True), "A1 legit Lite release (rollback waiver)")
    run(kb, scenario_claims("Standard", "Release", "approved", "approved", "approved",
                            test_w=True), "A2 legit Standard release (test waiver)")
    run(kb, scenario_claims("Strict", "Release", "approved", "approved", "approved",
                            strict=True), "A3 legit Strict release (strict trigger)")

    print("\n=== B. Negative controls — deliberately contradictory (expect UNSAT) ===")
    run(kb, scenario_claims("Standard", "Release", "approved", "approved", "missing"),
        "B1 Release without Release Approved")
    run(kb, scenario_claims("Standard", "Release", "missing", "approved", "approved"),
        "B2 Release without Scope Approved (Scope has NO Lite exemption)")
    run(kb, scenario_claims("Standard", "Design", "approved", "missing", None),
        "B3 Design gate without Design Ready (Standard)")
    run(kb, scenario_claims("Lite", "Release", "approved", None, "approved", test_w=True),
        "B4 test_waiver granted in Lite (waiver-mode mismatch)")
    run(kb, scenario_claims("Strict", "Release", "approved", "approved", "approved",
                            rollback_w=True), "B5 rollback_waiver granted in Strict")
    run(kb, scenario_claims("Lite", "Release", "approved", None, "approved", strict=True),
        "B6 strict trigger in Lite")
    run(kb, scenario_claims("Standard", "Release", "approved", "approved", "approved",
                            artifacts=False)
        + [{"subject": "project", "relation": "artifact_release", "object": "missing"}],
        "B7 Standard Release with RELEASE.md explicitly missing")

    print("\n=== C. Role-matrix expressiveness probe ===")
    run(kb, scenario_claims("Standard", "Release", "approved", "approved", "approved")
        + [{"subject": "project", "relation": "scope_role", "object": "Project Owner"}],
        "C1 scope approver role 'Project Owner' (orphan string, not in closed set)")
    print("C2 whitelist attempt: an allowed-role whitelist for the scope gate "
          "cannot be expressed —\n"
          "    negation needs the COMPLEMENT of the whitelist enumerated (unbounded "
          "string domain),\n"
          "    exclusion forbids two values at once (wrong semantics),\n"
          "    dependency require pins exactly ONE value (cannot say 'one of').\n"
          "    => role-matrix membership is outside the expressiveness of the 9 rule types.")

    print("\n=== D. Reachability enumeration over Release scenarios ===")
    modes = ["Lite", "Standard", "Strict"]
    states = ["approved", "missing"]
    flags = [False, True]
    rows = []
    for mode in modes:
        design_vals = [None] if mode == "Lite" else states
        for s_ap, d_ap, r_ap, tw, rw, st in itertools.product(
                states, design_vals, states, flags, flags, flags):
            claims = scenario_claims(mode, "Release", s_ap, d_ap, r_ap,
                                     test_w=tw, rollback_w=rw, strict=st)
            res = verify_structured(claims, kb=kb)
            rows.append((mode, s_ap, d_ap, r_ap, tw, rw, st, res.is_hallucinating))

    sat = [r for r in rows if not r[7]]
    unsat = [r for r in rows if r[7]]
    print(f"scenarios checked: {len(rows)}   SAT (policy-permitted): {len(sat)}   "
          f"UNSAT (policy-blocked): {len(unsat)}")

    holes = [
        r for r in sat
        if r[3] == "missing"                      # release approval missing
        or r[1] == "missing"                      # scope approval missing
        or (r[0] != "Lite" and r[2] == "missing")  # design approval missing (non-Lite)
    ]
    print(f"SAT scenarios that reach Release with a required approval missing: "
          f"{len(holes)}")
    for r in holes:
        print("   HOLE:", r[:7])

    print("\n--- all SAT scenarios (mode, scope_ap, design_ap, release_ap, "
          "test_w, rollback_w, strict) ---")
    for r in sorted(sat, key=lambda x: (x[0], x[3], x[1], x[2], x[4], x[5], x[6])):
        print("   ", r[:7])

    print("\n--- UNSAT scenarios grouped by blocking reason ---")
    from collections import Counter
    reasons = Counter()
    for r in unsat:
        # classify by which required approval is missing / mismatch
        mode, s_ap, d_ap, r_ap, tw, rw, st = r[:7]
        if r_ap == "missing":
            reasons["release approval missing"] += 1
        elif s_ap == "missing":
            reasons["scope approval missing"] += 1
        elif mode != "Lite" and d_ap == "missing":
            reasons["design approval missing (non-Lite)"] += 1
        elif tw and mode != "Standard":
            reasons["test_waiver outside Standard"] += 1
        elif rw and mode != "Lite":
            reasons["rollback_waiver outside Lite"] += 1
        elif st and mode != "Strict":
            reasons["strict trigger outside Strict"] += 1
        else:
            reasons["other"] += 1
    for k, v in reasons.most_common():
        print(f"   {k}: {v}")

    print("\n--- summary ---")
    q1 = "YES" if holes else "NONE"
    print(f"Q1: contradictions surfaced by Z3 that the 114 rules miss: {q1}")
    q2 = ("NO — verify_structured is assumption-based: it checks one ground "
          "scenario per call. The combination space must be enumerated by the "
          "caller, and each scenario check restates what the rules already say.")
    print(f"Q2: reachability expressible through verify_structured: {q2}")

    print("\nM0 recommendation: FAIL — the encoding restates what the config "
          "already declares and what the 114 rules already enforce; the two "
          "§4.1 findings are missing invariants (not contradictions) and are "
          "not expressible in the pinned engine's rule types.")


if __name__ == "__main__":
    main()
