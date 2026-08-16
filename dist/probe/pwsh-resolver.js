// Resolves the PowerShell host for probe reference runs, mirroring
// scripts/lib/pwsh-host.ps1's resolution order: AXIOM_PWSH override first, then
// `pwsh` on PATH. No hardcoded local path — a dev machine without pwsh on PATH
// sets AXIOM_PWSH, exactly like the PowerShell reference does.
import { spawnSync } from "node:child_process";
export function resolvePwsh() {
    const override = process.env.AXIOM_PWSH;
    if (override)
        return override;
    const probe = spawnSync("pwsh", ["--version"], { encoding: "utf8" });
    if (probe.status === 0)
        return "pwsh";
    throw new Error("pwsh not found on PATH and AXIOM_PWSH not set. Set AXIOM_PWSH to the full path of a PowerShell executable.");
}
