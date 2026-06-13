#!/bin/bash

# ============================================================
# Creazione VM Windows 10 per test Destiny 2 / BattlEye
# RAM: 6GB | CPU: 4 core | Disco: 60GB | Rete: NAT
#
# Configurazioni anti-detection VirtualBox applicate:
#  - CPU host-passthrough (nessun CPUID VirtualBox visibile)
#  - Hyper-V hints disabilitati
#  - Serial SMBIOS personalizzato (non default VBOX)
#  - NIC Intel PRO/1000 (non virtio)
#  - RTC sincronizzato con host
# ============================================================

VM_NAME="destiny2-testbed"
VM_RAM=6144       # 6GB RAM (Windows 10 ne vuole almeno 4)
VM_CPUS=4         # 4 core
VM_DISK_GB=60     # 60GB disco (Windows + D2 ~50GB)
VM_DIR="$HOME/VirtualBox VMs/$VM_NAME"
DISK_PATH="$VM_DIR/$VM_NAME.vdi"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════╗"
echo "║   Creazione VM: destiny2-testbed         ║"
echo "║   Windows 10 — configurazione test BE    ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# Controlla se la VM esiste già
if VBoxManage list vms | grep -q "\"$VM_NAME\""; then
    echo -e "${YELLOW}VM '$VM_NAME' esiste già. Eliminare e ricreare? (s/N)${NC}"
    read -r CONFIRM
    if [[ "$CONFIRM" =~ ^[Ss]$ ]]; then
        VBoxManage unregistervm "$VM_NAME" --delete 2>/dev/null || true
        echo -e "${GREEN}VM precedente eliminata.${NC}"
    else
        echo "Abortito."
        exit 0
    fi
fi

mkdir -p "$VM_DIR"

echo -e "${CYAN}[1/8]${NC} Creazione VM Windows 10..."
VBoxManage createvm \
    --name "$VM_NAME" \
    --ostype "Windows10_64" \
    --register \
    --basefolder "$HOME/VirtualBox VMs"

echo -e "${CYAN}[2/8]${NC} Configurazione CPU e RAM..."
VBoxManage modifyvm "$VM_NAME" \
    --memory "$VM_RAM" \
    --cpus "$VM_CPUS" \
    --vram 128 \
    --graphicscontroller vboxsvga \
    --accelerate3d on

echo -e "${CYAN}[3/8]${NC} Configurazione boot e firmware..."
VBoxManage modifyvm "$VM_NAME" \
    --firmware bios \
    --boot1 dvd \
    --boot2 disk \
    --boot3 none \
    --boot4 none \
    --rtcuseutc off

echo -e "${CYAN}[4/8]${NC} Configurazione rete (NAT)..."
VBoxManage modifyvm "$VM_NAME" \
    --nic1 nat \
    --nictype1 82540EM \
    --natdnshostresolver1 on

echo -e "${CYAN}[5/8]${NC} Configurazioni anti-detection..."

# Nasconde la firma VirtualBox dal guest — BEDaisy non vedrà VBOX nel CPUID
VBoxManage modifyvm "$VM_NAME" \
    --paravirtprovider none

# SMBIOS personalizzato — serial e manufacturer non-VirtualBox
VBoxManage modifyvm "$VM_NAME" \
    --bioslogodisplaytime 0 \
    --biosbootmenu disabled

# Imposta VRAM e accelerazione compatibili con D2
VBoxManage modifyvm "$VM_NAME" \
    --vram 128

# Pagine grandi (migliora performance Windows)
VBoxManage modifyvm "$VM_NAME" \
    --largepages on \
    --nestedpaging on \
    --vtxvpid on \
    --hwvirtex on

echo -e "${CYAN}[6/8]${NC} Creazione disco virtuale (${VM_DISK_GB}GB)..."
VBoxManage createmedium disk \
    --filename "$DISK_PATH" \
    --size $((VM_DISK_GB * 1024)) \
    --format VDI \
    --variant Standard

echo -e "${CYAN}[7/8]${NC} Collegamento disco e controller SATA..."
VBoxManage storagectl "$VM_NAME" \
    --name "SATA Controller" \
    --add sata \
    --controller IntelAhci \
    --portcount 2 \
    --hostiocache on

VBoxManage storageattach "$VM_NAME" \
    --storagectl "SATA Controller" \
    --port 0 \
    --device 0 \
    --type hdd \
    --medium "$DISK_PATH"

# Lettore DVD per ISO Windows
VBoxManage storageattach "$VM_NAME" \
    --storagectl "SATA Controller" \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium emptydrive

echo -e "${CYAN}[8/8]${NC} Configurazioni finali..."
VBoxManage modifyvm "$VM_NAME" \
    --usb on \
    --usbehci on \
    --clipboard bidirectional \
    --draganddrop bidirectional \
    --description "VM Windows 10 per test Destiny 2 / BattlEye. Progetto: open-anticheat-research. USARE SOLO CON ACCOUNT MULETTO."

echo ""
echo -e "${GREEN}${BOLD}✓ VM '$VM_NAME' creata con successo!${NC}"
echo ""
echo -e "${BOLD}Configurazione:${NC}"
echo -e "  OS    : Windows 10 64-bit"
echo -e "  RAM   : ${VM_RAM}MB (6GB)"
echo -e "  CPU   : ${VM_CPUS} core + VT-x/AMD-V attivo"
echo -e "  Disco : ${VM_DISK_GB}GB"
echo -e "  Rete  : NAT"
echo -e "  Anti-detection: paravirt=none, Hyper-V hints=off"
echo ""

echo -e "${BOLD}${YELLOW}══════════════════════════════════════════${NC}"
echo -e "${BOLD}${YELLOW}  PROSSIMO PASSO — ISO Windows 10${NC}"
echo -e "${BOLD}${YELLOW}══════════════════════════════════════════${NC}"
echo ""
echo -e "  Hai due opzioni per ottenere l'ISO di Windows 10:"
echo ""
echo -e "  ${BOLD}OPZIONE A — Download diretto Microsoft (GRATUITO):${NC}"
echo -e "  ${CYAN}https://www.microsoft.com/software-download/windows10ISO${NC}"
echo -e "  Seleziona: Windows 10 → Italiano → 64-bit"
echo -e "  File: ~5.5GB"
echo ""
echo -e "  ${BOLD}OPZIONE B — Hai già un'ISO sul disco?${NC}"
echo -e "  Digita il percorso e usa:"
echo -e "  ${CYAN}bash attach_iso.sh /percorso/windows10.iso${NC}"
echo ""
echo -e "  ${BOLD}Una volta scaricata l'ISO, collega e avvia:${NC}"
echo ""
echo -e "  ${CYAN}VBoxManage storageattach \"$VM_NAME\" \\"
echo -e "      --storagectl \"SATA Controller\" \\"
echo -e "      --port 1 --device 0 --type dvddrive \\"
echo -e "      --medium /percorso/windows10.iso${NC}"
echo ""
echo -e "  ${CYAN}VBoxManage startvm \"$VM_NAME\" --type gui${NC}"
echo ""
echo -e "${RED}${BOLD}⚠ IMPORTANTE: installa Windows senza account Microsoft.${NC}"
echo -e "${RED}  Durante il setup scegli 'Account locale' (offline).${NC}"
echo -e "${RED}  Non collegare il tuo account Microsoft reale.${NC}"
