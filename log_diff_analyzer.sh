#!/bin/bash

# ============================================================
# Log Diff Analyzer — open-anticheat-research
#
# Confronta un log Linux (tuo) con un log Windows di riferimento
# per isolare la "stringa rivelatrice" — quella che dice a
# BattlEye che sei su Linux.
#
# USO:
#   bash log_diff_analyzer.sh <linux_log> <windows_reference_log>
#   bash log_diff_analyzer.sh --demo   (usa log di esempio interni)
# ============================================================

set -uo pipefail

WINMERDA_DIR="/home/lollo/winmerda"
EVIDENCE_DIR="$WINMERDA_DIR/evidence"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# ============================================================
# LOG DI DEMO — Simulazione basata su dati reali da forum
# ============================================================
create_demo_logs() {
    DEMO_DIR="/tmp/be_diff_demo_$TIMESTAMP"
    mkdir -p "$DEMO_DIR"

    # Log Linux simulato (quello che Proton genera — basato su report ProtonDB reali)
    cat > "$DEMO_DIR/linux_proton.log" << 'LINUXEOF'
[0000.00] Proton: Starting Steam game 1085660
[0000.01] Proton: Using Proton 9.0-3
[0000.05] wine: Call from 0x7f3a... to unimplemented function ntoskrnl.exe.KeInitializeDpc
[0000.06] BEService: Starting BattlEye service...
[0000.07] BEService: Attempting to load kernel driver bedaisy.sys
[0000.08] wine: Call from 0x7f3a... to unimplemented function ntdll.NtLoadDriver
[0000.08] BEService: NtLoadDriver failed: STATUS_PRIVILEGE_NOT_HELD (0xC0000061)
[0000.09] BEService: Kernel driver load FAILED - falling back to usermode only
[0000.10] BEService: Connecting to \\.\namedpipe\Battleye ...
[0000.11] wine: fixme:npipe:CreateNamedPipeW unsupported mode
[0000.12] BEService: Named pipe created with latency mode
[0000.15] BEClient: Injecting into destiny2.exe...
[0000.16] BEClient: Running environment checks
[0000.17] BEClient: Check #1 - hal.dll integrity... [module found: WINE HAL]
[0000.17] BEClient: hal.dll signature: 0x4D5A (PE), size=58465 bytes
[0000.18] BEClient: hal.dll check FAILED - expected signature 0x9CEE... got 0xBB3A...
[0000.18] BEClient: Sending report 0x46 [HAL_INTEGRITY_FAIL]
[0000.20] BEClient: Check #2 - Sleep delta test...
[0000.21] wine: fixme:sync:NtWaitForSingleObject using INFINITE timeout
[1000.85] BEClient: Sleep(1000) delta = 1847ms [THRESHOLD: 1200ms]
[1000.85] BEClient: Sending report 0x45 [SLEEP_DELTA_EXCEEDED]
[1000.86] BEClient: Check #3 - OS version check...
[1000.87] BEClient: RtlGetVersion returned: 10.0.19041
[1000.87] BEClient: Kernel structure validation FAILED [Linux syscall table detected]
[1000.88] BEClient: Sending report 0x71 [OS_STRUCTURE_MISMATCH]
[1000.89] BEClient: Check #4 - Hardware ID...
[1000.89] BEClient: ZwOpenFile(\Device\Harddisk0\DR0) -> STATUS_OBJECT_NAME_NOT_FOUND
[1000.90] BEClient: Hardware ID collection FAILED
[1000.90] BEClient: Sending report 0x12 [HWID_READ_FAIL]
[1000.91] BEClient: Sending all reports to BEServer...
[1000.95] BEServer: Received 4 anomaly reports from client
[1000.96] BEServer: Client environment flagged as UNTRUSTED
[1001.00] Bungie: Server disconnect initiated
[1001.01] Game: Connection terminated - Error Code: PLUM
[1001.02] Game: Session ended
LINUXEOF

    # Log Windows di riferimento (sistema pulito — basato su forum Bungie/Reddit)
    cat > "$DEMO_DIR/windows_clean.log" << 'WINEOF'
[0000.00] BEService: Starting BattlEye service...
[0000.01] BEService: Loading kernel driver bedaisy.sys... OK
[0000.02] BEService: Driver loaded at 0xFFFFF804DEFDB000
[0000.03] BEService: Kernel module initialized - Ring 0 active
[0000.04] BEService: Creating named pipe \\.\namedpipe\Battleye ... OK
[0000.05] BEClient: Injecting into destiny2.exe... OK
[0000.06] BEClient: Running environment checks
[0000.07] BEClient: Check #1 - hal.dll integrity... [module found]
[0000.07] BEClient: hal.dll signature: 0x9CEE0B4A OK [size: 356352 bytes]
[0000.08] BEClient: hal.dll check PASSED
[0000.09] BEClient: Check #2 - Sleep delta test...
[1001.03] BEClient: Sleep(1000) delta = 1003ms [THRESHOLD: 1200ms] OK
[1001.03] BEClient: Sleep delta check PASSED
[1001.04] BEClient: Check #3 - OS version check...
[1001.05] BEClient: RtlGetVersion: 10.0.19041 [validated]
[1001.05] BEClient: Kernel structure validation PASSED
[1001.06] BEClient: Check #4 - Hardware ID...
[1001.06] BEClient: ZwOpenFile(\Device\Harddisk0\DR0) -> OK
[1001.07] BEClient: IOCTL 0x2D1400 -> Serial: WDC-WD10EZEX OK
[1001.08] BEClient: Hardware ID collected successfully
[1001.09] BEClient: All checks PASSED - sending auth token
[1001.10] BEServer: Client authenticated successfully
[1001.11] BEServer: Environment: TRUSTED
[1001.12] Bungie: Connection established
[1001.13] Game: Connected to Bungie servers - OK
WINEOF

    echo "$DEMO_DIR"
}

