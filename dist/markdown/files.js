// Shared Markdown discovery + local-link helpers, ported from
// scripts/lib/markdown-files.ps1.
import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, resolve, dirname } from "node:path";
export function getMarkdownFiles(rootPath) {
    if (!existsSync(rootPath) || !statSync(rootPath).isDirectory())
        return [];
    const results = [];
    const walk = (dir) => {
        for (const entry of readdirSync(dir)) {
            const full = join(dir, entry);
            let st;
            try {
                st = statSync(full);
            }
            catch {
                continue;
            }
            if (st.isDirectory())
                walk(full);
            else if (st.isFile() && entry.toLowerCase().endsWith(".md"))
                results.push(full);
        }
    };
    walk(rootPath);
    return results;
}
export function readMarkdownText(path) {
    try {
        return readFileSync(path, "utf8");
    }
    catch {
        return "";
    }
}
export function testMarkdownLocalLinkPath(basePath, target) {
    try {
        let decodedTarget;
        try {
            decodedTarget = decodeURIComponent(target);
        }
        catch {
            decodedTarget = target;
        }
        if (/[\x00-\x1F<>:"|?*]/.test(decodedTarget)) {
            return { validPath: false, exists: false, resolvedPath: null };
        }
        const resolved = resolve(basePath, decodedTarget);
        const exists = existsSync(resolved);
        return { validPath: true, exists, resolvedPath: resolved };
    }
    catch {
        return { validPath: false, exists: false, resolvedPath: null };
    }
}
// Re-export dirname for callers that need to compute a link base.
export { dirname };
