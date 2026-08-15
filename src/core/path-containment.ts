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
