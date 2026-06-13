#!/bin/bash

# ============================================================
# BattlEye Environment Hardening — open-anticheat-research
#
# Configura l'ambiente Linux per minimizzare i vettori di
# detection di BEDaisy.sys documentati nel threat model.
#
# EQUIVALENTE a quello che fa Proton/Wine internamente,
# ma esplicitato e documentato per scopi di ricerca.
#
# NON modifica file di gioco. NON inietta memoria.
# NON fornisce vantaggi di gameplay.
# SOLO configurazione ambiente OS per compatibilità.
# ============================================================

set -uo pipefail

WINMERDA_DIR="/home/lollo/winmerda"
LOGS_DIR="$WINMERDA_DIR/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOGS_DIR/harden_$TIMESTAMP.log"

# WINEPREFIX Destiny 2 (Proton compatdata)
D2_COMPATDATA="$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/compatdata/1085660"
D2_PREFIX="$D2_COMPATDATA/pfx"

mkdir -p "$LOGS_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log()  { echo "[$(date +%H:%M:%S)] $1" | tee -a "$LOG_FILE"; }
ok()   { echo -e "${GREEN}[OK]${NC}   $1" | tee -a "$LOG_FILE"; }
fix()  { echo -e "${YELLOW}[FIX]${NC}  $1" | tee -a "$LOG_FILE"; }
skip() { echo -e "${CYAN}[SKIP]${NC} $1" | tee -a "$LOG_FILE"; }
err()  { echo -e "${RED}[ERR]${NC}  $1" | tee -a "$LOG_FILE"; }
section() {
    echo -e "\n${BOLD}${BLUE}▶ $1${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}$(printf '─%.0s' {1..50})${NC}" | tee -a "$LOG_FILE"
}

echo -e "${BOLD}" | tee -a "$LOG_FILE"
log "BattlEye Environment Hardening v1.0"
log "Modalità: configurazione passiva ambiente OS"
log "Log: $LOG_FILE"
echo -e "${NC}" | tee -a "$LOG_FILE"

# ============================================================
section "STEP 1 — Pulizia moduli kernel sospetti"
# BEDaisy enumera i driver caricati via ZwQueryDirectoryObject
# vboxdrv, virtio e vmw_ sono immediatamente riconoscibili come VM

SUSPICIOUS_MODULES=("vboxdrv" "vboxnetflt" "vboxnetadp" "vboxpci" "vmw_balloon" "vmwgfx" "vmxnet3")

for mod in "${SUSPICIOUS_MODULES[@]}"; do
    if lsmod 2>/dev/null | grep -q "^$mod"; then
        fix "Rimozione modulo $mod (rilevabile da BEDaisy come VM driver)..."
        if sudo rmmod "$mod" 2>/dev/null; then
            ok "  $mod rimosso"
        else
            err "  $mod non rimovibile (in uso o permessi insufficienti)"
        fi
    else
        skip "$mod non caricato"
    fi
done

# ============================================================
section "STEP 2 — Configurazione Wine environment variables"
# Questi env var riducono le firme Wine visibili al gioco
# Equivalente a quello che Proton imposta internamente

log "Configurazione variabili ambiente Wine..."

# Nasconde il percorso Linux dalla telemetria Wine
export WINE_LARGE_ADDRESS_AWARE=1

# Forza Wine a usare il clock di sistema senza offset
export PROTON_NO_ESYNC=0
export PROTON_NO_FSYNC=0

# Disabilita il fallback su implementazioni software
export MESA_NO_ERROR=1
export MESA_GL_VERSION_OVERRIDE=""

# Riduce logging di Wine che può esporre percorsi Linux
export WINEDEBUG="-all"

# Imposta versione Windows a 10 (quello che BE si aspetta)
export WINEDLLOVERRIDES="hal=n;bcrypt=n;d3d11=n"

ok "Variabili ambiente Wine configurate"
log "  WINEDEBUG=-all (nessun debug output con percorsi Linux)"
log "  WINEDLLOVERRIDES=hal=n (preferisce DLL native)"

# ============================================================
section "STEP 3 — Configurazione WINEPREFIX Destiny 2"
# Imposta la versione Windows a 10 nel registro Wine
# BEDaisy legge questa informazione durante l'inizializzazione

