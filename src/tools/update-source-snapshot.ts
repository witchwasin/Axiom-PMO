// `update-source-snapshot`, ported from scripts/update-source-snapshot.ps1.
// Regenerates PROJECT.md's Source Snapshot table from source/** files.

import { readFileSync, writeFileSync, existsSync, readdirSync, statSync, copyFileSync } from "node:fs";
import { join, resolve, basename, extname } from "node:path";
import { createHash } from "node:crypto";

export interface SnapshotResult {
  output: string;
  exitCode: number;
}

function sha256(buf: Buffer): string {
  return createHash("sha256").update(buf).digest("hex").toLowerCase();
}

function deriveSourceId(name: string): string {
  let m = /(MOM|REQ|TR)[-_]?(\d{8}|V\d+)/.exec(name);
  if (m) return `${m[1]}-${m[2]}`;
  m = /(\d{8}).*(MOM|REQ|TR)/.exec(name);
  if (m) return `${m[2]}-${m[1]}`;
  return name;
}

export function updateSourceSnapshot(projectPath: string, dryRun: boolean): SnapshotResult {
  const project = resolve(projectPath);
  const projectFile = join(project, "PROJECT.md");
  const sourceRoot = join(project, "source");

  if (!existsSync(projectFile)) return { output: `No PROJECT.md found: ${projectFile}\n`, exitCode: 1 };
  if (!existsSync(sourceRoot)) return { output: `No source directory found: ${sourceRoot}\n`, exitCode: 1 };

  const syncedAt = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
  const rows: Array<{ sourceId: string; version: string; sha: string; syncedAt: string; relative: string }> = [];

  const walk = (dir: string) => {
    for (const entry of readdirSync(dir)) {
      const full = join(dir, entry);
      if (statSync(full).isDirectory()) walk(full);
      else if (statSync(full).isFile()) {
        const relative = full.substring(project.length).replace(/^[/\\]/, "").replace(/\\/g, "/");
        const name = basename(entry, extname(entry));
        rows.push({
          sourceId: deriveSourceId(name),
          version: "v1",
          sha: sha256(readFileSync(full)),
          syncedAt,
          relative,
        });
      }
    }
  };
  walk(sourceRoot);

  const sorted = rows.sort((a, b) => a.sourceId.localeCompare(b.sourceId) || a.relative.localeCompare(b.relative));
  const table = ["| Source ID | Version / Date | SHA256 | Last Synced At |", "|---|---|---|---|",
    ...sorted.map((r) => `| ${r.sourceId} | ${r.version} | ${r.sha} | ${r.syncedAt} |`)];
  const replacement = "## Source Snapshot\r\n\r\n" + table.join("\r\n") + "\r\n";

  const text = readFileSync(projectFile, "utf8");
  if (!/## Source Snapshot[\s\S]*?(?=\r?\n## )/.test(text)) {
    return { output: "PROJECT.md has no Source Snapshot section to update.\n", exitCode: 1 };
  }
  const updated = text.replace(/## Source Snapshot[\s\S]*?(?=\r?\n## )/, replacement);

  if (dryRun) return { output: replacement + "\n", exitCode: 0 };

  copyFileSync(projectFile, projectFile + ".bak");
  writeFileSync(projectFile, updated, "utf8");
  return { output: `Updated Source Snapshot in ${projectFile}\nBackup written to ${projectFile}.bak\n`, exitCode: 0 };
}
