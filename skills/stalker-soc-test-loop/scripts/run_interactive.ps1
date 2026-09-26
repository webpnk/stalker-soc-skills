# Runs a command line in the user's interactive desktop session via a one-off scheduled task.
# Claude's shell lives in Session 0, where the game cannot create its input device (it crashes), and
# windows cannot be captured or focused. The task is deleted immediately after it starts.
param(
    [Parameter(Mandatory)][string]$Exe,
    [string]$Arguments = "",
    [string]$WorkDir = (Resolve-Path "$PSScriptRoot\..\..\game").Path
)
$name = "modrun_" + [guid]::NewGuid().ToString("N").Substring(0, 8)
$action = New-ScheduledTaskAction -Execute $Exe -Argument $Arguments -WorkingDirectory $WorkDir
$principal = New-ScheduledTaskPrincipal -UserId (whoami) -LogonType Interactive
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 4)
Register-ScheduledTask -TaskName $name -Action $action -Principal $principal -Settings $settings | Out-Null
Start-ScheduledTask -TaskName $name
Start-Sleep -Seconds 2
Unregister-ScheduledTask -TaskName $name -Confirm:$false
"started $Exe via $name"
