# MFC Vysocina backend auto-start
# Spustí: 1) FastAPI backend  2) Cloudflare quick tunnel
# Po startu tunelu update GitHub repo variable s novou URL → web se přebuilduje automaticky.

$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
$logsDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

# ── 1. Start backend (uvicorn) ────────────────────────────────────────
Write-Host "[mfc] Starting backend on :5002..." -ForegroundColor Cyan
$pyExe = Join-Path $root 'venv\Scripts\python.exe'
$backendArgs = @('-m', 'uvicorn', 'app.main:app', '--host', '0.0.0.0', '--port', '5002', '--proxy-headers', '--forwarded-allow-ips=*')
$backend = Start-Process -FilePath $pyExe -ArgumentList $backendArgs -WorkingDirectory $root -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $logsDir 'backend.out') `
    -RedirectStandardError  (Join-Path $logsDir 'backend.err')
Write-Host "[mfc] backend PID = $($backend.Id)" -ForegroundColor Green
Start-Sleep -Seconds 4

# ── 2. Start Cloudflare quick tunnel ──────────────────────────────────
Write-Host "[mfc] Starting Cloudflare tunnel..." -ForegroundColor Cyan
$cloudflared = "$env:ProgramFiles (x86)\cloudflared\cloudflared.exe"
if (-not (Test-Path $cloudflared)) {
    $cloudflared = "$env:ProgramFiles\cloudflared\cloudflared.exe"
}
$tunnelLog = Join-Path $logsDir 'tunnel.log'
$tunnel = Start-Process -FilePath $cloudflared -ArgumentList @('tunnel', '--url', 'http://localhost:5002', '--no-autoupdate') -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $tunnelLog `
    -RedirectStandardError  $tunnelLog
Write-Host "[mfc] tunnel PID = $($tunnel.Id)" -ForegroundColor Green

# ── 3. Vytahnout URL z logu (max 60 s) ────────────────────────────────
Write-Host "[mfc] Waiting for tunnel URL..." -ForegroundColor Cyan
$tunnelUrl = $null
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 1
    if (Test-Path $tunnelLog) {
        $line = Select-String -Path $tunnelLog -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($line) {
            if ($line.Matches[0].Value -match 'https://[a-z0-9-]+\.trycloudflare\.com') {
                $tunnelUrl = $matches[0]
                break
            }
        }
    }
}

if (-not $tunnelUrl) {
    Write-Host "[mfc] !!! Tunnel URL not found in log after 60 s. Check logs/tunnel.log" -ForegroundColor Red
    exit 1
}
$wsUrl = $tunnelUrl -replace '^https://', 'wss://'
Write-Host "[mfc] tunnel URL: $tunnelUrl" -ForegroundColor Green

# ── 4. Update GitHub repo variable + spustit redeploy webu ─────────────
$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($gh) {
    $repo = 'jhfumarevape/mfc-vysocina-app'
    Write-Host "[mfc] Updating GitHub variables..." -ForegroundColor Cyan
    & gh variable set API_BASE_URL --body $tunnelUrl --repo $repo 2>&1 | Out-Null
    & gh variable set WS_BASE_URL  --body $wsUrl     --repo $repo 2>&1 | Out-Null
    Write-Host "[mfc] Triggering Pages rebuild..." -ForegroundColor Cyan
    & gh workflow run deploy-web.yml --repo $repo 2>&1 | Out-Null
    Write-Host "[mfc] Web bude online s novou URL za ~3 min: https://jhfumarevape.github.io/mfc-vysocina-app/" -ForegroundColor Green
} else {
    Write-Host "[mfc] gh CLI not found, skip web auto-update. URL: $tunnelUrl" -ForegroundColor Yellow
}

# ── 5. Zapsat URL do souboru pro snadnou kontrolu ─────────────────────
$tunnelUrl | Out-File -FilePath (Join-Path $root 'CURRENT_URL.txt') -Encoding utf8
Write-Host "[mfc] All started. Backend + tunnel running in background." -ForegroundColor Green
Write-Host "[mfc] Logs in $logsDir, current URL in $root\CURRENT_URL.txt" -ForegroundColor DarkGray
