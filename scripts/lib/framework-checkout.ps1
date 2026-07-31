# Guard for the scripts that audit the Axiom-PMO framework itself.
#
# Milestone 6.1's spike surfaced a distinction that had been implicit:
#
#   User-facing scripts (validate-project, assess-handoff, the execution
#   contract trio, the CLI) read only scripts/, pmo-config/ and templates/.
#   They work from a plugin install, and must.
#
#   Maintainer scripts (pmo-doctor, check-public-hygiene, measure-context,
#   prepare-public-release, the test runners) audit the framework's OWN
#   repository, so they legitimately read VERSION, AGENTS.md, CLAUDE.md,
#   CHANGELOG.md, .gitignore and .claude/. A plugin install carries none of
#   those, and should not: there is no checkout for a plugin user to audit.
#
# So these scripts failing outside a checkout is correct. What was NOT correct
# is HOW they failed -- a raw PowerShell exception from whichever Get-Content
# happened to run first, which reads as a bug in the tool rather than as "this
# tool does not apply here."
#
# The temptation is to fix it by shipping VERSION and friends into the plugin
# so the command appears to work. That would be worse: the command would then
# audit a copy of the framework rather than a real checkout, and report a
# clean bill of health for something it never inspected. Fail with an
# explanation instead.

function Test-FrameworkCheckout {
  <#
    .SYNOPSIS
      Is $Root an Axiom-PMO source checkout rather than a packaged install?
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][string]$Root)

  # VERSION and AGENTS.md are both present in every checkout and absent from
  # any packaged distribution of the framework. Two markers rather than one so
  # a single stray file does not make a directory look like a checkout.
  foreach ($marker in @("VERSION", "AGENTS.md")) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root $marker))) { return $false }
  }
  return $true
}

function Assert-FrameworkCheckout {
  <#
    .SYNOPSIS
      Exit with a diagnostic when a maintainer-only tool is run outside a
      framework checkout.

    .PARAMETER ToolName
      Shown to the user, e.g. "pmo-doctor".

    .PARAMETER Alternative
      What the user probably wanted instead. Every maintainer tool has a
      user-facing counterpart, and saying so is the difference between a dead
      end and a redirection.
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$ToolName,
    [string]$Alternative = "scripts/validate-project.ps1 -ProjectPath <your project>"
  )

  if (Test-FrameworkCheckout -Root $Root) { return }

  Write-Host "[FAIL] FRAMEWORK-001 '$ToolName' needs an Axiom-PMO source checkout and this is not one."
  Write-Host ""
  Write-Host "  Looked in: $Root"
  Write-Host "  Expected:  VERSION and AGENTS.md (present in a git checkout, absent from a packaged install)"
  Write-Host ""
  Write-Host "  Why: '$ToolName' audits the Axiom-PMO framework itself -- its version file,"
  Write-Host "  agent rules, changelog and skill manifest. A plugin install deliberately does not"
  Write-Host "  carry those, because a plugin user has no framework checkout to audit. Shipping"
  Write-Host "  them so this command appeared to work would be worse than failing: it would"
  Write-Host "  report a clean result for a copy it never really inspected."
  Write-Host ""
  Write-Host "  If you meant to check YOUR project, that is a different command and it does"
  Write-Host "  work from a plugin install:"
  Write-Host "    $Alternative"
  Write-Host ""
  Write-Host "  If you meant to check the framework, clone it and run this from the clone:"
  Write-Host "    git clone https://github.com/witchwasin/Axiom-PMO"
  Write-Host ""
  Write-Host "Summary: PASS=0 WARN=0 FAIL=1"
  exit 1
}
