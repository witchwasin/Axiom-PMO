# Resolve the PowerShell executable used to spawn child validator/doctor
# processes.
#
# Why this exists: the runners used to hardcode `& powershell`, which only
# resolves on Windows PowerShell 5.1. On PowerShell 7 (`pwsh`) -- the documented
# minimum for Linux/macOS and the default in the Makefile and scripts/check.sh
# -- every child invocation failed with "The term 'powershell' is not
# recognized", so the whole fixture suite reported FAIL for reasons unrelated to
# the validator under test.
#
# Resolution order:
#   1. $env:AXIOM_PWSH             -- explicit override (CI pinning, odd installs)
#   2. the *current* host's own executable -- a child process of the same host
#      as the parent is always the closest match to the caller's intent
#   3. pwsh -> powershell -> powershell.exe on PATH
#
# Callers must treat a $null return as "PowerShell not found" and surface the
# remediation text from Get-PowerShellHostMissingMessage rather than silently
# skipping checks.

function Get-PowerShellHost {
  [CmdletBinding()]
  param()

  if ($script:PmoResolvedPowerShellHost) {
    return $script:PmoResolvedPowerShellHost
  }

  $candidates = New-Object System.Collections.Generic.List[string]

  if ($env:AXIOM_PWSH) {
    $candidates.Add($env:AXIOM_PWSH) | Out-Null
  }

  # Re-entering the same host keeps semantics stable: a suite started under
  # pwsh 7 must not silently fan out to Windows PowerShell 5.1, where JSON
  # depth, encoding, and regex behaviour differ.
  try {
    $selfPath = (Get-Process -Id $PID).Path
    if ($selfPath) {
      $candidates.Add($selfPath) | Out-Null
    }
  } catch {
    # Process introspection can be blocked in constrained runtimes; PATH
    # discovery below is enough on its own.
  }

  foreach ($name in @("pwsh", "powershell", "powershell.exe")) {
    $candidates.Add($name) | Out-Null
  }

  foreach ($candidate in $candidates) {
    if ([string]::IsNullOrWhiteSpace($candidate)) { continue }

    # An override or self-path is an absolute path; PATH names need lookup.
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      $script:PmoResolvedPowerShellHost = (Resolve-Path -LiteralPath $candidate).Path
      return $script:PmoResolvedPowerShellHost
    }

    $command = Get-Command -Name $candidate -CommandType Application -ErrorAction SilentlyContinue |
      Select-Object -First 1
    if ($command) {
      $script:PmoResolvedPowerShellHost = $command.Source
      return $script:PmoResolvedPowerShellHost
    }
  }

  return $null
}

function Get-PowerShellHostMissingMessage {
  return @(
    "PowerShell was not found on PATH.",
    "Install PowerShell 7 (pwsh): https://aka.ms/powershell",
    "Or set AXIOM_PWSH to the full path of a PowerShell executable."
  ) -join [Environment]::NewLine
}

# Standard argument prefix for a child PowerShell run. Kept in one place so the
# -NoProfile/-ExecutionPolicy pair cannot drift between runners.
function Get-PowerShellChildArgs {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath,

    [string[]]$ScriptArgs = @()
  )

  $childArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ScriptPath)
  if ($ScriptArgs -and $ScriptArgs.Count -gt 0) {
    $childArgs += $ScriptArgs
  }
  return $childArgs
}

# Invoke a PowerShell script in a child process. Returns the captured stdout
# lines; the caller reads $LASTEXITCODE for the child's exit code, exactly as it
# would with a direct `& powershell ...` call.
function Invoke-PowerShellScript {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath,

    [string[]]$ScriptArgs = @(),

    [switch]$SuppressStdErr
  )

  $exe = Get-PowerShellHost
  if (-not $exe) {
    throw (Get-PowerShellHostMissingMessage)
  }

  $childArgs = Get-PowerShellChildArgs -ScriptPath $ScriptPath -ScriptArgs $ScriptArgs
  if ($SuppressStdErr) {
    return & $exe @childArgs 2>$null
  }
  return & $exe @childArgs
}
