<#
.SYNOPSIS
    Ensures the Docker engine is running on a Windows runner before container
    operations. Runs under Windows PowerShell 5.1 (shell: powershell).

.DESCRIPTION
    Works around the GitHub Actions windows-2022/windows-2025 runner regression
    (actions/runner-images #13729) where, after the Docker Engine v29 rollout,
    the Docker service intermittently boots in a Stopped state because of a
    Hyper-V virtual switch creation race. Symptom:

        failed to connect to the docker API at npipe:////./pipe/docker_engine;
        ... open //./pipe/docker_engine: The system cannot find the file
        specified.

    The script probes readiness with `docker info` (not Test-Path on the named
    pipe), starts any *docker* services that are not running, and polls until
    the engine responds or the timeout elapses. It deliberately avoids any
    PowerShell 7-only syntax so it can run on the Windows PowerShell that ships
    with the runner image.

.PARAMETER TimeoutSeconds
    Maximum time to wait for the Docker engine to become ready. Default 120.

.PARAMETER PollIntervalSeconds
    Delay between readiness probes. Default 3.

.EXAMPLE
    powershell -NoProfile -File Tooling/Wait-ForDockerWindows.ps1
#>

[CmdletBinding()]
param(
    [ValidateRange(1, 3600)]
    [int]$TimeoutSeconds = 120,

    [ValidateRange(1, 60)]
    [int]$PollIntervalSeconds = 3
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Invoke-DockerSafely {
    # Runs the docker CLI without letting native stderr (e.g. the npipe error
    # emitted while the daemon is down) raise a terminating NativeCommandError
    # under $ErrorActionPreference = 'Stop'. Returns the exit code and output.
    param([Parameter(Mandatory = $true)][string[]]$DockerArgs)

    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & docker @DockerArgs 2>&1 | Out-String
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
    } catch {
        return [pscustomobject]@{ ExitCode = 1; Output = $_.Exception.Message }
    } finally {
        $ErrorActionPreference = $previous
    }
}

function Test-DockerReady {
    return ((Invoke-DockerSafely -DockerArgs @('info')).ExitCode -eq 0)
}

function Start-DockerService {
    $services = Get-Service -Name '*docker*' -ErrorAction SilentlyContinue
    if (-not $services) {
        Write-Host 'No Docker-related Windows services were found.'
        return
    }

    foreach ($service in $services) {
        Write-Host ("Docker service '{0}' status: {1}" -f $service.Name, $service.Status)
        if ($service.Status -ne 'Running') {
            try {
                Write-Host ("Starting Docker service '{0}'..." -f $service.Name)
                Start-Service -Name $service.Name
            } catch {
                Write-Warning ("Failed to start service '{0}': {1}" -f $service.Name, $_.Exception.Message)
            }
        }
    }
}

function Write-DockerDiagnostic {
    Write-Host '--- Docker service status ---'
    Get-Service -Name '*docker*' -ErrorAction SilentlyContinue |
        Format-Table -AutoSize -Property Name, Status, StartType |
        Out-String | Write-Host

    Write-Host '--- docker version ---'
    Write-Host (Invoke-DockerSafely -DockerArgs @('version')).Output

    try {
        Write-Host '--- Recent System event log (docker / hyper-v / hns / vmcompute) ---'
        $events = Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = (Get-Date).AddMinutes(-15) } -ErrorAction SilentlyContinue |
            Where-Object { $_.ProviderName -match 'docker|hyper-v|hns|vmcompute' } |
            Select-Object -First 20 -Property TimeCreated, ProviderName, Id, LevelDisplayName, Message
        if ($events) {
            $events | Format-List | Out-String | Write-Host
        } else {
            Write-Host 'No matching recent events.'
        }
    } catch {
        Write-Warning ("Could not read event logs: {0}" -f $_.Exception.Message)
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if (-not (Get-Command -Name docker -ErrorAction SilentlyContinue)) {
    Write-Error 'Docker CLI not found on PATH.' -ErrorAction Continue
    exit 1
}

Write-Host '============================================================'
Write-Host ' Ensuring Docker engine is ready (Windows)'
Write-Host (' Timeout: {0}s  Poll: {1}s' -f $TimeoutSeconds, $PollIntervalSeconds)
Write-Host '============================================================'

if (Test-DockerReady) {
    Write-Host 'Docker engine is already responding.'
    exit 0
}

Write-Host 'Docker engine not responding yet; attempting to start services...'
Start-DockerService

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$attempt = 0
while ((Get-Date) -lt $deadline) {
    $attempt++
    if (Test-DockerReady) {
        Write-Host ("Docker engine became ready after {0} attempt(s)." -f $attempt)
        exit 0
    }
    Write-Host ("Docker not ready (attempt {0}); retrying in {1}s..." -f $attempt, $PollIntervalSeconds)
    Start-Sleep -Seconds $PollIntervalSeconds
}

Write-DockerDiagnostic
Write-Error ("Docker engine did not become ready within {0} seconds." -f $TimeoutSeconds) -ErrorAction Continue
exit 1
