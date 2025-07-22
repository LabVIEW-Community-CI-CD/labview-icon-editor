# ----------------------------------------
# Script: Invoke-MissingInProjectCLI.ps1
# Description: Launches the MissingInProjectCLI LabVIEW VI via the G-CLI tool 
#              to check a LabVIEW project for missing files.
# Usage (local test example):
#    .\Invoke-MissingInProjectCLI.ps1 -LVVersion 2021 -Arch 64 -ProjectFile "C:\path\to\project.lvproj"
# ----------------------------------------

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$LVVersion,    # LabVIEW version (e.g. "2021")

    [Parameter(Mandatory=$true)]
    [ValidateSet(32, 64)]
    [int]$Arch,            # Bitness: 32 or 64

    [Parameter(Mandatory=$true)]
    [string]$ProjectFile   # Path to the .lvproj file to inspect
)

# Start of script execution
Write-Host "ℹ️ Starting Invoke-MissingInProjectCLI.ps1..."
# Example output: ℹ️ Starting Invoke-MissingInProjectCLI.ps1...

# Determine script directory for reliable file access
$ScriptDir = $PSScriptRoot  # The directory where this script resides:contentReference[oaicite:2]{index=2}
Write-Host "ℹ️ Script directory is $ScriptDir"
# Example output: ℹ️ Script directory is D:\Actions\MissingInProject

# Validate that G-CLI is installed and accessible
$gcliPath = Get-Command g-cli -ErrorAction SilentlyContinue
if (-not $gcliPath) {
    Write-Host "❌ ERROR: 'g-cli' command not found. Ensure G-CLI is installed and in your PATH."
    exit 1
}
Write-Host "ℹ️ Found g-cli at $($gcliPath.Source)"
# Example output: ℹ️ Found g-cli at C:\Program Files\GCLI\g-cli.exe

# Build path to the LabVIEW VI that should be in the action directory
$viPath = Join-Path -Path $ScriptDir -ChildPath 'MissingInProjectCLI.vi'
if (-not (Test-Path $viPath)) {
    Write-Host "❌ ERROR: Required VI file not found at `$viPath`. The file should exist alongside the script."
    exit 1
}
Write-Host "ℹ️ Found LabVIEW VI at $viPath"
# Example output: ℹ️ Found LabVIEW VI at D:\Actions\MissingInProject\MissingInProjectCLI.vi

# If the project file path is not absolute, you might want to resolve it relative to current directory or a base path.
# (For local testing, we assume an absolute or correct path is provided. In a GitHub Action, this was handled in a prior step.)

# Check that the provided project file actually exists
if (-not (Test-Path $ProjectFile)) {
    Write-Host "❌ ERROR: Specified project file not found: $ProjectFile"
    exit 1
}
Write-Host "ℹ️ Project file to check: $ProjectFile"
# Example output: ℹ️ Project file to check: C:\Users\Runner\work\repo\lv_icon.lvproj

# Invoke G-CLI to run the LabVIEW VI, passing the project file as an argument
Write-Host "ℹ️ Invoking g-cli for LabVIEW $LVVersion ($Arch-bit) to run MissingInProjectCLI.vi..."
# Example output: ℹ️ Invoking g-cli for LabVIEW 2021 (64-bit) to run MissingInProjectCLI.vi...
try {
    # Execute g-cli with appropriate arguments. The `--arch` flag is used for bitness (available in G-CLI 3.0+).
    # The '--' separator indicates that everything following it should be passed as arguments to the VI.
    $gcliOutput = & g-cli --lv-ver $LVVersion --arch $Arch "`"$viPath`"" -- "`"$ProjectFile`"" 2>&1 | Tee-Object -Variable gcliOutput
    # Note: We wrap paths in quotes in case they contain spaces.
}
catch {
    Write-Host "❌ ERROR: Failed to start g-cli:`n$($_.Exception.Message)"
    exit 1
}

# Capture the exit code from G-CLI execution
$exitCode = $LASTEXITCODE

# Log all output from G-CLI (already displayed in real-time by Tee-Object). 
# In a real scenario, you might parse $gcliOutput here to extract specific results.
Write-Host "ℹ️ G-CLI process exited with code $exitCode"
# Example output (if success): ℹ️ G-CLI process exited with code 0
# Example output (if failure): ℹ️ G-CLI process exited with code 1

# Determine success/failure and exit accordingly
if ($exitCode -eq 0) {
    Write-Host "✅ G-CLI completed successfully. No missing files detected by the VI."
    # In a GitHub Action, we might set output variables here based on $gcliOutput (e.g., passed=true).
    exit 0
}
else {
    Write-Host "❌ G-CLI (or the VI) reported an error. Exiting with code $exitCode."
    # In a GitHub Action, we could parse $gcliOutput for missing file list and set outputs before exiting.
    exit $exitCode
}