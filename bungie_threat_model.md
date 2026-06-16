# Bungie/BattlEye Threat Model
## Analisi completa basata su reverse engineering di BEDaisy.sys, BEClient.dll e dati ProtonDB
### Fonti: secret.club, s4dbrd.github.io, Aki2k/BEDaisy, The Verge, UnknownCheats, ProtonDB

---

## Architettura del Sistema di Difesa

```
BEService_x64.exe  (Servizio Windows — userspace)
    │
    ├── pipe: \\.\namedpipe\Battleye  (comunicazione criptata XOR)
    │
    └── BEClient_x64.dll  (iniettato nel processo destiny2.exe)
              │
              └── Shellcode scaricato da BEServer (runtime)
                      │
                      └── Esegue detection loop continuo durante gameplay

BEDaisy.sys  (Driver kernel — Ring 0)
    │
    ├── PsSetCreateProcessNotifyRoutineEx  → callback ogni nuovo processo
    ├── PsSetLoadImageNotifyRoutine        → callback ogni DLL caricata
    ├── ObRegisterCallbacks               → blocca accesso memoria game
    ├── ZwOpenFile(\Device\Harddisk0\DR0) → legge serial disco fisico
    └── ZwDeviceIoControlFile             → IOCTL per HWID hardware
```

---

## Configurazione BattlEye Destiny 2 (dati locali reali)

```ini
# BEClient_x64.cfg
GameID d2
MasterPort 3074

# BELauncher.ini
[Launcher]
GameID=d2
BasePort=3077
64BitExe=destiny2.exe
SilentInstall=-1
PrivacyBox=1
```

**Binari**: `BEClient_x64.dll` (6.1MB), `BEService_x64.exe` (9.9MB)
**Porte da monitorare**: 3074 (master), 3077 (base)

---

## Mappa Completa Detection — 9 Vettori Documentati

| # | Vettore | API usata (da RE) | Comportamento su Wine/Linux | Soluzione | Stato |
|---|---------|-------------------|----------------------------|-----------|-------|
| 1 | **HWID Disco** | `ZwOpenFile(\Device\Harddisk0\DR0)` + `ZwDeviceIoControlFile(0x2D1400)` | Device non esiste o restituisce dati emulati | KVM con disco virtuale + serial custom realistico | PENDING |
| 2 | **Sleep Delta** | `GetTickCount()` + `Sleep(1000)` — soglia 1200ms | Wine introduce latenza — tick_delta supera 1200ms → report `0x45` → **PLUM** | KVM Hyper-V enlightenments + TSC nativo | PENDING |
| 3 | **HAL.dll checksum** | `GetModuleHandleA("hal.dll")` — legge bytes a offset `+0x1000` | Wine hal.dll ha bytes diversi dall'originale Windows → report `0x46` | hal.dll nativa da Windows legittimo | PENDING |
| 4 | **Device Beep/Null** | `CreateFileA("\\\\.\\Beep")` + `CreateFileA("\\\\.\\Null")` | Wine espone questi device — su Windows reale non esistono — segnala driver hijacking → report `0x3E` | Patch Wine per non esporre questi device | PENDING |
| 5 | **OS Version anomalia** | `RtlGetVersion` (kernel) | Versione OS riportata non corrisponde alle strutture kernel Linux sottostanti | KVM con Windows reale — unica soluzione affidabile | PENDING |
| 6 | **Process parent chain** | `PsGetProcessInheritedFromUniqueProcessId` + `g_ExpectedParentToken` | BEDaisy verifica che destiny2.exe sia figlio diretto di BEService.exe | Avviare sempre tramite `destiny2launcher.exe`, mai direttamente | PENDING |
| 7 | **Named pipe** | `\\.\namedpipe\Battleye` — comunicazione criptata XOR | Wine emula named pipe ma con latenze anomale — shellcode non arriva correttamente | Proton-GE aggiornato, verificare emulazione pipe | PENDING |
| 8 | **Kernel object scan** | `ZwOpenDirectoryObject` + `ZwQueryDirectoryObject` | Oggetti kernel Linux non corrispondono alla struttura Windows — driver "sconosciuti" rilevati | VM KVM isolata — kernel guest Windows non vede host Linux | PENDING |
| 9 | **Bungie server-side** | Sistema proprietario Bungie (non BE) — analisi pattern connessione | Firma handshake non-Windows rilevata — escalation da kick a ban dopo tentativi ripetuti | Nessuna soluzione tecnica — richiede supporto ufficiale Bungie | BLOCCATO |

---

## La Sequenza Esatta del Ban (ricostruita da fonti multiple)