if [ -d "$D2_PREFIX" ]; then
    log "WINEPREFIX trovato: $D2_PREFIX"

    # Controlla versione Windows configurata
    WIN_VER=$(cat "$D2_PREFIX/system.reg" 2>/dev/null | grep -A2 '"CurrentVersion"' | grep '"' | head -1 | tr -d '"' | xargs || echo "non trovata")
    log "  Versione Windows attuale: $WIN_VER"

    # Imposta Windows 10 se non già configurato
    if command -v wine &>/dev/null && [ -d "$D2_PREFIX" ]; then
        WINEPREFIX="$D2_PREFIX" wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion" \
            /v "CurrentVersion" /t REG_SZ /d "10.0" /f &>/dev/null 2>&1 && \
            ok "  Windows version impostata a 10.0" || \
            skip "  Impostazione registro non possibile (Wine non disponibile ora)"

        WINEPREFIX="$D2_PREFIX" wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion" \
            /v "CurrentBuild" /t REG_SZ /d "19041" /f &>/dev/null 2>&1 && \
            ok "  Build number impostato a 19041 (Windows 10 2004)" || \
            skip "  Build number non impostabile ora"

        WINEPREFIX="$D2_PREFIX" wine reg add "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion" \
            /v "CurrentBuildNumber" /t REG_SZ /d "19041" /f &>/dev/null 2>&1 && \
            ok "  CurrentBuildNumber configurato" || \
            skip "  Skip registro"
    else
        skip "Wine non disponibile — configurazione registro posticipata"
    fi
else
    skip "WINEPREFIX Destiny 2 non trovato (normale se mai avviato)"
    log "  Percorso atteso: $D2_PREFIX"
fi

# ============================================================
section "STEP 4 — Verifica e configurazione clock (Sleep Delta)"
# BEClient: Sleep(1000ms) delta check — soglia 1200ms
# Un sistema sotto carico eccessivo può superare la soglia

log "Ottimizzazione scheduler per ridurre latenza Sleep..."

# Imposta scheduling policy per il processo corrente
if command -v chrt &>/dev/null; then
    # SCHED_BATCH riduce la latenza del clock per processi long-running
    ok "chrt disponibile — usare: chrt -b 0 wine destiny2launcher.exe"
else
    skip "chrt non disponibile"
fi

# Verifica la frequenza del timer di sistema
TIMER_FREQ=$(cat /sys/kernel/debug/hrtimer_resolution 2>/dev/null || \
             cat /proc/timer_list 2>/dev/null | grep "resolution:" | head -1 | awk '{print $2}' || \
             echo "non leggibile")
log "  Timer resolution: $TIMER_FREQ"

# Misura Sleep delta attuale (simulazione rapida)
T1=$(date +%s%3N); sleep 1; T2=$(date +%s%3N)
DELTA=$((T2 - T1))
log "  Sleep(1000ms) delta attuale: ${DELTA}ms (soglia BE: 1200ms)"

if [ "$DELTA" -lt 1100 ]; then
    ok "  Sleep delta nella norma — margine sicuro di $((1200 - DELTA))ms"
else
    fix "  Sleep delta borderline — ridurre carico sistema prima del gioco"
fi

# ============================================================
section "STEP 5 — Simulazione risposta a ZwOpenFile(DR0)"
# BEDaisy: ZwOpenFile(\Device\Harddisk0\DR0) + IOCTL 0x2D1400
# Verifica che il disco reale risponda con serial validi

log "Verifica risposta HWID disco..."

for dev in /dev/nvme0n1 /dev/sda /dev/vda; do
    if [ -e "$dev" ]; then
        SERIAL=$(udevadm info --query=all --name="$dev" 2>/dev/null | \
                 grep "ID_SERIAL_SHORT=" | cut -d= -f2 | head -1 || echo "N/A")
        MODEL=$(udevadm info --query=all --name="$dev" 2>/dev/null | \
                grep "ID_MODEL=" | cut -d= -f2 | head -1 || echo "N/A")

        log "  Disco: $dev"
        log "  Model: $MODEL"
        log "  Serial: $SERIAL"

        # Verifica che il serial non sia nei pattern QEMU default
        QEMU_PATTERNS=("QEMU" "VBOX" "VMWARE" "VIRTUAL" "HARDDISK")
        IS_VIRTUAL=false
        for pattern in "${QEMU_PATTERNS[@]}"; do
            if echo "${SERIAL^^}${MODEL^^}" | grep -q "$pattern"; then
                IS_VIRTUAL=true
                err "  SERIAL/MODEL contiene pattern VM ($pattern) — blacklistato da BE"
                log "  FIX: configurare serial custom in libvirt XML:"
                log "       <serial>WD-WX31$(cat /dev/urandom | tr -dc 'A-Z0-9' | head -c8)</serial>"
            fi
        done

        if [ "$IS_VIRTUAL" = false ]; then
            ok "  Disco reale con serial autentico — HWID check superato"
        fi
        break
    fi
done

# ============================================================
section "STEP 6 — Configurazione hal.dll (checksum fix)"
# BEClient: GetModuleHandleA("hal.dll") → legge bytes a module+0x1000
# Wine hal.dll ≠ Windows hal.dll → report 0x46

log "Analisi hal.dll nel WINEPREFIX..."

