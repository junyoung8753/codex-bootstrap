[CmdletBinding()]
param(
    [string]$BaselineRepo = "junyoung8753/codex-portable-baseline",
    [string]$InstallRoot = (Join-Path $env:USERPROFILE "Documents\Codex"),
    [switch]$SkipGitHubLogin
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-Command {
    param([string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Add-CommonToolPaths {
    $paths = @(
        "$env:ProgramFiles\Git\cmd",
        "$env:ProgramFiles\GitHub CLI"
    )

    foreach ($path in $paths) {
        if ((Test-Path -LiteralPath $path) -and ($env:Path -notlike "*$path*")) {
            $env:Path = "$env:Path;$path"
        }
    }
}

function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$Name
    )

    if (-not (Test-Command winget)) {
        throw "winget was not found. Install 'App Installer' from Microsoft Store, then rerun this script."
    }

    Write-Step "Installing $Name with winget if needed"
    winget install --id $Id --exact --source winget --accept-source-agreements --accept-package-agreements
}

function Ensure-GitHubRepoAccess {
    param([string]$Repo)

    Write-Step "Checking private baseline access"
    gh repo view $Repo --json name *> $null
    if ($LASTEXITCODE -eq 0) {
        return
    }

    if ($SkipGitHubLogin) {
        throw "GitHub CLI cannot access $Repo. Rerun without -SkipGitHubLogin and complete GitHub OAuth."
    }

    Write-Step "Refreshing GitHub OAuth scopes for private repo access"
    gh auth refresh -h github.com -s repo
    gh repo view $Repo --json name *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub CLI still cannot access $Repo. Confirm the GitHub account has access to the private baseline repo, then rerun this script."
    }
}

if (-not $IsWindows -and $env:OS -ne "Windows_NT") {
    throw "This bootstrap currently supports Windows only."
}

New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
Add-CommonToolPaths

if (-not (Test-Command git)) {
    Install-WingetPackage -Id "Git.Git" -Name "Git"
    Add-CommonToolPaths
}

if (-not (Test-Command gh)) {
    Install-WingetPackage -Id "GitHub.cli" -Name "GitHub CLI"
    Add-CommonToolPaths
}

if (-not (Test-Command git)) {
    throw "Git is still not available on PATH. Restart PowerShell and rerun this script."
}

if (-not (Test-Command gh)) {
    throw "GitHub CLI is still not available on PATH. Restart PowerShell and rerun this script."
}

if (-not $SkipGitHubLogin) {
    Write-Step "Checking GitHub authentication"
    gh auth status -h github.com *> $null
    if ($LASTEXITCODE -ne 0) {
        gh auth login -h github.com -s repo --web
    }
}

Ensure-GitHubRepoAccess -Repo $BaselineRepo

$target = Join-Path $InstallRoot "codex-portable-baseline"
if (Test-Path -LiteralPath (Join-Path $target ".git")) {
    Write-Step "Updating private portable baseline"
    git -C $target pull --ff-only
}
elseif (Test-Path -LiteralPath $target) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $target = Join-Path $InstallRoot "codex-portable-baseline-$stamp"
    Write-Step "Existing non-git baseline path found; cloning into $target"
    gh repo clone $BaselineRepo $target
}
else {
    Write-Step "Cloning private portable baseline"
    gh repo clone $BaselineRepo $target
}

$sourceCodex = Join-Path $target ".codex"
if (-not (Test-Path -LiteralPath $sourceCodex)) {
    throw "Private baseline was cloned, but .codex was not found at $sourceCodex."
}

$destCodex = Join-Path $env:USERPROFILE ".codex"
New-Item -ItemType Directory -Force -Path $destCodex | Out-Null

Write-Step "Copying portable Codex baseline"
robocopy $sourceCodex $destCodex /E /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) {
    throw "robocopy failed with exit code $LASTEXITCODE."
}

$configPath = Join-Path $destCodex "config.toml"
$configTemplate = Join-Path $destCodex "config.template.toml"
if ((-not (Test-Path -LiteralPath $configPath)) -and (Test-Path -LiteralPath $configTemplate)) {
    Copy-Item -LiteralPath $configTemplate -Destination $configPath -Force
}

$bootstrap = Join-Path $destCodex "scripts\Invoke-CodexNewPcBootstrap.ps1"
if (Test-Path -LiteralPath $bootstrap) {
    Write-Step "Running private baseline new-PC bootstrap"
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bootstrap -InstallMissingTools -Login -LoginMcp
}
else {
    Write-Step "Private baseline copied. Restart Codex."
}

Write-Step "Done. Complete any official browser/device approvals, then restart Codex."
