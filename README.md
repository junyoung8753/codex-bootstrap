# Codex Bootstrap

Public, no-secret bootstrap entrypoint for Junyoung's Codex setup.

This repository does not contain Codex settings, private baseline files, tokens, cookies, passwords, or credential stores. It only installs/uses official tools, asks the user to complete GitHub OAuth when needed, and then pulls the private `junyoung8753/codex-portable-baseline` repository.

## Fast Path

Run this from Windows PowerShell or PowerShell 7 on a new Windows PC:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "iwr https://raw.githubusercontent.com/junyoung8753/codex-bootstrap/main/install.ps1 -UseBasicParsing | iex"
```

## Safer Inspect-First Path

```powershell
$script = Join-Path $env:TEMP "codex-bootstrap-install.ps1"
iwr https://raw.githubusercontent.com/junyoung8753/codex-bootstrap/main/install.ps1 -OutFile $script
notepad $script
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script
```

## What It Does

- Checks that Windows is running.
- Installs GitHub CLI and Git through `winget` when they are missing.
- Starts official GitHub CLI web login when private-repo access is not already available.
- Verifies that the signed-in GitHub account can access the private baseline repo before cloning.
- Clones or updates the private `junyoung8753/codex-portable-baseline` repo.
- Copies the portable `.codex` baseline into `%USERPROFILE%\.codex`.
- Runs the private baseline's new-PC bootstrap script when available.

## What It Will Not Do

- It will not store passwords, OAuth tokens, cookies, recovery codes, or vault exports in this public repo.
- It will not make the private portable baseline public.
- It will not disable UAC, Defender, credential protections, or other broad security controls.