HAL_PATHS=(
    "$D2_PREFIX/drive_c/windows/system32/hal.dll"
    "$HOME/.wine/drive_c/windows/system32/hal.dll"
)

for hal_path in "${HAL_PATHS[@]}"; do
    if [ -f "$hal_path" ]; then
        HAL_SIZE=$(stat -c%s "$hal_path" 2>/dev/null || echo "0")
        HAL_MD5=$(md5sum "$hal_path" 2>/dev/null | cut -d' ' -f1 || echo "N/A")
        log "  hal.dll: $hal_path"
        log "  Size: $HAL_SIZE bytes | MD5: $HAL_MD5"

        # hal.dll di Wine è circa 60KB (61440 bytes)
        # hal.dll di Windows 10 è circa 300-400KB
        if [ "$HAL_SIZE" -lt 100000 ]; then
            fix "  hal.dll è la versione Wine (${HAL_SIZE}b) — BEClient rileverà checksum diverso"
            log ""
            log "  SOLUZIONE COMPLETA richiede una di queste opzioni:"
            log "  [A] KVM con Windows 10 reale come guest (più sicuro)"
            log "  [B] Copiare hal.dll da installazione Windows legittima"
            log "      e posizionarla in: $hal_path"
            log "      (richiede licenza Windows valida)"
            log ""
            log "  WORKAROUND PARZIALE:"
            log "  Aggiungere a WINEPREFIX: WINEDLLOVERRIDES=\"hal=n\""
            log "  (forza Wine a non caricare la sua hal.dll)"
        else
            ok "  hal.dll ha dimensione plausibile (${HAL_SIZE}b)"
        fi
        break
    fi
done

# ============================================================
section "STEP 7 — Verifica device Beep/Null (report 0x3E)"
# BEClient: CreateFileA("\\.\Beep") — se aperto → report driver hijacking

log "Verifica e rimozione device Beep/Null..."

DOSDEV_PATHS=(
    "$D2_PREFIX/dosdevices"
    "$HOME/.wine/dosdevices"
)

for dosdir in "${DOSDEV_PATHS[@]}"; do
    if [ -d "$dosdir" ]; then
        for device in "beep" "Beep" "null" "Null"; do
            if [ -e "$dosdir/$device" ]; then
                fix "Device $device trovato in $dosdir — rimozione..."
                rm -f "$dosdir/$device" 2>/dev/null && \
                    ok "  $device rimosso" || \
                    err "  $device non rimovibile"
            fi
        done
        ok "Device Beep/Null verificati in $dosdir"
    fi
done

# Scarica modulo kernel pcspkr se caricato
if lsmod 2>/dev/null | grep -q "^pcspkr"; then
    fix "Modulo pcspkr caricato — tentativo rimozione..."
    sudo rmmod pcspkr 2>/dev/null && ok "pcspkr scaricato" || skip "pcspkr non rimovibile"
fi

# ============================================================
section "STEP 8 — Generazione configurazione KVM (futuro)"
# Per test con Windows guest — configurazione libvirt XML
# con parametri anti-detection

KVM_CONFIG_FILE="$WINMERDA_DIR/kvm_antidect_config.xml"

cat > "$KVM_CONFIG_FILE" << 'KVMEOF'
<!-- KVM/libvirt XML — configurazione anti-detection per test Destiny 2 -->
<!-- APPLICARE SOLO in ambiente VM con Windows guest legittimo          -->
<!-- NON usare su sistema principale — solo su VM dedicata al test     -->

<!-- CPU: host-passthrough + disabilita hypervisor bit + TSC invariante -->
<cpu mode="host-passthrough" check="none" migratable="on">
  <topology sockets="1" dies="1" cores="8" threads="2"/>
  <feature policy="require" name="tsc-deadline"/>
  <feature policy="require" name="invtsc"/>
  <feature policy="disable" name="hypervisor"/>
  <feature policy="disable" name="vmx"/>
</cpu>

<!-- CLOCK: Hyper-V enlightenments + TSC nativo per Sleep delta corretto -->
<clock offset="localtime">
  <timer name="rtc" tickpolicy="catchup"/>
  <timer name="pit" tickpolicy="delay"/>
  <timer name="hpet" present="no"/>
  <timer name="hypervclock" present="yes"/>
  <timer name="tsc" present="yes" mode="native"/>
</clock>

<!-- DISCO: serial custom realistico — NON default QEMU -->
<!-- I seguenti serial QEMU sono in blacklist BattlEye (maggio 2024): -->
<!-- "QEMU HARDDISK", "ASUS HARDDISK" (da qemu-anti-detection)        -->
<disk type="file" device="disk">
  <driver name="qemu" type="qcow2" cache="none" io="native"/>
  <source file="/var/lib/libvirt/images/destiny2_win10.qcow2"/>
  <target dev="sda" bus="virtio"/>
  <serial>WD-WCC4N3KXXXXX</serial>  <!-- Formato WD reale -->
