# Script PowerShell per catturare log BattlEye e Destiny 2 su Windows nativo
# Educational purposes only - per analisi tecnica e documentazione

# Configurazione
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputDir = "C:\BattlEyeLogs_$timestamp"
$beLogDir = "$env:PROGRAMDATA\BattlEye"
$destinyLogDir = "$env:LOCALAPPDATA\Bungie\Destiny2"
$destinyInstallDir = "G:\SteamLibrary\steamapps\common\Destiny 2"

# Crea directory di output
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
Write-Host "Directory di output creata: $outputDir"

# Funzione per copiare log BattlEye
function Copy-BattlEyeLogs {
    Write-Host "Cercando log BattlEye..."
    
    if (Test-Path $beLogDir) {
        Write-Host "Trovata directory BattlEye: $beLogDir"
        
        # Copia tutti i file di log
        $beFiles = Get-ChildItem -Path $beLogDir -Recurse -Filter "*.log" -ErrorAction SilentlyContinue
        if ($beFiles) {
            foreach ($file in $beFiles) {
                $destPath = "$outputDir\BattlEye\$($file.Name)"
                New-Item -ItemType Directory -Force -Path (Split-Path $destPath) | Out-Null
                Copy-Item -Path $file.FullName -Destination $destPath -Force
                Write-Host "Copiato: $($file.Name)"
            }
        } else {
            Write-Host "Nessun file di log BattlEye trovato"
        }
        
        # Copia anche i file di configurazione
        $beConfig = Get-ChildItem -Path $beLogDir -Recurse -Filter "*.xml" -ErrorAction SilentlyContinue
        if ($beConfig) {
            foreach ($file in $beConfig) {
                $destPath = "$outputDir\BattlEye\Config\$($file.Name)"
                New-Item -ItemType Directory -Force -Path (Split-Path $destPath) | Out-Null
                Copy-Item -Path $file.FullName -Destination $destPath -Force
                Write-Host "Copiato config: $($file.Name)"
            }
        }
    } else {
        Write-Host "Directory BattlEye non trovata: $beLogDir"
    }
}

# Funzione per copiare log Destiny 2
function Copy-DestinyLogs {
    Write-Host "Cercando log Destiny 2..."
    
    if (Test-Path $destinyLogDir) {
        Write-Host "Trovata directory Destiny 2: $destinyLogDir"
        
        # Copia tutti i file di log
        $destinyFiles = Get-ChildItem -Path $destinyLogDir -Recurse -Filter "*.log" -ErrorAction SilentlyContinue
        if ($destinyFiles) {
            foreach ($file in $destinyFiles) {
                $destPath = "$outputDir\Destiny2\$($file.Name)"
                New-Item -ItemType Directory -Force -Path (Split-Path $destPath) | Out-Null
                Copy-Item -Path $file.FullName -Destination $destPath -Force
                Write-Host "Copiato: $($file.Name)"
            }
        } else {
            Write-Host "Nessun file di log Destiny 2 trovato"
        }
    } else {
        Write-Host "Directory Destiny 2 non trovata: $destinyLogDir"
    }
}

