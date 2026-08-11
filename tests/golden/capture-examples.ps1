param(
  [string]$RepoPath = ".",
  [switch]$Verify
)
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")
. (Join-Path $PSScriptRoot "../../scripts/lib/golden-normalizer.ps1")

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}
$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$validator = Join-Path $repo "scripts/validate-project.ps1"
$goldenDir = Join-Path $repo "tests/golden"
New-Item -ItemType Directory -Force -Path $goldenDir | Out-Null

$cmds = @(
  @{ Name = "run-all-checks-lite-example"; Path = "examples/LITE-BUGFIX"; Mode = "Lite"; Gate = "Scope" },
  @{ Name = "run-all-checks-standard-example"; Path = "examples/STANDARD-FEATURE"; Mode = "Standard"; Gate = "Release" },
  # The same example at the Handoff gate. Release exercises none of the
  # HANDOFF-### rules, so the golden above cannot show a handoff regression --
  # it stayed byte-identical while a stale HANDOFF-REVIEW.json raised a blocking
  # WARN at -Gate Handoff. Every case in this table runs with -FailOnWarning
  # (see $psArgs), which is what makes that WARN visible in this golden's
  # exit code rather than silently absent from it.
  @{ Name = "run-all-checks-standard-example-handoff"; Path = "examples/STANDARD-FEATURE"; Mode = "Standard"; Gate = "Handoff" },
  @{ Name = "run-all-checks-strict-example"; Path = "examples/STRICT-HIGH-RISK"; Mode = "Strict"; Gate = "Release" }
)

$mismatches = @()
foreach ($c in $cmds) {
  $projectPath = Join-Path $repo $c.Path
  $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $validator, "-ProjectPath", $projectPath, "-Mode", $c.Mode, "-Gate", $c.Gate, "-Format", "Json", "-FailOnWarning")
  $prevEAP = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & $pwshExe @psArgs 2>$null
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $prevEAP
  $raw = ($output | Out-String).TrimEnd() + "`nEXIT_CODE=$exitCode"
  # The JSON output embeds the resolved absolute project path, which differs by
  # checkout location (local clone vs a CI runner path). Strip it to a fixed
  # placeholder so these example goldens are portable across machines. Handle
  # both the raw path and its JSON-escaped (doubled backslash) form -- same
  # normalization scripts/run-validation-tests.ps1 applies to its golden masters.
  $repoJsonEscaped = $repo -replace '\\', '\\'
  $raw = $raw.Replace($repoJsonEscaped, '<REPO_ROOT>').Replace($repo, '<REPO_ROOT>')
  $file = Join-Path $goldenDir "$($c.Name).txt"
  if ($Verify) {
    if (-not (Test-Path -LiteralPath $file)) {
      $mismatches += "$($c.Name): no golden file"
    } else {
      # Canonical comparison (scripts/lib/golden-normalizer.ps1): git text
      # normalization rewrites golden files on checkout and the JSON
      # pretty-printer differs between PowerShell hosts, so byte-exact
      # comparison false-flags without catching any real behavior change.
      $expected = Get-Content -LiteralPath $file -Raw
      if (-not (Test-GoldenMatch -Expected $expected -Actual $raw)) { $mismatches += "$($c.Name): differs" }
    }
  } else {
    # Canonical form, so a capture on any PowerShell host produces the same file.
    Set-Content -LiteralPath $file -Value (Get-CanonicalGoldenText -Text $raw) -NoNewline -Encoding utf8
    Write-Host "Captured $($c.Name)"
  }
}
if ($Verify) {
  if ($mismatches.Count -gt 0) {
    Write-Host "MISMATCHES:"; $mismatches | ForEach-Object { Write-Host "  - $_" }
    exit 1
  }
  Write-Host "All example golden outputs match."
}
exit 0
