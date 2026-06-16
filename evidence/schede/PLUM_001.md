# Scheda Tecnica — PLUM 001

> Stato: [x] APERTA  [ ] VERIFICATA  [ ] RISOLTA

---

## Metadati

| Campo | Valore |
|-------|--------|
| **Data** | 2026-06-13 |
| **Codice errore** | PLUM |
| **Fase di detection** | CONNESSIONE (5-30 sec dall'avvio) |
| **Sistema** | Garuda Linux 7.0.11-zen1 + Proton 9.0 |
| **Account usato** | MULETTO (da creare prima del test) |
| **Riproducibile** | Sì — ogni avvio su Wine/Proton puro |

---

## Trigger

```
- Proton version usata:    Proton 9.0-3 (default Steam)
- Flags di avvio Steam:    PROTON_LOG=1 %command%
- Tool in background:      NESSUNO (modalità passiva)
- Moduli kernel caricati:  vboxdrv (da rimuovere prima del test)
- Config Wine speciali:    nessuna oltre default Proton
```

---

## Sintomo Osservato

```
Errore visualizzato: Schermata rossa Destiny 2

Messaggio esatto:   "Error Code: PLUM"
                    "BattlEye service has encountered an issue"

Dopo quanto:        ~15-30 secondi dall'avvio del gioco
                    Dopo la schermata di caricamento iniziale
                    PRIMA del login al server Bungie
```

---

## Log Estratto (sanitizzato)

> Questo è il log ATTESO basato su report ProtonDB e forum Bungie.
> Da sostituire con log REALE al primo test con account muletto.

```
[Proton] [0x7f...] BEService: starting
[Proton] [0x7f...] BEService: connecting to named pipe \\.\namedpipe\Battleye
[Proton] [0x7f...] BEService: failed to load bedaisy.sys: Access denied
[Proton] [0x7f...] BEService: kernel module not available
[Proton] [0x7f...] BEClient: heartbeat timeout (>1200ms)
[Proton] [0x7f...] BEClient: environment check failed
[Proton] [0x7f...] Game: received disconnect from server
[Proton] [0x7f...] Game: error code PLUM
```

---

## Log Windows di Riferimento

> Frammento tipico su sistema Windows funzionante.
> Fonte: forum.bungie.net help thread + reddit r/DestinyTechSupport

```
[BEService] Starting BattlEye Service...
[BEService] Loading bedaisy.sys... OK
[BEService] Kernel module initialized at 0xfffff...
[BEService] Named pipe created: \\.\namedpipe\Battleye
[BEClient] Heartbeat OK (delta: 1003ms)
[BEClient] Environment check: PASS
[BEClient] Sending client token to BEServer...
[BEServer] Client authenticated
[Game] Connected to Bungie servers
```

---

## Analisi Diff (Linux vs Windows)

| Linea nel log Linux | Linea equivalente Windows | Differenza critica |
|--------------------|--------------------------|-------------------|
| `failed to load bedaisy.sys: Access denied` | `Loading bedaisy.sys... OK` | bedaisy.sys non ottiene Ring 0 su Wine |
| `heartbeat timeout (>1200ms)` | `Heartbeat OK (delta: 1003ms)` | Wine introduce latenza >200ms extra |
| `kernel module not available` | `Kernel module initialized` | Strutture kernel Windows assenti su Linux |
| `error code PLUM` | `Connected to Bungie servers` | Conseguenza degli errori precedenti |

**La "stringa rivelatrice"**: `failed to load bedaisy.sys: Access denied`
BEDaisy non ottiene accesso Ring 0 reale → tutto il resto fallisce a cascata.

---

## Vettore BEDaisy Coinvolto

- [ ] #1 HWID Disco
- [x] #2 Sleep Delta (`GetTickCount + Sleep(1000)` > 1200ms) — **PRIMARIO**
- [ ] #3 HAL.dll checksum
- [ ] #4 Device Beep/Null
- [x] #5 OS Version (`RtlGetVersion` mismatch) — **SECONDARIO**
- [x] #6 Process parent chain — **SECONDARIO**
- [x] #7 Named pipe latenza — **SECONDARIO**
- [ ] #8 Kernel object scan
- [ ] #9 Bungie server-side

---

## Contromisura Proposta

```
Contromisura: Eliminare la causa radice — bedaisy.sys deve girare in Ring 0 reale

Implementazione:
  - Tipo: [x] KVM config
  - Difficoltà: [x] Alta

  PERCORSO A — KVM con Windows guest (risolve #2, #5, #6, #7 automaticamente)
    1. Configurare VM con kvm_antidect_config.xml
    2. Installare Windows 10 legittimo come guest
    3. Avviare Destiny 2 nella VM — bedaisy.sys gira nel kernel Windows reale

  PERCORSO B — Proton puro (mitigazione parziale, non risolve bedaisy.sys)
    1. Rimuovere vboxdrv prima del test
    2. Usare Proton-GE (fork con patch aggiuntive)
    3. Impostare WINEDLLOVERRIDES="hal=n"
    4. Monitorare Sleep delta < 1100ms prima di avviare

Stato test:
  - [x] Non testata (in attesa completamento download D2 + account muletto)
```

---

## Note Aggiuntive

```
- Link ProtonDB: https://www.protondb.com/app/1085660 (rating: Borked)
- Thread Bungie: forum.bungie.net — "Linux ban" (2021-2024)
- Fonte BEDaisy RE: https://s4dbrd.github.io/posts/reversing-bedaisy/
- Il problema principale non è PLUM in sé, è che PLUM ripetuto → ban permanente
- Non tentare più di 2 volte con la stessa firma hardware
```
