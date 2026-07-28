param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

. (Join-Path $RepoPath "scripts/lib/markdown-files.ps1")
. (Join-Path $RepoPath "scripts/lib/pwsh-host.ps1")

$pass = 0
$fail = 0

function Assert-Check {
  param(
    [string]$Name,
    [bool]$Condition
  )

  if ($Condition) {
    $script:pass++
    Write-Host "[PASS] $Name"
  } else {
    $script:fail++
    Write-Host "[FAIL] $Name"
  }
}

$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pmo doctor markdown " + [guid]::NewGuid().ToString("N"))
$integrationMarkdown = Join-Path $RepoPath ("doctor-invalid-link-" + [guid]::NewGuid().ToString("N") + ".md")

try {
  $nested = Join-Path $workRoot "nested"
  New-Item -ItemType Directory -Force -Path $nested | Out-Null

  $thaiMarkdown = Join-Path $nested "thai.md"
  $thaiText = -join (
    @(0x0E2B, 0x0E31, 0x0E27, 0x0E02, 0x0E49, 0x0E2D, 0x0E20, 0x0E32, 0x0E29, 0x0E32, 0x0E44, 0x0E17, 0x0E22) |
      ForEach-Object { [char]$_ }
  )
  "$thaiText`n`n[missing](missing.md)" |
    Set-Content -LiteralPath $thaiMarkdown -Encoding UTF8

  # The payload deliberately resembles the byte sequence that made the
  # repository's real PPTX look like a Markdown link to Windows PowerShell 5.1.
  # Discovery must ignore it solely because it is not a Markdown file.
  $binaryPath = Join-Path $workRoot "deck.pptx"
  $binaryPayload = [System.Text.Encoding]::ASCII.GetBytes(
    "PK`0`0[slide](" + [char]0x11 + "bad:path)`0compressed"
  )
  [System.IO.File]::WriteAllBytes($binaryPath, $binaryPayload)

  $markdownFiles = @(Get-MarkdownFiles -RootPath $workRoot)
  Assert-Check "discovery returns only Markdown files" (
    $markdownFiles.Count -eq 1 -and $markdownFiles[0].FullName -eq $thaiMarkdown
  )
  Assert-Check "PPTX payload is excluded from Markdown discovery" (
    @($markdownFiles | Where-Object { $_.Extension -ieq ".pptx" }).Count -eq 0
  )

  $markdownText = Read-MarkdownText -Path $thaiMarkdown -Raw
  Assert-Check "UTF-8 Thai Markdown survives reading" ($markdownText -match [regex]::Escape($thaiText))

  $invalidTarget = "bad" + [char]0x01 + "path.md"
  $invalidResult = Test-MarkdownLocalLinkPath -BasePath $nested -Target $invalidTarget
  Assert-Check "illegal local-link path is rejected without throwing" (-not $invalidResult.valid_path)

  $missingResult = Test-MarkdownLocalLinkPath -BasePath $nested -Target "missing.md"
  Assert-Check "valid missing local-link path remains reportable" (
    $missingResult.valid_path -and -not $missingResult.exists
  )

  $spaceDirectory = Join-Path $nested "space dir"
  New-Item -ItemType Directory -Force -Path $spaceDirectory | Out-Null
  $encodedResult = Test-MarkdownLocalLinkPath -BasePath $nested -Target "space%20dir"
  Assert-Check "percent-encoded Markdown path resolves on disk" (
    $encodedResult.valid_path -and $encodedResult.exists
  )

  $invalidMarkdownTarget = "bad" + [char]0x01 + "path.md"
  ("[invalid](" + $invalidMarkdownTarget + ")") |
    Set-Content -LiteralPath $integrationMarkdown -Encoding UTF8

  $ps = Get-PowerShellHost
  if (-not $ps) {
    throw (Get-PowerShellHostMissingMessage)
  }
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $doctorOutput = & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoPath "scripts/pmo-doctor.ps1") -RepoPath $RepoPath 2>&1
  $doctorExitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorActionPreference
  $doctorText = $doctorOutput | Out-String
  $integrationName = Split-Path -Leaf $integrationMarkdown

  Assert-Check "doctor reports an invalid Markdown target without failing" (
    $doctorExitCode -eq 0 -and
    $doctorText -match ([regex]::Escape($integrationName) + " line 1 -> invalid local link target")
  )
  Assert-Check "doctor emits no illegal-path exception" ($doctorText -notmatch "Illegal characters in path")
} finally {
  if (Test-Path -LiteralPath $integrationMarkdown) {
    Remove-Item -LiteralPath $integrationMarkdown -Force
  }
  if (Test-Path -LiteralPath $workRoot) {
    Remove-Item -LiteralPath $workRoot -Recurse -Force
  }
}

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail"

if ($fail -gt 0) {
  exit 1
}
exit 0
