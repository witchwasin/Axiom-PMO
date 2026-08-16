param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

# Milestone 6.1 packaging spike.
#
# The question this answers is narrow and worth stating precisely, because the
# obvious overstatement of it is exactly the kind of "check that answers a
# slightly adjacent question" that cost Milestone 5 four rounds of review:
#
#   Does the Axiom-PMO framework still work when its files are NOT in a git
#   checkout, NOT the current directory, and NOT writable -- i.e. installed
#   the way a Claude Code plugin is installed -- while operating on a user
#   project somewhere else entirely?
#
# That is a NECESSARY condition for the plugin shape decided in Milestone 6.0
# (docs/architecture/claude-code-integration.md section 7). It is not a SUFFICIENT
# one: nothing here launches Claude Code, loads a plugin, or exercises its
# permission model. What Claude Code itself does with a plugin is answered
# from primary source in the spike report, and separated there from what this
# file proves.
#
# The simulated install root deliberately contains a space and a dot-directory
# in its path, because a real install root
# (~/.claude/plugins/marketplaces/<name>/plugins/<plugin>) has both, and
# unquoted-path bugs are the classic way this fails on Windows only.

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$pass = 0
$fail = 0

function Assert-True {
  param([string]$Name, [bool]$Condition, [string]$Detail = "")
  if ($Condition) {
    Write-Host "[PASS] $Name"
    $script:pass++
  } else {
    Write-Host "[FAIL] $Name$(if ($Detail) { " -- $Detail" })"
    $script:fail++
  }
}

function Invoke-FixtureGit {
  # Native stderr is a terminating error under $ErrorActionPreference = "Stop"
  # on Windows PowerShell 5.1, including for purely informational output such
  # as git's CRLF notice. See docs/architecture/powershell-portability.md.
  param([string]$Dir, [Parameter(ValueFromRemainingArguments = $true)]$GitArgs)
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try { & git -C $Dir @GitArgs 2>&1 | Out-Null } finally { $ErrorActionPreference = $previous }
}

function Invoke-Framework {
  # Runs a framework script from the simulated plugin root, as a real child
  # process, with the working directory set somewhere unrelated to both the
  # framework and the project -- which is the situation a plugin invocation
  # actually creates.
  param(
    [string]$InstallRoot,
    [string]$RelativeScript,
    [string[]]$Arguments = @(),
    [string]$WorkingDirectory = $null
  )
  $scriptPath = Join-Path $InstallRoot $RelativeScript
  $argv = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptPath) + $Arguments

  $previousLocation = Get-Location
  if ($WorkingDirectory) { Set-Location -LiteralPath $WorkingDirectory }
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & $pwshExe @argv 2>&1
    $code = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previous
    Set-Location -LiteralPath $previousLocation
  }
  $text = ($output | ForEach-Object { [string]$_ }) -join "`n"
  return [pscustomobject]@{ ExitCode = $code; Text = $text }
}

function New-SimulatedPluginInstall {
  # Copies exactly what Milestone 6.0 section 7 says the plugin would carry --
  # scripts, cli, pmo-config, templates, skills -- plus the compiled engine
  # (dist/) and nothing else. No .git, no tests, no examples. If a framework
  # script needs something outside that list, this harness is where it shows up
  # as a failure rather than in a user's first install.
  #
  # dist/ joined the set with the Phase 7 CLI rewire: cli/axiom.mjs now runs the
  # in-process Node engine and imports its compiled library from ../dist/, so a
  # plugin install without dist/ cannot run the CLI at all (ERR_MODULE_NOT_FOUND
  # on first command). The plugin root is the repository root (marketplace
  # source "./", docs/architecture/claude-code-integration.md section 7) and
  # dist/ is a committed artifact, so real installs carry it; the simulation
  # must mirror that. This surfaced on the first qualifying canary run
  # (Fixed_plan/phase7/canary-log.md), exactly the failure this harness exists
  # to catch.
  param([string]$Root)
  $install = Join-Path $Root "marketplaces/axiom pmo/plugins/axiom-pmo"
  New-Item -ItemType Directory -Path $install -Force | Out-Null
  foreach ($dir in @("scripts", "cli", "pmo-config", "templates", "dist")) {
    Copy-Item -LiteralPath (Join-Path $repo $dir) -Destination (Join-Path $install $dir) -Recurse -Force
  }
  # Skills land at <plugin-root>/skills/, which is where Claude Code's
  # discovery expects them; in this repository they live at .claude/skills/.
  # Reconciling those two is a packaging decision, not a runtime one, so the
  # spike copies rather than assumes a layout.
  Copy-Item -LiteralPath (Join-Path $repo ".claude/skills") -Destination (Join-Path $install "skills") -Recurse -Force
  return $install
}

