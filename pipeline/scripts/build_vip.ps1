<#
This PowerShell script automates the process of updating a LabVIEW VIPB file’s 
“Display Information” fields using the given JSON data and then builds the 
VI Package via g-cli.

Key Steps:
1. Resolves paths for your VIPB file and LabVIEW project directory.
2. (Optionally) creates the release notes file if it does not exist.
3. Calculates the final LabVIEW version string (e.g., "21.0 (64-bit)").
4. Parses and updates the DisplayInformationJSON ("Package Version" field) 
   with Major, Minor, Patch, Build from script parameters.
5. Calls a LabVIEW VI (via g-cli) to update the VIPB file’s display information 
   using the updated JSON.
6. Builds the VI Package (again via g-cli), injecting the same version info 
   (major, minor, patch, build) and release notes.
7. Handles errors by outputting error details in JSON format.

Example Usage:
.\build_vip.ps1 `
  -SupportedBitness "64" `
  -RelativePath "C:\labview-icon-editor-fork" `
  -VIPBPath "Tooling\deployment\NI Icon editor.vipb" `
  -MinimumSupportedLVVersion 2021 `
  -LabVIEWMinorRevision 3 `
  -Major 1 `
  -Minor 0 `
  -Patch 0 `
  -Build 2 `
  -Commit "Placeholder" `
  -ReleaseNotesFile "C:\labview-icon-editor-fork\Tooling\deployment\release_notes.md" `
  -DisplayInformationJSON '{"Package Version":{"major":0,"minor":0,"patch":0,"build":0},"Product Name":"","Company Name":"","Author Name (Person or Company)":"","Product Homepage (URL)":"","Legal Copyright":"","License Agreement Name":"","Product Description Summary":"","Product Description":"","Release Notes - Change Log":""}'

#>

param (
    [string]$SupportedBitness,
    [string]$RelativePath,
    [string]$VIPBPath,

    [int]$MinimumSupportedLVVersion,

    [ValidateSet("0","3")]
    [string]$LabVIEWMinorRevision = "0",

    [int]$Major,
    [int]$Minor,
    [int]$Patch,
    [int]$Build,
    [string]$Commit,
    [string]$ReleaseNotesFile,

    [Parameter(Mandatory=$true)]
    [string]$DisplayInformationJSON
)

# 1) Resolve paths
try {
    $ResolvedRelativePath = Resolve-Path -Path $RelativePath -ErrorAction Stop
    $ResolvedVIPBPath = Join-Path -Path $ResolvedRelativePath -ChildPath $VIPBPath -ErrorAction Stop
}
catch {
    $errorObject = [PSCustomObject]@{
        error      = "Error resolving paths. Ensure RelativePath and VIPBPath are valid."
        exception  = $_.Exception.Message
        stackTrace = $_.Exception.StackTrace
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

# 2) Create release notes if needed
if (-not (Test-Path $ReleaseNotesFile)) {
    Write-Host "Release notes file '$ReleaseNotesFile' does not exist. Creating it..."
    New-Item -ItemType File -Path $ReleaseNotesFile -Force | Out-Null
}

# 3) Calculate the LabVIEW version string
$lvNumericMajor    = $MinimumSupportedLVVersion - 2000
$lvNumericVersion  = "$($lvNumericMajor).$LabVIEWMinorRevision"
if ($SupportedBitness -eq "64") {
    $VIP_LVVersion_A = "$lvNumericVersion (64-bit)"
}
else {
    $VIP_LVVersion_A = $lvNumericVersion
}
Write-Output "Building VI Package for LabVIEW $VIP_LVVersion_A..."

# 4) Parse and update the DisplayInformationJSON
try {
    $jsonObj = $DisplayInformationJSON | ConvertFrom-Json
}
catch {
    $errorObject = [PSCustomObject]@{
        error      = "Failed to parse DisplayInformationJSON into valid JSON."
        exception  = $_.Exception.Message
        stackTrace = $_.Exception.StackTrace
    }
    $errorObject | ConvertTo-Json -Depth 10
    exit 1
}

# If "Package Version" doesn't exist, create it as a subobject
if (-not $jsonObj.'Package Version') {
    $jsonObj | Add-Member -MemberType NoteProperty -Name 'Package Version' -Value ([PSCustomObject]@{
        major = $Major
        minor = $Minor
        patch = $Patch
        build = $Build
    })
}
else {
    # "Package Version" exists, so just overwrite its fields
    $jsonObj.'Package Version'.major = $Major
    $jsonObj.'Package Version'.minor = $Minor
    $jsonObj.'Package Version'.patch = $Patch
    $jsonObj.'Package Version'.build = $Build
}

# Re-convert to a JSON string with a comfortable nesting depth
$UpdatedDisplayInformationJSON = $jsonObj | ConvertTo-Json -Depth 5

# 5) Build and execute the g‑cli commands ────────────────
#    We invoke each command individually, check $LASTEXITCODE,
#    and stop on first failure.

# Helper to run g‑cli and abort on error
function Invoke-GCliSafely {
    param (
        [string[]]$Args,          # full argument list, first element is the exe
        [string]  $FailureLabel   # short description for error object
    )

    # Pretty‑print the command we’re about to run
    Write-Output ('{0} {1}' -f $Args[0], ($Args[1..($Args.Count-1)] -join ' '))

    & $Args[0] $Args[1..($Args.Count-1)]
    if ($LASTEXITCODE -ne 0) {
        # Wrap the failure the same way earlier errors are wrapped
        $errorObject = [pscustomobject]@{
            error      = "$FailureLabel failed."
            exitCode   = $LASTEXITCODE
        }
        $errorObject | ConvertTo-Json -Depth 5
        exit $LASTEXITCODE
    }
}

# ── First g‑cli: update the VIPB display information
$modifyArgs = @(
    'g-cli'
    '--lv-ver'  , $MinimumSupportedLVVersion
    '--arch'    , $SupportedBitness
    "$($ResolvedRelativePath)\Tooling\deployment\Modify_VIPB_Display_Information.vi"
    '--'        , $ResolvedVIPBPath
    $VIP_LVVersion_A
    $UpdatedDisplayInformationJSON
)
Invoke-GCliSafely -Args $modifyArgs -FailureLabel 'Modify_VIPB_Display_Information.vi'

# ── Second g‑cli: build the VI Package
$buildArgs = @(
    'g-cli'
    '--lv-ver'      , $MinimumSupportedLVVersion
    '--arch'        , $SupportedBitness
    'vipb'          , '--'
    '--buildspec'   , $ResolvedVIPBPath
    '-v'            , "$Major.$Minor.$Patch.$Build"
    '--release-notes', $ReleaseNotesFile
    '--timeout'     , '300'
)
Invoke-GCliSafely -Args $buildArgs -FailureLabel 'vipb build'

Write-Host "Successfully built VI package: $ResolvedVIPBPath"