# Funzione per copiare log BattlEye dalla cartella di installazione
function Copy-DestinyBattlEyeLogs {
    Write-Host "Cercando log BattlEye nella cartella di installazione..."
    
    if (Test-Path $destinyInstallDir) {
        Write-Host "Trovata directory installazione Destiny 2: $destinyInstallDir"
        
        # Copia log dalla cartella BattlEye
        $beDir = "$destinyInstallDir\BattlEye"
        if (Test-Path $beDir) {
            Write-Host "Trovata directory BattlEye: $beDir"
            
            $beFiles = Get-ChildItem -Path $beDir -Filter "*.log" -ErrorAction SilentlyContinue
            if ($beFiles) {
                foreach ($file in $beFiles) {
                    $destPath = "$outputDir\Destiny2\BattlEye\$($file.Name)"
                    New-Item -ItemType Directory -Force -Path (Split-Path $destPath) | Out-Null
                    Copy-Item -Path $file.FullName -Destination $destPath -Force
                    Write-Host "Copiato log BE: $($file.Name)"
                }
            } else {
                Write-Host "Nessun file di log BattlEye trovato nella cartella di installazione"
            }
            
            # Copia anche i file di configurazione
            $beConfig = Get-ChildItem -Path $beDir -Filter "*.xml" -ErrorAction SilentlyContinue
            if ($beConfig) {
                foreach ($file in $beConfig) {
                    $destPath = "$outputDir\Destiny2\BattlEye\Config\$($file.Name)"
                    New-Item -ItemType Directory -Force -Path (Split-Path $destPath) | Out-Null
                    Copy-Item -Path $file.FullName -Destination $destPath -Force
                    Write-Host "Copiato config BE: $($file.Name)"
                }
            }
        } else {
            Write-Host "Directory BattlEye non trovata nella cartella di installazione"
        }
    } else {
        Write-Host "Directory installazione Destiny 2 non trovata: $destinyInstallDir"
    }
}

# Funzione per catturare informazioni di sistema
function Get-SystemInfo {
    Write-Host "Catturando informazioni di sistema..."
    
    $systemInfo = @"
=== SYSTEM INFO ===
Timestamp: $timestamp
OS: $((Get-WmiObject Win32_OperatingSystem).Caption)
Version: $((Get-WmiObject Win32_OperatingSystem).Version)
ComputerName: $env:COMPUTERNAME
Username: $env:USERNAME

=== HARDWARE INFO ===
CPU: $((Get-WmiObject Win32_Processor).Name)
RAM: $((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB) GB
GPU: $((Get-WmiObject Win32_VideoController).Name)

=== BATTLEYE INFO ===
BE Service: $((Get-Service -Name BEService -ErrorAction SilentlyContinue).Status)
BE Process: $((Get-Process -Name BEService -ErrorAction SilentlyContinue).Path)

=== DESTINY 2 INFO ===
Destiny 2 Process: $((Get-Process -Name destiny2 -ErrorAction SilentlyContinue).Path)
"@
    
    $systemInfo | Out-File -FilePath "$outputDir\system_info.txt" -Encoding UTF8
    Write-Host "Informazioni di sistema salvate"
}

# Funzione per catturare registro eventi
function Get-EventLogs {
    Write-Host "Catturando registro eventi..."
    
    $eventLogs = Get-EventLog -LogName Application -After (Get-Date).AddHours(-1) -ErrorAction SilentlyContinue | 
                 Where-Object { $_.Source -like "*BattlEye*" -or $_.Source -like "*Destiny*" }
    
    if ($eventLogs) {
        $eventLogs | Export-Csv -Path "$outputDir\event_logs.csv" -NoTypeInformation
        Write-Host "Registro eventi salvato"
    } else {
        Write-Host "Nessun evento rilevante trovato"
    }
}

# Esegui tutte le funzioni
try {
    Write-Host "=== INIZIO CATTURA LOG BATTLEYE ==="
    Write-Host "Timestamp: $timestamp"
    Write-Host ""
    
    Copy-BattlEyeLogs
    Write-Host ""
    
    Copy-DestinyLogs
    Write-Host ""
    
    Copy-DestinyBattlEyeLogs
    Write-Host ""
    
    Get-SystemInfo
    Write-Host ""
    
    Get-EventLogs
    Write-Host ""
    
    Write-Host "=== CATTURA COMPLETATA ==="
    Write-Host "Log salvati in: $outputDir"
    Write-Host ""
    Write-Host "NOTA: Questi log sono per scopi educativi e di ricerca tecnica."
    Write-Host "Non contengono dati personali sensibili."
    
} catch {
    Write-Host "ERRORE: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}

# Apri la directory di output
Invoke-Item $outputDir