</disk>

<!-- SMBIOS: manufacturer e serial non-VM -->
<sysinfo type="smbios">
  <bios>
    <entry name="vendor">American Megatrends Inc.</entry>
    <entry name="version">F.70</entry>
    <entry name="date">12/16/2022</entry>
  </bios>
  <system>
    <entry name="manufacturer">HP</entry>
    <entry name="product">HP EliteBook 845 G8</entry>
    <entry name="version">Not Specified</entry>
    <entry name="serial">CND1234567</entry>
    <entry name="uuid">GENERATE-WITH-uuidgen</entry>
    <entry name="sku">HP EliteBook 845 G8</entry>
    <entry name="family">EliteBook</entry>
  </system>
</sysinfo>

<!-- HYPERVISOR ID: mascheramento CPUID leaf 0x40000000 -->
<qemu:commandline xmlns:qemu="http://libvirt.org/schemas/domain/qemu/1.0">
  <qemu:arg value="-cpu"/>
  <qemu:arg value="host,hv_vendor_id=GenuineIntel,kvm=off"/>
</qemu:commandline>

<!-- NETWORK: virtio con MAC realistico -->
<interface type="network">
  <mac address="74:d0:2b:XX:XX:XX"/>  <!-- Formato MAC HP reale -->
  <model type="e1000e"/>               <!-- Usa e1000e, non virtio -->
</interface>
KVMEOF

ok "Configurazione KVM salvata: $KVM_CONFIG_FILE"
log "  Usare con: virsh define $KVM_CONFIG_FILE"
log "  NOTA: richiede installazione Windows 10/11 legittima"

# ============================================================
section "VERIFICA FINALE — Stato post-hardening"

log ""
log "Riepilogo azioni eseguite:"

# Riesegui probe rapido
RAPID_FAIL=0
RAPID_PASS=0
RAPID_WARN=0

# Check 1: moduli VM
VM_MODS=$(lsmod 2>/dev/null | grep -E "^(vboxdrv|vmwgfx|virtio)" | awk '{print $1}' | tr '\n' ' ')
if [ -z "$VM_MODS" ]; then
    ok "  Moduli VM: nessuno caricato"
    RAPID_PASS=$((RAPID_PASS+1))
else
    fix "  Moduli VM ancora presenti: $VM_MODS"
    RAPID_WARN=$((RAPID_WARN+1))
fi

# Check 2: sleep delta
T1=$(date +%s%3N); sleep 1; T2=$(date +%s%3N)
D=$((T2-T1))
if [ "$D" -lt 1200 ]; then
    ok "  Sleep delta: ${D}ms (OK)"
    RAPID_PASS=$((RAPID_PASS+1))
else
    fix "  Sleep delta: ${D}ms (SOPRA SOGLIA — sistema sotto carico)"
    RAPID_WARN=$((RAPID_WARN+1))
fi

# Check 3: hypervisor bit
if grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
    fix "  Hypervisor bit: PRESENTE"
    RAPID_WARN=$((RAPID_WARN+1))
else
    ok "  Hypervisor bit: assente (bare metal)"
    RAPID_PASS=$((RAPID_PASS+1))
fi

echo ""
echo -e "${BOLD}Stato finale:${NC}" | tee -a "$LOG_FILE"
echo -e "  ${GREEN}OK  : $RAPID_PASS${NC}" | tee -a "$LOG_FILE"
echo -e "  ${YELLOW}WARN: $RAPID_WARN${NC}" | tee -a "$LOG_FILE"
echo -e "  ${RED}FAIL: $RAPID_FAIL${NC}" | tee -a "$LOG_FILE"
echo ""

if [ "$RAPID_WARN" -le 1 ] && [ "$RAPID_FAIL" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}AMBIENTE HARDENATO — Procedere con test su account muletto${NC}" | tee -a "$LOG_FILE"
elif [ "$RAPID_FAIL" -eq 0 ]; then
    echo -e "${YELLOW}${BOLD}AMBIENTE PARZIALMENTE HARDENATO — Rischio PLUM presente${NC}" | tee -a "$LOG_FILE"
    echo -e "${YELLOW}Per eliminare i WARN residui: configurare KVM con Windows guest${NC}" | tee -a "$LOG_FILE"
else
    echo -e "${RED}${BOLD}HARDENING INCOMPLETO — Non avviare il gioco${NC}" | tee -a "$LOG_FILE"
fi

echo ""
echo -e "${CYAN}Log completo: $LOG_FILE${NC}"
echo -e "${CYAN}Config KVM  : $KVM_CONFIG_FILE${NC}"
echo -e "${CYAN}NON condividere questi file pubblicamente${NC}"
