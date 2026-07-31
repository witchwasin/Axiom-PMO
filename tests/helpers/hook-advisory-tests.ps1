param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

# Milestone 6.5: the optional scope advisory hook.
#
# Milestone 6.0 called this the most interesting item on the integration list
# and also the only one that can make a user's editor feel broken, and carved
# it into its own opt-in milestone for exactly that reason. The cases below are
# therefore weighted towards what it must NOT do:
#
#   - it must be silent unless a project opted in;
#   - it must never emit a permission decision, at any input;
#   - it must never fail in a way that breaks a tool call;
#   - it must not be an authority, and its output must not read like one;
#   - it must agree with the real matcher rather than reimplementing one.
#
# The last is the subtle one. A second glob implementation that disagreed with
# SCOPE-DIFF would be worse than no hook: it would teach users that the
# advisory and the gate mean different things, and the gate is the one that
# decides.

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$hookScript = Join-Path $repo "scripts/hook-scope-advisory.ps1"
$shim = Join-Path $repo "hooks/scope-advisory.sh"
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

function Invoke-Hook {
  # Through the PowerShell half directly, using a payload file rather than
  # stdin so the case works identically on every host.
  param([string]$Project, [string]$Payload)
  $payloadPath = Join-Path $script:sandbox ("payload-" + [guid]::NewGuid().ToString("N").Substring(0, 8) + ".json")
  [System.IO.File]::WriteAllText($payloadPath, $Payload, (New-Object System.Text.UTF8Encoding($false)))
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $out = & $pwshExe -NoProfile -ExecutionPolicy Bypass -File $hookScript -ProjectPath $Project -PayloadPath $payloadPath 2>&1
    $code = $LASTEXITCODE
  } finally { $ErrorActionPreference = $previous }
  return [pscustomobject]@{ ExitCode = $code; Text = (($out | ForEach-Object { [string]$_ }) -join "`n").Trim() }
}

function New-HookProject {
  param([string]$Name, [bool]$OptIn, [string]$Scope = '{"schema_version":"1.0","project":"H","implementation_scope":{"include":["src/payments/**"],"exclude":["src/payments/vendor/**"]}}')
  $dir = Join-Path $script:sandbox $Name
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  if ($Scope) {
    [System.IO.File]::WriteAllText((Join-Path $dir "SCOPE.json"), $Scope, (New-Object System.Text.UTF8Encoding($false)))
  }
  if ($OptIn) {
    New-Item -ItemType Directory -Path (Join-Path $dir ".axiom") -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $dir ".axiom/hooks.json"), '{"scope_advisory": true}', (New-Object System.Text.UTF8Encoding($false)))
  }
  return $dir
}

