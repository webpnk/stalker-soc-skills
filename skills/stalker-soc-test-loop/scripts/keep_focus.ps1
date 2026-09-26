# Re-focuses the game window every few seconds for $Seconds (runs in the interactive session).
param([int]$Seconds = 90)
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end) {
    & "$PSScriptRoot\focus_game.ps1"
    Start-Sleep -Seconds 2
}
