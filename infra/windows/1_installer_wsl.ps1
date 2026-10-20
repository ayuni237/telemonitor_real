#Requires -RunAsAdministrator
<#
  Étape 1/2 — WSL2, prérequis de Docker Desktop.
  À lancer dans PowerShell **en tant qu'administrateur**, APRÈS avoir activé la
  virtualisation dans le BIOS (voir INFRA.md, étape 0).
  Un redémarrage est nécessaire à la fin.
#>
$ErrorActionPreference = 'Stop'

$hv = (systeminfo /fo csv | ConvertFrom-Csv).'Hyper-V Requirements'
if ($hv -match 'Virtualization Enabled In Firmware: No') {
    Write-Host "La virtualisation est encore désactivée dans le BIOS." -ForegroundColor Red
    Write-Host "Redémarrez, appuyez sur F10, Advanced > System Options > cochez 'Virtualization Technology (VTx)' ou 'SVM', enregistrez, puis relancez ce script."
    exit 1
}

Write-Host "Activation de WSL2 et de la plateforme de machine virtuelle..." -ForegroundColor Cyan
wsl --install --no-distribution
wsl --set-default-version 2

Write-Host ""
Write-Host "Terminé. REDÉMARREZ l'ordinateur, puis lancez 2_installer_docker.ps1 (administrateur)." -ForegroundColor Green
