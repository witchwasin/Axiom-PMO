param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

# Contract tests for the structured diagnostic shape declared in
# pmo-config/diagnostics-schema.json.
#
# The golden masters prove that specific projects produce specific findings.
# These tests prove something different and orthogonal: that whatever the
# validator emits, it always has the shape a machine consumer was promised.
# A new rule added tomorrow with a malformed diagnostic would slip past the
# goldens (its case simply would not exist yet); it fails here.

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$schema = Get-Content -LiteralPath (Join-Path $repo "pmo-config/diagnostics-schema.json") -Raw | ConvertFrom-Json
$catalog = Get-Content -LiteralPath (Join-Path $repo "pmo-config/validation-rules.json") -Raw | ConvertFrom-Json

$pass = 0
$fail = 0

function Assert-True {
  param([string]$Name, [bool]$Condition, [string]$Detail = "")
  if ($Condition) {
    $script:pass++
    Write-Host "[PASS] $Name"
  } else {
    $script:fail++
    Write-Host "[FAIL] $Name$(if ($Detail) { " -- $Detail" })"
  }
}

function Invoke-Validator {
  param([string]$Fixture, [string]$Mode, [string]$Gate, [switch]$FailOnWarning)

  $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
    (Join-Path $repo "scripts/validate-project.ps1"),
    "-ProjectPath", (Join-Path $repo $Fixture),
    "-Mode", $Mode, "-Gate", $Gate, "-Format", "Json")
  if ($FailOnWarning) { $psArgs += "-FailOnWarning" }

  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & $pwshExe @psArgs 2>$null
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $previous

  return [pscustomobject]@{
    Json = (($output | Out-String) | ConvertFrom-Json)
    ExitCode = $exitCode
  }
}

Write-Host "Axiom-PMO Diagnostics Contract Tests: $repo"
Write-Host ""

# A mix that exercises every level: a clean run, a failing run, and a
# warning-only run.
$samples = @(
  @{ Name = "clean-standard-release"; Fixture = "tests/fixtures/valid-standard"; Mode = "Standard"; Gate = "Release" },
  @{ Name = "failing-standard-release"; Fixture = "tests/fixtures/invalid-no-source-ref"; Mode = "Standard"; Gate = "Release" },
  @{ Name = "warning-github-task-source"; Fixture = "tests/fixtures/valid-github-task-source-no-delivery"; Mode = "Standard"; Gate = "Release" },
  @{ Name = "strict-release"; Fixture = "examples/STRICT-HIGH-RISK"; Mode = "Strict"; Gate = "Release" }
)

$expectedDiagnosticKeys = @($schema.diagnostic.required)
$expectedEnvelopeKeys = @($schema.envelope.required)
$declaredSchemaVersion = [string]$schema.diagnostics_schema_version
$catalogRuleIds = @($catalog.rules.PSObject.Properties.Name)
$docBase = [string]$catalog.documentation_base_url

$allResults = @()

foreach ($sample in $samples) {
  $run = Invoke-Validator -Fixture $sample.Fixture -Mode $sample.Mode -Gate $sample.Gate
  $json = $run.Json

  Assert-True "$($sample.Name): envelope parses" ($null -ne $json)
  if (-not $json) { continue }

  $envelopeKeys = @($json.PSObject.Properties.Name)
  $missingEnvelope = @($expectedEnvelopeKeys | Where-Object { $envelopeKeys -notcontains $_ })
  Assert-True "$($sample.Name): envelope has every required key" ($missingEnvelope.Count -eq 0) ($missingEnvelope -join ", ")

  Assert-True "$($sample.Name): envelope schema_version is $declaredSchemaVersion" `
    ("$($json.schema_version)" -eq $declaredSchemaVersion) "got '$($json.schema_version)'"

  Assert-True "$($sample.Name): exit code is a declared value" `
    (@(0, 1, 2) -contains $run.ExitCode) "got $($run.ExitCode)"

  # The summary counters must agree with the rows actually emitted; a drifting
  # counter would make a dashboard disagree with its own detail view.
  $rows = @($json.results)
  $countedPass = @($rows | Where-Object { $_.level -eq "PASS" }).Count
  $countedWarn = @($rows | Where-Object { $_.level -eq "WARN" }).Count
  $countedFail = @($rows | Where-Object { $_.level -eq "FAIL" }).Count
  $countedWarnBlocking = @($rows | Where-Object { $_.level -eq "WARN" -and $_.blocking }).Count
  Assert-True "$($sample.Name): summary counters match the results array" `
    ($json.summary.pass -eq $countedPass -and $json.summary.warn -eq $countedWarn -and
     $json.summary.fail -eq $countedFail -and $json.summary.warn_blocking -eq $countedWarnBlocking) `
    "summary=$($json.summary.pass)/$($json.summary.warn)/$($json.summary.fail) counted=$countedPass/$countedWarn/$countedFail"

  $allResults += $rows
}

Write-Host ""
Write-Host "Checking $($allResults.Count) diagnostic row(s) against the contract..."

$shapeProblems = @()
$enumProblems = @()
$catalogProblems = @()
$suggestionProblems = @()
$docProblems = @()
$sensitiveProblems = @()

