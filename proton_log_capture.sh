#!/bin/bash

# ============================================================
# Proton Log Capture — open-anticheat-research
#
# Lancia Destiny 2 con PROTON_LOG=1 e cattura simultaneamente:
#   - Log Proton completo (tutto quello che Wine vede)
#   - Log BattlEye dalla sua cartella
#   - dmesg al momento del crash (kernel events)
#   - Snapshot processi al momento del crash
#
# MODALITA PASSIVA: nessuna modifica al gioco
# USO: bash proton_log_capture.sh [--dry-run]
# ============================================================

set -uo pipefail

WINMERDA_DIR="/home/lollo/winmerda"
EVIDENCE_DIR="$WINMERDA_DIR/evidence/raw_logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SESSION_DIR="$EVIDENCE_DIR/session_$TIMESTAMP"

D2_APPID="1085660"
D2_INSTALL="/run/media/lollo/F9FF-FB10/SteamLibrary/steamapps/common/Destiny 2"
D2_BATTLEYE_LOG="$D2_INSTALL/BattlEye/BEClient.log"

STEAM_COMPAT="$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/compatdata/$D2_APPID"
PROTON_LOG_FILE="$STEAM_COMPAT/proton.log"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

mkdir -p "$SESSION_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log()  { echo -e "[$(date +%H:%M:%S)] $1" | tee -a "$SESSION_DIR/capture.log"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1" | tee -a "$SESSION_DIR/capture.log"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$SESSION_DIR/capture.log"; }
err()  { echo -e "${RED}[ERR]${NC} $1" | tee -a "$SESSION_DIR/capture.log"; }
info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$SESSION_DIR/capture.log"; }

# ============================================================
echo -e "${BOLD}"
log "Proton Log Capture v1.0 — open-anticheat-research"
log "Sessione: $SESSION_DIR"
$DRY_RUN && log "MODALITA DRY-RUN: nessun gioco verrà avviato"
echo -e "${NC}"

# ============================================================
log "=== PRE-FLIGHT CHECK ==="

# Verifica gioco installato
if [ -d "$D2_INSTALL" ]; then
    ok "Destiny 2 trovato: $D2_INSTALL"
else
    warn "Destiny 2 non trovato in $D2_INSTALL"
    warn "Aggiornare D2_INSTALL nello script con il percorso corretto"
fi

# Verifica Steam (Flatpak)
STEAM_CMD=""
if command -v flatpak &>/dev/null && flatpak list 2>/dev/null | grep -q "com.valvesoftware.Steam"; then
    STEAM_CMD="flatpak run com.valvesoftware.Steam"
    ok "Steam Flatpak trovato"
elif command -v steam &>/dev/null; then
    STEAM_CMD="steam"
    ok "Steam nativo trovato"
else
    warn "Steam non trovato — aggiornare STEAM_CMD nello script"
fi

# Verifica account muletto
echo ""
echo -e "${YELLOW}${BOLD}⚠ IMPORTANTE: Stai usando un account MULETTO?${NC}"
echo -e "   Il log PROTON_LOG=1 genera un crash intenzionale di rilevamento."
echo -e "   NON usare account principale."
echo ""
if ! $DRY_RUN; then
    read -r -p "Conferma account muletto (s/N): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
        err "Abortito. Crea un account muletto prima del test."
        exit 1
    fi
fi

# ============================================================
log "=== SNAPSHOT PRE-AVVIO ==="

# Snapshot dmesg prima dell'avvio (riferimento)
dmesg --time-format=reltime 2>/dev/null | tail -100 > "$SESSION_DIR/dmesg_before.log"
ok "Snapshot dmesg pre-avvio salvato"

# Lista moduli kernel attivi
lsmod > "$SESSION_DIR/lsmod_before.log"
ok "Lista moduli kernel salvata"

# Lista processi
ps aux > "$SESSION_DIR/ps_before.log"
ok "Snapshot processi pre-avvio salvato"

# Misura Sleep delta baseline
T1=$(date +%s%3N); sleep 1; T2=$(date +%s%3N)
DELTA=$((T2 - T1))
echo "baseline_sleep_delta_ms=$DELTA" > "$SESSION_DIR/baseline.env"
log "Sleep delta baseline: ${DELTA}ms"

if [ "$DELTA" -ge 1200 ]; then
    warn "Sleep delta CRITICO (${DELTA}ms) — PLUM garantito indipendentemente da Wine"
    warn "Riduci il carico sistema prima del test"
fi