# ============================================================
# Funzione principale di analisi diff
# ============================================================
analyze_diff() {
    local LINUX_LOG="$1"
    local WIN_LOG="$2"
    local OUTPUT_DIR="${3:-/tmp/be_diff_output_$TIMESTAMP}"

    mkdir -p "$OUTPUT_DIR"
    local REPORT="$OUTPUT_DIR/diff_report.md"

    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║        BattlEye Log Diff Analyzer v1.0              ║"
    echo "║        open-anticheat-research                       ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo "# Diff Report — $TIMESTAMP" > "$REPORT"
    echo "- Linux log: $LINUX_LOG" >> "$REPORT"
    echo "- Windows log: $WIN_LOG" >> "$REPORT"
    echo "" >> "$REPORT"

    # --------------------------------------------------------
    echo -e "${BOLD}${YELLOW}▶ FASE 1 — Pattern critici nel log Linux${NC}"
    echo "" >> "$REPORT"
    echo "## Pattern Critici Rilevati (log Linux)" >> "$REPORT"
    echo "" >> "$REPORT"

    declare -A PATTERNS
    PATTERNS["HAL_INTEGRITY"]="hal.dll.*FAIL|HAL_INTEGRITY"
    PATTERNS["SLEEP_DELTA"]="delta.*[0-9]{4,}ms|SLEEP_DELTA|1[2-9][0-9][0-9]ms|[2-9][0-9][0-9][0-9]ms"
    PATTERNS["DRIVER_FAIL"]="NtLoadDriver.*failed|PRIVILEGE_NOT_HELD|bedaisy.*FAIL"
    PATTERNS["HWID_FAIL"]="Harddisk0.*NOT_FOUND|HWID_READ_FAIL|DR0.*fail"
    PATTERNS["OS_MISMATCH"]="OS_STRUCTURE_MISMATCH|Linux syscall|kernel structure.*FAIL"
    PATTERNS["PIPE_ISSUE"]="namedpipe.*unsupported|npipe.*fixme|pipe.*latency"
    PATTERNS["PLUM"]="PLUM|Error Code.*PLUM|code PLUM"
    PATTERNS["WINE_FIXME"]="wine:.*fixme|unimplemented function"
    PATTERNS["REPORTS_SENT"]="report 0x[0-9a-f]{2}|Sending report"
    PATTERNS["UNTRUSTED"]="UNTRUSTED|flagged|anomaly"

    for pattern_name in "${!PATTERNS[@]}"; do
        pattern="${PATTERNS[$pattern_name]}"
        matches=$(grep -iE "$pattern" "$LINUX_LOG" 2>/dev/null || true)
        count=0
        [ -n "$matches" ] && count=$(echo "$matches" | wc -l)

        if [ "$count" -gt 0 ]; then
            echo -e "${RED}[DETECTED]${NC} $pattern_name ($count occorrenze)"
            echo "### ⚠ $pattern_name ($count occorrenze)" >> "$REPORT"
            echo '```' >> "$REPORT"
            echo "$matches" | head -5 >> "$REPORT"
            echo '```' >> "$REPORT"
            echo "" >> "$REPORT"
        fi
    done

    # --------------------------------------------------------
    echo ""
    echo -e "${BOLD}${YELLOW}▶ FASE 2 — Confronto diretto linee chiave${NC}"
    echo "## Confronto Diretto Linux vs Windows" >> "$REPORT"
    echo "" >> "$REPORT"
    echo "| Vettore | Linux (tuo) | Windows (riferimento) | Delta |" >> "$REPORT"
    echo "|---------|-------------|----------------------|-------|" >> "$REPORT"

    # Sleep delta
    LINUX_DELTA=$(grep -iE "Sleep.*delta|delta.*ms" "$LINUX_LOG" 2>/dev/null | \
                  grep -oE "[0-9]{3,4}ms" | head -1 || echo "N/A")
    WIN_DELTA=$(grep -iE "Sleep.*delta|delta.*ms" "$WIN_LOG" 2>/dev/null | \
                grep -oE "[0-9]{3,4}ms" | head -1 || echo "N/A")
    echo "| Sleep Delta | $LINUX_DELTA | $WIN_DELTA | $([ "$LINUX_DELTA" != "N/A" ] && echo '⚠ DIVERSO' || echo 'N/A') |" >> "$REPORT"

    # hal.dll size
    LINUX_HAL=$(grep -i "hal.dll.*size\|size.*hal" "$LINUX_LOG" 2>/dev/null | \
                grep -oE "size[=: ]*[0-9]+" | head -1 || echo "N/A")
    WIN_HAL=$(grep -i "hal.dll.*size\|size.*hal" "$WIN_LOG" 2>/dev/null | \
              grep -oE "size[=: ]*[0-9]+" | head -1 || echo "N/A")
    echo "| hal.dll size | $LINUX_HAL | $WIN_HAL | $([ "$LINUX_HAL" != "$WIN_HAL" ] && echo '⚠ DIVERSO' || echo 'OK') |" >> "$REPORT"

    # Driver load
    LINUX_DRV=$(grep -i "bedaisy\|kernel driver" "$LINUX_LOG" 2>/dev/null | \
                grep -iE "FAIL|OK|success|error" | head -1 | grep -oiE "FAIL|OK|success|error" || echo "N/A")
    WIN_DRV=$(grep -i "bedaisy\|kernel driver" "$WIN_LOG" 2>/dev/null | \
              grep -iE "FAIL|OK|success|error" | head -1 | grep -oiE "FAIL|OK|success|error" || echo "N/A")
    echo "| BEDaisy load | $LINUX_DRV | $WIN_DRV | $([ "$LINUX_DRV" != "$WIN_DRV" ] && echo '⚠ DIVERSO' || echo 'OK') |" >> "$REPORT"

    echo "" >> "$REPORT"

    # --------------------------------------------------------
    echo ""
    echo -e "${BOLD}${YELLOW}▶ FASE 3 — Stringa rivelatrice${NC}"
    echo "## La 'Stringa Rivelatrice'" >> "$REPORT"
    echo "" >> "$REPORT"
    echo "Le linee che appaiono nel log Linux ma NON in quello Windows:" >> "$REPORT"
    echo '```' >> "$REPORT"

    # Linee uniche nel log Linux (non presenti nel riferimento Windows)
    # Normalizza prima rimuovendo timestamp e indirizzi memoria variabili
    sed -E 's/\[([0-9]+\.[0-9]+)\]/[TIMESTAMP]/g; s/0x[0-9a-fA-F]+/0xADDR/g' \
        "$LINUX_LOG" > "/tmp/linux_norm_$TIMESTAMP.log" 2>/dev/null
    sed -E 's/\[([0-9]+\.[0-9]+)\]/[TIMESTAMP]/g; s/0x[0-9a-fA-F]+/0xADDR/g' \
        "$WIN_LOG" > "/tmp/win_norm_$TIMESTAMP.log" 2>/dev/null

    # Trova linee uniche Linux (quelle che BE vede e che tradiscono Linux)
    comm -23 \
        <(sort "/tmp/linux_norm_$TIMESTAMP.log") \
        <(sort "/tmp/win_norm_$TIMESTAMP.log") \
        2>/dev/null | grep -iE "fail|error|wine|fixme|linux|denied|mismatch|unsupported" | \
        head -20 >> "$REPORT" || echo "(nessuna differenza trovata automaticamente)" >> "$REPORT"

    echo '```' >> "$REPORT"
    rm -f "/tmp/linux_norm_$TIMESTAMP.log" "/tmp/win_norm_$TIMESTAMP.log"

    # --------------------------------------------------------
    echo ""
    echo -e "${BOLD}${YELLOW}▶ FASE 4 — Vettori BEDaisy attivati${NC}"
    echo "" >> "$REPORT"
    echo "## Vettori BEDaisy Coinvolti" >> "$REPORT"
    echo "" >> "$REPORT"

    declare -A VECTOR_PATTERNS
    VECTOR_PATTERNS["#1 HWID Disco"]="DR0|Harddisk0|HWID_READ_FAIL|0x2D1400"
    VECTOR_PATTERNS["#2 Sleep Delta"]="delta.*[0-9]{4}ms|SLEEP_DELTA_EXCEEDED|0x45"
    VECTOR_PATTERNS["#3 HAL.dll"]="HAL_INTEGRITY|hal.dll.*FAIL|0x46"
    VECTOR_PATTERNS["#4 Beep/Null"]="0x3E|Beep.*device|Null.*device"
    VECTOR_PATTERNS["#5 OS Version"]="OS_STRUCTURE|RtlGetVersion.*FAIL|0x71"
    VECTOR_PATTERNS["#6 Parent Chain"]="PRIVILEGE_NOT_HELD|NtLoadDriver.*fail"
    VECTOR_PATTERNS["#7 Named Pipe"]="namedpipe.*unsupported|npipe.*fixme"
    VECTOR_PATTERNS["#8 Kernel Scan"]="kernel structure|syscall table"
    VECTOR_PATTERNS["#9 Server-side"]="UNTRUSTED|flagged|PLUM"

    for vector in "${!VECTOR_PATTERNS[@]}"; do
        pat="${VECTOR_PATTERNS[$vector]}"
        if grep -iqE "$pat" "$LINUX_LOG" 2>/dev/null; then
            echo -e "${RED}[ATTIVATO]${NC} $vector"
            echo "- **[ATTIVATO]** $vector" >> "$REPORT"
        else
            echo -e "${GREEN}[OK]     ${NC} $vector"
            echo "- [ok] $vector" >> "$REPORT"
        fi
    done

    # --------------------------------------------------------
    echo ""
    echo -e "${BOLD}${GREEN}Report salvato: $REPORT${NC}"
    echo ""
    echo -e "${CYAN}Per creare una scheda tecnica con questi dati:${NC}"
    echo -e "  cp $WINMERDA_DIR/evidence/schede/TEMPLATE.md \\"
    echo -e "     $WINMERDA_DIR/evidence/schede/PLUM_$(date +%Y%m%d).md"
    echo ""
}

