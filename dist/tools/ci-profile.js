// ci-profile classifier, ported from scripts/ci-profile.ps1. Risk-based CI
// profile selection: fast | targeted | full, from a set of changed paths.
const HOST_CATALOG = {
    "windows-ps51": { name: "windows-ps51", runsOn: "windows-2025", shell: "powershell", exe: "powershell.exe" },
    "windows-ps7": { name: "windows-ps7", runsOn: "windows-2025", shell: "pwsh", exe: "pwsh" },
    linux: { name: "linux", runsOn: "ubuntu-24.04", shell: "pwsh", exe: "pwsh" },
    macos: { name: "macos", runsOn: "macos-15", shell: "pwsh", exe: "pwsh" },
};
const ALL_HOSTS = ["windows-ps51", "windows-ps7", "linux", "macos"];
function normalizePath(path) {
    let p = path.trim();
    if (!p)
        return null;
    p = p.replace(/\\/g, "/");
    p = p.replace(/^\.\//, "");
    return p.replace(/\/+$/, "");
}
function addUnique(list, value) {
    if (!list.includes(value))
        list.push(value);
}
export function resolveCiProfile(paths) {
    let level = 0;
    const suites = [];
    const hosts = [];
    const reasons = [];
    for (const raw of paths) {
        const p = normalizePath(raw);
        if (!p)
            continue;
        if (p.startsWith(".github/workflows/") || p === "action.yml" ||
            p.startsWith("scripts/lib/") ||
            p === "scripts/run-all-checks.ps1" || p === "scripts/validate-project.ps1" ||
            p === "scripts/ci-profile.ps1" || p === "scripts/run-ci-suite.ps1" ||
            p.startsWith("src/") || p.startsWith("dist/") ||
            p === "package.json" || p === "package-lock.json" || p.startsWith("tsconfig")) {
            if (level < 2)
                level = 2;
            addUnique(reasons, `${p} -> high-risk (workflow / shared-lib / runtime / CI control plane / Node interpreter)`);
            continue;
        }
        if (p.startsWith("cli/") || p === "tests/helpers/cli-tests.mjs" || p === "tests/helpers/github-action-tests.mjs") {
            if (level < 1)
                level = 1;
            addUnique(suites, "cli");
            addUnique(hosts, "linux");
            addUnique(reasons, `${p} -> cli@linux`);
            continue;
        }
        if (p.startsWith("pmo-config/") || p.startsWith("templates/")) {
            if (level < 1)
                level = 1;
            addUnique(suites, "config-mutation");
            addUnique(hosts, "windows-ps51");
            addUnique(hosts, "windows-ps7");
            addUnique(reasons, `${p} -> config/template@windows`);
            continue;
        }
        if (p.startsWith("scripts/")) {
            if (level < 1)
                level = 1;
            addUnique(suites, "doctor");
            addUnique(hosts, "windows-ps51");
            addUnique(hosts, "windows-ps7");
            addUnique(reasons, `${p} -> scripts@windows`);
            continue;
        }
        if (p.startsWith("tests/")) {
            if (level < 1)
                level = 1;
            addUnique(suites, "validation-fixtures");
            addUnique(hosts, "windows-ps51");
            addUnique(hosts, "windows-ps7");
            addUnique(reasons, `${p} -> tests@windows`);
            continue;
        }
        if (p.startsWith("examples/") || p.startsWith("demo/")) {
            if (level < 1)
                level = 1;
            addUnique(suites, "validation-fixtures");
            addUnique(hosts, "linux");
            addUnique(reasons, `${p} -> examples/demo@linux`);
            continue;
        }
        if (p.startsWith(".claude/") || p.startsWith("skills/") || p.startsWith("hooks/")) {
            if (level < 1)
                level = 1;
            addUnique(suites, "plugin-drift");
            addUnique(hosts, "linux");
            addUnique(reasons, `${p} -> skills/hooks@linux`);
            continue;
        }
        if (p.startsWith("docs/") || (!p.includes("/") && /\.md$/i.test(p))) {
            addUnique(reasons, `${p} -> docs/report only (fast)`);
            continue;
        }
        if (level < 1)
            level = 1;
        addUnique(hosts, "linux");
        addUnique(reasons, `${p} -> unclassified, targeted@linux (one level up)`);
    }
    const profile = level === 2 ? "full" : level === 1 ? "targeted" : "fast";
    let hostList;
    let suiteList;
    if (profile === "full") {
        hostList = ALL_HOSTS;
        suiteList = [];
    }
    else if (profile === "targeted") {
        hostList = [...new Set(hosts)];
        suiteList = [...new Set(suites)];
    }
    else {
        hostList = ["linux"];
        suiteList = [];
    }
    const reason = reasons.length === 0 ? "no changed paths (default fast)" : [...new Set(reasons)].join("; ");
    return { profile, suite: suiteList.join(","), hosts: hostList.join(","), reason };
}
// Ported from Resolve-DispatchProfile: the workflow_dispatch path, where the
// caller states the profile explicitly instead of it being classified from
// changed paths.
export function resolveDispatchProfile(profile, targetHost, suite) {
    let hostList = ["linux"];
    if (profile === "full") {
        hostList = ALL_HOSTS;
    }
    else if (profile === "targeted") {
        if (targetHost && targetHost !== "all") {
            if (!(targetHost in HOST_CATALOG)) {
                throw new Error(`Unknown host '${targetHost}'. Expected one of: ${ALL_HOSTS.join(", ")}, or 'all'.`);
            }
            hostList = [targetHost];
        }
        else {
            hostList = ALL_HOSTS;
        }
    }
    let reason = `workflow_dispatch profile=${profile}`;
    if (profile === "targeted") {
        const h = targetHost || "all";
        const s = suite || "(default)";
        reason += ` host=${h} suite=${s}`;
    }
    return { profile, suite, hosts: hostList.join(","), reason };
}
// Ported from Get-CiMatrixJson: built by hand rather than JSON.stringify so a
// single-host selection stays a real array in the GITHUB_OUTPUT line (the PS
// original's own comment: ConvertTo-Json collapses a one-element array to an
// object, which would break `matrix.include` on the single-host targeted case
// -- JSON.stringify(arr) does not have that failure mode, but the shape is
// kept identical to the reference regardless).
export function getCiMatrixJson(hostList) {
    const parts = hostList.map((h) => {
        const c = HOST_CATALOG[h];
        return `{"name":"${c.name}","runsOn":"${c.runsOn}","shell":"${c.shell}","exe":"${c.exe}"}`;
    });
    return `[${parts.join(",")}]`;
}
