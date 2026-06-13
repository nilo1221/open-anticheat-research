#!/bin/bash

# ============================================================
# Collega ISO Windows alla VM e avvia
# USO: bash attach_and_start_vm.sh /percorso/windows10.iso
# ============================================================

VM_NAME="destiny2-testbed"
ISO_PATH="${1:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

if [ -z "$ISO_PATH" ]; then
    echo -e "${YELLOW}Cerca ISO Windows sul disco esterno...${NC}"
    ISO_PATH=$(find /run/media/lollo /home/lollo -name "Win10*.iso" -o -name "windows10*.iso" -o -name "Windows10*.iso" 2>/dev/null | head -1)
    if [ -z "$ISO_PATH" ]; then
        echo -e "${RED}ISO non trovata. Specifica il percorso:${NC}"
        echo -e "  bash attach_and_start_vm.sh /percorso/Win10.iso"
        exit 1
    fi
    echo -e "${GREEN}ISO trovata: $ISO_PATH${NC}"
fi

[ -f "$ISO_PATH" ] || { echo -e "${RED}File non trovato: $ISO_PATH${NC}"; exit 1; }

echo -e "${CYAN}Collegamento ISO alla VM $VM_NAME...${NC}"
VBoxManage storageattach "$VM_NAME" \
    --storagectl "SATA Controller" \
    --port 1 --device 0 \
    --type dvddrive \
    --medium "$ISO_PATH"

echo -e "${GREEN}ISO collegata.${NC}"
echo ""
echo -e "${BOLD}${YELLOW}══════ GUIDA INSTALLAZIONE WINDOWS ══════${NC}"
echo ""
echo -e "  Quando si apre la VM, segui ESATTAMENTE questi passi:"
echo ""
echo -e "  ${BOLD}1. Installazione Windows${NC}"
echo -e "     - Lingua: Italiano — Avanti — Installa"
echo -e "     - Chiave prodotto: clicca 'Non ho un codice Product Key'"
echo -e "     - Edizione: Windows 10 Pro — Avanti"
echo -e "     - Accetta licenza"
echo -e "     - Tipo installazione: 'Personalizzata' (non Aggiorna)"
echo -e "     - Seleziona il disco da 60GB — Avanti"
echo ""
echo -e "  ${BOLD}2. Setup iniziale (OOBE) — CRITICO${NC}"
echo -e "     - Area geografica: Italia"
echo -e "     - Layout tastiera: Italiano"
echo -e "     - ${RED}ACCOUNT: scegli 'Account offline' / 'Esperienza limitata'${NC}"
echo -e "     - ${RED}NON inserire email Microsoft — usa nome fittizio${NC}"
echo -e "     - Password: lascia vuota o mettine una semplice"
echo -e "     - Domande sicurezza: rispondi a caso"
echo -e "     - Tutte le opzioni privacy: NO"
echo -e "     - Cortana: NO"
echo ""
echo -e "  ${BOLD}3. Appena entri nel desktop — PRIMA DI TUTTO${NC}"
echo -e "     - ${YELLOW}NON aggiornare Windows (blocca aggiornamenti)${NC}"
echo -e "     - Apri PowerShell come admin e digita:"
echo -e "       ${CYAN}sc config wuauserv start=disabled${NC}"
echo -e "       ${CYAN}net stop wuauserv${NC}"
echo ""
echo -e "  ${BOLD}4. Installa VirtualBox Guest Additions${NC}"
echo -e "     - Nel menu VirtualBox: Dispositivi → Inserisci Guest Additions"
echo -e "     - Esegui VBoxWindowsAdditions.exe nella VM"
echo -e "     - Riavvia la VM"
echo ""
echo -e "  ${BOLD}5. Poi: installa Steam → scarica Destiny 2 → avvia${NC}"
echo -e "     - Steam: https://store.steampowered.com/about/"
echo -e "     - Accedi con ACCOUNT MULETTO (mai quello principale)"
echo ""
echo -e "${BOLD}${GREEN}Avvio VM...${NC}"
echo ""
VBoxManage startvm "$VM_NAME" --type gui
