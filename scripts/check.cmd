@echo off
REM Cross-platform convenience wrapper around the PowerShell reference
REM implementation. It does not duplicate validation logic; it locates
REM PowerShell and forwards to scripts\run-all-checks.ps1, preserving the exit code.
setlocal

where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
  set "PS=pwsh"
) else (
  where powershell >nul 2>nul
  if %ERRORLEVEL%==0 (
    set "PS=powershell"
  ) else (
    echo PowerShell was not found on PATH.>&2
    echo Install PowerShell 7 ^(pwsh^): https://aka.ms/powershell>&2
    exit /b 127
  )
)

pushd "%~dp0.."
"%PS%" -NoProfile -ExecutionPolicy Bypass -File scripts\run-all-checks.ps1 -RepoPath . %*
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%
