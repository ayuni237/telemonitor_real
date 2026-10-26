<#
  Launches the benchmarks, one VISIBLE WINDOW per task, with live progress bars.
  No administrator rights needed. Run it ONCE: the script refuses to start if a
  benchmark is already running.

  Usage (from any folder):
    powershell -ExecutionPolicy Bypass -File C:\Projects\infra\windows\rerun_benchmarks.ps1
  Options:
    -Tasks haemodynamic          a single task
    -Leads "12 36"               24 h and 48 h horizons (hypothesis H2)

  Each window stays open at the end. Closing a window stops its run; the same
  command resumes it where it stopped (saved outputs in out\runs\...).
  Log: out\runs\<run>\run.log
#>
param([string[]]$Tasks = @('haemodynamic', 'glycaemic'), [string]$Leads = '0')
$launcher = Join-Path $PSScriptRoot '_benchmark_task.ps1'

$running = Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
    Where-Object { $_.CommandLine -match '06_benchmark' }
if ($running) {
    Write-Host "A benchmark is already running (process $($running.ProcessId -join ', '))." -ForegroundColor Yellow
    Write-Host "Check its window, or stop it:  Stop-Process -Id $($running.ProcessId -join ',')" -ForegroundColor Yellow
    exit 1
}

foreach ($task in $Tasks) {
    $title = "Benchmark $task"
    # 'cmd /c start' opens a new console window; Start-Process powershell fails on this machine (0xffffffff)
    & cmd.exe /c start "`"$title`"" powershell.exe -NoExit -NoProfile -ExecutionPolicy Bypass -File "`"$launcher`"" -Task $task -Leads "`"$Leads`""
    if ($LASTEXITCODE -ne 0) {
        Write-Host "$task : the window could not be opened (code $LASTEXITCODE)." -ForegroundColor Red
        Write-Host "Start it by hand:  powershell -ExecutionPolicy Bypass -File `"$launcher`" -Task $task -Leads `"$Leads`""
    } else {
        Write-Host "$task : window `"$title`" opened."
    }
}
