# Evidence Repository — open-anticheat-research

Archivio strutturato di "frammenti di ban": log reali, confronti
Linux vs Windows e schede tecniche di ogni vettore di rilevamento.

## Struttura

```
evidence/
├── schede/          # Schede tecniche per ogni errore/detection
│   ├── TEMPLATE.md
│   └── PLUM_001.md  # Esempio
├── raw_logs/        # Log grezzi anonimizzati (MAI log con dati personali)
│   ├── .gitkeep
│   └── *.sanitized.log
└── windows_reference/ # Frammenti di log Windows "puliti" da forum pubblici
    ├── .gitkeep
    └── *.reference.log
```

## Come contribuire una scheda

1. Copia `schede/TEMPLATE.md` → `schede/CODICE_NNN.md`
2. Compila TUTTI i campi
3. Sanitizza il log (vedi sotto)
4. Apri una Pull Request

## Sanitizzazione obbligatoria prima di caricare un log

```bash
# Rimuovi username, path personali, IP, MAC address
sed -i \
  -e 's|/home/[^/]*/|/home/USER/|g' \
  -e 's|C:\\Users\\[^\\]*\\|C:\\Users\\USER\\|g' \
  -e "s|$(whoami)|USER|g" \
  -e 's/[0-9a-f]\{2\}:[0-9a-f]\{2\}:[0-9a-f]\{2\}:[0-9a-f]\{2\}:[0-9a-f]\{2\}:[0-9a-f]\{2\}/XX:XX:XX:XX:XX:XX/g' \
  -e 's/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/X.X.X.X/g' \
  tuo_log.log
```

## Cosa NON caricare

- Log con username reali
- Log con IP address reali
- Serial number hardware reali
- Qualsiasi dato che identifichi l'account Bungie
