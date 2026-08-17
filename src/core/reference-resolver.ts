// Typed reference resolver, ported from scripts/lib/reference-resolver.ps1.

import { existsSync, statSync } from "node:fs";
import { resolve, join, sep } from "node:path";

export interface ReferenceResult {
  value: string;
  type: string | null;
  resolved: boolean;
  externallyUnverified: boolean;
  pathEscaped: boolean;
}

export interface ReferenceTypesConfig {
  reference_types: Record<string, string>; // name -> regex
  externally_unverified_types: string[];
}

function getReferenceType(value: string, config: ReferenceTypesConfig): string | null {
  if (!value) return null;
  const trimmed = value.trim();
  for (const [name, pattern] of Object.entries(config.reference_types)) {
    if (new RegExp(pattern).test(trimmed)) return name;
  }
  return null;
}

export function resolveReference(
  value: string,
  config: ReferenceTypesConfig,
  projectRoot: string,
  decisionIds: string[] | null = null,
  requirementIds: string[] | null = null,
  deliveryIds: string[] | null = null,
  testIds: string[] | null = null,
  releaseId: string | null = null,
): ReferenceResult {
  const result: ReferenceResult = {
    value,
    type: null,
    resolved: false,
    externallyUnverified: false,
    pathEscaped: false,
  };

  const trimmed = String(value).trim();
  if (trimmed.length === 0) return result;

  const type = getReferenceType(trimmed, config);
  result.type = type;
  if (!type) return result;

  const externalTypes = config.externally_unverified_types;
  if (externalTypes.includes(type)) {
    result.externallyUnverified = true;
    result.resolved = true;
    return result;
  }

  switch (type) {
    case "decision":
      result.resolved = decisionIds === null ? true : decisionIds.includes(trimmed);
      break;
    case "requirement":
      result.resolved = requirementIds === null ? true : requirementIds.includes(trimmed);
      break;
    case "delivery":
      result.resolved = deliveryIds === null ? true : deliveryIds.includes(trimmed);
      break;
    case "test":
      result.resolved = testIds === null ? true : testIds.includes(trimmed);
      break;
    case "release":
      result.resolved = releaseId === null ? true : trimmed === releaseId;
      break;
    case "file": {
      const filePath = trimmed.substring(5);
      if (/^[/\\]/.test(filePath) || /^[A-Za-z]:[\\/]?/.test(filePath)) {
        result.pathEscaped = true;
      } else {
        try {
          const rootFull = resolve(projectRoot);
          const resolvedFull = resolve(join(projectRoot, filePath));
          if (resolvedFull !== rootFull && !resolvedFull.startsWith(rootFull + sep)) {
            result.pathEscaped = true;
          } else {
            result.resolved = existsSync(resolvedFull) && statSync(resolvedFull).isFile();
          }
        } catch {
          // unnormalizable path: leave unresolved
        }
      }
      break;
    }
    default:
      result.resolved = false;
  }

  return result;
}
