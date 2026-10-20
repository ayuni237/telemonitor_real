<#
  Lance UNE tâche du benchmark au premier plan, dans la fenêtre courante, avec les barres de
  progression en direct. Appelé par relancer_benchmarks.ps1 (une fenêtre par tâche) ;
  utilisable aussi directement :
    powershell -ExecutionPolicy Bypass -File C:\Projects\infra\windows\_benchmark_tache.ps1 -Task haemodynamic -Leads "0"
#>
param([Parameter(Mandatory = $true)][string]$Task, [string]$Leads = '0')
$host.UI.RawUI.WindowTitle = "Benchmark $Task (horizon $Leads)"
Set-Location 'C:\Projects\telemonitor-research'
$env:PYTHONUNBUFFERED = '1'
$leadArgs = $Leads -split '[ ,]+' | Where-Object { $_ }
python scripts\06_benchmark.py --tasks $Task --leads @leadArgs
Write-Host ''
if ($LASTEXITCODE -eq 0) { Write-Host "Terminé. Vous pouvez fermer cette fenêtre." -ForegroundColor Green }
else { Write-Host "Arrêté (code $LASTEXITCODE). La même commande reprend le run." -ForegroundColor Yellow }
