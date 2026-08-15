// Unit tests for marker-block pure transforms, pinning the canonical body digest
// (frozen literal) and the ownership/round-trip semantics. The digest is the
// load-bearing contract: editing the body without recording it would orphan
// every installed block.
import { test } from "node:test";
import assert from "node:assert/strict";
import { getAxiomCanonicalBody, getAxiomBlockDigest, findAxiomBlock, testAxiomBlockOwnership, newAxiomBlockText, setAxiomBlock, removeAxiomBlock, } from "./marker-block.js";
const body = getAxiomCanonicalBody("1");
test("canonical body digest matches the frozen v1 literal", () => {
    assert.equal(getAxiomBlockDigest(body), "b3af36639b1077269108f6719c53630ecdf6c3c517f410589a599686194c626b");
});
test("canonical body is recognized as owned", () => {
    assert.equal(testAxiomBlockOwnership({ status: "present", content: body, digest: getAxiomBlockDigest(body) }), "owned");
});
test("install then uninstall returns original bytes", () => {
    const installed = setAxiomBlock("some user content\n", body).text;
    const removed = removeAxiomBlock(installed).text;
    assert.equal(removed, "some user content\n");
});
test("edited block (not owned, no force) blocks replace", () => {
    const installed = setAxiomBlock("# rules\n", body).text;
    const edited = installed.replace("You may not approve", "You CAN approve");
    assert.equal(testAxiomBlockOwnership(findAxiomBlock(edited)), "edited");
    assert.equal(setAxiomBlock(edited, body).action, "blocked");
    assert.equal(setAxiomBlock(edited, body, "\n", true).action, "replaced");
});
test("foreign block (matching digest, non-canonical body) blocks without force", () => {
    const foreign = `<!-- AXIOM-PMO:BEGIN sha256=${getAxiomBlockDigest("not canonical")} -->\nnot canonical\n<!-- AXIOM-PMO:END -->`;
    assert.equal(testAxiomBlockOwnership(findAxiomBlock(foreign)), "foreign");
    assert.equal(removeAxiomBlock(foreign).action, "blocked");
});
test("unknown block (no digest) blocks without force", () => {
    const unknown = "<!-- AXIOM-PMO:BEGIN -->\nsomething else\n<!-- AXIOM-PMO:END -->";
    assert.equal(testAxiomBlockOwnership(findAxiomBlock(unknown)), "unknown");
});
test("malformed marker (two BEGINs) is refused", () => {
    const malformed = "<!-- AXIOM-PMO:BEGIN -->\n<!-- AXIOM-PMO:BEGIN -->\n<!-- AXIOM-PMO:END -->";
    assert.equal(findAxiomBlock(malformed).status, "malformed");
    assert.equal(setAxiomBlock(malformed, body).action, "blocked");
});
test("absent is not a conflict", () => {
    assert.equal(findAxiomBlock("no markers").status, "absent");
    assert.equal(setAxiomBlock("no markers", body).action, "inserted");
});
