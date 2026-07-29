# Shared Markdown discovery and local-link helpers for pmo-doctor.
#
# Windows PowerShell 5.1 can apply -Include inconsistently when it is combined
# with -LiteralPath and -Recurse. In this repository that allowed a tracked
# PPTX to reach the Markdown link parser. Its compressed bytes happened to look
# like a Markdown link, and Test-Path then terminated on illegal path
# characters. -Filter is evaluated by the filesystem provider and therefore
# keeps binary files out of the pipeline on every supported PowerShell host.

function Get-MarkdownFiles {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$RootPath
  )

  if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
    return @()
  }

  return @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter "*.md" -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -ieq ".md" })
}

function Read-MarkdownText {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [switch]$Raw
  )

  if ($Raw) {
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
  }
  return @(Get-Content -LiteralPath $Path -Encoding UTF8 -ErrorAction SilentlyContinue)
}

function Test-MarkdownLocalLinkPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$BasePath,

    [Parameter(Mandatory = $true)]
    [string]$Target
  )

  try {
    $decodedTarget = [System.Uri]::UnescapeDataString($Target)

    # Apply the portable subset before asking the host filesystem. Unix permits
    # several characters that Windows rejects, but Markdown checked in here
    # must remain valid on the Windows PowerShell 5.1 reference platform.
    if ($decodedTarget -match '[\x00-\x1F<>:"|?*]') {
      return [pscustomobject]@{
        valid_path = $false
        exists = $false
        resolved_path = $null
      }
    }

    $invalidPathChars = [System.IO.Path]::GetInvalidPathChars()
    if ($decodedTarget.IndexOfAny($invalidPathChars) -ge 0) {
      return [pscustomobject]@{
        valid_path = $false
        exists = $false
        resolved_path = $null
      }
    }

    $resolved = Join-Path $BasePath $decodedTarget -ErrorAction Stop
    $exists = Test-Path -LiteralPath $resolved -ErrorAction Stop
    return [pscustomobject]@{
      valid_path = $true
      exists = [bool]$exists
      resolved_path = $resolved
    }
  } catch {
    return [pscustomobject]@{
      valid_path = $false
      exists = $false
      resolved_path = $null
    }
  }
}
