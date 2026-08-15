// Typed reference resolver, ported from scripts/lib/reference-resolver.ps1.
import { existsSync, statSync } from "node:fs";
import { resolve, join } from "node:path";
function getReferenceType(value, config) {
    if (!value)
        return null;
    const trimmed = value.trim();
    for (const [name, pattern] of Object.entries(config.reference_types)) {
        if (new RegExp(pattern).test(trimmed))
            return name;
    }
    return null;
}
export function resolveReference(value, config, projectRoot, decisionIds = null, requirementIds = null, deliveryIds = null, testIds = null, releaseId = null) {
    const result = {
        value,
        type: null,
        resolved: false,
        externallyUnverified: false,
        pathEscaped: false,
    };
    const trimmed = String(value).trim();
    if (trimmed.length === 0)
        return result;
    const type = getReferenceType(trimmed, config);
    result.type = type;
    if (!type)
        return result;
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
            }
            else {
                try {
                    const rootFull = resolve(projectRoot);
                    const resolvedFull = resolve(join(projectRoot, filePath));
                    if (resolvedFull !== rootFull && !resolvedFull.startsWith(rootFull + "/")) {
                        result.pathEscaped = true;
                    }
                    else {
                        result.resolved = existsSync(resolvedFull) && statSync(resolvedFull).isFile();
                    }
                }
                catch {
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
