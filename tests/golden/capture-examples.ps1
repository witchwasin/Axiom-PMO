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
  $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $validator, "-ProjectPath", $projectPath, "-Mode", $c.Mode, "-Gate", $c.Gate, "-Format", "Json", "-FailOnWarning")
  $prevEAP = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & powershell @args 2>$null
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $prevEAP
  $raw = ($output | Out-String).TrimEnd() + "`nEXIT_CODE=$exitCode"
  $file = Join-Path $goldenDir "$($c.Name).txt"
  if ($Verify) {
    if (-not (Test-Path -LiteralPath $file)) {
      $mismatches += "$($c.Name): no golden file"
    } else {
      $expected = (Get-Content -LiteralPath $file -Raw).TrimEnd()
      if ($expected -ne $raw.TrimEnd()) { $mismatches += "$($c.Name): differs" }
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
