# Canonical artifact SHA-256 (CR-018).
#
# One shared hashing convention for the M4-M6 artifact contracts (design
# provider input/output and externalization outgoing artifacts), so a digest
# means the same thing on every host and every checkout:
#
#   text    decode strictly as UTF-8, strip one leading UTF-8 BOM, normalize
#           CRLF/CR to LF, re-encode as UTF-8 without BOM, hash those bytes
#   binary  hash the original bytes unchanged
#
# Why: raw byte hashing made every provider digest depend on the checkout's
# line endings (LF vs CRLF) and on whether an editor wrote a BOM. A review
# recorded on one host read as stale on another. This helper keeps digests
# stable across LF/CRLF and UTF-8 BOM/no-BOM while remaining byte-sensitive
# for real content changes and for binary artifacts.
#
# The text-extension list is a narrowly documented shared constant: it mirrors
# the repository's governed text types (.gitattributes) plus the markdown and
# JSON the M4-M6 contracts digest. Unknown extensions fail safe to byte
# hashing -- a binary file with a misleading extension is never decoded.

$script:canonicalTextHashExtensions = @(
  ".md", ".markdown", ".json", ".puml", ".csv", ".txt", ".yaml", ".yml", ".html", ".htm"
)

function Test-CanonicalTextFile {
  param([string]$Path)
  $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
  return $script:canonicalTextHashExtensions -contains $extension
}

function Get-ArtifactSha256 {
  param([string]$Path)

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  if (Test-CanonicalTextFile -Path $Path) {
    $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
    $text = $null
    try {
      $text = $strictUtf8.GetString($bytes)
    } catch {
      # Not valid UTF-8 despite the extension: fail safe to byte hashing.
      $text = $null
    }
    if ($null -ne $text) {
      if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) {
        $text = $text.Substring(1)
      }
      $text = $text -replace "`r`n", "`n"
      $text = $text -replace "`r", "`n"
      $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($text)
    }
  }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    return ([System.BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}
