<#
  Runs ONE benchmark task in the foreground, in the current window, with live progress
  bars. Called by rerun_benchmarks.ps1 (one window per task); can also be used directly:
    powershell -ExecutionPolicy Bypass -File C:\Projects\infra\windows\_benchmark_task.ps1 -Task haemodynamic -Leads "0"
#>
param([Parameter(Mandatory = $true)][string]$Task, [string]$Leads = '0')
$host.UI.RawUI.WindowTitle = "Benchmark $Task (lead $Leads)"
Set-Location 'C:\Projects\telemonitor-research'
$env:PYTHONUNBUFFERED = '1'
$leadArgs = $Leads -split '[ ,]+' | Where-Object { $_ }
python scripts\06_benchmark.py --tasks $Task --leads @leadArgs
Write-Host ''
if ($LASTEXITCODE -eq 0) { Write-Host "Done. You can close this window." -ForegroundColor Green }
else { Write-Host "Stopped (code $LASTEXITCODE). The same command resumes the run." -ForegroundColor Yellow }
