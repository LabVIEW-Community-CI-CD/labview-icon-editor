#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LVVersion,
    [Parameter(Mandatory)][ValidateSet('32','64')][string]$Arch,
    [Parameter(Mandatory)][string]$ProjectFile
)

$ErrorActionPreference = 'Stop'

# ---------- GLOBAL STATE ----------
$Script:HelperExitCode     = 0
$Script:MissingFileLines   = @()   # lines representing missing files
$Script:ParsingFailed      = $false    # true if we couldn't interpret helper output

# Pattern that identifies a meaningful “missing file” line
$MissingFilterPattern = '^(?!INFO:).+'   # anything non-empty & not starting with INFO:

$HelperPath = Join-Path $PSScriptRoot 'RunMissingCheckWithGCLI.ps1'
if (-not (Test-Path $HelperPath)) {
    Write-Error "Helper script not found: $HelperPath"
    exit 100
}

# =========================  SETUP  =========================
function Setup {
    Write-Host "=== Setup ==="
    Write-Host "LVVersion  : $LVVersion"
    Write-Host "Arch       : $Arch-bit"
    Write-Host "ProjectFile: $ProjectFile"
}

# =====================  MAIN SEQUENCE  =====================
function MainSequence {

    Write-Host "`n=== MainSequence ==="
    Write-Host "Invoking missing‑file check via helper script …`n"

    # -- call helper & capture all stdout lines --
    $outputLines = & $HelperPath -LVVersion $LVVersion -Arch $Arch -ProjectFile $ProjectFile
    $Script:HelperExitCode = $LASTEXITCODE

    # Ensure LabVIEW is closed (redundant if helper did it)
    & g-cli --lv-ver $LVVersion --arch $Arch QuitLabVIEW | Out-Null

    if ($Script:HelperExitCode -ne 0) {
        Write-Error "Helper script returned non‑zero exit code: $Script:HelperExitCode"
    }

    # Filter lines that represent missing files
    $Script:MissingFileLines = $outputLines |
                               ForEach-Object { $_.Trim() } |
                               Where-Object   { $_ -match $MissingFilterPattern }

    # If helper returned 0 but we got NO lines => success
    # If helper returned 0 but we DID get lines => there are missing files
    # If helper returned non‑zero but produced no parseable lines, treat as “g‑cli failure”
    if (($Script:HelperExitCode -ne 0) -and ($Script:MissingFileLines.Count -eq 0)) {
        $Script:ParsingFailed = $true
        return
    }

    # ----------  TABULAR REPORT  ----------
    Write-Host ""
    $col1 = "FilePath"
    $maxLen = if ($Script:MissingFileLines.Count) {
                  ($Script:MissingFileLines | Measure-Object -Maximum Length).Maximum
              } else {
                  $col1.Length
              }

    # Header
    Write-Host ($col1.PadRight($maxLen)) -ForegroundColor Cyan

    if ($Script:MissingFileLines.Count -eq 0) {
        $msg = "No missing files detected"
        Write-Host ($msg.PadRight($maxLen)) -ForegroundColor Green
    }
    else {
        foreach ($line in $Script:MissingFileLines) {
            Write-Host ($line.PadRight($maxLen)) -ForegroundColor Red
        }
    }
}

# ========================  CLEANUP  ========================
function Cleanup {
    Write-Host "`n=== Cleanup ==="
    # Nothing to delete for this action – placeholder for symmetry
}

# ====================  EXECUTION FLOW  =====================
Setup
MainSequence
Cleanup

# ====================  GH‑ACTION OUTPUTS ===================
$passed = ($Script:HelperExitCode -eq 0) -and ($Script:MissingFileLines.Count -eq 0) -and (-not $Script:ParsingFailed)
$passedStr = $passed.ToString().ToLower()
$missingCsv = ($Script:MissingFileLines -join ',')

if ($env:GITHUB_OUTPUT) {
    Add-Content -Path $env:GITHUB_OUTPUT -Value "passed=$passedStr"
    Add-Content -Path $env:GITHUB_OUTPUT -Value "missing-files=$missingCsv"
}

# =====================  FINAL EXIT CODE  ===================
if ($Script:ParsingFailed) {
    exit 1                    # g-cli or helper problem
}
elseif (-not $passed) {
    exit 2                    # missing files detected
}
else {
    exit 0                    # perfect run
}
