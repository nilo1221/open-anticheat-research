#!/bin/bash

# ============================================================
# Condivide la cartella SteamLibrary via SMB per la VM Windows
# USO: bash setup_smb_share.sh
# ============================================================

SHARE_PATH="/run/media/lollo/F9FF-FB10/SteamLibrary"
SHARE_NAME="SteamLibrary"
SMB_USER="vmuser"
SMB_PASS="vmuser123"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════╗"
echo "║   Setup SMB Share per VM Windows        ║"
echo "║   Monta SSD esterno come rete           ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# Verifica che il percorso esista
if [ ! -d "$SHARE_PATH" ]; then
    echo -e "${RED}Errore: $SHARE_PATH non esiste${NC}"
    echo "Collega l'SSD esterno e riprova."
    exit 1
fi

echo -e "${CYAN}[1/4]${NC} Installazione Samba..."
if ! command -v smbd &>/dev/null; then
    sudo pacman -S samba --noconfirm
else
    echo -e "${GREEN}Samba già installato${NC}"
fi

echo -e "${CYAN}[2/4]${NC} Configurazione smb.conf..."
SMB_CONF="/etc/samba/smb.conf"
sudo cp "$SMB_CONF" "$SMB_CONF.bak" 2>/dev/null || true

# Aggiunge configurazione se non esiste
if ! grep -q "\[$SHARE_NAME\]" "$SMB_CONF" 2>/dev/null; then
    sudo bash -c "cat >> '$SMB_CONF' << EOF

[$SHARE_NAME]
    path = $SHARE_PATH
    browseable = yes
    read only = no
    guest ok = yes
    force user = lollo
EOF"
    echo -e "${GREEN}Configurazione aggiunta${NC}"
else
    echo -e "${GREEN}Configurazione già presente${NC}"
fi

echo -e "${CYAN}[3/4]${NC} Riavvio servizio Samba..."
sudo systemctl restart smbd nmbd
sudo systemctl enable smbd nmbd
echo -e "${GREEN}Samba attivo${NC}"

echo -e "${CYAN}[4/4]${NC} Informazioni connessione VM..."
echo ""
echo -e "${BOLD}Nella VM Windows:${NC}"
echo -e "  1. Apri 'Esegui' (Win+R)"
echo -e "  2. Digita: ${CYAN}\\\\$HOSTNAME\\$SHARE_NAME${NC}"
echo -e "  3. Clicca destro → Connetti unità di rete"
echo -e "  4. Assegna lettera unità (es. Z:)"
echo ""
echo -e "${BOLD}Oppure in Steam:${NC}"
echo -e "  Steam → Impostazioni → Download → Cartelle libreria Steam"
echo -e "  Aggiungi: ${CYAN}\\\\$HOSTNAME\\$SHARE_NAME${NC}"
echo ""
echo -e "${GREEN}✓ SMB share configurata${NC}"
