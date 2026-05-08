# Spustit jako Administrator (UAC) — zaregistruje úlohu, která spouští backend + tunnel po přihlášení.
$ErrorActionPreference = 'Stop'

$user = "$env:USERDOMAIN\$env:USERNAME"
$script = 'C:\Users\H1r0sh1ma\Desktop\mfc-vysocina-app\mfc-app\start-server.ps1'

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit (New-TimeSpan -Days 0) ` # bez limitu
$principal = New-ScheduledTaskPrincipal -UserId $user -RunLevel Limited -LogonType Interactive

Register-ScheduledTask `
    -TaskName 'MFC Vysocina Server' `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description 'Auto-start FastAPI backend + Cloudflare tunnel + update GitHub Pages with new URL.' `
    -Force | Out-Null

Write-Host "✓ Scheduled Task 'MFC Vysocina Server' zaregistrovana." -ForegroundColor Green
Write-Host "  Spousti se po prihlaseni uzivatele $user." -ForegroundColor DarkGray
Write-Host ""
Write-Host "Toto okno se za 5 sekund zavre..."
Start-Sleep -Seconds 5
