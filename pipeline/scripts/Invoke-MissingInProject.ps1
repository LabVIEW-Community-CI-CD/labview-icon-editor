<#
.SYNOPSIS
  Runs MissinInProjectCLI.vi via g‑cli, pointing at <ProjectPath>/lv_icon.lvproj.

.PARAMETER ProjectPath
  Folder containing lv_icon.lvproj. Defaults to repo root.

.PARAMETER LVVersion
  LabVIEW version (e.g. '2021' or '2023').

.PARAMETER Bitness
  Bitness to pass to g‑cli (32 or 64).
#>
param(
  [Parameter(Mandatory=$false)]
  [string]$ProjectPath = $Env:GITHUB_WORKSPACE,

  [Parameter(Mandatory=$true)]
  [ValidateSet('2021','2023')]
  [string]$LVVersion,

  [Parameter(Mandatory=$true)]
  [ValidateSet('32','64')]
  [string]$Bitness
)

function Assert-PathExists {
  param($Path, $Description)
  if (-not (Test-Path $Path)) {
    Write-Host "ERROR: $Description not found at $Path" -ForegroundColor Red
    exit 1
  }
}

function Execute-Script {
  param($Exe, $Arguments)
  Write-Host "▶ $Exe $Arguments" -ForegroundColor Cyan
  & $Exe $Arguments
  if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Exit code $LASTEXITCODE from $Exe" -ForegroundColor Red
    exit $LASTEXITCODE
  }
}

try {
  # 1) Validate project and .lvproj
  Assert-PathExists $ProjectPath "Project folder"
  $lvproj = Join-Path $ProjectPath 'lv_icon.lvproj'
  Assert-PathExists $lvproj "lv_icon.lvproj"

  # 2) Locate the VI in your action folder
  $actionDir = Join-Path $Env:GITHUB_WORKSPACE '.github/actions/missing-in-project'
  $viFile    = Join-Path $actionDir 'MissinInProjectCLI.vi'
  Assert-PathExists $viFile "MissinInProjectCLI.vi"

  # 3) Build and invoke g‑cli
  $args = "--lv-ver $LVVersion --arch $Bitness `"$viFile`" `"$lvproj`""
  Execute-Script 'g-cli' $args

  Write-Host "✅ Missing‑In‑Project check passed." -ForegroundColor Green
}
catch {
  Write-Host "❌ $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