```
FASE 1 — AVVIO (0-5 secondi)
    destiny2launcher.exe → BEService_x64.exe
    BEDaisy.sys si carica nel kernel Windows
    │
    ├── [DETECTION 1] ZwOpenFile(\Device\Harddisk0\DR0) → FAIL su Wine
    ├── [DETECTION 5] RtlGetVersion → mismatch strutture kernel
    └── BEDaisy registra callbacks kernel (PsSetCreateProcessNotifyRoutineEx)

FASE 2 — INIEZIONE (5-30 secondi)
    BEClient_x64.dll iniettato in destiny2.exe
    Shellcode scaricato da BEServer via \\.\namedpipe\Battleye
    │
    ├── [DETECTION 2] Sleep(1000) → tick_delta > 1200ms → report 0x45
    ├── [DETECTION 3] hal.dll checksum → bytes anomali → report 0x46
    └── [DETECTION 4] \\.\Beep + \\.\Null presenti → report 0x3E

FASE 3 — DECISIONE (30-60 secondi)
    BEServer riceve tutti i report
    Bungie server-side riceve handshake con firma anomala
    │
    ├── Primo tentativo → KICK: ERROR CODE PLUM (no ban)
    ├── Tentativi 2-3   → Warning interno Bungie
    └── Tentativi 4+    → GAME BAN permanente + possibile HWID BAN
```

---

## Perché Wine NON Funziona (Architetturalmente)

```
Windows reale:
    BEDaisy.sys [Ring 0 vero] → accesso diretto al kernel → strutture reali

Wine su Linux:
    BEDaisy.sys [Ring 0 EMULATO] → syscall passano per Wine
    Wine non può mentire al kernel Linux
    Il kernel Linux non ha strutture Windows native
    BEDaisy riceve risposte "strane" → detection immediata
```

**Conclusione tecnica**: Su Wine puro i detection #1, #2, #3, #5, #8 falliscono **sempre**.
Su KVM/QEMU con Windows reale: possibile con configurazione corretta.

---

## Il Paradosso Bungie (Documentato da The Verge, 2022)

- BattlEye ha il modulo Linux nativo — Valve ha dichiarato che basta "un'email" per abilitarlo
- Destiny 2 già gira su Linux — Bungie lo ha portato su Google Stadia (Linux-based)
- Bungie ha risposto con: *"Players who attempt to bypass Destiny 2 incompatibility will be met with a game ban"*
- Staff Bungie forum: *"BattlEye is just ONE LAYER. All the OTHER detection systems are for Windows OS"*

---

## Configurazione KVM Consigliata (per test futuri)

```xml
<!-- libvirt XML — anti-detection configuration -->
<cpu mode="host-passthrough">
  <feature policy="require" name="tsc-deadline"/>
  <feature policy="require" name="invtsc"/>
  <feature policy="disable" name="hypervisor"/>
</cpu>

<clock offset="localtime">
  <timer name="hypervclock" present="yes"/>
  <timer name="tsc" present="yes" mode="native"/>
</clock>

<disk type="block" device="disk">
  <serial>WD-WX31A75XXXXX</serial>
</disk>
```

---

## Priorità di Lavoro

| Priorità | Azione | Note |
|----------|--------|------|
| 🔴 CRITICA | Verificare stato BEService (`wine sc query BEService`) | Se non RUNNING, crash silenzioso |
| 🔴 CRITICA | Misurare Sleep delta reale in Wine | `wine cmd` → script timing test |
| 🟠 ALTA | Controllare device Beep/Null nel WINEPREFIX | `ls ~/.../pfx/dosdevices/` |
| 🟠 ALTA | Configurare KVM con Hyper-V enlightenments | Clock sync fondamentale |
| 🟡 MEDIA | Serial disk custom in libvirt | Evitare blacklist QEMU default |
| 🟡 MEDIA | hal.dll nativa nel WINEPREFIX | Da Windows legittimo |

---

## Legenda Stati

- **PENDING**: Da testare/verificare con log reali
- **ACTIVE**: Contromisura implementata
- **VERIFIED**: Verificata funzionante con log
- **FAILED**: Non funzionante (rilevazione confermata)
- **BLOCCATO**: Impossibile senza supporto Bungie

---

## Regole Operative

- Test sempre con account muletto
- Analisi solo post-mortem (mai durante esecuzione gioco)
- Mai più di 2-3 tentativi con stessa firma hardware
- Log rimangono locali in `~/winmerda/logs` (mai pubblici)
- Porte da monitorare con tcpdump: 3074, 3077