# ============================================================
log "=== AVVIO MONITOR BACKGROUND ==="

# Monitora dmesg in background per catturare kernel events durante il crash
(
    dmesg -w --time-format=reltime 2>/dev/null >> "$SESSION_DIR/dmesg_live.log" &
    DMESG_PID=$!
    echo $DMESG_PID > "$SESSION_DIR/dmesg_monitor.pid"
) 2>/dev/null || warn "Monitor dmesg non disponibile (prova con sudo)"

# Monitora BattlEye log in background
(
    if [ -f "$D2_BATTLEYE_LOG" ]; then
        tail -f "$D2_BATTLEYE_LOG" > "$SESSION_DIR/battleye_live.log" 2>/dev/null &
        echo $! > "$SESSION_DIR/be_monitor.pid"
        ok "Monitor BattlEye log avviato"
    else
        warn "BattlEye log non trovato: $D2_BATTLEYE_LOG"
        warn "Verra' creato al primo avvio del gioco"
    fi
) &

# ============================================================
log "=== AVVIO DESTINY 2 CON PROTON LOG ==="

# Variabili ambiente per cattura completa
export PROTON_LOG=1
export PROTON_LOG_DIR="$SESSION_DIR"
export WINEDEBUG="err+all,warn+module,warn+dll,warn+heap"
export DXVK_LOG_LEVEL="info"
export VKD3D_DEBUG="warn"

# Costruisci comando Steam con launch options
STEAM_LAUNCH_OPTS="PROTON_LOG=1 PROTON_LOG_DIR=\"$SESSION_DIR\" WINEDEBUG=\"err+all,warn+module,warn+dll\" %command%"

log "Variabili cattura configurate:"
info "  PROTON_LOG=1"
info "  PROTON_LOG_DIR=$SESSION_DIR"
info "  WINEDEBUG=err+all,warn+module,warn+dll"
info ""
info "Per avviare il gioco con questi parametri:"
info ""
info "  METODO A — Via Steam GUI:"
info "    1. Tasto destro Destiny 2 → Properties → Launch Options"
info "    2. Incolla: PROTON_LOG=1 PROTON_LOG_DIR=\"$SESSION_DIR\" %command%"
info "    3. Avvia il gioco"
info ""
info "  METODO B — Via terminale (se Steam nativo):"
info "    steam -applaunch $D2_APPID"
info ""

if ! $DRY_RUN && [ -n "$STEAM_CMD" ]; then
    log "Avvio Steam con parametri di cattura..."
    env PROTON_LOG=1 \
        PROTON_LOG_DIR="$SESSION_DIR" \
        WINEDEBUG="err+all,warn+module,warn+dll,warn+heap" \
        $STEAM_CMD -applaunch "$D2_APPID" &>/dev/null &
    STEAM_PID=$!
    echo $STEAM_PID > "$SESSION_DIR/steam.pid"
    ok "Steam avviato (PID: $STEAM_PID)"

    # Aspetta crash/chiusura gioco
    log "In attesa del crash o chiusura gioco..."
    log "(Premi Ctrl+C per terminare la cattura manualmente)"
    wait $STEAM_PID 2>/dev/null || true
fi

# ============================================================
log "=== RACCOLTA POST-CRASH ==="

sleep 2

# Snapshot dmesg dopo il crash
dmesg --time-format=reltime 2>/dev/null | tail -200 > "$SESSION_DIR/dmesg_after.log"
ok "Snapshot dmesg post-crash salvato"

# Diff dmesg (solo le righe nuove apparse durante il gioco)
diff "$SESSION_DIR/dmesg_before.log" "$SESSION_DIR/dmesg_after.log" 2>/dev/null | \
    grep "^>" | sed 's/^> //' > "$SESSION_DIR/dmesg_diff.log" || true
DMESG_NEW=$(wc -l < "$SESSION_DIR/dmesg_diff.log" 2>/dev/null || echo "0")
ok "Nuovi eventi kernel durante sessione: $DMESG_NEW righe"

# Copia log BattlEye se esiste
if [ -f "$D2_BATTLEYE_LOG" ]; then
    cp "$D2_BATTLEYE_LOG" "$SESSION_DIR/BEClient.log"
    ok "Log BattlEye copiato"
fi

