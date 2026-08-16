// Guard for maintainer tools that audit the Axiom-PMO framework itself,
// ported from scripts/lib/framework-checkout.ps1.
//
// User-facing tools (validate-project, assess-handoff, the execution
// contract trio, the CLI) read only scripts/, pmo-config/, and templates/.
// They work from a plugin install, and must.
//
// Maintainer tools (pmo-doctor, check-public-hygiene, measure-context,
// prepare-public-release, the test runners) audit the framework's OWN
// repository, so they legitimately read VERSION, AGENTS.md, CLAUDE.md,
// CHANGELOG.md, .gitignore, and .claude/. A plugin install carries none of
// those, and should not: there is no checkout for a plugin user to audit.
// Failing outside a checkout is correct; failing with a raw exception is not.
import { existsSync } from "node:fs";
import { join } from "node:path";
export function testFrameworkCheckout(root) {
    // VERSION and AGENTS.md are both present in every checkout and absent from
    // any packaged distribution. Two markers rather than one so a single stray
    // file does not make a directory look like a checkout.
    return ["VERSION", "AGENTS.md"].every((marker) => existsSync(join(root, marker)));
}
export function frameworkCheckoutFailureMessage(root, toolName, alternative = "node cli/axiom.mjs validate --project <your project>") {
    return [
        `[FAIL] FRAMEWORK-001 '${toolName}' needs an Axiom-PMO source checkout and this is not one.`,
        "",
        `  Looked in: ${root}`,
        "  Expected:  VERSION and AGENTS.md (present in a git checkout, absent from a packaged install)",
        "",
        `  Why: '${toolName}' audits the Axiom-PMO framework itself -- its version file,`,
        "  agent rules, changelog and skill manifest. A plugin install deliberately does not",
        "  carry those, because a plugin user has no framework checkout to audit. Shipping",
        "  them so this command appeared to work would be worse than failing: it would",
        "  report a clean result for a copy it never really inspected.",
        "",
        "  If you meant to check YOUR project, that is a different command and it does",
        "  work from a plugin install:",
        `    ${alternative}`,
        "",
        "  If you meant to check the framework, clone it and run this from the clone:",
        "    git clone https://github.com/witchwasin/Axiom-PMO",
        "",
        "Summary: PASS=0 WARN=0 FAIL=1",
    ].join("\n");
}
