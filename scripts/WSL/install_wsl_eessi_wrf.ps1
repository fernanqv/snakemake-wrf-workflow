#Requires -Version 5.1

<#
.SYNOPSIS
Creates a complete Ubuntu WSL2 environment with EESSI and WRF.

.EXAMPLE
PowerShell (Administrator):
  Set-ExecutionPolicy -Scope Process Bypass
  .\scripts\install_wsl_eessi_wrf.ps1

.NOTES
Author: Valvanuz Fernández <valvanuz.fernandez@unican.es>
The script never unregisters or overwrites an existing WSL distribution.
#>

[CmdletBinding()]
param(
    [string]$DistroName = "Ubuntu-EESSI-WRF",
    [string]$LinuxUser = "wrf",
    [string]$InstallRoot = "C:\WSL",
    [string]$UbuntuVersion = "24.04.4",
    [string]$EessiVersion = "2025.06",
    [string]$WrfModule = "WRF/4.6.1-foss-2024a-dmpar",
    [int]$CvmfsQuotaMB = 10000,
    [string]$RepositoryPath = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function ConvertTo-BashLiteral([string]$Value) {
    $singleQuote = [char]39
    $replacement = "$singleQuote`"$singleQuote`"$singleQuote"
    return $singleQuote + $Value.Replace([string]$singleQuote, $replacement) + $singleQuote
}

function Invoke-WSL {
    param(
        [Parameter(Mandatory)][string[]]$Arguments
    )

    & wsl.exe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "wsl.exe failed with exit code ${LASTEXITCODE}: $($Arguments -join ' ')"
    }
}

$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this script from PowerShell as Administrator."
}

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw "wsl.exe is unavailable. Enable the Windows Subsystem for Linux feature and rerun this script after restarting Windows."
}

$RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
$LinuxSetupScript = Join-Path $RepositoryPath "scripts\setup_wsl_eessi.sh"
if (-not (Test-Path -LiteralPath $LinuxSetupScript -PathType Leaf)) {
    throw "Missing Linux provisioning script: $LinuxSetupScript"
}

Write-Step "Checking and updating WSL"
& wsl.exe --status | Out-Host
if ($LASTEXITCODE -ne 0) {
    Write-Host "WSL components are not ready. Installing them now..."
    & wsl.exe --install --no-distribution
    if ($LASTEXITCODE -ne 0) {
        throw "WSL component installation failed with exit code $LASTEXITCODE."
    }
    Write-Host "Restart Windows and run this script again to continue."
    exit 3010
}
Invoke-WSL -Arguments @("--update")
Invoke-WSL -Arguments @("--set-default-version", "2")

$existingDistros = @(& wsl.exe --list --quiet) | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$distroExists = $existingDistros -contains $DistroName
$distroDirectory = Join-Path $InstallRoot $DistroName

if (-not $distroExists) {
    if ((Test-Path -LiteralPath $distroDirectory) -and
        (Get-ChildItem -LiteralPath $distroDirectory -Force -ErrorAction SilentlyContinue)) {
        throw "Installation directory exists and is not empty: $distroDirectory"
    }

    Write-Step "Downloading the official Ubuntu $UbuntuVersion WSL image"
    $downloadDirectory = Join-Path $InstallRoot "downloads"
    New-Item -ItemType Directory -Force -Path $downloadDirectory | Out-Null
    New-Item -ItemType Directory -Force -Path $distroDirectory | Out-Null

    $imageName = "ubuntu-$UbuntuVersion-wsl-amd64.wsl"
    $imagePath = Join-Path $downloadDirectory $imageName
    $releaseBase = "https://releases.ubuntu.com/24.04"

    if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) {
        Invoke-WebRequest -Uri "$releaseBase/$imageName" -OutFile $imagePath
    }

    Write-Step "Verifying the Ubuntu image checksum"
    $checksums = (Invoke-WebRequest -Uri "$releaseBase/SHA256SUMS").Content
    $checksumLine = ($checksums -split "`n" | Where-Object { $_ -match [regex]::Escape($imageName) } | Select-Object -First 1)
    if (-not $checksumLine) {
        throw "Could not find $imageName in Ubuntu SHA256SUMS."
    }
    $expectedHash = ($checksumLine.Trim() -split '\s+')[0].ToLowerInvariant()
    $actualHash = (Get-FileHash -LiteralPath $imagePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        throw "Ubuntu image checksum mismatch. Delete $imagePath and rerun the script."
    }

    Write-Step "Installing $DistroName as a new WSL2 distribution"
    Invoke-WSL -Arguments @(
        "--install", "--from-file", $imagePath,
        "--name", $DistroName,
        "--location", $distroDirectory,
        "--version", "2", "--no-launch"
    )
}
else {
    Write-Step "Distribution $DistroName already exists; reusing it without overwriting it"
}

Write-Step "Initializing Ubuntu and locating the Linux setup script"
Invoke-WSL -Arguments @("-d", $DistroName, "-u", "root", "--", "true")
$setupPathInWSL = (& wsl.exe -d $DistroName -u root -- wslpath -a $LinuxSetupScript).Trim()
if ($LASTEXITCODE -ne 0 -or -not $setupPathInWSL) {
    throw "Could not translate the setup script path into WSL."
}

Write-Step "Installing Ubuntu packages, CernVM-FS, EESSI, MPI and WRF"
Invoke-WSL -Arguments @(
    "-d", $DistroName, "-u", "root", "--",
    "env", "TARGET_USER=$LinuxUser", "EESSI_VERSION=$EessiVersion",
    "WRF_MODULE=$WrfModule", "CVMFS_QUOTA_MB=$CvmfsQuotaMB",
    "bash", $setupPathInWSL
)

Write-Step "Restarting $DistroName to verify automatic EESSI mounting"
Invoke-WSL -Arguments @("--terminate", $DistroName)
Start-Sleep -Seconds 2
Invoke-WSL -Arguments @(
    "-d", $DistroName, "-u", "root", "--",
    "bash", "-lc", "cvmfs_config probe software.eessi.io"
)

Write-Step "Copying the current repository into the Linux filesystem"
$repositoryPathInWSL = (& wsl.exe -d $DistroName -- wslpath -a $RepositoryPath).Trim()
if ($LASTEXITCODE -ne 0 -or -not $repositoryPathInWSL) {
    throw "Could not translate the repository path into WSL."
}

$linuxRepository = "/home/$LinuxUser/src/snakemake-wrf-workflow"
$copyCommand = @(
    "mkdir -p $(ConvertTo-BashLiteral $linuxRepository)",
    "rsync -a --exclude=.snakemake -- $(ConvertTo-BashLiteral ($repositoryPathInWSL + '/')) $(ConvertTo-BashLiteral ($linuxRepository + '/'))",
    "chown -R $(ConvertTo-BashLiteral ($LinuxUser + ':' + $LinuxUser)) $(ConvertTo-BashLiteral $linuxRepository)",
    "cd $(ConvertTo-BashLiteral $linuxRepository)",
    "git config core.autocrlf true",
    "git status --short --branch"
) -join " && "
Invoke-WSL -Arguments @("-d", $DistroName, "-u", "root", "--", "bash", "-lc", $copyCommand)

Write-Step "Performing the final WRF verification"
$verificationCommand = @(
    "source /cvmfs/software.eessi.io/versions/$EessiVersion/init/bash >/dev/null",
    "module load $(ConvertTo-BashLiteral $WrfModule)",
    "command -v wrf.exe",
    "command -v real.exe",
    "command -v mpirun",
    "cvmfs_config probe software.eessi.io"
) -join " && "
Invoke-WSL -Arguments @("-d", $DistroName, "-u", $LinuxUser, "--", "bash", "-lc", $verificationCommand)

$windowsLinuxHome = "\\wsl.localhost\$DistroName\home\$LinuxUser"
Write-Host "`nInstallation completed successfully." -ForegroundColor Green
Write-Host "Open the environment with:  wsl.exe -d $DistroName"
Write-Host "Linux repository:           $linuxRepository"
Write-Host "Windows access:             $windowsLinuxHome"
