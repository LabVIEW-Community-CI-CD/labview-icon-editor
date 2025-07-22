<#
.SYNOPSIS
    Checks for missing items in a LabVIEW project using g-cli.

.DESCRIPTION
    This script locates its own folder, builds the path to MissingInProjectCLI.vi,
    then invokes g-cli to update Localhost.LibraryPaths based on your project INI.

.EXAMPLE
    # From your repo root, assuming this script lives in .\scripts\
    .\scripts\Invoke-MissingInProject.ps1 `
        -LVVersion "2022" `
        -SupportedBitness "64" `
        -ProjectPath "C:\Repos\MyLabVIEWProject"
#>

param(
    [string]$LVVersion,         # LabVIEW version to target (e.g. "2021", "2022")
    [string]$SupportedBitness,  # CPU bitness ("32" or "64")
    [string]$ProjectPath        # Root folder of your LabVIEW project
)

# ------------------------------------------------------------------------------
# 1) Determine the directory where this script is located.
#    $MyInvocation.MyCommand.Definition gives the path to the running .ps1 file.
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# 2) Construct the full path to the MissingInProjectCLI.vi file under the script folder.
$VIPath = Join-Path $ScriptDir '.\MissingInProjectCLI.vi'

# 3) Prepare the g-cli command, wrapping paths in quotes to handle spaces.
$gcliCmd = @"
g-cli --lv-ver $LVVersion --arch $SupportedBitness -v "$VIPath" -- "$ProjectPath"
"@

# 4) Output the exact command for logging/debugging purposes.
Write-Output "Executing command:"
Write-Output $gcliCmd

# 5) Invoke the command and handle errors.
try {
    Invoke-Expression $gcliCmd

    # 6) Check g-cli's exit code: 0 = success
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Successfully updated Localhost.LibraryPaths from INI file."
    }
    else {
        Write-Error "❌ g-cli failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}
catch {
    # 7) Catch any unexpected exceptions and report them.
    Write-Error "❌ Exception while running g-cli: $_"
    exit 1
}