function New-Payload {
  param([string]$Project, [string]$FilePath, [string]$Tool = "Edit")
  $escapedProject = $Project -replace "\\", "\\\\"
  $escapedFile = $FilePath -replace "\\", "\\\\"
  return "{`"cwd`":`"$escapedProject`",`"tool_name`":`"$Tool`",`"tool_input`":{`"file_path`":`"$escapedFile`"}}"
}

$script:sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("axiom-hook-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $script:sandbox -Force | Out-Null

try {
  # ---- Off by default ---------------------------------------------------

  $p = New-HookProject -Name "no-optin" -OptIn $false
  $r = Invoke-Hook -Project $p -Payload (New-Payload -Project $p -FilePath "src/other/thing.ts")
  Assert-True "with no opt-in file the hook says nothing" ($r.Text -eq "") ($r.Text)
  Assert-True "…and exits 0" ($r.ExitCode -eq 0) ("exit=" + $r.ExitCode)

  $p = New-HookProject -Name "optin-false" -OptIn $false
  New-Item -ItemType Directory -Path (Join-Path $p ".axiom") -Force | Out-Null
  [System.IO.File]::WriteAllText((Join-Path $p ".axiom/hooks.json"), '{"scope_advisory": false}', (New-Object System.Text.UTF8Encoding($false)))
  $r = Invoke-Hook -Project $p -Payload (New-Payload -Project $p -FilePath "src/other/thing.ts")
  Assert-True "an explicit opt-out is respected" ($r.Text -eq "") ($r.Text)

  # A file that exists but says something else entirely must not be read as
  # consent. Opt-in means the flag, not the file.
  [System.IO.File]::WriteAllText((Join-Path $p ".axiom/hooks.json"), '{"something_else": true}', (New-Object System.Text.UTF8Encoding($false)))
  $r = Invoke-Hook -Project $p -Payload (New-Payload -Project $p -FilePath "src/other/thing.ts")
  Assert-True "an opt-in file that does not name this feature is not consent" ($r.Text -eq "") ($r.Text)

  # ---- Opted in: reports, and only when it should ----------------------

  $p = New-HookProject -Name "optin" -OptIn $true
  $r = Invoke-Hook -Project $p -Payload (New-Payload -Project $p -FilePath "src/other/thing.ts")
  Assert-True "an out-of-scope path is reported once opted in" ($r.Text -match "scope advisory") ($r.Text)
  Assert-True "…and names the offending path" ($r.Text -match "src/other/thing\.ts") ($r.Text)

  $r = Invoke-Hook -Project $p -Payload (New-Payload -Project $p -FilePath "src/payments/charge.ts")
  Assert-True "an in-scope path produces no noise" ($r.Text -eq "") ($r.Text)

  # Agreement with the real matcher, not a second implementation: an excluded
  # subtree inside an included one is the case a naive prefix check gets wrong.
  $r = Invoke-Hook -Project $p -Payload (New-Payload -Project $p -FilePath "src/payments/vendor/lib.ts")
  Assert-True "an excluded path inside an included tree is not reported" ($r.Text -eq "") ($r.Text)

  $r = Invoke-Hook -Project $p -Payload (New-Payload -Project $p -FilePath (Join-Path $p "src/other/absolute.ts"))
  Assert-True "an absolute path inside the project is resolved and reported" `
    ($r.Text -match "src/other/absolute\.ts") ($r.Text)

  $r = Invoke-Hook -Project $p -Payload (New-Payload -Project $p -FilePath "/etc/hosts")
  Assert-True "a path outside the project is not commented on at all" ($r.Text -eq "") ($r.Text)

  # ---- It decides nothing ----------------------------------------------
  # The single most important property. Checked against output rather than
  # asserted about the code, and checked for every case that produces output.

  $r = Invoke-Hook -Project $p -Payload (New-Payload -Project $p -FilePath "src/other/thing.ts")
  Assert-True "the response carries no permission decision field" `
    ($r.Text -notmatch "(?i)permissionDecision|permission_decision") ($r.Text)
  Assert-True "…no deny or block verdict" `
    ($r.Text -notmatch "(?i)`"(deny|block|ask)`"") ($r.Text)
  Assert-True "…and says in its own words that nothing is blocked" `
    ($r.Text -match "(?i)nothing is blocked|report-only") ($r.Text)
  Assert-True "…and disclaims being evidence or a decision" `
    ($r.Text -match "(?i)not a decision and not evidence") ($r.Text)
  Assert-True "…and points at the check that actually decides" `
    ($r.Text -match "SCOPE-DIFF") ($r.Text)

  # Nothing anywhere in the shipped hook can emit a decision, because there is
  # no code to do it. Asserted on the source, since "no case produced one" is
  # weaker than "no case could".
  # Comments are stripped first. The documentation block deliberately NAMES the
  # field it refuses to emit -- that is the clearest way to say so -- and an
  # assertion that cannot tell prose from code would force the explanation out
  # of the file to satisfy itself.
  $hookCode = (@(
    [System.IO.File]::ReadAllLines($hookScript) |
      Where-Object { $_ -notmatch '^\s*#' }
  ) -join "`n")
  $hookCode = [regex]::Replace($hookCode, "(?s)<#.*?#>", "")
  Assert-True "no executable line in the hook emits a permission-decision field" `
    ($hookCode -notmatch "(?i)permissionDecision|permission_decision|hookSpecificOutput") `
    ("the point is not that no case produced one, but that no case could")
  Assert-True "…and none emits a deny or block verdict" `
    ($hookCode -notmatch '"deny"|"block"')

  # ---- It never breaks a tool call -------------------------------------

  foreach ($case in @(
    @{ Name = "empty payload"; Payload = "" },
    @{ Name = "not JSON"; Payload = "this is not json at all" },
    @{ Name = "JSON but not an object"; Payload = "[1,2,3]" },
    @{ Name = "no tool_input"; Payload = "{`"cwd`":`"$($p -replace '\\','\\')`"}" },
    @{ Name = "tool_input with no path"; Payload = "{`"cwd`":`"$($p -replace '\\','\\')`",`"tool_input`":{`"content`":`"x`"}}" },
    @{ Name = "null tool_input"; Payload = "{`"cwd`":`"$($p -replace '\\','\\')`",`"tool_input`":null}" },
    @{ Name = "unexpected extra fields"; Payload = "{`"cwd`":`"$($p -replace '\\','\\')`",`"future_field`":{`"a`":1},`"tool_input`":{`"file_path`":`"src/payments/ok.ts`",`"new_field`":true}}" }
  )) {
    $r = Invoke-Hook -Project $p -Payload $case.Payload
    Assert-True "malformed input ($($case.Name)) exits 0" ($r.ExitCode -eq 0) ("exit=" + $r.ExitCode + " " + $r.Text)
    Assert-True "malformed input ($($case.Name)) emits no error text" `
      ($r.Text -notmatch "(?i)exception|at line|ParameterBinding") ($r.Text)
  }

  # A project with no SCOPE.json has declared no scope, so there is nothing to
  # be outside of. Silence, not a complaint about the missing file.
  $p2 = New-HookProject -Name "no-scope" -OptIn $true -Scope $null
  $r = Invoke-Hook -Project $p2 -Payload (New-Payload -Project $p2 -FilePath "anywhere.ts")
  Assert-True "a project with no SCOPE.json gets no advisory" ($r.Text -eq "") ($r.Text)

  $p3 = New-HookProject -Name "broken-scope" -OptIn $true -Scope "{ this is not valid json"
  $r = Invoke-Hook -Project $p3 -Payload (New-Payload -Project $p3 -FilePath "anywhere.ts")
  Assert-True "a malformed SCOPE.json degrades to silence, not to a broken edit" `
    ($r.ExitCode -eq 0 -and $r.Text -eq "") ("exit=" + $r.ExitCode + " " + $r.Text)

  # ---- The shell shim ---------------------------------------------------

  if ($IsWindows -ne $true) {
    Assert-True "the hook shim is executable" (Test-Path -LiteralPath $shim)

    function Invoke-Shim {
      param([string]$Payload, [hashtable]$Env = @{})
      $previous = $ErrorActionPreference
      $ErrorActionPreference = "Continue"
      $saved = @{}
      foreach ($k in $Env.Keys) { $saved[$k] = [System.Environment]::GetEnvironmentVariable($k); [System.Environment]::SetEnvironmentVariable($k, $Env[$k]) }
      try {
        # /bin/sh by absolute path: one case below narrows PATH deliberately,
        # and resolving the shell through PATH would then fail to launch the
        # shim at all -- testing the harness rather than the hook.
        $out = ($Payload | & /bin/sh $shim 2>&1)
        $code = $LASTEXITCODE
      } finally {
        foreach ($k in $saved.Keys) { [System.Environment]::SetEnvironmentVariable($k, $saved[$k]) }
        $ErrorActionPreference = $previous
      }
      return [pscustomobject]@{ ExitCode = $code; Text = (($out | ForEach-Object { [string]$_ }) -join "`n").Trim() }
    }

    $env = @{ AXIOM_PWSH = $pwshExe; CLAUDE_PLUGIN_ROOT = $repo }

    $off = New-HookProject -Name "shim-off" -OptIn $false
    $r = Invoke-Shim -Payload (New-Payload -Project $off -FilePath "src/other/x.ts") -Env $env
    Assert-True "the shim is silent when the project has not opted in" ($r.Text -eq "" -and $r.ExitCode -eq 0) ($r.Text)

    $on = New-HookProject -Name "shim-on" -OptIn $true
    $r = Invoke-Shim -Payload (New-Payload -Project $on -FilePath "src/other/x.ts") -Env $env
    Assert-True "the shim reports through to the advisory when opted in" ($r.Text -match "scope advisory") ($r.Text)

    # No PowerShell available is a normal state for a plugin user who never
    # installed it. It must mean "no advisory", never "broken edit".
    #
    # Simulated with a PATH containing every utility the shim needs and no
    # PowerShell. Emptying PATH outright would make grep and sed vanish too,
    # and the shim would exit 0 for the wrong reason -- passing the assertion
    # while proving nothing about the case it claims to cover.
    $fakeBin = Join-Path $script:sandbox "bin-without-pwsh"
    New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null
    foreach ($tool in @("sh", "sed", "grep", "cat", "dirname", "head", "pwd", "command")) {
      $real = (& /usr/bin/which $tool 2>$null | Select-Object -First 1)
      if ($real -and (Test-Path -LiteralPath $real)) {
        & ln -s $real (Join-Path $fakeBin $tool) 2>&1 | Out-Null
      }
    }
    $r = Invoke-Shim -Payload (New-Payload -Project $on -FilePath "src/other/x.ts") `
      -Env @{ AXIOM_PWSH = "/nonexistent/pwsh"; CLAUDE_PLUGIN_ROOT = $repo; PATH = $fakeBin }
    Assert-True "no PowerShell on the host means no advisory, not a failure" `
      ($r.ExitCode -eq 0) ("exit=" + $r.ExitCode + " " + $r.Text)
    Assert-True "…and it stays silent rather than printing an error" `
      ($r.Text -eq "") ($r.Text)

    $r = Invoke-Shim -Payload "" -Env $env
    Assert-True "the shim tolerates an empty payload" ($r.ExitCode -eq 0 -and $r.Text -eq "") ($r.Text)

    # The disabled path runs on every Write/Edit for every user who installed
    # the plugin and never enabled this. It must not start PowerShell.
    $shimSource = [System.IO.File]::ReadAllText($shim)
    $optinIndex = $shimSource.IndexOf("scope_advisory")
    $pwshIndex = $shimSource.IndexOf("pwsh_bin")
    Assert-True "the opt-in check happens before PowerShell is ever located" `
      ($optinIndex -gt 0 -and $pwshIndex -gt $optinIndex) `
      ("optin@$optinIndex pwsh@$pwshIndex")
  } else {
    Write-Host "[SKIP] shell shim not exercised on Windows (the hook command is sh-based)"
  }

  # ---- The registration -------------------------------------------------

  $hooksJsonPath = Join-Path $repo "hooks/hooks.json"
  Assert-True "the plugin registers the hook" (Test-Path -LiteralPath $hooksJsonPath)
  $hooksJson = Get-Content -LiteralPath $hooksJsonPath -Raw | ConvertFrom-Json
  Assert-True "…on PreToolUse" ($null -ne $hooksJson.hooks.PreToolUse)
  Assert-True "…scoped to editing tools rather than every tool call" `
    ([string]@($hooksJson.hooks.PreToolUse)[0].matcher -match "Write|Edit") `
    ("matcher=" + [string]@($hooksJson.hooks.PreToolUse)[0].matcher)
  Assert-True "…via `${CLAUDE_PLUGIN_ROOT}, not a hardcoded path" `
    ([string]@(@($hooksJson.hooks.PreToolUse)[0].hooks)[0].command -match [regex]::Escape('${CLAUDE_PLUGIN_ROOT}'))
  Assert-True "…with a timeout, so a wedged advisory cannot hang an edit" `
    ($null -ne @(@($hooksJson.hooks.PreToolUse)[0].hooks)[0].timeout)
  Assert-True "…and the registration describes itself as report-only and opt-in" `
    ([string]$hooksJson.description -match "(?i)report-only" -and [string]$hooksJson.description -match "(?i)opt-in")
} finally {
  if (Test-Path -LiteralPath $script:sandbox) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { Remove-Item -LiteralPath $script:sandbox -Recurse -Force -ErrorAction SilentlyContinue } finally { $ErrorActionPreference = $previous }
  }
}

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail"
if ($fail -gt 0) { exit 1 }
exit 0
