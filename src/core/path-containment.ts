// Physical path containment (CR-017), ported from scripts/lib/path-containment.ps1.
// Resolves the FINAL physical target of a path by walking every component (so a
// symlinked directory is followed too), answering whether the real file lives
// inside the project root.

import { existsSync, lstatSync, realpathSync } from "node:fs";
import { resolve, sep, isAbsolute, dirname, basename } from "node:path";

function getPhysicalTargetPath(path: string): string | null {
  // realpathSync resolves all symlinks in every component (the "walk every
  // component" behavior). It throws on a broken link; we treat that as null.
  try {
    return realpathSync(path);
  } catch {
    // Broken link or missing final component: return null (broken link) —
    // callers treat null as "escape / cannot resolve".
    return null;
  }
}

export function testPhysicalContainment(path: string, root: string): boolean {
  let physicalRoot: string | null;
  try {
    physicalRoot = realpathSync(root);
  } catch {
    physicalRoot = resolve(root);
  }
  const rootNorm = physicalRoot.replace(/[/\\]+$/, "");
  const target = getPhysicalTargetPath(path);
  if (target === null) return false;
  if (target.toLowerCase() === rootNorm.toLowerCase()) return true;
  return target.toLowerCase().startsWith((rootNorm + sep).toLowerCase());
}

// Finds a reparse point ANYWHERE in `path`'s own ancestry -- not just whether
// `path` itself is a symlink/junction, but whether a directory somewhere
// above it is, which redirects the whole subtree it contains. Comparing
// physical-vs-lexical directly (realpathSync(path) !== resolve(path)) is
// tempting but wrong: it false-positives on ordinary OS-level prefix aliases
// that have nothing to do with an escape (e.g. /tmp -> /private/tmp on macOS,
// or a mounted-volume alias) -- exactly the paths this project's own test
// suite uses for every fixture. Those aliases only ever rewrite a LEADING
// prefix, identically for every path under them; a planted symlink/junction
// instead diverts one INTERIOR component to somewhere unrelated. So: compare
// path components from the tail (leaf) backward. If they match all the way
// until one side runs out, the only difference is a prefix alias -- safe. The
// first point where a component actually differs is a real redirect.
export function findAncestorReparsePoint(path: string): string | null {
  const lexical = resolve(path);
  let physical: string;
  try {
    physical = realpathSync(path);
  } catch {
    return null; // doesn't exist yet -- nothing to walk
  }
  const lexParts = lexical.split(sep).filter(Boolean);
  const physParts = physical.split(sep).filter(Boolean);
  let i = lexParts.length - 1;
  let j = physParts.length - 1;
  let matched = 0;
  while (i >= 0 && j >= 0) {
    const lexPart = lexParts[i] as string;
    const physPart = physParts[j] as string;
    if (lexPart.toLowerCase() !== physPart.toLowerCase()) break;
    matched++;
    i--;
    j--;
  }
  if (i < 0 || j < 0) return null; // one side exhausted first: prefix alias only, safe
  // Trim `matched` trailing components off the lexical path's own STRING (via
  // repeated dirname) rather than rejoining the split parts, so a Windows
  // drive root (C:\) or UNC prefix reconstructs correctly instead of being
  // silently dropped by the split/filter above.
  let ancestor = lexical;
  for (let k = 0; k < matched; k++) ancestor = dirname(ancestor);
  return ancestor;
}
