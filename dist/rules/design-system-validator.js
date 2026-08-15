// DESIGN-001: design system token agreement, ported from
// scripts/lib/design-system-validator.ps1.
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { addResult } from "../core/result-writer.js";
export function getDesignSystemDeclaredTokens(markdownText) {
    const tokens = [];
    if (!markdownText?.trim())
        return tokens;
    const lines = markdownText.split(/\r?\n/);
    let inTokenSection = false;
    let section = "";
    let tokenIndex = -1;
    let valueIndex = -1;
    for (const line of lines) {
        const headingMatch = /^\s*##\s+(.*)$/.exec(line);
        if (headingMatch) {
            const heading = headingMatch[1].trim();
            inTokenSection = /^Design Tokens/.test(heading);
            section = heading;
            tokenIndex = -1;
            valueIndex = -1;
            continue;
        }
        if (!inTokenSection)
            continue;
        if (!/^\s*\|/.test(line)) {
            if (!/\S/.test(line)) {
                tokenIndex = -1;
                valueIndex = -1;
            }
            continue;
        }
        let cells = line.split("|");
        if (cells.length < 3)
            continue;
        cells = cells.slice(1, cells.length - 1).map((c) => c.trim());
        if (tokenIndex < 0) {
            for (let i = 0; i < cells.length; i++) {
                if (cells[i] === "Token")
                    tokenIndex = i;
                if (cells[i] === "Value")
                    valueIndex = i;
            }
            continue;
        }
        if (valueIndex < 0)
            continue;
        if (/^-{2,}:?$/.test(cells[tokenIndex] ?? "") || /^:?-{2,}:?$/.test(cells[tokenIndex] ?? ""))
            continue;
        if (cells.length <= tokenIndex || cells.length <= valueIndex)
            continue;
        const name = cells[tokenIndex];
        const value = cells[valueIndex];
        if (!name?.trim())
            continue;
        if (!/^[A-Za-z][A-Za-z0-9-]*$/.test(name))
            continue;
        tokens.push({ name, value, section });
    }
    return tokens;
}
export function getDesignSystemSheetTokens(htmlText) {
    const tokens = [];
    if (!htmlText?.trim())
        return tokens;
    const rootMatch = /:root\s*\{([\s\S]*?)\}/.exec(htmlText);
    if (!rootMatch)
        return tokens;
    let body = rootMatch[1];
    body = body.replace(/\/\*[\s\S]*?\*\//g, " ");
    for (const declaration of body.split(";")) {
        const m = /^\s*--([A-Za-z][A-Za-z0-9-]*)\s*:\s*(.+?)\s*$/.exec(declaration);
        if (!m)
            continue;
        tokens.push({ name: m[1], value: m[2] });
    }
    return tokens;
}
export function resolveDesignSystemVarReferences(sheetTokens) {
    const resolved = {};
    for (const token of sheetTokens)
        resolved[token.name] = token.value;
    for (let pass = 0; pass < 3; pass++) {
        let changed = false;
        for (const name of Object.keys(resolved)) {
            const value = resolved[name];
            const expanded = value.replace(/var\(\s*--([A-Za-z][A-Za-z0-9-]*)\s*\)/g, (_m, referenced) => {
                return resolved[referenced] !== undefined ? resolved[referenced] : `var(--${referenced})`;
            });
            if (expanded !== value) {
                resolved[name] = expanded;
                changed = true;
            }
        }
        if (!changed)
            break;
    }
    return resolved;
}
function getNormalizedTokenValue(value) {
    let normalized = (value ?? "").replace(/\s+/g, " ").trim();
    normalized = normalized.replace(/#([0-9A-Fa-f]{3,8})\b/g, (_m, hex) => "#" + hex.toUpperCase());
    return normalized;
}
export function testDesignSystemTokens(acc, catalog, project, gate) {
    const markdownRelative = "DESIGN/DESIGN-SYSTEM.md";
    const htmlRelative = "DESIGN/DESIGN-SYSTEM.html";
    const markdownPath = join(project, markdownRelative);
    const htmlPath = join(project, htmlRelative);
    if (!existsSync(markdownPath))
        return;
    if (!existsSync(htmlPath))
        return;
    const markdownText = readFileSync(markdownPath, "utf8");
    const htmlText = readFileSync(htmlPath, "utf8");
    const declared = getDesignSystemDeclaredTokens(markdownText);
    if (declared.length === 0)
        return;
    const sheetTokens = getDesignSystemSheetTokens(htmlText);
    const resolved = resolveDesignSystemVarReferences(sheetTokens);
    const problems = [];
    for (const token of declared) {
        const match = Object.keys(resolved).find((k) => k === token.name);
        if (!match) {
            problems.push(`${token.name} is declared in ${markdownRelative} but no --${token.name} exists in the sheet`);
            continue;
        }
        const sheetValue = getNormalizedTokenValue(resolved[match]);
        const declaredValue = getNormalizedTokenValue(token.value);
        if (sheetValue !== declaredValue) {
            problems.push(`${token.name} is '${declaredValue}' in ${markdownRelative} but '${sheetValue}' in the sheet`);
        }
    }
    if (problems.length === 0) {
        addResult(acc, catalog, "PASS", `Design system tokens agree between ${markdownRelative} and the sheet (${declared.length} checked)`, { ruleId: "DESIGN-001" });
        return;
    }
    const level = gate === "Draft" ? "INFO" : gate === "Scope" ? "WARN" : "FAIL";
    addResult(acc, catalog, level, `Design system token drift: ${problems.slice(0, 6).join("; ")}`, { ruleId: "DESIGN-001", blocking: true, artifact: htmlRelative });
}
