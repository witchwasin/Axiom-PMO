// F8 / CR-018: the canonical digest contract, verified against the PowerShell
// implementation. These digests are persisted in shipped artifacts, so a
// divergence makes existing evidence stale.
import { test } from "node:test";
import assert from "node:assert/strict";
import { getArtifactSha256, testCanonicalTextFile } from "./artifact-hash.js";
test("canonical text hash matches PowerShell on a no-BOM markdown file", () => {
    assert.equal(getArtifactSha256("examples/LITE-BUGFIX/PROJECT.md"), "7de3ccdb1176753c6abafd9196af5c2c32fd891ef1fd4a291e00789ffd9adedd");
});
test("canonical text hash matches PowerShell on a BOM JSON file", () => {
    // Expected digest re-verified directly against Get-ArtifactSha256 (the PS
    // reference) after the Phase 8 version bump changed this fixture's content
    // (2.1.0 -> 2.2.0) -- not just updated to whatever Node happened to compute.
    assert.equal(getArtifactSha256("pmo-config/policy.json"), "a72ec270fab19740a05cf9579b8e503f3db05905c6aeb6b1b299fe3abefe7a17");
});
test("binary hash matches PowerShell on an svg (unknown extension -> byte hash)", () => {
    assert.equal(getArtifactSha256("examples/DESIGN-SYSTEM-DEMO/DESIGN/BRAND/app-icon.svg"), "6156b4f04821de1c0f4b43ebf593db3bf1149b97265fb215d66bb6b41857b477");
});
test("extension allowlist classification", () => {
    assert.equal(testCanonicalTextFile("a.md"), true);
    assert.equal(testCanonicalTextFile("a.MD"), true);
    assert.equal(testCanonicalTextFile("a.png"), false);
    assert.equal(testCanonicalTextFile("a.json"), true);
});
