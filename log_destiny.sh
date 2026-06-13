#!/bin/bash

# Destiny 2 / BattlEye Passive Analysis Script
# Modalita PASSIVA: solo lettura syscall e traffico rete, zero scrittura memoria

set -e

WINMERDA_DIR="/home/lollo/winmerda"
LOGS_DIR="$WINMERDA_DIR/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Percorso reale Destiny 2 (rilevato automaticamente)
DESTINY_BASE="/run/media/lollo/F9FF-FB10/SteamLibrary/steamapps/common/Destiny 2"
DESTINY_EXE="$DESTINY_BASE/destiny2.exe"

# Porte BattlEye identificate da BEClient_x64.cfg e BELauncher.ini
BE_MASTER_PORT=3074
BE_BASE_PORT=3077

mkdir -p "$LOGS_DIR"

LOG_STRACE="$LOGS_DIR/strace_$TIMESTAMP.log"
LOG_NET="$LOGS_DIR/battleye_net_$TIMESTAMP.pcap"
LOG_FILTERED="$LOGS_DIR/filtered_$TIMESTAMP.log"

echo "=========================================="
echo " Destiny 2 / BattlEye Passive Analyzer"
echo "=========================================="
echo " Eseguibile : $DESTINY_EXE"
echo " Log strace : $LOG_STRACE"
echo " Capture net: $LOG_NET"
echo " Porte BE   : $BE_MASTER_PORT (master), $BE_BASE_PORT (base)"
echo "=========================================="

# Verifica eseguibile
if [ ! -f "$DESTINY_EXE" ]; then
    echo "[ERRORE] Destiny 2 non trovato: installazione ancora in corso?"
    echo "         Eseguibile atteso: $DESTINY_EXE"
    exit 1
fi

# Step 1: Avvia cattura rete passiva in background (porte BattlEye)
echo ""
echo "[1/3] Avvio cattura traffico BattlEye (porte $BE_MASTER_PORT/$BE_BASE_PORT)..."
sudo tcpdump -i any \
    "port $BE_MASTER_PORT or port $BE_BASE_PORT" \
    -w "$LOG_NET" \
    -q 2>/dev/null &
TCPDUMP_PID=$!
echo "      tcpdump PID: $TCPDUMP_PID"

# Breve attesa per assicurarsi che tcpdump sia pronto
sleep 1

# Step 2: Avvia strace in modalita PASSIVA (solo syscall di lettura, no ptrace write)
echo "[2/3] Avvio strace passivo (syscall read-only)..."
SYSCALLS_READONLY="open,openat,stat,statfs,uname,access,readlink,getcwd,connect,sendto,recvfrom,read"
strace -f \
    -e trace=$SYSCALLS_READONLY \
    -o "$LOG_STRACE" \
    -s 512 \
    "$DESTINY_EXE" 2>&1 || true

# Step 3: Ferma tcpdump
echo "[3/3] Cattura completata, fermo tcpdump..."
kill $TCPDUMP_PID 2>/dev/null || true
wait $TCPDUMP_PID 2>/dev/null || true

echo ""
echo "=========================================="
echo " Filtraggio log per pattern critici..."
echo "=========================================="

PATTERNS=(
    "wine" "proton" "linux" "unix"
    "battleye" "kernel" "driver"
    "unauthori" "denied" "error" "fail"
    "/home/" "/proc/" "/sys/"
)

for pattern in "${PATTERNS[@]}"; do
    grep -i "$pattern" "$LOG_STRACE" >> "$LOG_FILTERED" 2>/dev/null || true
done

echo " Linee strace totali : $(wc -l < "$LOG_STRACE")"
echo " Linee filtrate      : $(wc -l < "$LOG_FILTERED")"
echo ""
echo " Prime 20 righe filtrate:"
echo "------------------------------------------"
head -n 20 "$LOG_FILTERED"
echo "------------------------------------------"
echo ""
echo " Analisi completata."
echo " Log locali in: $LOGS_DIR"
echo " NON caricare questi file pubblicamente."
