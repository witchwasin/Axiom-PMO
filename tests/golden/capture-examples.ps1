param(
  [string]$RepoPath = ".",
  [switch]$Verify
)
$ErrorActionPreference = "Stop"
$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$validator = Join-Path $repo "scripts/validate-project.ps1"
$goldenDir = Join-Path $repo "tests/golden"
New-Item -ItemType Directory -Force -Path $goldenDir | Out-Null

$cmds = @(
  @{ Name = "run-all-checks-lite-example"; Path = "examples/LITE-BUGFIX"; Mode = "Lite"; Gate = "Scope" },
  @{ Name = "run-all-checks-standard-example"; Path = "examples/STANDARD-FEATURE"; Mode = "Standard"; Gate = "Release" },
  @{ Name = "run-all-checks-strict-example"; Path = "examples/STRICT-HIGH-RISK"; Mode = "Strict"; Gate = "Release" }
)

$mismatches = @()
foreach ($c in $cmds) {
  $projectPath = Join-Path $repo $c.Path
  $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $validator, "-ProjectPath", $projectPath, "-Mode", $c.Mode, "-Gate", $c.Gate, "-Format", "Json", "-FailOnWarning")
  $prevEAP = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & powershell @psArgs 2>$null
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
      # Normalized line endings: git text normalization rewrites golden files
      # on checkout, so byte-exact comparison false-flags after a round-trip.
      $expected = ((Get-Content -LiteralPath $file -Raw) -replace "`r`n", "`n").TrimEnd()
      if ($expected -ne ($raw -replace "`r`n", "`n").TrimEnd()) { $mismatches += "$($c.Name): differs" }
    }
  } else {
    Set-Content -LiteralPath $file -Value $raw -NoNewline -Encoding utf8
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
