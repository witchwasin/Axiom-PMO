// Removes the committed dist/ bundle before a clean rebuild, so stale compiled
// output cannot silently survive a `tsc` run. Called by `npm run clean`.
import { rmSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
rmSync(resolve(repoRoot, "dist"), { recursive: true, force: true });
