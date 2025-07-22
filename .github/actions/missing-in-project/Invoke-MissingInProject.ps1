<#
.SYNOPSIS
    Run MissinInProjectCLI.vi via g‑cli and surface the result to GitHub.

.PARAMETER LVVersion
    LabVIEW version to pass to g‑cli (--lv-ver).

.PARAMETER Arch
    Bitness to pass to g‑cli (--arch).

.PARAMETER ProjectFile
    Full path to the .lvproj file; default is handled by the caller.

.NOTES
    - Mimics the pattern used in Close_LabVIEW.ps1 (Invoke‑Expression + exit‑code check).
    - Outputs two GitHub step outputs: passed, missing-files.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$LVVersion,

    [Parameter(Mandatory = $true)]
    [string]$Arch,

    [Parameter(Mandatory = $true)]
    [string]$ProjectFile
)

# -------------------------------------------------------------------------
# Validate paths
# -------------------------------------------------------------------------
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$VIPath    = Join-Path $ScriptDir 'MissinInProjectCLI.vi'

if (-not (Test-Path $VIPath)) {
    Write-Error "VI not found at $VIPath."
    exit 2
}

if (-not (Test-Path $ProjectFile)) {
    Write-Error "Project file not found at $ProjectFile."
    exit 3
}

# -------------------------------------------------------------------------
# Build and execute the g‑cli command
# -------------------------------------------------------------------------
$command = @"
g-cli --lv-ver $LVVersion --arch $Arch "`"$VIPath`"" "`"$ProjectFile`""
"@

Write-Output "Executing:"
Write-Output $command

try {
    $json = Invoke-Expression $command

    if ($LASTEXITCODE -ne 0) {
        Write-Error "g‑cli exited with code $LASTEXITCODE."
        exit $LASTEXITCODE
    }

    $result = $json | ConvertFrom-Json
}
catch {
    Write-Error "Failed to run g‑cli or parse JSON output."
    exit 4
}

# -------------------------------------------------------------------------
# Surface results to GitHub Actions
# -------------------------------------------------------------------------
$passed  = [string]$result.Passed
$missing = $result.MissingFiles

if ($Env:GITHUB_OUTPUT) {
    "passed=$passed"            | Out-File -FilePath $Env:GITHUB_OUTPUT -Append
    "missing-files=$missing"    | Out-File -FilePath $Env:GITHUB_OUTPUT -Append
}

if (-not $result.Passed) {
    Write-Error "Missing files detected:`n$missing"
    exit 1
}

Write-Host "✅ All files present."
exit 0
