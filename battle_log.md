# Battle Log - Registro Errori BattlEye
# Log catturati durante l'analisi di Destiny 2 su Linux

## Format
- **Data**: YYYY-MM-DD HH:MM:SS
- **Test**: Descrizione del test eseguito
- **Risultato**: Crash/Error/Success
- **Log File**: Percorso del log catturato
- **Analisi**: Correlazione con threat model

## Sessioni di Test

### Sessione 1 - [DATA DA COMPILARE]
- **Test**: Avvio iniziale Destiny 2 su Linux (Proton/Wine)
- **Risultato**: PENDING
- **Log File**: PENDING
- **Analisi**: PENDING

---

## Note Importanti
- Tutti i log rimangono in ~/winmerda/logs
- Mai caricare log pubblicamente (GitHub, forum, etc.)
- Ogni log deve essere analizzato contro bungie_threat_model.md
- Prima di ogni test: snapshot snapper del sistema

## Pattern da Cercare
- Stringhe "Wine", "Proton", "Linux" nei log
- Errori di connessione server Bungie
- Messaggi "Unauthorized", "Not supported", "Anti-cheat failed"
- Percorsi /home/ nei pacchetti di rete
- Hash mismatch nei file di gioco