function New-UserProject {
  # A user's repository: real git, real work item, and deliberately NOT
  # containing any part of the framework.
  param([string]$Root)
  $project = Join-Path $Root "user work/my-app"
  New-Item -ItemType Directory -Path (Join-Path $project "src/payments") -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $project "source/MOM") -Force | Out-Null

  Set-Content -LiteralPath (Join-Path $project "PROJECT.md") -Value @"
# PROJECT - P90-PLUGIN

Task source: delivery

## Scope

| ID | Requirement | Source Ref | Evidence Status |
|---|---|---|---|
| REQ-001 | Card payments are captured. | MOM-20260731 item-1 | supported |
"@ -NoNewline

  Set-Content -LiteralPath (Join-Path $project "DELIVERY.md") -Value @"
# DELIVERY - P90-PLUGIN

Task source: delivery

## Work Items

| ID | Mode | Feature / Deliverable | Requirement Ref | Design Ref | Acceptance Criteria | Test Checklist | Owner | Status |
|---|---|---|---|---|---|---|---|---|
| D-001 | Standard | Capture card payments | REQ-001 | DESIGN/FLOW.puml | Given a valid card, when charged, then a receipt is issued. | unit tests | Dev | To Do |
"@ -NoNewline

  Set-Content -LiteralPath (Join-Path $project "SCOPE.json") `
    -Value '{"schema_version":"1.0","project":"P90-PLUGIN","implementation_scope":{"include":["src/payments/**"],"exclude":[]}}' -NoNewline
  Set-Content -LiteralPath (Join-Path $project "source/MOM/MOM-20260731.md") -Value "# MOM 2026-07-31`n`nitem-1: capture card payments." -NoNewline
  Set-Content -LiteralPath (Join-Path $project "src/payments/charge.ts") -Value "export const charge = () => 0;" -NoNewline

  Invoke-FixtureGit $project init
  Invoke-FixtureGit $project config user.email "spike@example.invalid"
  Invoke-FixtureGit $project config user.name "Spike"
  Invoke-FixtureGit $project config core.autocrlf false
  Invoke-FixtureGit $project add -A
  Invoke-FixtureGit $project commit -q -m "base"
  return $project
}

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-spike-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $root -Force | Out-Null

try {
  $install = New-SimulatedPluginInstall -Root $root
  $project = New-UserProject -Root $root
  $elsewhere = Join-Path $root "elsewhere"
  New-Item -ItemType Directory -Path $elsewhere -Force | Out-Null

  Assert-True "install root is not a git repository" `
    (-not (Test-Path -LiteralPath (Join-Path $install ".git")))
  Assert-True "install root path contains a space (Windows quoting exercised)" `
    ($install -match " ")

  # ---- Q: which scripts actually survive a plugin install? ---------------
  # The spike's first run answered this differently than expected, and the
  # distinction it exposed is the useful part:
  #
  #   USER-FACING scripts (validate, assess-handoff, export, run, verify, the
  #   CLI) read only scripts/, pmo-config/ and templates/ -- exactly the
  #   plugin's content set -- and work.
  #
  #   MAINTAINER scripts (pmo-doctor, check-public-hygiene, measure-context,
  #   prepare-public-release, the test runners) audit the framework's OWN
  #   repository and legitimately read VERSION, AGENTS.md, CLAUDE.md,
  #   CHANGELOG.md, .gitignore and .claude/. A plugin does not carry those and
  #   should not: auditing a checkout is not something a plugin user does.
  #
  # This is asserted rather than described, so the split cannot drift silently.
  $doctor = Invoke-Framework -InstallRoot $install -RelativeScript "scripts/pmo-doctor.ps1" -WorkingDirectory $elsewhere
  Assert-True "pmo-doctor is a maintainer tool and does not survive a plugin install" `
    ($doctor.ExitCode -ne 0) `
    ("pmo-doctor unexpectedly succeeded; if it no longer needs a checkout, this split has changed")
  # M6.2 closed the half of this that WAS a defect: it still fails, correctly,
  # but now with a diagnostic naming the tool, what it looked for, why a plugin
  # install cannot satisfy it, and which command the user probably wanted.
  Assert-True "...and fails with a FRAMEWORK-001 diagnostic, not a raw exception" `
    ($doctor.Text -match "FRAMEWORK-001") `
    ($doctor.Text.Substring(0, [Math]::Min(400, $doctor.Text.Length)))
  Assert-True "...and the diagnostic redirects to the user-facing command" `
    ($doctor.Text -match "validate-project\.ps1")
  Assert-True "...and no raw PowerShell exception leaks alongside it" `
    ($doctor.Text -notmatch "(?i)Get-Content:|Cannot find path|FileNotFoundException") `
    ($doctor.Text.Substring(0, [Math]::Min(400, $doctor.Text.Length)))

  # ---- Q: framework root vs project root, kept distinct? -----------------
  $validate = Invoke-Framework -InstallRoot $install -RelativeScript "scripts/validate-project.ps1" `
    -Arguments @("-ProjectPath", $project, "-Mode", "Standard", "-Gate", "Scope") -WorkingDirectory $elsewhere
  Assert-True "validate-project runs against a project outside the install root" `
    ($validate.Text -match "Summary: PASS=\d+") ("exit=" + $validate.ExitCode + " " + $validate.Text.Substring(0, [Math]::Min(400, $validate.Text.Length)))
  Assert-True "the validated project is the user's, not the framework's" `
    ($validate.Text -match "P90-PLUGIN" -or $validate.Text -match [regex]::Escape($project)) `
    ($validate.Text.Substring(0, [Math]::Min(400, $validate.Text.Length)))

  # ---- Q: does validation write into the framework install? ---------------
  # A plugin directory may be shared, replaced on update, or read-only. Any
  # write there is a defect even when it succeeds locally.
  $before = @(Get-ChildItem -LiteralPath $install -Recurse -File | ForEach-Object { $_.FullName }) | Sort-Object
  Invoke-Framework -InstallRoot $install -RelativeScript "scripts/validate-project.ps1" `
    -Arguments @("-ProjectPath", $project, "-Mode", "Standard", "-Gate", "Handoff") -WorkingDirectory $elsewhere | Out-Null
  $after = @(Get-ChildItem -LiteralPath $install -Recurse -File | ForEach-Object { $_.FullName }) | Sort-Object
  Assert-True "validation writes no new file into the install root" `
    (($before -join "`n") -eq ($after -join "`n")) `
    ("delta=" + (@(Compare-Object $before $after | ForEach-Object { $_.InputObject }) -join ", "))

  # ---- Q: are templates readable from a read-only install? ---------------
  Assert-True "templates are present in the install and readable" `
    (Test-Path -LiteralPath (Join-Path $install "templates/PROJECT.md"))

  # ---- Q: does the M5 loop work end to end from a plugin install? --------
  # This is the one that matters for the milestone's objective: a governed
  # handoff goes out, work happens, and the result comes back and is verified
  # -- with the framework never inside the user's repository.
  $export = Invoke-Framework -InstallRoot $install -RelativeScript "scripts/export-execution-contract.ps1" `
    -Arguments @("-ProjectPath", $project, "-WorkItemId", "D-001", "-Grant", "commit") -WorkingDirectory $elsewhere
  $contractPath = Join-Path $project ".execution/D-001/EXECUTION-CONTRACT.json"
  Assert-True "axiom export writes the contract into the USER's repo" `
    (Test-Path -LiteralPath $contractPath) ("exit=" + $export.ExitCode + " " + $export.Text.Substring(0, [Math]::Min(400, $export.Text.Length)))
  Assert-True "the contract sidecar is written alongside it" `
    (Test-Path -LiteralPath ($contractPath + ".sha256"))

  $run = Invoke-Framework -InstallRoot $install -RelativeScript "scripts/run-execution-command.ps1" `
    -Arguments @("-ProjectPath", $project, "-WorkItemId", "D-001", "-Name", "unit tests", "-Command", "echo ok") -WorkingDirectory $elsewhere
  Assert-True "axiom run executes a real child process from the install root" `
    ($run.ExitCode -eq 0) ($run.Text.Substring(0, [Math]::Min(400, $run.Text.Length)))

  $verify = Invoke-Framework -InstallRoot $install -RelativeScript "scripts/verify-execution-result.ps1" `
    -Arguments @("-ProjectPath", $project, "-ResultPath", (Join-Path $project ".execution/D-001/EXECUTION-RESULT.json")) -WorkingDirectory $elsewhere
  # No result document exists yet, so the correct behaviour is a clean refusal
  # with a diagnostic -- not a crash, and not a pass.
  Assert-True "verify refuses a missing result cleanly rather than crashing" `
    ($verify.Text -match "(?i)EXEC-|not found|missing") ("exit=" + $verify.ExitCode + " " + $verify.Text.Substring(0, [Math]::Min(400, $verify.Text.Length)))

  # ---- Q: does a REAL result verify from the install root? ---------------
  # The one case that speaks to the milestone's objective directly: a governed
  # handoff goes out, work is executed, and the result comes back and reaches
  # a verdict -- with the framework never inside the user's repository. The
  # 120 in-repo cases already prove the verification logic; what is under test
  # here is only that it still reaches the same verdict from an install root.
  $recordPath = Get-ChildItem -LiteralPath (Join-Path $project ".execution/D-001/runs") -File |
    Where-Object { $_.Name -notlike "*.sha256" } | Select-Object -First 1
  $recordDigest = (Get-FileHash -LiteralPath $recordPath.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  $contractDigest = (Get-Content -LiteralPath ($contractPath + ".sha256") -Raw).Trim()
  $head = & git -C $project rev-parse HEAD
  $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json

  # The human acceptance the artifact-observed runner record requires, written
  # in the user's own repo and deliberately not committed -- the same order a
  # real reviewer works in.
  $token = "axiom-authority: type=test-evidence-accepted; work_item=D-001; contract=$contractDigest; test=unit tests; evidence=$recordDigest"
  Set-Content -LiteralPath (Join-Path $project "decision-log.md") -Value @"
# Decision Log - P90-PLUGIN

| Date | Decision ID | Topic | Options Presented | User Choice | Rationale | Source Ref | Impact |
|---|---|---|---|---|---|---|---|
| 2026-07-31 | DEC-100 | Accept unit test evidence for D-001 | accept / require CI | accept | reviewed the run record by hand. $token | none | accepted |
"@ -NoNewline

  $result = [ordered]@{
    contract_version = "1.0"; work_item_id = "D-001"; contract_sha256 = $contractDigest
    base_sha = [string]$contract.base_sha; head_sha = ([string]$head).Trim()
    execution_status = "completed"; changed_files = @()
    test_evidence = @([ordered]@{
      type = "runner-exit-record"; name = "unit tests"
      run_record_path = ".execution/D-001/runs/" + $recordPath.Name
    })
    authority_claims = @([ordered]@{
      type = "test-evidence-accepted"; actor = "human"; claim = "accepted"
      decision_ref = "DEC-100"; test_name = "unit tests"; evidence_sha256 = $recordDigest
      evidence_type = "runner-exit-record"; work_item_id = "D-001"
    })
  }
  $resultPath = Join-Path $project ".execution/D-001/EXECUTION-RESULT.json"
  Set-Content -LiteralPath $resultPath -Value ($result | ConvertTo-Json -Depth 12) -NoNewline

  $realVerify = Invoke-Framework -InstallRoot $install -RelativeScript "scripts/verify-execution-result.ps1" `
    -Arguments @("-ProjectPath", $project, "-ResultPath", $resultPath) -WorkingDirectory $elsewhere
  Assert-True "a complete execution result verifies to a pass from the install root" `
    ($realVerify.Text -match "(?m)^Verdict: pass") `
    ("exit=" + $realVerify.ExitCode + " " + $realVerify.Text.Substring(0, [Math]::Min(600, $realVerify.Text.Length)))

  # ---- Q: does the Node CLI resolve the same way? ------------------------
  $node = Get-Command node -ErrorAction SilentlyContinue
  if (-not $node) {
    Write-Host "[SKIP] node is not installed; CLI resolution from an install root not exercised"
  } else {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $previousLocation = Get-Location
    try {
      Set-Location -LiteralPath $elsewhere
      $cliOut = & node (Join-Path $install "cli/axiom.mjs") "validate" "--project" $project "--mode" "Standard" 2>&1
      $cliCode = $LASTEXITCODE
    } finally {
      $ErrorActionPreference = $previous
      Set-Location -LiteralPath $previousLocation
    }
    $cliText = ($cliOut | ForEach-Object { [string]$_ }) -join "`n"
    Assert-True "the CLI resolves the framework from its own install location" `
      ($cliText -match "Summary: PASS=\d+" -or $cliText -match "P90-PLUGIN") `
      ("exit=" + $cliCode + " " + $cliText.Substring(0, [Math]::Min(400, $cliText.Length)))
  }

  # ---- Q: does a read-only install still work? ---------------------------
  # A plugin install can legitimately be read-only. Tested last, because it
  # changes permissions on the tree the earlier cases used.
  if (-not (Test-WindowsHost)) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { & chmod -R a-w $install 2>&1 | Out-Null } finally { $ErrorActionPreference = $previous }
    $roValidate = Invoke-Framework -InstallRoot $install -RelativeScript "scripts/validate-project.ps1" `
      -Arguments @("-ProjectPath", $project, "-Mode", "Standard", "-Gate", "Scope") -WorkingDirectory $elsewhere
    Assert-True "the user-facing validator runs from a read-only install root" `
      ($roValidate.Text -match "Summary: PASS=\d+") ("exit=" + $roValidate.ExitCode + " " + $roValidate.Text.Substring(0, [Math]::Min(400, $roValidate.Text.Length)))
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { & chmod -R u+w $install 2>&1 | Out-Null } finally { $ErrorActionPreference = $previous }
  } else {
    Write-Host "[SKIP] read-only install not exercised on Windows (ACL semantics differ from chmod)"
  }
} finally {
  if (Test-Path -LiteralPath $root) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue } finally { $ErrorActionPreference = $previous }
  }
}

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail"
if ($fail -gt 0) { exit 1 }
exit 0