# Cerca log Proton generati da Steam
for logfile in \
    "$STEAM_COMPAT/proton.log" \
    "$HOME/.steam/steam/logs/proton_$D2_APPID.log" \
    "/tmp/proton_$D2_APPID"*.log \
    "$SESSION_DIR"/*.log; do
    if [ -f "$logfile" ] && [ "$logfile" != "$SESSION_DIR/capture.log" ]; then
        BASENAME=$(basename "$logfile")
        cp "$logfile" "$SESSION_DIR/proton_$BASENAME" 2>/dev/null && \
            ok "Log copiato: $BASENAME"
    fi
done

# Termina monitor background
for pidfile in "$SESSION_DIR"/*.pid; do
    if [ -f "$pidfile" ]; then
        PID=$(cat "$pidfile" 2>/dev/null || echo "")
        [ -n "$PID" ] && kill "$PID" 2>/dev/null || true
    fi
done

# ============================================================
log "=== SANITIZZAZIONE AUTOMATICA ==="

SANITIZED_DIR="$SESSION_DIR/sanitized"
mkdir -p "$SANITIZED_DIR"

for logfile in "$SESSION_DIR"/*.log "$SESSION_DIR"/*.txt; do
    [ -f "$logfile" ] || continue
    BASENAME=$(basename "$logfile")

    sed \
        -e "s|/home/[^/ ]*|/home/USER|g" \
        -e "s|C:\\\\Users\\\\[^\\\\]*|C:\\\\Users\\\\USER|g" \
        -e "s|$(whoami)|USER|g" \
        -e 's/[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}:[0-9a-fA-F]\{2\}/XX:XX:XX:XX:XX:XX/g' \
        -e 's/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/X.X.X.X/g' \
        -e 's/Serial[^=]*=\s*[^ ]*/Serial=REDACTED/gi' \
        "$logfile" > "$SANITIZED_DIR/${BASENAME%.log}.sanitized.log" 2>/dev/null
done

ok "Log sanitizzati in: $SANITIZED_DIR"

# ============================================================
log "=== ANALISI AUTOMATICA PRELIMINARE ==="

ANALYSIS_FILE="$SESSION_DIR/auto_analysis.md"

cat > "$ANALYSIS_FILE" << ANALYSIS_EOF
# Auto-analisi sessione $TIMESTAMP

## Metriche Rapide
- Sleep delta baseline: ${DELTA}ms
- Nuovi eventi dmesg: $DMESG_NEW

## Pattern BE Critici Cercati

ANALYSIS_EOF

# Cerca pattern critici nei log
PATTERNS=(
    "bedaisy"
    "BattlEye"
    "heartbeat"
    "Access denied"
    "kernel module"
    "failed to load"
    "PLUM"
    "environment check"
    "integrity"
    "namedpipe"
    "hal.dll"
)

for pattern in "${PATTERNS[@]}"; do
    COUNT=$(grep -ri "$pattern" "$SESSION_DIR"/*.log 2>/dev/null | \
            grep -v "auto_analysis\|capture.log" | wc -l || echo "0")
    if [ "$COUNT" -gt 0 ]; then
        echo "### Pattern: \`$pattern\` — $COUNT occorrenze" >> "$ANALYSIS_FILE"
        grep -ri "$pattern" "$SESSION_DIR"/*.log 2>/dev/null | \
            grep -v "auto_analysis\|capture.log" | \
            head -5 >> "$ANALYSIS_FILE" 2>/dev/null || true
        echo "" >> "$ANALYSIS_FILE"
    fi
done

ok "Analisi preliminare salvata: $ANALYSIS_FILE"

# ============================================================
log "=== RIEPILOGO SESSIONE ==="

echo ""
echo -e "${BOLD}File generati in: $SESSION_DIR${NC}"
ls -lh "$SESSION_DIR"/ 2>/dev/null | grep -v "^total" | awk '{print "  " $NF " (" $5 ")"}'
echo ""
echo -e "${GREEN}${BOLD}Prossimo passo:${NC}"
echo -e "  1. Esamina $SESSION_DIR/auto_analysis.md"
echo -e "  2. Copia le ultime 50 righe di proton_*.log"
echo -e "  3. Incollale nel template: evidence/schede/PLUM_00N.md"
echo -e "  4. Confronta con il log Windows in evidence/schede/PLUM_001.md"
echo ""
echo -e "${CYAN}Per caricare su GitHub (solo sanitized/):${NC}"
echo -e "  cp -r $SANITIZED_DIR/* $WINMERDA_DIR/evidence/raw_logs/"
echo -e "  git add evidence/ && git commit -m 'evidence: session $TIMESTAMP'"
echo ""
echo -e "${RED}NON caricare i file NON sanitizzati.${NC}"
