

<#
.SYNOPSIS
    Wrapper for GitHub Actions. Calls RunMissingCheckWithGCLI.ps1,
    captures its output & exit code, and writes step outputs:
      passed         (true | false)
      missing-files  (comma‑separated list)
#>
#Requires -Version 7.0
[CmdletBinding()]

param(
    [Parameter(Mandatory)][string]$LVVersion,
    [Parameter(Mandatory)][ValidateSet('32','64')][string]$Arch,
    [Parameter(Mandatory)][string]$ProjectFile
)

$ErrorActionPreference = 'Stop'
Write-Host "ℹ️  Wrapper starting ..."

$helperPath = Join-Path $PSScriptRoot 'RunMissingCheckWithGCLI.ps1'
if (-not (Test-Path $helperPath)) {
    Write-Host "❌  Helper script not found: $helperPath"
    exit 100
}

# ---------- invoke helper & capture stdout ----------
$helperOutput = & $helperPath -LVVersion $LVVersion -Arch $Arch -ProjectFile $ProjectFile
$helperExit   = $LASTEXITCODE

# ensure LabVIEW is closed (redundant if helper already quit it)
& g-cli --lv-ver $LVVersion --arch $Arch QuitLabVIEW | Out-Null

# ---------- determine pass/fail ----------
$passed     = ($helperExit -eq 0)
$passedStr  = $passed.ToString().ToLower()

# ---------- build missing‑file CSV ----------
$missingLines = $helperOutput |
                ForEach-Object { $_.Trim() } |
                Where-Object   { $_ -ne '' -and $_ -notmatch '^INFO:' }

$missingCsv   = ($missingLines -join ',')

Write-Host "ℹ️  Passed        : $passedStr"
Write-Host "ℹ️  Missing files : $missingCsv"

# ---------- write GitHub step outputs ----------
if ($env:GITHUB_OUTPUT) {
    Add-Content -Path $env:GITHUB_OUTPUT -Value "passed=$passedStr"
    Add-Content -Path $env:GITHUB_OUTPUT -Value "missing-files=$missingCsv"
}

# ---------- propagate failure if missing files ----------
if (-not $passed) {
    Write-Host "❌  Failing step because missing files were detected."
    exit $helperExit
}

Write-Host "✅  Action completed successfully."
