@echo off
REM Cross-platform convenience wrapper around the Node CLI. It does not
REM duplicate validation logic; it locates Node and forwards to
REM cli\axiom.mjs check, preserving the exit code.
setlocal

where node >nul 2>nul
if not %ERRORLEVEL%==0 (
  echo Node.js was not found on PATH.>&2
  echo Install Node.js: https://nodejs.org>&2
  exit /b 127
)

pushd "%~dp0.."
node cli\axiom.mjs check %*
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%
