#Requires -RunAsAdministrator
<#
  Étape 2/2 — Docker Desktop (moteur WSL2).
  À lancer dans PowerShell **en tant qu'administrateur**, après 1_installer_wsl.ps1 et
  le redémarrage. L'installateur officiel a déjà été téléchargé (winget, empreinte vérifiée).

  -User : le compte Windows qui utilisera Docker (ajouté au groupe docker-users).
#>
param(
    [string]$Installer = 'C:\Users\ELITEBOOK 745G6\Downloads\docker-desktop\Docker Desktop_4.96.0_Machine_X64_exe_en-US.exe',
    [string]$User = 'ELITEBOOK 745G6'
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Installer)) {
    Write-Host "Installateur introuvable. Téléchargement via winget..." -ForegroundColor Yellow
    $dir = Split-Path $Installer
    New-Item -ItemType Directory -Force $dir | Out-Null
    winget download --id Docker.DockerDesktop -e --download-directory $dir --accept-source-agreements --accept-package-agreements
    $Installer = (Get-ChildItem $dir -Filter 'Docker Desktop*.exe' | Select-Object -First 1).FullName
}

Write-Host "Installation de Docker Desktop (quelques minutes)..." -ForegroundColor Cyan
$p = Start-Process -FilePath $Installer -ArgumentList 'install', '--quiet', '--accept-license', '--backend=wsl-2' -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "L'installateur a échoué (code $($p.ExitCode))." }

Write-Host "Ajout de '$User' au groupe docker-users..." -ForegroundColor Cyan
try { Add-LocalGroupMember -Group 'docker-users' -Member $User -ErrorAction Stop }
catch { Write-Host "  (déjà membre ou compte introuvable : $($_.Exception.Message))" }

Write-Host ""
Write-Host "Terminé. Fermez la session Windows et rouvrez-la, lancez Docker Desktop une fois" -ForegroundColor Green
Write-Host "(accepter les conditions), puis vérifiez dans un terminal normal :  docker run --rm hello-world" -ForegroundColor Green
