# ============================================================
# Script per montare automaticamente SSD esterno via SMB
# USO: PowerShell -ExecutionPolicy Bypass -File mount_ssd.ps1
# ============================================================

$SharePath = "\\192.168.1.59\SteamLibrary"
$DriveLetter = "Z:"
$Username = "lollo"
$Password = "lollo"

Write-Host "[INFO] Montaggio SSD esterno via SMB..." -ForegroundColor Cyan

# Crea oggetto credenziali
$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($Username, $SecurePassword)

# Rimuovi mappatura esistente se presente
if (Test-Path $DriveLetter) {
    Write-Host "[INFO] Rimozione mappatura esistente $DriveLetter..." -ForegroundColor Yellow
    Remove-PSDrive -Name $DriveLetter.Substring(0,1) -Force -ErrorAction SilentlyContinue
    net use $DriveLetter /delete /y | Out-Null
}

# Monta la condivisione SMB
try {
    Write-Host "[INFO] Connessione a $SharePath..." -ForegroundColor Cyan
    New-PSDrive -Name $DriveLetter.Substring(0,1) -PSProvider FileSystem -Root $SharePath -Credential $Credential -Persist -ErrorAction Stop
    
    Write-Host "[SUCCESS] SSD esterno montato come $DriveLetter" -ForegroundColor Green
    Write-Host "[INFO] Percorso: $SharePath" -ForegroundColor Cyan
    
    # Verifica montaggio
    if (Test-Path $DriveLetter) {
        Write-Host "[INFO] Contenuto SSD esterno:" -ForegroundColor Cyan
        Get-ChildItem $DriveLetter | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
    }
} catch {
    Write-Host "[ERROR] Impossibile montare SSD esterno: $_" -ForegroundColor Red
    Write-Host "[INFO] Verifica che Samba sia in esecuzione sul host Linux" -ForegroundColor Yellow
    exit 1
}

Write-Host "[SUCCESS] Montaggio completato con successo" -ForegroundColor Green
