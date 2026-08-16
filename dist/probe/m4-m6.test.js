// Ported from tests/helpers/m4-m6-tests.ps1.
//
// Reclassified from tests-disposition.md's "re-derive from golden" bucket
// after reading the file: like m2-m3, it is a long sequence of progressive
// mutations against one working copy of OPTIONAL-TRACKS (M4 externalization,
// M5 design-provider, M6 research, plus the FB-002 regression batch and
// CR-018 digest-canonicalization checks) -- a single golden snapshot cannot
// cover a mutation sequence, so this needs a real native port.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, cpSync, rmSync, readFileSync, writeFileSync, readdirSync, statSync, symlinkSync, unlinkSync, existsSync, } from "node:fs";
import { tmpdir, platform } from "node:os";
import { createHash } from "node:crypto";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { runPortedChain } from "./validate-chain.js";
import { newProject } from "../tools/new-project.js";
const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
function copyDir(src, dest) {
    for (const entry of readdirSync(src)) {
        if (entry === ".git" || entry === "node_modules" || entry === "dist")
            continue;
        const s = join(src, entry);
        const d = join(dest, entry);
        if (statSync(s).isDirectory()) {
            mkdirSync(d, { recursive: true });
            copyDir(s, d);
        }
        else
            cpSync(s, d);
    }
}
function invoke(repo, project, mode, gate) {
    return runPortedChain(repo, project, mode, gate).diagnostics;
}
function assertRule(results, rule, name) {
    assert.ok(results.some((r) => r.rule_id === rule && r.level === "FAIL"), `${name} did not emit expected FAIL ${rule}`);
}
function assertNoRule(results, rule, name) {
    assert.equal(results.filter((r) => r.rule_id === rule && r.level === "FAIL").length, 0, `${name} unexpectedly emitted FAIL ${rule}`);
}
function assertClean(results, name) {
    const fails = results.filter((r) => r.level === "FAIL");
    assert.equal(fails.length, 0, `${name} expected a clean run but got FAILs: ${fails.map((f) => f.rule_id).join(", ")}`);
}
function sha256File(path) {
    return createHash("sha256").update(readFileSync(path)).digest("hex").toLowerCase();
}
function readJson(path) {
    return JSON.parse(readFileSync(path, "utf8"));
}
function writeJson(path, doc) {
    writeFileSync(path, JSON.stringify(doc, null, 2), "utf8");
}
function restore(active, rels) {
    for (const rel of rels)
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS", rel), join(active, rel));
}
test("M4-M6: contract mutations against OPTIONAL-TRACKS", () => {
    const workRoot = mkdtempSync(join(tmpdir(), "pmo-m4-m6-"));
    const tempRepo = join(workRoot, "repo");
    try {
        mkdirSync(tempRepo, { recursive: true });
        copyDir(REPO_ROOT, tempRepo);
        const active = join(tempRepo, "examples/OPTIONAL-TRACKS");
        const legacy = join(tempRepo, "examples/HANDOFF-DEMO");
        // Positive control: the canonical example is clean at Design and Scope.
        assertClean(invoke(tempRepo, active, "Standard", "Design"), "OPTIONAL-TRACKS Design gate");
        assertClean(invoke(tempRepo, active, "Standard", "Scope"), "OPTIONAL-TRACKS Scope gate");
        // Inactive tracks are silent.
        let result = invoke(tempRepo, legacy, "Standard", "Design");
        assertNoRule(result, "EXT-001", "legacy externalization silent");
        assertNoRule(result, "RESEARCH-002", "legacy research silent");
        assertNoRule(result, "DPROV-002", "legacy design provider silent");
        // Research off stays silent even when other artifacts exist.
        const offProjectMd = join(active, "PROJECT.md");
        let offText = readFileSync(offProjectMd, "utf8");
        offText = offText.replace(/^> Research mode: guided\s*$/m, "> Research mode: off");
        offText = offText.replace(/^> Research provider: feyman\s*$/m, "> Research provider: none");
        writeFileSync(offProjectMd, offText, "utf8");
        result = invoke(tempRepo, active, "Standard", "Design");
        assertNoRule(result, "RESEARCH-002", "research off is silent");
        offText = readFileSync(offProjectMd, "utf8").replace(/^> Research mode: off\s*$/m, "> Research mode: guided");
        offText = offText.replace(/^> Research provider: none\s*$/m, "> Research provider: feyman");
        writeFileSync(offProjectMd, offText, "utf8");
        // ---- M4: Externalization structure, authority, scan honesty, freshness.
        const extPath = join(active, "EXTERNALIZATION.json");
        let extDoc = readJson(extPath);
        extDoc.entries[0]["classification"] = "Confidential";
        extDoc.entries[0]["decision_ref"] = "";
        extDoc.entries[0]["reviewer"] = "Dev Team";
        writeJson(extPath, extDoc);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "EXT-002", "Confidential transfer without Human evidence");
        extDoc.entries[0]["classification"] = "Public";
        extDoc.entries[0]["status"] = "pending";
        extDoc.entries[0]["decision_ref"] = "";
        extDoc.entries[0]["reviewer"] = "";
        extDoc.entries[0]["human_review_required"] = false;
        writeJson(extPath, extDoc);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "EXT-001", "entry with unrecognized status");
        // Scan honesty: declare clean while a secret pattern is present in an
        // outgoing artifact. The secret must never appear in diagnostics.
        const secret = "ghp_" + "MUSTNOTECHO" + "12345678901234567890";
        const projectMd = join(active, "PROJECT.md");
        writeFileSync(projectMd, readFileSync(projectMd, "utf8") + `\nDiagnostic fixture: ${secret}`, "utf8");
        const newHash = sha256File(projectMd);
        extDoc = readJson(extPath);
        extDoc.entries[0] = {
            ...extDoc.entries[0],
            classification: "Internal", status: "approved", human_review_required: true,
            reviewer: "Demo Tech Lead", decision_ref: "DEC-003",
            outgoing_artifacts: [{ path: "PROJECT.md", sha256: newHash }], scan_result: "clean",
        };
        writeJson(extPath, extDoc);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "EXT-003", "declared clean scan contradicts re-scan");
        assert.ok(!result.some((r) => r.message.includes(secret)), "EXT diagnostics echoed a detected secret value");
        // Freshness: stale outgoing digest.
        extDoc.entries[0]["scan_result"] = "finding";
        extDoc.entries[0]["human_review_required"] = true;
        extDoc.entries[0]["outgoing_artifacts"] = [{ path: "PROJECT.md", sha256: "a".repeat(64) }];
        writeJson(extPath, extDoc);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "EXT-004", "stale externalization digest");
        // ---- M5: Claude Design provider contract.
        const manifestPath = join(active, "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json");
        const reviewPath = join(active, "DESIGN/CLAUDE-DESIGN/REVIEW.json");
        const outputDir = join(active, "DESIGN/CLAUDE-DESIGN/OUTPUT");
        let manifestDoc = readJson(manifestPath);
        manifestDoc.inputs[0]["sha256"] = "b".repeat(64);
        writeJson(manifestPath, manifestDoc);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "DPROV-003", "stale manifest input digest");
        manifestDoc = readJson(manifestPath);
        manifestDoc.externalization = "EXT-999";
        writeJson(manifestPath, manifestDoc);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "DPROV-004", "manifest without approved externalization");
        let reviewDoc = readJson(reviewPath);
        reviewDoc["preflight"] = null;
        writeJson(reviewPath, reviewDoc);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "DPROV-005", "review before preflight");
        reviewDoc = readJson(reviewPath);
        reviewDoc["preflight"] = {
            status: "passed", checked_at: "2026-08-14T10:15:00Z",
            manifest_digest: "477a5cb59d8ad382b46a96404f8297ff18fcdc8a1ac3cdb459f2ddfc78c1f84c",
            outputs_digest: "68710242a1030a108434d8472fc50fbe8b0aec0fd3d4de17d50343a14c8f2f83",
        };
        reviewDoc["acceptance"]["reviewer_kind"] = "ai";
        reviewDoc["acceptance"]["decision"] = "accepted";
        reviewDoc["acceptance"]["decision_ref"] = "DEC-002";
        writeJson(reviewPath, reviewDoc);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "DPROV-006", "AI reviewer cannot mark acceptance");
        // Revision invalidates prior review.
        reviewDoc = readJson(reviewPath);
        reviewDoc["acceptance"]["reviewer_kind"] = "human";
        reviewDoc["acceptance"]["decision"] = "accepted";
        writeJson(reviewPath, reviewDoc);
        const uiDirection = join(outputDir, "ui-direction.md");
        writeFileSync(uiDirection, readFileSync(uiDirection, "utf8") + "\nRevision note.", "utf8");
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "DPROV-005", "changed output invalidates recorded acceptance");
        // Technical finding routes to Change Control.
        rmSync(join(active, "CHANGE-REQUESTS.json"), { force: true });
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "DPROV-007", "routed finding without change request");
        // Manifest missing at Handoff on a claude_design project.
        rmSync(manifestPath, { force: true });
        result = invoke(tempRepo, active, "Standard", "Handoff");
        assertRule(result, "DPROV-002", "claude_design project without input manifest at Handoff");
        // ---- M6: Guided research contract.
        const researchReport = join(active, "RESEARCH/RESEARCH.md");
        const provenancePath = join(active, "RESEARCH/PROVENANCE.json");
        rmSync(researchReport, { force: true });
        result = invoke(tempRepo, active, "Standard", "Scope");
        assertRule(result, "RESEARCH-002", "guided research without report");
        const researchText1 = [
            "# RESEARCH - OPTIONAL-TRACKS", "",
            "## Research Status and Scope", "", "Status: complete", "",
            "## Problem and Research Questions", "", "Question.", "",
            "## Existing Solutions", "", "Nothing.", "",
            "## Feature Parity", "", "None.", "",
            "## Relevant Standards and Regulations", "", "None.", "",
            "## Differentiation and Value Implications", "", "None.", "",
            "## Risks and Unknowns", "", "None.", "",
            "## Impact Assessment", "", "None.", "",
            "## Change Proposals", "",
            "| Proposal ID | Proposal | Impact | Accepted Impact | Status | Human Owner | Decision Ref |",
            "|---|---|---|---|---|---|---|",
            "| CP-001 | Defer multi-warehouse stock | scope | yes | accepted | Demo PO | DEC-004 |", "",
            "## Explicit Limits and Unanswered Questions", "", "None.",
        ].join("\n");
        writeFileSync(researchReport, researchText1, "utf8");
        let provDoc = readJson(provenancePath);
        provDoc.claims[0]["sources"] = [];
        writeJson(provenancePath, provDoc);
        result = invoke(tempRepo, active, "Standard", "Scope");
        assertRule(result, "RESEARCH-003", "claim without a source");
        provDoc = readJson(provenancePath);
        provDoc.claims[0]["sources"] = [{ reference: "MOM-20260714", title: "t", issuer: "i", date: "2026-07-14", primary: true, verification: "verified" }];
        writeJson(provenancePath, provDoc);
        writeFileSync(researchReport, readFileSync(researchReport, "utf8").replace(/DEC-004/, "DEC-999"), "utf8");
        result = invoke(tempRepo, active, "Standard", "Scope");
        assertRule(result, "RESEARCH-004", "accepted proposal without resolvable decision");
        // Unresolved accepted-impact proposal blocks Scope.
        writeFileSync(researchReport, readFileSync(researchReport, "utf8").replace("| CP-001 | Defer multi-warehouse stock | scope | yes | accepted | Demo PO | DEC-999 |", "| CP-001 | Defer multi-warehouse stock | scope | yes | proposed | Demo PO | |"), "utf8");
        result = invoke(tempRepo, active, "Standard", "Scope");
        assertRule(result, "RESEARCH-005", "unresolved accepted-impact proposal blocks Scope");
        // Truthful provider availability.
        writeFileSync(researchReport, readFileSync(researchReport, "utf8").replace("| CP-001 | Defer multi-warehouse stock | scope | yes | proposed | Demo PO | |", "| CP-001 | Defer multi-warehouse stock | scope | yes | accepted | Demo PO | DEC-004 |"), "utf8");
        provDoc = readJson(provenancePath);
        provDoc.fallback_used = true;
        provDoc.provider_available = true;
        writeJson(provenancePath, provDoc);
        result = invoke(tempRepo, active, "Standard", "Scope");
        assertRule(result, "RESEARCH-006", "fallback claimed while provider available");
        // External provider must cite an approved externalization entry.
        provDoc = readJson(provenancePath);
        provDoc.fallback_used = false;
        provDoc.provider_available = true;
        provDoc["externalization"] = "EXT-999";
        writeJson(provenancePath, provDoc);
        result = invoke(tempRepo, active, "Standard", "Scope");
        assertRule(result, "RESEARCH-007", "external provider without approved externalization");
        // -------------------------------------------------------------------
        // FB-002 regression mutations. Reset to pristine, then exercise each
        // repaired rule with its own negative mutation.
        // -------------------------------------------------------------------
        const resetRels = [
            "EXTERNALIZATION.json", "DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json", "DESIGN/CLAUDE-DESIGN/REVIEW.json",
            "CHANGE-REQUESTS.json", "RESEARCH/RESEARCH.md", "RESEARCH/PROVENANCE.json", "PROJECT.md",
        ];
        restore(active, resetRels);
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/OUTPUT/ui-direction.md"), uiDirection);
        // CR-002: network_transfer_occurred is a required JSON boolean.
        extDoc = readJson(extPath);
        delete extDoc.entries[0]["network_transfer_occurred"];
        writeJson(extPath, extDoc);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "EXT-001", "missing network_transfer_occurred is a structural defect");
        // CR-005: Human Owner chose policy-allowed Internal by default.
        extDoc = readJson(extPath);
        extDoc.entries[0] = {
            id: "EXT-001", purpose: extDoc.entries[0]["purpose"], provider: extDoc.entries[0]["provider"],
            provider_type: "web", outgoing_artifacts: extDoc.entries[0]["outgoing_artifacts"],
            classification: "Public", minimization_redaction: extDoc.entries[0]["minimization_redaction"],
            scan_result: "clean", human_review_required: false, reviewer: "", decision_ref: "",
            network_transfer_occurred: true, status: "approved", recorded_at: "2026-08-14T09:30:00Z",
        };
        writeJson(extPath, extDoc);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertNoRule(result, "EXT-002", "Public approved transfer proceeds under policy");
        extDoc = readJson(extPath);
        extDoc.entries[0]["classification"] = "Internal";
        writeJson(extPath, extDoc);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertNoRule(result, "EXT-002", "Internal approved transfer proceeds under the Human-selected default");
        // Policy remains load-bearing.
        const orchestrationPolicyPath = join(tempRepo, "pmo-config/orchestration-policy.json");
        const orchestrationPolicy = readJson(orchestrationPolicyPath);
        orchestrationPolicy.externalization["internal_default_human_review"] = true;
        writeJson(orchestrationPolicyPath, orchestrationPolicy);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "EXT-002", "Internal conservative policy requires Human review");
        cpSync(join(REPO_ROOT, "pmo-config/orchestration-policy.json"), orchestrationPolicyPath);
        // CR-015: nested sensitive path (.env at depth) is caught by the scan.
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/EXTERNALIZATION.json"), extPath);
        const envDir = join(active, "source");
        mkdirSync(envDir, { recursive: true });
        const envPath = join(envDir, ".env");
        writeFileSync(envPath, "TOKEN=not-a-real-secret-abcdef123456", "utf8");
        const envHash = sha256File(envPath);
        extDoc = readJson(extPath);
        extDoc.entries[0]["outgoing_artifacts"] = [{ path: "source/.env", sha256: envHash }];
        writeJson(extPath, extDoc);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "EXT-003", "nested sensitive path matches the policy patterns");
        rmSync(envPath, { force: true });
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/EXTERNALIZATION.json"), extPath);
        // CR-017: a repo-relative link that escapes the project is rejected.
        const outsideDir = mkdtempSync(join(tmpdir(), "fb002-outside-"));
        const outsideFile = join(outsideDir, "leaked.txt");
        writeFileSync(outsideFile, "outside content", "utf8");
        const linkPath = join(active, "escape-link");
        let linkCreated = false;
        try {
            symlinkSync(outsideDir, linkPath, platform() === "win32" ? "junction" : "dir");
            linkCreated = true;
        }
        catch {
            linkCreated = false;
        }
        if (linkCreated) {
            const leakedHash = sha256File(join(linkPath, "leaked.txt"));
            extDoc = readJson(extPath);
            extDoc.entries[0]["outgoing_artifacts"] = [{ path: "escape-link/leaked.txt", sha256: leakedHash }];
            writeJson(extPath, extDoc);
            result = invoke(tempRepo, active, "Standard", "Design");
            assertRule(result, "EXT-001", "externalization artifact escaping the boundary is rejected");
            // Same boundary escape through the design provider manifest input set.
            const projectMdHash = sha256File(join(active, "PROJECT.md"));
            manifestDoc = readJson(manifestPath);
            manifestDoc.inputs = [
                { kind: "project_summary", path: "PROJECT.md", sha256: projectMdHash },
                { kind: "raw_source", path: "escape-link/leaked.txt", sha256: leakedHash, governed_justification: "Containment test fixture." },
            ];
            writeJson(manifestPath, manifestDoc);
            result = invoke(tempRepo, active, "Standard", "Design");
            assertRule(result, "DPROV-003", "design provider input escaping the boundary is rejected");
            unlinkSync(linkPath);
        }
        rmSync(outsideDir, { recursive: true, force: true });
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/EXTERNALIZATION.json"), extPath);
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/INPUT-MANIFEST.json"), manifestPath);
        // CR-007: REVIEW.json is required at Handoff for a claude_design track.
        rmSync(reviewPath, { force: true });
        result = invoke(tempRepo, active, "Standard", "Handoff");
        assertRule(result, "DPROV-005", "missing provider review blocks Handoff");
        // CR-008: declared output inventory must match the OUTPUT/ file set.
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/REVIEW.json"), reviewPath);
        reviewDoc = readJson(reviewPath);
        reviewDoc["outputs"] = [{ path: "missing-file.md", sha256: "d".repeat(64) }];
        writeJson(reviewPath, reviewDoc);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "DPROV-005", "declared output that does not exist is rejected");
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/REVIEW.json"), reviewPath);
        writeFileSync(join(outputDir, "extra.md"), "undeclared", "utf8");
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "DPROV-005", "undeclared output file is rejected");
        rmSync(join(outputDir, "extra.md"), { force: true });
        // CR-001: preflight must speak for the current manifest.
        reviewDoc = readJson(reviewPath);
        reviewDoc["preflight"]["manifest_digest"] = "0".repeat(64);
        writeJson(reviewPath, reviewDoc);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "DPROV-005", "stale preflight manifest digest is rejected");
        // CR-009: routing is derived; open technical finding blocks acceptance.
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/REVIEW.json"), reviewPath);
        reviewDoc = readJson(reviewPath);
        reviewDoc["findings"] = [{
                id: "DP-002", lens: "technical", impact: "technical", routes_to_change_control: false,
                summary: "Test finding with derived routing", status: "open", owner: "Demo Tech Lead", decision_ref: "",
            }];
        writeJson(reviewPath, reviewDoc);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "DPROV-007", "self-asserted routing is ignored; open technical finding blocks acceptance");
        // CR-010: the externalization payload must cover the manifest inputs.
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/REVIEW.json"), reviewPath);
        extDoc = readJson(extPath);
        extDoc.entries[0]["outgoing_artifacts"] = [{ path: "PROJECT.md", sha256: "c8d3ccf7cae03bc612b4f1271f6cee130803bf9925f17e5cce192317e9d14b70" }];
        writeJson(extPath, extDoc);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "DPROV-004", "manifest payload not covered by the externalization entry");
        // CR-003: a forged MOM reference is not resolvable.
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/EXTERNALIZATION.json"), extPath);
        provDoc = readJson(provenancePath);
        provDoc.claims[0]["sources"] = [{ reference: "MOM-99999999", title: "forged", issuer: "forged", date: "2026-07-14", primary: true, verification: "verified" }];
        writeJson(provenancePath, provDoc);
        result = invoke(tempRepo, active, "Standard", "Scope");
        assertRule(result, "RESEARCH-003", "forged repo-local source reference is unresolvable");
        // CR-011: accepted Impact Assessment must resolve through a proposal.
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/RESEARCH/PROVENANCE.json"), provenancePath);
        writeFileSync(researchReport, readFileSync(researchReport, "utf8").replace("| RC-001 | Scope (REQ-003 receive) | receive is a first-class operation | accepted | CP-001 |", "| RC-001 | Scope (REQ-003 receive) | receive is a first-class operation | accepted | |"), "utf8");
        result = invoke(tempRepo, active, "Standard", "Scope");
        assertRule(result, "RESEARCH-004", "accepted impact without a governed proposal is rejected");
        // CR-012: a rejected proposal still needs a Human decision.
        writeFileSync(researchReport, readFileSync(researchReport, "utf8").replace("| CP-001 | Defer multi-warehouse stock; demo covers a single site | scope | yes | accepted | Demo PO | DEC-004 |", "| CP-001 | Defer multi-warehouse stock; demo covers a single site | scope | yes | rejected | Demo PO | |"), "utf8");
        result = invoke(tempRepo, active, "Standard", "Scope");
        assertRule(result, "RESEARCH-004", "rejected proposal without a Human decision is rejected");
        // CR-013 final: provenance metadata, provider agreement, and freshness.
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/RESEARCH/PROVENANCE.json"), provenancePath);
        provDoc = readJson(provenancePath);
        delete provDoc.claims[0]["sources"][0]["primary"];
        writeJson(provenancePath, provDoc);
        result = invoke(tempRepo, active, "Standard", "Scope");
        assertRule(result, "RESEARCH-003", "missing primary classification is rejected");
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/RESEARCH/PROVENANCE.json"), provenancePath);
        provDoc = readJson(provenancePath);
        provDoc.claims[0]["sources"][0]["verification"] = "invented";
        writeJson(provenancePath, provDoc);
        result = invoke(tempRepo, active, "Standard", "Scope");
        assertRule(result, "RESEARCH-003", "unknown source verification is rejected");
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/RESEARCH/PROVENANCE.json"), provenancePath);
        provDoc = readJson(provenancePath);
        provDoc.claims[0]["sources"][0]["date"] = "2026-06-30";
        writeJson(provenancePath, provDoc);
        result = invoke(tempRepo, active, "Standard", "Scope");
        assertRule(result, "RESEARCH-003", "source older than the minimum cutoff is stale");
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/RESEARCH/PROVENANCE.json"), provenancePath);
        provDoc = readJson(provenancePath);
        delete provDoc.claims[0]["sources"][0]["date"];
        writeJson(provenancePath, provDoc);
        result = invoke(tempRepo, active, "Standard", "Scope");
        assertRule(result, "RESEARCH-003", "cutoff freshness requires a source date");
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/RESEARCH/PROVENANCE.json"), provenancePath);
        provDoc = readJson(provenancePath);
        provDoc.provider_used = "web";
        writeJson(provenancePath, provDoc);
        result = invoke(tempRepo, active, "Standard", "Scope");
        assertRule(result, "RESEARCH-006", "provider used must match the concrete project declaration");
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/RESEARCH/PROVENANCE.json"), provenancePath);
        provDoc = readJson(provenancePath);
        delete provDoc["retrieved_at"];
        writeJson(provenancePath, provDoc);
        result = invoke(tempRepo, active, "Standard", "Scope");
        assertRule(result, "RESEARCH-006", "retrieved_at is required");
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/RESEARCH/PROVENANCE.json"), provenancePath);
        provDoc = readJson(provenancePath);
        provDoc.retrieved_at = "2026-08-14T09:00:00+07:00";
        writeJson(provenancePath, provDoc);
        result = invoke(tempRepo, active, "Standard", "Scope");
        assertRule(result, "RESEARCH-006", "retrieved_at must use deterministic UTC Z form");
        // `auto` may resolve to a concrete allowed provider.
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/RESEARCH/PROVENANCE.json"), provenancePath);
        const projPath = join(active, "PROJECT.md");
        writeFileSync(projPath, readFileSync(projPath, "utf8").replace(/^> Research provider: feyman\s*$/m, "> Research provider: auto"), "utf8");
        result = invoke(tempRepo, active, "Standard", "Scope");
        assertNoRule(result, "RESEARCH-006", "auto resolves to an allowed concrete provider");
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/PROJECT.md"), projPath);
        // -------------------------------------------------------------------
        // CR-018: canonical artifact hashing -- LF/CRLF and UTF-8 BOM stable for
        // text, byte-sensitive for binary, real content changes still invalidate.
        // -------------------------------------------------------------------
        const digestRels = [...resetRels, "DESIGN/BUILD-SPEC.md"];
        restore(active, digestRels);
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/OUTPUT/ui-direction.md"), uiDirection);
        // LF -> CRLF must not change a text artifact digest.
        const lfText = readFileSync(projPath, "utf8").replace(/\r\n/g, "\n");
        writeFileSync(projPath, lfText.replace(/\n/g, "\r\n"), "utf8");
        result = invoke(tempRepo, active, "Standard", "Design");
        assertClean(result, "LF to CRLF does not change provider digests");
        // A UTF-8 BOM must not change a text artifact digest either.
        const buildSpec = join(active, "DESIGN/BUILD-SPEC.md");
        const bsBytes = readFileSync(buildSpec);
        writeFileSync(buildSpec, Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), bsBytes]));
        result = invoke(tempRepo, active, "Standard", "Design");
        assertClean(result, "UTF-8 BOM does not change provider digests");
        // Binary artifacts hash by original bytes: one changed byte fails EXT-004.
        const assetDir = join(active, "assets");
        mkdirSync(assetDir, { recursive: true });
        const pngPath = join(assetDir, "logo.png");
        writeFileSync(pngPath, Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x01, 0x02]));
        const pngHash = sha256File(pngPath);
        extDoc = readJson(extPath);
        extDoc.entries[0]["outgoing_artifacts"].push({ path: "assets/logo.png", sha256: pngHash });
        writeJson(extPath, extDoc);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertClean(result, "binary artifact hashes by bytes");
        const pngBytes = readFileSync(pngPath);
        pngBytes[9] = 0x99;
        writeFileSync(pngPath, pngBytes);
        result = invoke(tempRepo, active, "Standard", "Design");
        assertRule(result, "EXT-004", "binary byte change invalidates the digest");
        // ---- CR-014/CR-021: generator E2E -- a real optional-track generation
        // must pass its own Draft gate.
        const genOut = join(tempRepo, "projects");
        mkdirSync(genOut, { recursive: true });
        newProject(tempRepo, "E2E-TRACKS", "Standard", "development_handoff", "guided", "standard", "feyman", "claude_design", "none", "normal feature", "PM", genOut, false, "internal", 14);
        const genProject = join(genOut, "E2E-TRACKS");
        assert.ok(existsSync(genProject), "optional-track generator produced a project directory");
        result = invoke(tempRepo, genProject, "Standard", "Draft");
        assertClean(result, "generated optional-track project passes Draft");
        // ---- CR-021: active-track Handoff and Release coverage.
        restore(active, digestRels);
        cpSync(join(REPO_ROOT, "examples/OPTIONAL-TRACKS/DESIGN/CLAUDE-DESIGN/OUTPUT/ui-direction.md"), uiDirection);
        rmSync(pngPath, { force: true });
        result = invoke(tempRepo, active, "Standard", "Handoff");
        assertClean(result, "active-track example passes Handoff");
        result = invoke(tempRepo, active, "Standard", "Release");
        const m46Fails = result.filter((r) => r.level === "FAIL" && /^(EXT|DPROV|RESEARCH)-/.test(r.rule_id));
        assert.equal(m46Fails.length, 0, `M4-M6 rules failed at Release: ${m46Fails.map((f) => f.rule_id).join(", ")}`);
    }
    finally {
        rmSync(workRoot, { recursive: true, force: true });
    }
});
