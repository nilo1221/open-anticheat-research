# ============================================================
# BattlEye Log Capture Script per Windows VM
# USO: PowerShell -ExecutionPolicy Bypass -File capture_battleye_logs.ps1
# ============================================================

# Configurazione
$LOG_DIRS = @(
    "C:\ProgramData\BattlEye\BEService",
    "C:\Users\$env:USERNAME\AppData\Local\BattlEye",
    "C:\Program Files (x86)\Steam\steamapps\common\Destiny 2"
)

$OUTPUT_DIR = "D:\BattlEyeLogs"  # Cambia con lettera unità SSD esterno
$INTERVAL_SECONDS = 5

# Crea directory output se non esiste
if (-not (Test-Path $OUTPUT_DIR)) {
    New-Item -ItemType Directory -Path $OUTPUT_DIR -Force
    Write-Host "[INFO] Directory output creata: $OUTPUT_DIR"
}

Write-Host "[INFO] Monitoraggio log BattlEye avviato..."
Write-Host "[INFO] Output: $OUTPUT_DIR"
Write-Host "[INFO] Intervallo: $INTERVAL_SECONDS secondi"
Write-Host "[INFO] Premi CTRL+C per fermare"

# Funzione per copiare nuovi log
function Copy-NewLogs {
    foreach ($dir in $LOG_DIRS) {
        if (Test-Path $dir) {
            $files = Get-ChildItem -Path $dir -Filter "*.log" -Recurse -ErrorAction SilentlyContinue
            foreach ($file in $files) {
                $destFile = Join-Path $OUTPUT_DIR ($file.Name + "_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
                if (-not (Test-Path $destFile)) {
                    Copy-Item $file.FullName -Destination $destFile -Force
                    Write-Host "[COPY] $($file.Name) -> $destFile"
                }
            }
        }
    }
}

# Loop principale
while ($true) {
    Copy-NewLogs
    Start-Sleep -Seconds $INTERVAL_SECONDS
}
