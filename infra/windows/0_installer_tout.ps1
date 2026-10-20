#Requires -RunAsAdministrator
<#
  Installation complète, en une fois (PowerShell administrateur) :
    1. virtualisation activée dans le BIOS HP (via l'interface WMI du BIOS HP) ;
    2. WSL2 ;
    3. Docker Desktop (moteur WSL2), installation silencieuse ;
    4. le compte utilisateur ajouté au groupe docker-users.
  Aucun redémarrage automatique : redémarrez vous-même à la fin.
  Journal : C:\Projects\infra\windows\install_log.txt
#>
param(
    [string]$Installer = 'C:\Users\ELITEBOOK 745G6\Downloads\docker-desktop\Docker Desktop_4.96.0_Machine_X64_exe_en-US.exe',
    [string]$User = 'ELITEBOOK 745G6',
    [string]$BiosPassword = ''
)
$log = 'C:\Projects\infra\windows\install_log.txt'
$done = 'C:\Projects\infra\windows\install_done.txt'
Remove-Item $done -ErrorAction SilentlyContinue
function Log($m) { $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m"; Write-Host $line; Add-Content -Path $log -Value $line -Encoding UTF8 }

Log "=== Début de l'installation ==="

# 1. BIOS
try {
    $setting = Get-CimInstance -Namespace root\HP\InstrumentedBIOS -ClassName HP_BIOSEnumeration -ErrorAction Stop |
        Where-Object { $_.Name -match 'Virtualization Technology|SVM|AMD-V' } | Select-Object -First 1
    if (-not $setting) {
        Log "BIOS : aucun réglage de virtualisation trouvé dans le WMI HP -> à faire à la main (F10)."
    } elseif ($setting.CurrentValue -match 'Enable') {
        Log "BIOS : '$($setting.Name)' déjà activé."
    } else {
        $target = ($setting.PossibleValues | Where-Object { $_ -match '^Enable' } | Select-Object -First 1)
        $iface = Get-CimInstance -Namespace root\HP\InstrumentedBIOS -ClassName HP_BIOSSettingInterface
        $biosPwd = if ($BiosPassword) { "<utf-16/>$BiosPassword" } else { '' }
        $r = Invoke-CimMethod -InputObject $iface -MethodName SetBIOSSetting -Arguments @{Name = $setting.Name; Value = $target; Password = $biosPwd}
        switch ($r.Return) {
            0 { Log "BIOS : '$($setting.Name)' réglé sur '$target' (effectif après redémarrage)." }
            6 { Log "BIOS : refusé (mot de passe BIOS). Relancez avec -BiosPassword '...' ou activez-la avec F10." }
            default { Log "BIOS : échec, code $($r.Return). Activez-la avec F10 (Advanced > System Options)." }
        }
    }
} catch { Log "BIOS : WMI HP inaccessible ($($_.Exception.Message)). Activez la virtualisation avec F10." }

# 2. WSL2
try {
    Log "WSL2 : installation des composants..."
    $out = & wsl.exe --install --no-distribution 2>&1 | Out-String
    Log ("WSL2 : " + ($out -replace "`0", '' -replace '\s+', ' ').Trim())
} catch { Log "WSL2 : échec ($($_.Exception.Message))." }

# 3. Docker Desktop
try {
    if (-not (Test-Path $Installer)) { throw "installateur introuvable : $Installer" }
    Log "Docker Desktop : installation silencieuse (plusieurs minutes)..."
    $p = Start-Process -FilePath $Installer -ArgumentList 'install', '--quiet', '--accept-license', '--backend=wsl-2' -Wait -PassThru
    if ($p.ExitCode -eq 0) { Log "Docker Desktop : installé." } else { Log "Docker Desktop : code de sortie $($p.ExitCode)." }
} catch { Log "Docker Desktop : échec ($($_.Exception.Message))." }

# 4. groupe docker-users
try { Add-LocalGroupMember -Group 'docker-users' -Member $User -ErrorAction Stop; Log "Groupe docker-users : '$User' ajouté." }
catch { Log "Groupe docker-users : $($_.Exception.Message)" }

Log "=== Terminé. REDÉMARREZ l'ordinateur, puis lancez Docker Desktop une fois. ==="
Set-Content -Path $done -Value (Get-Date) -Encoding UTF8
