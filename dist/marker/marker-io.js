// Marker-block filesystem I/O layer, ported from scripts/lib/marker-block.ps1.
// Stateful (reads/writes user files) — verified by the §8.6 fresh-tree
// methodology, not by golden comparison. Pure transforms stay in marker-block.ts.
import { readFileSync, writeFileSync, existsSync, mkdirSync, renameSync, copyFileSync, readdirSync, statSync } from "node:fs";
import { join, dirname, basename } from "node:path";
export function readTextFileState(path) {
    if (!existsSync(path)) {
        return { exists: false, supported: true, encoding: "utf-8", text: "", hasBom: false, newline: "\n" };
    }
    const bytes = readFileSync(path);
    // BOM sniffing first (UTF-32 before UTF-16: UTF-32LE BOM starts with UTF-16LE BOM).
    if (bytes.length >= 4) {
        if (bytes[0] === 0xff && bytes[1] === 0xfe && bytes[2] === 0 && bytes[3] === 0) {
            return { exists: true, supported: false, encoding: "UTF-32LE", text: "", hasBom: true, newline: "\n" };
        }
        if (bytes[0] === 0 && bytes[1] === 0 && bytes[2] === 0xfe && bytes[3] === 0xff) {
            return { exists: true, supported: false, encoding: "UTF-32BE", text: "", hasBom: true, newline: "\n" };
        }
    }
    if (bytes.length >= 2) {
        if (bytes[0] === 0xff && bytes[1] === 0xfe) {
            return { exists: true, supported: false, encoding: "UTF-16LE", text: "", hasBom: true, newline: "\n" };
        }
        if (bytes[0] === 0xfe && bytes[1] === 0xff) {
            return { exists: true, supported: false, encoding: "UTF-16BE", text: "", hasBom: true, newline: "\n" };
        }
    }
    const hasBom = bytes.length >= 3 && bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf;
    let text;
    try {
        const offset = hasBom ? 3 : 0;
        text = new TextDecoder("utf-8", { fatal: true }).decode(bytes.subarray(offset));
    }
    catch {
        return { exists: true, supported: false, encoding: "not valid UTF-8", text: "", hasBom, newline: "\n" };
    }
    // Dominant newline, not first.
    const crlfCount = (text.match(/\r\n/g) ?? []).length;
    const lfCount = (text.match(/(?<!\r)\n/g) ?? []).length;
    const newline = crlfCount > lfCount ? "\r\n" : "\n";
    return {
        exists: true,
        supported: true,
        encoding: hasBom ? "utf-8 with BOM" : "utf-8",
        text,
        hasBom,
        newline,
    };
}
export function writeTextFileAtomic(path, text, hasBom = false) {
    const directory = dirname(path) || ".";
    if (!existsSync(directory))
        mkdirSync(directory, { recursive: true });
    const temp = join(directory, `.axiom-write-${Math.random().toString(36).slice(2, 12)}.tmp`);
    const bytes = new TextEncoder().encode(text);
    const withBom = hasBom ? Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), bytes]) : Buffer.from(bytes);
    try {
        writeFileSync(temp, withBom);
        renameSync(temp, path);
    }
    catch (e) {
        if (existsSync(temp)) {
            try {
                import("node:fs").then(({ unlinkSync }) => unlinkSync(temp));
            }
            catch { }
        }
        throw e;
    }
}
export function newAxiomBackup(path) {
    const stamp = formatInvariantStamp(new Date());
    let candidate = `${path}.axiom-backup-${stamp}`;
    let counter = 1;
    while (existsSync(candidate)) {
        candidate = `${path}.axiom-backup-${stamp}-${counter}`;
        counter++;
    }
    try {
        copyFileSync(path, candidate);
    }
    catch (e) {
        throw new Error(`could not write a backup next to ${basename(path)}: ${e.message}`);
    }
    return candidate;
}
function formatInvariantStamp(d) {
    // Gregorian, invariant culture — NOT locale-aware (the PS uses invariant
    // culture because th-TH Buddhist year would break cross-machine sort).
    const p = (n, w = 2) => String(n).padStart(w, "0");
    return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}
export function getAxiomBackups(path) {
    const directory = dirname(path) || ".";
    const leaf = basename(path);
    if (!existsSync(directory))
        return [];
    return readdirSync(directory)
        .filter((n) => n.startsWith(`${leaf}.axiom-backup-`) && statSync(join(directory, n)).isFile())
        .sort((a, b) => (a < b ? 1 : -1)); // newest first (descending name sort)
}
