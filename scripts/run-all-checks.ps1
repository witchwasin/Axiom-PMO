param(
  [string]$RepoPath = ".",
  [string]$TestChildScript = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib/pwsh-host.ps1")

$root = Resolve-Path -LiteralPath $RepoPath
$repo = $root.Path

# Maintainer-only: audits the framework's own checkout, so it fails with a
# diagnostic rather than a raw exception when run from a packaged install.
. (Join-Path $PSScriptRoot "lib/framework-checkout.ps1")
Assert-FrameworkCheckout -Root $repo -ToolName "run-all-checks" -Alternative "scripts/validate-project.ps1 -ProjectPath <your project>"

$ps = Get-PowerShellHost
if (-not $ps) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

Write-Host "Running Axiom-PMO framework checks for $repo"
Write-Host ""

function Invoke-Check {
  param(
    [string]$Name,
    [scriptblock]$Command
  )

  & $Command
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    Write-Host ""
    Write-Host "Check failed: $Name exit $exitCode"
    # This aggregator runs a dozen checks inside a single CI step, so a bare
    # "Process completed with exit code 1" annotation says nothing about which
    # one broke -- and downloading the job log needs repository admin rights
    # that a contributor reading a failed PR does not have. A workflow-command
    # annotation puts the failing check's name on the run summary, where anyone
    # can see it.
    if ($env:GITHUB_ACTIONS -eq "true") {
      Write-Host "::error title=Axiom-PMO check failed::$Name exited $exitCode"
    }
    exit $exitCode
  }
}

if ($TestChildScript) {
  $testChild = Resolve-Path -LiteralPath $TestChildScript
  Invoke-Check "fault-injection" { & $ps -NoProfile -ExecutionPolicy Bypass -File $testChild.Path }
}

Invoke-Check "pmo-doctor" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/pmo-doctor.ps1") -RepoPath $repo }
Invoke-Check "doctor-markdown" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/doctor-markdown-tests.ps1") -RepoPath $repo }
# -VerifyGolden here rather than as a separate CI step. Running the fixture
# matrix is by far the most expensive thing this suite does -- 148 child
# PowerShell processes -- and verifying the goldens re-runs every one of those
# cases. Doing both in one pass costs nothing extra and saves the entire second
# pass; measured at ~2.5 minutes per CI run, growing with every fixture added.
Invoke-Check "validation-fixtures" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/run-validation-tests.ps1") -RepoPath $repo -VerifyGolden }
# The example goldens were verified nowhere: not here, and not in the workflow.
# They are cheap (three cases) and they are what proves the README's worked
# examples still produce what the docs say they produce.
Invoke-Check "example-golden" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/golden/capture-examples.ps1") -RepoPath $repo -Verify }
Invoke-Check "config-mutation" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/config-mutation-tests.ps1") -RepoPath $repo }
Invoke-Check "diagnostics-contract" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/diagnostics-contract-tests.ps1") -RepoPath $repo }
Invoke-Check "line-endings" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/line-ending-tests.ps1") -RepoPath $repo }
Invoke-Check "handoff-assessment" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/handoff-assessment-tests.ps1") -RepoPath $repo }
Invoke-Check "visual-proof" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/visual-proof-tests.ps1") -RepoPath $repo }
Invoke-Check "scope-diff" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/scope-diff-tests.ps1") -RepoPath $repo }
Invoke-Check "execution-contract" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/execution-contract-tests.ps1") -RepoPath $repo }
Invoke-Check "adversarial-review" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/adversarial-review-tests.ps1") -RepoPath $repo }
Invoke-Check "learning-registry" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/learning-registry-tests.ps1") -RepoPath $repo }
Invoke-Check "demo-smoke" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/demo-smoke-tests.ps1") -RepoPath $repo }
# Milestone 6.2: the plugin manifests, and the drift gate on the generated
# skills/ mirror. A mirror maintained by convention drifts; this makes it a
# build failure instead.
Invoke-Check "plugin-package" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/plugin-package-tests.ps1") -RepoPath $repo }
Invoke-Check "plugin-skills-drift" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/build-plugin-package.ps1") -Check }
# Milestone 6.3: the only code in this milestone that writes to a file the user
# owns. Adversarial by design -- malformed markers, hand edits, CRLF, BOM,
# symlinks, read-only targets, and content trying to manufacture authority.
Invoke-Check "setup-integration" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/setup-integration-tests.ps1") -RepoPath $repo }
# Milestone 6.5: the optional advisory hook. Weighted towards what it must NOT
# do -- speak when nobody opted in, emit a permission decision, or break a tool
# call when anything goes wrong.
Invoke-Check "hook-advisory" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/hook-advisory-tests.ps1") -RepoPath $repo }
# Milestone 6.4: the claim a user actually cares about -- installing this does
# not break what they already have -- plus the governance claims a friendlier
# integration would be most tempted to soften.
Invoke-Check "clean-room" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/clean-room-tests.ps1") -RepoPath $repo }
# Milestone 6.1 spike: the framework must keep working when its files are not
# in a git checkout, not the cwd, and not writable -- the way a Claude Code
# plugin is installed. Run on every host, because the failure mode this guards
# (unquoted install paths) is Windows-only.
Invoke-Check "plugin-install" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/helpers/plugin-install-spike-tests.ps1") -RepoPath $repo }
Invoke-Check "lite-example" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/validate-project.ps1") -ProjectPath (Join-Path $repo "examples/LITE-BUGFIX") -Mode Lite -Gate Scope -FailOnWarning }
Invoke-Check "standard-example" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/validate-project.ps1") -ProjectPath (Join-Path $repo "examples/STANDARD-FEATURE") -Mode Standard -Gate Release -FailOnWarning }
Invoke-Check "strict-example" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "scripts/validate-project.ps1") -ProjectPath (Join-Path $repo "examples/STRICT-HIGH-RISK") -Mode Strict -Gate Release -FailOnWarning }
Invoke-Check "e2e-lite" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/e2e/lite.ps1") -RepoPath $repo }
Invoke-Check "e2e-standard" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/e2e/standard.ps1") -RepoPath $repo }
Invoke-Check "e2e-strict" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/e2e/strict.ps1") -RepoPath $repo }
Invoke-Check "e2e-handoff" { & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tests/e2e/handoff.ps1") -RepoPath $repo }

# The CLI is the only part of the framework that is not PowerShell, so it is the
# only check that can be skipped for a missing runtime. Skipping is reported,
# never silent: a check that quietly does not run is worse than one that fails.
$node = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($node) {
  Invoke-Check "cli" { & $node.Source (Join-Path $repo "tests/helpers/cli-tests.mjs") }
  # The GitHub Action wrapper is Node like the CLI, and its integration tests
  # shell out to the same PowerShell host this whole run already required --
  # running it here gets Windows/Ubuntu/macOS coverage for free from the
  # existing CI matrix instead of needing a separate consumer-repo workflow.
  Invoke-Check "github-action" { & $node.Source (Join-Path $repo "tests/helpers/github-action-tests.mjs") }
} else {
  Write-Host ""
  Write-Host "SKIPPED: cli and github-action tests -- Node.js was not found on PATH."
  Write-Host "         The CLI is an optional wrapper; the PowerShell scripts above are the reference implementation."
}

Write-Host ""
Write-Host "All Axiom-PMO framework checks completed."