# ============================================================
# MAIN
# ============================================================
if [[ "${1:-}" == "--demo" ]]; then
    echo -e "${YELLOW}Modalità DEMO — usando log simulati da dati reali forum${NC}"
    echo ""
    DEMO_DIR=$(create_demo_logs)
    analyze_diff \
        "$DEMO_DIR/linux_proton.log" \
        "$DEMO_DIR/windows_clean.log" \
        "$EVIDENCE_DIR/diff_demo_$TIMESTAMP"

elif [ $# -ge 2 ]; then
    [ -f "$1" ] || { echo "Errore: file non trovato: $1"; exit 1; }
    [ -f "$2" ] || { echo "Errore: file non trovato: $2"; exit 1; }
    analyze_diff "$1" "$2" "${3:-$EVIDENCE_DIR/diff_$TIMESTAMP}"

else
    echo "USO:"
    echo "  bash log_diff_analyzer.sh --demo"
    echo "    Esegue l'analisi con log di esempio simulati"
    echo ""
    echo "  bash log_diff_analyzer.sh <linux_log> <windows_ref_log>"
    echo "    Confronta i tuoi log reali con un riferimento Windows"
    echo ""
    echo "  bash log_diff_analyzer.sh <linux_log> <windows_ref_log> <output_dir>"
    echo "    Specifica cartella di output personalizzata"
fi
