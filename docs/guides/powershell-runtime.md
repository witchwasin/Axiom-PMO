# PowerShell Runtime Setup

Axiom-PMO's validators run on PowerShell. Use PowerShell 7 (`pwsh`) for the
portable experience on macOS, Linux, and Windows. Windows PowerShell 5.1
remains compatibility coverage, not the preferred cross-platform runtime.

## macOS

Install the current stable package by following Microsoft's
[PowerShell installation guide for macOS](https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-macos).
The guide covers Apple silicon and Intel packages, binary archives, and
alternate installation methods.

After installation, start a new terminal and verify the runtime:

```bash
pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion'
```

Then run the repository checks:

```bash
pwsh -NoProfile -File scripts/run-all-checks.ps1 -RepoPath .
```

## Existing or nonstandard installation

If `pwsh` is installed outside `PATH`, point Axiom-PMO at the executable without
copying the runtime into the repository:

```bash
AXIOM_PWSH=/absolute/path/to/pwsh node cli/axiom.mjs check
```

`AXIOM_PWSH` applies to the current command or shell environment. Do not commit
machine-specific absolute paths.

## Troubleshooting

- Exit code `127` means the CLI could not find a usable PowerShell host.
- Run `command -v pwsh` to see whether the executable is on `PATH`.
- Use `pwsh -NoLogo -NoProfile -Command '$PSVersionTable'` to capture runtime
  details for a bug report.
- Keep downloaded installers, archives, and local test evidence outside the
  repository. They may be deleted after the test run is complete and durable
  CI evidence has been recorded.
