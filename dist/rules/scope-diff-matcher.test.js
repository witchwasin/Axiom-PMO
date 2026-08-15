// Unit tests for the SCOPE-DIFF matcher, encoding the behaviors asserted by
// tests/helpers/scope-diff-tests.ps1 (case sensitivity, exclude precedence,
// rename old/new side verdicts, glob grammar).
import { test } from "node:test";
import assert from "node:assert/strict";
import { convertToScopeGlobRegex, resolveScopeVerdict, testScopeGlobSyntax, } from "./scope-diff-matcher.js";
function verdict(path, include, exclude = []) {
    return resolveScopeVerdict(path, include.map((p) => new RegExp(convertToScopeGlobRegex(p))), exclude.map((p) => new RegExp(convertToScopeGlobRegex(p))), []).verdict;
}
test("in-scope path matches its include pattern", () => {
    assert.equal(verdict("src/payments/foo.ts", ["src/payments/**"]), "in_scope");
});
test("case sensitivity: wrong-case path is out_of_scope", () => {
    assert.equal(verdict("SRC/PAYMENTS/bar.ts", ["src/payments/**"]), "out_of_scope");
});
test("exclude wins over include", () => {
    assert.equal(verdict("src/payments/generated/client.ts", ["src/payments/**"], ["src/payments/generated/**"]), "excluded");
});
test("globstar matches zero or more path segments", () => {
    assert.equal(verdict("src/a.ts", ["src/**"]), "in_scope");
    assert.equal(verdict("src/deep/nested/a.ts", ["src/**"]), "in_scope");
});
test("single star does not cross a path separator", () => {
    assert.equal(verdict("src/deep/a.ts", ["src/*"]), "out_of_scope");
});
test("question mark matches exactly one non-separator char", () => {
    assert.equal(verdict("src/a.ts", ["src/?.ts"]), "in_scope");
    assert.equal(verdict("src/ab.ts", ["src/?.ts"]), "out_of_scope");
});
test("bare ** matches anything", () => {
    assert.equal(verdict("anything/at/all", ["**"]), "in_scope");
});
test("syntax gate rejects leading slash, backslash, .. segment", () => {
    assert.match(testScopeGlobSyntax("/src/**") ?? "", /start with/);
    assert.match(testScopeGlobSyntax("src\\foo") ?? "", /backslash/);
    assert.match(testScopeGlobSyntax("src/../foo") ?? "", /\.\./);
    assert.equal(testScopeGlobSyntax("src/**"), null);
});
