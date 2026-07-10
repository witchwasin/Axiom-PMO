param(
  [string]$RepoPath = "."
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path -LiteralPath $RepoPath
$repo = $root.Path
$validator = Join-Path $repo "scripts/validate-project.ps1"

$cases = @(
  @{ Name = "example-lite-bugfix"; Path = "examples/LITE-BUGFIX"; Mode = "Lite"; Gate = "Scope"; ShouldPass = $true },
  @{ Name = "example-standard-feature"; Path = "examples/STANDARD-FEATURE"; Mode = "Standard"; Gate = "Release"; ShouldPass = $true },
  @{ Name = "example-strict-high-risk"; Path = "examples/STRICT-HIGH-RISK"; Mode = "Strict"; Gate = "Release"; ShouldPass = $true },
  @{ Name = "valid-standard"; Path = "tests/fixtures/valid-standard"; Mode = "Standard"; Gate = "Release"; ShouldPass = $true },
  @{ Name = "invalid-no-project"; Path = "tests/fixtures/invalid-no-project"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false },
  @{ Name = "invalid-no-source-ref"; Path = "tests/fixtures/invalid-no-source-ref"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false },
  @{ Name = "invalid-fake-approval"; Path = "tests/fixtures/invalid-fake-approval"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false },
  @{ Name = "invalid-open-blocker"; Path = "tests/fixtures/invalid-open-blocker"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false },
  @{ Name = "invalid-missing-rollback"; Path = "tests/fixtures/invalid-missing-rollback"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false },
  @{ Name = "invalid-broken-link"; Path = "tests/fixtures/invalid-broken-link"; Mode = "Standard"; Gate = "Release"; ShouldPass = $false }
)

$pass = 0
$fail = 0

Write-Host "PMO Validation Fixture Tests: $repo"
Write-Host ""

foreach ($case in $cases) {
  $projectPath = Join-Path $repo $case.Path
  & powershell -NoProfile -ExecutionPolicy Bypass -File $validator -ProjectPath $projectPath -Mode $case.Mode -Gate $case.Gate *> $null
  $actualPass = ($LASTEXITCODE -eq 0)

  if ($actualPass -eq $case.ShouldPass) {
    $pass++
    Write-Host "[PASS] $($case.Name)"
  } else {
    $fail++
    $expected = if ($case.ShouldPass) { "pass" } else { "fail" }
    $actual = if ($actualPass) { "pass" } else { "fail" }
    Write-Host "[FAIL] $($case.Name) expected $expected but got $actual"
  }
}

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail"

if ($fail -gt 0) {
  exit 1
}

exit 0
