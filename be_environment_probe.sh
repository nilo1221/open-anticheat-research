#!/bin/bash

# ============================================================
# BattlEye Environment Probe — open-anticheat-research
# Testa tutti i vettori di detection documentati in
# bungie_threat_model.md e simula cosa vedrebbe BEDaisy.sys
#
# MODALITA PASSIVA: zero scrittura memoria, zero modifiche
# Solo lettura e misurazione dell'ambiente corrente
# ============================================================

set -uo pipefail

WINMERDA_DIR="/home/lollo/winmerda"
LOGS_DIR="$WINMERDA_DIR/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$LOGS_DIR/probe_report_$TIMESTAMP.txt"
WINEPREFIX_DEFAULT="$HOME/.wine"
PROTON_PREFIX="$HOME/.steam/steam/steamapps/compatdata/1085660/pfx"

mkdir -p "$LOGS_DIR"

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

PASS=0
FAIL=0
WARN=0

log() { echo "$1" | tee -a "$REPORT_FILE"; }
pass() { echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$REPORT_FILE"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1" | tee -a "$REPORT_FILE"; FAIL=$((FAIL+1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$REPORT_FILE"; WARN=$((WARN+1)); }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$REPORT_FILE"; }
section() { echo -e "\n${BOLD}${BLUE}══════════════════════════════════════════${NC}" | tee -a "$REPORT_FILE"
            echo -e "${BOLD}${BLUE}  $1${NC}" | tee -a "$REPORT_FILE"
            echo -e "${BOLD}${BLUE}══════════════════════════════════════════${NC}" | tee -a "$REPORT_FILE"; }

# ============================================================
echo -e "${BOLD}" | tee -a "$REPORT_FILE"
log "  BattlEye Environment Probe v1.0"
log "  open-anticheat-research — github.com/nilo1221/open-anticheat-research"
log "  Timestamp: $(date)"
log "  Report: $REPORT_FILE"
echo -e "${NC}" | tee -a "$REPORT_FILE"

# ============================================================
section "VETTORE #1 — HWID: Disco fisico (ZwOpenFile + IOCTL 0x2D1400)"
# BEDaisy apre \Device\Harddisk0\DR0 e invia IOCTL per leggere serial
# Su Wine: il device non esiste o restituisce dati emulati

info "Verifica accesso diretto al disco (equivalente Linux di DR0)..."

# Controlla se /dev/sda o /dev/nvme0n1 è leggibile (simula accesso raw)
DISK_DEVICE=""
for dev in /dev/nvme0n1 /dev/sda /dev/vda; do
    if [ -e "$dev" ]; then
        DISK_DEVICE="$dev"
        break
    fi
done

if [ -n "$DISK_DEVICE" ]; then
    info "Disco trovato: $DISK_DEVICE"
    # Leggi serial number (equivalente di IOCTL 0x2D1400)
    SERIAL=$(udevadm info --query=all --name="$DISK_DEVICE" 2>/dev/null | grep "ID_SERIAL=" | head -1 | cut -d= -f2 || echo "N/A")
    MODEL=$(udevadm info --query=all --name="$DISK_DEVICE" 2>/dev/null | grep "ID_MODEL=" | head -1 | cut -d= -f2 || echo "N/A")
    info "  Modello : $MODEL"
    info "  Serial  : $SERIAL"

    # BEDaisy blacklista serial QEMU default
    if echo "$SERIAL" | grep -qi "qemu\|virtio\|vbox\|vmware\|harddisk"; then
        fail "Serial disco è un default virtuale — BEDaisy lo rileverà come VM (BLACKLISTED)"
    elif [ "$SERIAL" = "N/A" ] || [ -z "$SERIAL" ]; then
        warn "Serial disco non leggibile — comportamento anomalo su sistema reale"
    else
        pass "Serial disco sembra reale: $SERIAL"
    fi
else
    fail "Nessun disco fisico trovato — ambiente completamente virtualizzato"
fi

# ============================================================
section "VETTORE #2 — SLEEP DELTA (GetTickCount + Sleep(1000), soglia 1200ms)"
# BEClient misura: tick_before = GetTickCount(); Sleep(1000); tick_after
# Se (tick_after - tick_before) >= 1200ms → report 0x45 → PLUM

info "Misura latenza Sleep(1000ms) — simulazione check BEClient..."
info "Eseguo 3 misurazioni per stabilità..."

TOTAL_DELTA=0
for i in 1 2 3; do
    T_START=$(date +%s%3N)
    sleep 1
    T_END=$(date +%s%3N)
    DELTA=$((T_END - T_START))
    info "  Misurazione $i: ${DELTA}ms"
    TOTAL_DELTA=$((TOTAL_DELTA + DELTA))
done
AVG_DELTA=$((TOTAL_DELTA / 3))

info "  Media: ${AVG_DELTA}ms (soglia BattlEye: 1200ms)"

if [ "$AVG_DELTA" -ge 1200 ]; then
    fail "SLEEP DELTA CRITICO: ${AVG_DELTA}ms >= 1200ms → BEClient invierà report 0x45 → PLUM garantito"
elif [ "$AVG_DELTA" -ge 1100 ]; then
    warn "SLEEP DELTA BORDERLINE: ${AVG_DELTA}ms — vicino alla soglia, instabile sotto carico"
else
    pass "Sleep delta OK: ${AVG_DELTA}ms < 1200ms (margine: $((1200 - AVG_DELTA))ms)"
fi

# ============================================================
section "VETTORE #3 — HAL.DLL: Hardware Abstraction Layer"
# BEClient: GetModuleHandleA("hal.dll") → legge bytes a offset +0x1000
# Wine hal.dll ha bytes diversi dall'originale Windows → report 0x46

info "Ricerca hal.dll nel WINEPREFIX..."

HAL_FOUND=false
for prefix in "$PROTON_PREFIX" "$WINEPREFIX_DEFAULT" "$HOME/.local/share/Steam/steamapps/compatdata/1085660/pfx"; do
    HAL_PATH="$prefix/drive_c/windows/system32/hal.dll"
    if [ -f "$HAL_PATH" ]; then
        HAL_FOUND=true
        HAL_SIZE=$(du -sh "$HAL_PATH" | cut -f1)
        HAL_MD5=$(md5sum "$HAL_PATH" 2>/dev/null | cut -d' ' -f1 || echo "N/A")
        info "  Trovata: $HAL_PATH"
        info "  Size   : $HAL_SIZE"
        info "  MD5    : $HAL_MD5"
        # Verifica se è la hal.dll di Wine (fake) o nativa Windows
        FILE_TYPE=$(file "$HAL_PATH" 2>/dev/null | head -1 || echo "N/A")
        info "  Type   : $FILE_TYPE"
        if echo "$FILE_TYPE" | grep -qi "PE32"; then
            warn "hal.dll trovata ma è probabilmente la versione Wine (emulata) — checksum diverso da Windows reale"
        else
            fail "hal.dll non è un PE32 valido — BEClient rileverà anomalia"
        fi
        break
    fi
done

if [ "$HAL_FOUND" = false ]; then
    warn "hal.dll non trovata nel WINEPREFIX (normale se Proton non ancora avviato)"
fi

# ============================================================
section "VETTORE #4 — DEVICE BEEP/NULL (report 0x3E — driver hijacking)"
# BEClient: CreateFileA("\\.\Beep") — se esiste → segnala driver hijacking
# Wine espone questi device innocentemente ma BE li vede come allarme

info "Verifica device Beep e Null nel WINEPREFIX..."

DOSDEVICES_DIRS=(
    "$PROTON_PREFIX/dosdevices"
    "$WINEPREFIX_DEFAULT/dosdevices"
)

BEEP_FOUND=false
NULL_FOUND=false

for dosdir in "${DOSDEVICES_DIRS[@]}"; do
    if [ -d "$dosdir" ]; then
        info "  Scansione: $dosdir"
        if [ -e "$dosdir/beep" ] || [ -e "$dosdir/Beep" ]; then
            BEEP_FOUND=true
            fail "  \\.\Beep trovato in $dosdir — BEClient invierà report 0x3E"
        fi
        if [ -e "$dosdir/null" ] || [ -e "$dosdir/Null" ]; then
            NULL_FOUND=true
            warn "  \\.\Null trovato in $dosdir — BEClient lo controlla"
        fi
        # Lista tutti i device presenti
        info "  Device presenti: $(ls "$dosdir" 2>/dev/null | tr '\n' ' ' || echo 'nessuno')"
    fi
done

# Controlla anche /dev/input (Wine a volte crea symlink)
if [ "$BEEP_FOUND" = false ] && [ "$NULL_FOUND" = false ]; then
    pass "Device Beep/Null non trovati nel WINEPREFIX (buono)"
fi

# Controlla il modulo kernel beep di Linux
if lsmod 2>/dev/null | grep -q "^pcspkr"; then
    warn "Modulo kernel pcspkr (beep) caricato — potrebbe essere esposto tramite Wine"
fi

# ============================================================
section "VETTORE #5 — OS VERSION (RtlGetVersion — mismatch strutture kernel)"

info "Verifica versione OS sistema host..."
KERNEL_VERSION=$(uname -r)
KERNEL_NAME=$(uname -s)
info "  Kernel   : $KERNEL_NAME $KERNEL_VERSION"
info "  OS       : $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 2>/dev/null || echo 'Unknown')"

if [ "$KERNEL_NAME" = "Linux" ]; then
    warn "Sistema host è Linux — BEDaisy.sys ottiene RtlGetVersion con strutture Linux-emulate da Wine"
    info "  Soluzione richiesta: KVM con Windows reale come guest"
fi

# Hypervisor detection
if grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
    warn "Hypervisor bit rilevato in /proc/cpuinfo — sistema gira in una VM"
    info "  Fix KVM: <feature policy='disable' name='hypervisor'/> in libvirt XML"
else
    pass "Hypervisor bit NON presente in /proc/cpuinfo (bare metal o VM ben configurata)"
fi

# CPUID check
if command -v cpuid &>/dev/null; then
    HYPERVISOR_ID=$(cpuid -1 -l 0x40000000 2>/dev/null | grep "ebx" | head -1 || echo "")
    if [ -n "$HYPERVISOR_ID" ]; then
        info "  CPUID 0x40000000: $HYPERVISOR_ID"
    fi
fi

# ============================================================
section "VETTORE #6 — PROCESS PARENT CHAIN (BEService come parent)"

info "Verifica presenza processi BattlEye..."

if pgrep -x "BEService_x64" &>/dev/null || pgrep -x "BEService" &>/dev/null; then
    info "  BEService in esecuzione (buono se avviato correttamente)"
else
    warn "  BEService non in esecuzione — avviare sempre tramite destiny2launcher.exe"
fi

# Verifica Wine/Proton in esecuzione
WINE_PROCS=$(pgrep -la "wine\|proton\|wineserver" 2>/dev/null | wc -l)
if [ "$WINE_PROCS" -gt 0 ]; then
    info "  Processi Wine/Proton attivi: $WINE_PROCS"
    warn "  Se il gioco è in esecuzione, questi processi sono visibili a BEDaisy"
fi

# ============================================================
section "VETTORE #7 — NAMED PIPE (\\.\namedpipe\Battleye)"

info "Verifica supporto named pipe in Wine..."

# Controlla se il socket Wine per named pipe è disponibile
WINE_SOCKET=$(find /tmp/.wine-* /run/user/*/wine* -name "*.sock" 2>/dev/null | head -3)
if [ -n "$WINE_SOCKET" ]; then
    info "  Socket Wine trovati: $WINE_SOCKET"
    pass "  Wine sembra attivo — named pipe probabilmente funzionante"
else
    warn "  Nessun socket Wine trovato — Wine non in esecuzione o named pipe non disponibile"
fi

# ============================================================
section "VETTORE #8 — KERNEL OBJECT SCAN (ZwQueryDirectoryObject)"

info "Verifica oggetti kernel sospetti..."

# Su Linux, /proc e /sys non hanno equivalenti Windows
PROC_EXISTS=$(ls /proc/ 2>/dev/null | wc -l)
SYS_EXISTS=$(ls /sys/ 2>/dev/null | wc -l)
info "  /proc entries: $PROC_EXISTS"
info "  /sys  entries: $SYS_EXISTS"

# Questi sono invisibili su KVM con Windows guest (corretto)
# Su Wine, Wine li espone parzialmente
warn "Su Wine puro, /proc e /sys possono essere visibili al gioco come strutture anomale"
info "  Soluzione: KVM con Windows guest — host Linux completamente isolato"

# Caricamento moduli sospetti
SUSPICIOUS_MODS=$(lsmod 2>/dev/null | grep -E "vboxdrv|vmw_|virtio" | awk '{print $1}' | tr '\n' ' ' || echo "nessuno")
info "  Moduli VM rilevati: $SUSPICIOUS_MODS"
if [ "$SUSPICIOUS_MODS" != "nessuno" ] && [ -n "$SUSPICIOUS_MODS" ]; then
    warn "Moduli virtualizzazione caricati: $SUSPICIOUS_MODS"
else
    pass "Nessun modulo VM ovvio caricato"
fi

# ============================================================
section "VETTORE #9 — NETWORK: Porte BattlEye (3074/3077)"

info "Verifica connettività verso porte BattlEye..."

# Controlla se le porte sono aperte nel firewall
if command -v ufw &>/dev/null; then
    UFW_STATUS=$(sudo ufw status 2>/dev/null | head -5 || echo "ufw non accessibile senza sudo")
    info "  UFW status: $UFW_STATUS"
fi

# Simula una connessione di test alle porte BE (solo connect, no dati)
for PORT in 3074 3077; do
    if timeout 3 bash -c "echo >/dev/tcp/1.1.1.1/$PORT" 2>/dev/null; then
        warn "  Porta $PORT: raggiungibile verso internet (verifica firewall)"
    else
        info "  Porta $PORT: test connessione neutro (normale)"
    fi
done

pass "Porte BattlEye (3074/3077) da monitorare con tcpdump durante il gioco"

# ============================================================
section "RIEPILOGO AMBIENTE"

info "Sistema: $(uname -n) — $(uname -r)"
info "CPU: $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs 2>/dev/null || echo 'N/A')"
info "RAM: $(free -h | awk '/^Mem:/{print $2}' 2>/dev/null || echo 'N/A')"
info "GPU: $(lspci 2>/dev/null | grep -i 'vga\|3d' | head -1 | cut -d: -f3 | xargs || echo 'N/A')"

# ============================================================
section "VERDETTO FINALE — Cosa vedrebbe BEDaisy"

echo "" | tee -a "$REPORT_FILE"
echo -e "${BOLD}Risultati:${NC}" | tee -a "$REPORT_FILE"
echo -e "  ${GREEN}PASS${NC}: $PASS vettori sicuri" | tee -a "$REPORT_FILE"
echo -e "  ${YELLOW}WARN${NC}: $WARN vettori a rischio" | tee -a "$REPORT_FILE"
echo -e "  ${RED}FAIL${NC}: $FAIL vettori critici" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

if [ "$FAIL" -gt 2 ]; then
    echo -e "${RED}${BOLD}VERDETTO: DETECTION CERTA${NC}" | tee -a "$REPORT_FILE"
    echo -e "${RED}BEDaisy rileverà questo ambiente. PLUM garantito al primo avvio.${NC}" | tee -a "$REPORT_FILE"
elif [ "$FAIL" -gt 0 ] || [ "$WARN" -gt 3 ]; then
    echo -e "${YELLOW}${BOLD}VERDETTO: DETECTION PROBABILE${NC}" | tee -a "$REPORT_FILE"
    echo -e "${YELLOW}Alcuni vettori critici attivi. Alto rischio PLUM, possibile ban.${NC}" | tee -a "$REPORT_FILE"
else
    echo -e "${GREEN}${BOLD}VERDETTO: AMBIENTE RELATIVAMENTE PULITO${NC}" | tee -a "$REPORT_FILE"
    echo -e "${GREEN}Pochi vettori di rischio. Procedere con test su account muletto.${NC}" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"
echo -e "${CYAN}Report completo salvato in: $REPORT_FILE${NC}"
echo -e "${CYAN}NON condividere questo file pubblicamente.${NC}"
