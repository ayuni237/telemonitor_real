<#
  Lance les benchmarks SANS Docker, une FENÊTRE VISIBLE par tâche, avec les barres de
  progression en direct. Pas besoin d'être administrateur. À lancer UNE seule fois :
  le script refuse s'il trouve déjà un benchmark en cours.

  Utilisation (depuis n'importe quel dossier) :
    powershell -ExecutionPolicy Bypass -File C:\Projects\infra\windows\relancer_benchmarks.ps1
  Options :
    -Tasks haemodynamic          une seule tâche
    -Leads "12 36"               horizons 24 h et 48 h (hypothèse H2)

  Chaque fenêtre reste ouverte à la fin. Fermer une fenêtre arrête son run ; la même
  commande le reprend là où il s'était arrêté (sauvegardes dans out\runs\...).
  Journal : out\runs\<run>\run.log
#>
param([string[]]$Tasks = @('haemodynamic', 'glycaemic'), [string]$Leads = '0')
$launcher = Join-Path $PSScriptRoot '_benchmark_tache.ps1'

$running = Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
    Where-Object { $_.CommandLine -match '06_benchmark' }
if ($running) {
    Write-Host "Un benchmark tourne déjà (processus $($running.ProcessId -join ', '))." -ForegroundColor Yellow
    Write-Host "Regardez sa fenêtre, ou arrêtez-le :  Stop-Process -Id $($running.ProcessId -join ',')" -ForegroundColor Yellow
    exit 1
}

foreach ($task in $Tasks) {
    $title = "Benchmark $task"
    # 'cmd /c start' opens a new console window; Start-Process powershell fails on this machine (0xffffffff)
    & cmd.exe /c start "`"$title`"" powershell.exe -NoExit -NoProfile -ExecutionPolicy Bypass -File "`"$launcher`"" -Task $task -Leads "`"$Leads`""
    if ($LASTEXITCODE -ne 0) {
        Write-Host "$task : la fenêtre n'a pas pu s'ouvrir (code $LASTEXITCODE)." -ForegroundColor Red
        Write-Host "Lancez-la à la main :  powershell -ExecutionPolicy Bypass -File `"$launcher`" -Task $task -Leads `"$Leads`""
    } else {
        Write-Host "$task : fenêtre « $title » ouverte."
    }
}
