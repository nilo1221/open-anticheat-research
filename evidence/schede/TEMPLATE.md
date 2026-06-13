# Scheda Tecnica — [CODICE ERRORE] [NNN]

> Formato: `CODICE_NNN.md` — es. `PLUM_001.md`, `BE_HEARTBEAT_001.md`
> Stato: [ ] APERTA  [ ] VERIFICATA  [ ] RISOLTA

---

## Metadati

| Campo | Valore |
|-------|--------|
| **Data** | YYYY-MM-DD |
| **Codice errore** | es. PLUM / BE_HEARTBEAT_LOST / CORRUPTED_DATA |
| **Fase di detection** | es. AVVIO / CONNESSIONE / GAMEPLAY |
| **Sistema** | es. Garuda Linux + Wine 9.x / Proton 9.0-3 |
| **Account usato** | MULETTO (mai account principale) |
| **Riproducibile** | Sì / No / Intermittente |

---

## Trigger

> Cosa stavamo facendo quando è avvenuta la detection?

```
- Proton version usata:
- Flags di avvio Steam:
- Tool in esecuzione in background:
- Moduli kernel caricati:
- Configurazioni Wine speciali:
```

---

## Sintomo Osservato

> Cosa ha mostrato il gioco/sistema?

```
Errore visualizzato:

Messaggio esatto:

Dopo quanto dall'avvio (secondi):
```

---

## Log Estratto (sanitizzato)

> Ultime 50 righe del log Proton (PROTON_LOG=1) o dmesg al momento del crash.
> SANITIZZA prima di incollare — vedi evidence/README.md

```
[INCOLLA QUI IL LOG SANITIZZATO]
```

---

## Log Windows di Riferimento

> Frammento di log "pulito" trovato su forum Bungie/Reddit/ProtonDB
> per lo stesso errore su un sistema Windows funzionante.
> Fonte: [URL fonte pubblica]

```
[INCOLLA QUI IL LOG WINDOWS DI RIFERIMENTO]
```

---

## Analisi Diff (Linux vs Windows)

> Cosa è DIVERSO tra il tuo log Linux e il log Windows di riferimento?
> Questa è la "firma" che ci fa bannare.

| Linea nel log Linux | Linea equivalente Windows | Differenza |
|--------------------|--------------------------|------------|
| `...` | `...` | Descrizione |

---

## Vettore BEDaisy Coinvolto

> Quale dei 9 vettori documentati nel `bungie_threat_model.md` è stato attivato?

- [ ] #1 HWID Disco (`ZwOpenFile\Device\Harddisk0\DR0`)
- [ ] #2 Sleep Delta (`GetTickCount + Sleep(1000)` > 1200ms)
- [ ] #3 HAL.dll checksum (`module+0x1000` diverso)
- [ ] #4 Device Beep/Null (report `0x3E`)
- [ ] #5 OS Version (`RtlGetVersion` mismatch)
- [ ] #6 Process parent chain (`g_ExpectedParentToken`)
- [ ] #7 Named pipe (`\\.\namedpipe\Battleye` latenza)
- [ ] #8 Kernel object scan (`ZwQueryDirectoryObject`)
- [ ] #9 Bungie server-side (detection proprietaria)

---

## Contromisura Proposta

> Cosa potrebbe prevenire questa detection?

```
Contromisura breve: ...

Implementazione:
  - Tipo: [ ] Wine patch  [ ] KVM config  [ ] Env var  [ ] Kernel mod
  - Difficoltà: [ ] Bassa  [ ] Media  [ ] Alta  [ ] Impossibile su Wine

Stato test:
  - [ ] Non testata
  - [ ] Testata — funziona
  - [ ] Testata — non funziona
  - [ ] Testata — parzialmente
```

---

## Note Aggiuntive

```
[Note libere, link a thread correlati, ecc.]
```