foreach ($row in $allResults) {
  $keys = @($row.PSObject.Properties.Name)

  $missing = @($expectedDiagnosticKeys | Where-Object { $keys -notcontains $_ })
  if ($missing.Count -gt 0) { $shapeProblems += "$($row.rule_id): missing $($missing -join ', ')" }

  # Absent-vs-null policy: fields are always present, never omitted, and never
  # the empty string.
  foreach ($key in $expectedDiagnosticKeys) {
    if ($keys -notcontains $key) { continue }
    $value = $row.$key
    if ($value -is [string] -and $value.Trim().Length -eq 0) {
      $shapeProblems += "$($row.rule_id): '$key' is an empty string instead of null"
    }
  }

  if ("$($row.schema_version)" -ne $declaredSchemaVersion) {
    $shapeProblems += "$($row.rule_id): row schema_version is '$($row.schema_version)'"
  }
  if (@("PASS", "WARN", "FAIL", "INFO") -notcontains "$($row.level)") {
    $enumProblems += "level '$($row.level)'"
  }
  if ("$($row.rule_id)" -notmatch '^[A-Z][A-Z0-9]*(-[A-Z0-9]+)+$') {
    $enumProblems += "rule_id '$($row.rule_id)' does not match the declared pattern"
  }
  if ($row.blocking -isnot [bool]) {
    $enumProblems += "$($row.rule_id): blocking is not a boolean"
  }
  if ([string]::IsNullOrWhiteSpace("$($row.message)")) {
    $shapeProblems += "$($row.rule_id): message is empty"
  }

  if ($catalogRuleIds -notcontains "$($row.rule_id)") {
    $catalogProblems += "$($row.rule_id) is not in validation-rules.json"
  }

  if ($row.level -eq "WARN" -or $row.level -eq "FAIL") {
    if ([string]::IsNullOrWhiteSpace("$($row.suggestion)")) {
      $suggestionProblems += "$($row.rule_id) has no suggestion on a $($row.level) row"
    }
  } else {
    # PASS/INFO must not carry remediation text: a consumer filtering on
    # "has a suggestion" would otherwise pick up healthy rows.
    if (-not [string]::IsNullOrWhiteSpace("$($row.suggestion)")) {
      $suggestionProblems += "$($row.rule_id) carries a suggestion on a $($row.level) row"
    }
    if (-not [string]::IsNullOrWhiteSpace("$($row.documentation_url)")) {
      $docProblems += "$($row.rule_id) carries a documentation_url on a $($row.level) row"
    }
  }

  if (-not [string]::IsNullOrWhiteSpace("$($row.documentation_url)")) {
    if (-not "$($row.documentation_url)".StartsWith($docBase)) {
      $docProblems += "$($row.rule_id): documentation_url does not start with documentation_base_url"
    }
    $relative = "$($row.documentation_url)".Substring($docBase.TrimEnd('/').Length).TrimStart('/')
    if (-not (Test-Path -LiteralPath (Join-Path $repo $relative) -PathType Leaf)) {
      $docProblems += "$($row.rule_id): documentation_url points at a file that does not exist ($relative)"
    }
  }

  # Sensitive-data policy: a diagnostic locates a problem, it does not
  # reproduce it. A multi-line message means artifact content was pasted in.
  if ("$($row.message)" -match "`n") {
    $sensitiveProblems += "$($row.rule_id): message spans multiple lines"
  }
  if ("$($row.message)".Length -gt 400) {
    $sensitiveProblems += "$($row.rule_id): message is $("$($row.message)".Length) chars, long enough to be quoting artifact content"
  }
}

Assert-True "every diagnostic has the full declared field set" ($shapeProblems.Count -eq 0) (($shapeProblems | Select-Object -First 5) -join "; ")
Assert-True "every diagnostic uses declared enum values and types" ($enumProblems.Count -eq 0) ((($enumProblems | Sort-Object -Unique) | Select-Object -First 5) -join "; ")
Assert-True "every emitted rule_id exists in the catalog" ($catalogProblems.Count -eq 0) ((($catalogProblems | Sort-Object -Unique) | Select-Object -First 5) -join "; ")
Assert-True "suggestion is present on WARN/FAIL and absent on PASS/INFO" ($suggestionProblems.Count -eq 0) ((($suggestionProblems | Sort-Object -Unique) | Select-Object -First 5) -join "; ")
Assert-True "documentation_url resolves and is absent on PASS/INFO" ($docProblems.Count -eq 0) ((($docProblems | Sort-Object -Unique) | Select-Object -First 5) -join "; ")
Assert-True "no diagnostic echoes artifact content" ($sensitiveProblems.Count -eq 0) ((($sensitiveProblems | Sort-Object -Unique) | Select-Object -First 5) -join "; ")

# Backward compatibility: the four v1.0 fields must still be present with their
# original names on every row. This is the check that would catch someone
# "tidying up" the contract by renaming `blocking` to `is_blocking`.
$v1Fields = @($schema.compatibility.stable_fields)
$v1Problems = @()
foreach ($row in $allResults) {
  $keys = @($row.PSObject.Properties.Name)
  foreach ($field in $v1Fields) {
    if ($keys -notcontains $field) { $v1Problems += "$($row.rule_id) lost v1.0 field '$field'" }
  }
}
Assert-True "v1.0 fields are still present on every diagnostic" ($v1Problems.Count -eq 0) ((($v1Problems | Sort-Object -Unique) | Select-Object -First 5) -join "; ")

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail"
if ($fail -gt 0) { exit 1 }
exit 0
