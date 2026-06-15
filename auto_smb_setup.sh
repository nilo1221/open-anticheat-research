#!/bin/bash

# ============================================================
# Script automatico per configurare SMB per accesso SSD esterno
# USO: sudo bash auto_smb_setup.sh
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════╗"
echo "║   Configurazione Automatica SMB          ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# Verifica se eseguito come root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Errore: Esegui come root (sudo)${NC}"
    exit 1
fi

SSD_PATH="/run/media/lollo/F9FF-FB10/SteamLibrary"
SMB_CONF="/etc/samba/smb.conf"

echo -e "${CYAN}[1/4]${NC} Verifica percorso SSD esterno..."
if [ ! -d "$SSD_PATH" ]; then
    echo -e "${RED}Errore: SSD esterno non trovato in $SSD_PATH${NC}"
    exit 1
fi
echo -e "${GREEN}✓ SSD esterno trovato${NC}"

echo -e "${CYAN}[2/4]${NC} Configurazione Samba..."
# Backup configurazione esistente
cp "$SMB_CONF" "$SMB_CONF.backup.$(date +%Y%m%d_%H%M%S)"

# Crea nuova configurazione
cat > "$SMB_CONF" << 'EOF'
[global]
   workgroup = WORKGROUP
   server string = Samba Server
   security = user
   map to guest = Bad User
   guest account = nobody
   usershare allow guests = yes
   client min protocol = NT1
   server min protocol = NT1

[SteamLibrary]
   path = /run/media/lollo/F9FF-FB10/SteamLibrary
   browseable = yes
   read only = no
   guest ok = yes
   force user = lollo
EOF

echo -e "${GREEN}✓ Configurazione Samba aggiornata${NC}"

echo -e "${CYAN}[3/4]${NC} Riavvio servizi Samba..."
systemctl restart smb nmb
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Samba riavviato${NC}"
else
    echo -e "${RED}✗ Errore riavvio Samba${NC}"
    exit 1
fi

echo -e "${CYAN}[4/4]${NC} Apertura firewall..."
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-service=samba
    firewall-cmd --reload
    echo -e "${GREEN}✓ Firewall configurato (firewalld)${NC}"
elif command -v ufw &> /dev/null; then
    ufw allow samba
    echo -e "${GREEN}✓ Firewall configurato (ufw)${NC}"
else
    echo -e "${YELLOW}⚠ Nessun firewall rilevato${NC}"
fi

# Ottieni IP del host
HOST_IP=$(ip addr show wlo1 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

echo -e "${BOLD}${GREEN}"
echo "╔══════════════════════════════════════════╗"
echo "║   Configurazione Completata!             ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${CYAN}IP Host: ${GREEN}$HOST_IP${NC}"
echo -e "${CYAN}Condivisione: ${GREEN}\\\\$HOST_IP\\SteamLibrary${NC}"
echo -e "${CYAN}Credenziali: ${GREEN}lollo / lollo${NC}"
echo ""
echo -e "${BOLD}Nella VM Windows:${NC}"
echo -e "  1. Apri PowerShell come amministratore"
echo -e "  2. Esegui: Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/nilo1221/open-anticheat-research/main/mount_ssd.ps1' -OutFile 'C:\\Users\\\$env:USERNAME\\Desktop\\mount_ssd.ps1'"
echo -e "  3. Esegui: PowerShell -ExecutionPolicy Bypass -File C:\\Users\\\$env:USERNAME\\Desktop\\mount_ssd.ps1"
echo ""
echo -e "${GREEN}✓ Configurazione completata con successo${NC}"
