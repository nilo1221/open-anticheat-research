# Bungie/BattlEye Threat Model
# Mappa delle azioni del "Colosso" e delle nostre contromisure

| Azione di Bungie (Il Colosso) | Cosa fa tecnicamente | La nostra Contromisura (Il Muro) | Stato |
|------------------------------|---------------------|----------------------------------|-------|
| **Integrity Check** | Calcola l'hash dei file nella cartella /game. Confronta con hash originali server-side. | Non modificare i file. Usiamo bind mounts (link simbolici) se serve cambiare configurazione. | PENDING |
| **System Audit** | Scansiona i processi in esecuzione alla ricerca di gdb, strace, debugger, monitor di sistema. | Non eseguire mai tool di analisi nel sistema in cui gira il gioco. Usiamo una VM isolata o monitor di rete esterno. | PENDING |
| **Hardware Fingerprinting** | Legge Serial Number di GPU, CPU, Disco, UUID, versione BIOS. | Usiamo QEMU/KVM con libvirt per fare lo spoofing di tutti i parametri hardware. | PENDING |
| **Kernel Anti-Cheat** | Inietta un driver (BattlEye) nel Ring 0 per controllo totale del sistema. | Analizziamo il traffico del driver usando un proxy di rete esterno (non sul PC del gioco). | PENDING |
| **Timing/Latency Check** | Misura il ritardo di risposta della CPU (RDTSC) per rilevare VM/hypervisor. | Configuriamo il clock della VM per sincronizzarlo perfettamente con l'host (Hyper-V enlightenments). | PENDING |
| **Registry Scan** | Scansiona il registro di Windows per stringhe "Wine", "Proton", percorsi Linux. | Zero modifiche al registro Wine. Mascheramento completo del sotto-albero di registro se necessario. | PENDING |
| **Network Telemetry** | Invia dati di telemetria al server Bungie (WINEPREFIX, percorso /home/, etc.). | Firewall ufw per bloccare telemetria sospetta. Analisi passiva del traffico per identificare leak. | PENDING |
| **File System Check** | Cerca file Linux (/proc, /sys, librerie .so invece di .dll). | Astrazione completa del filesystem. Nessun file Linux visibile al gioco. | PENDING |
| **CPU Flags Detection** | Legge i flag della CPU per rilevare hypervisor bit. | Rimozione completa dei flag di virtualizzazione nella configurazione QEMU/KVM. | PENDING |
| **Handshake Verification** | Il client comunica al server "Sono Windows" durante l'handshake iniziale. | Analisi del traffico di rete per identificare il pacchetto di handshake. Proxy per riscrittura se necessario. | PENDING |

## Dati Concreti Raccolti (Prima Analisi)

### File BEClient_x64.cfg
```
GameID d2
MasterPort 3074
```

### File BELauncher.ini
```
[Launcher]
GameID=d2
BasePort=3077
64BitExe=destiny2.exe
SilentInstall=-1
PrivacyBox=1
```

### Informazioni Chiave
- **Porta comunicazione BE ↔ server**: 3074 (master), 3077 (base)
- **GameID**: `d2` (usato dal server BattlEye per identificare il client)
- **PrivacyBox=1**: Modalità privacy attiva
- **Percorso BattlEye**: `/run/media/lollo/F9FF-FB10/SteamLibrary/steamapps/downloading/1085660/battleye/`
- **Binari chiave**: `BEClient_x64.dll` (6.1MB), `BEService_x64.exe` (9.9MB)

### Porte da monitorare con tcpdump
```bash
# Monitoraggio traffico BattlEye
sudo tcpdump -i any port 3074 or port 3077 -w ~/winmerda/logs/battleye_traffic.pcap
```

## Legenda Stati
- **PENDING**: Da testare/verificare
- **ACTIVE**: Contromisura implementata
- **VERIFIED**: Contromisura verificata funzionante
- **FAILED**: Contromisura non funzionante (ban rilevato)
- **RISKY**: Contromisura parzialmente funzionante con rischi

## Note Importanti
- Ogni test deve essere eseguito con account muletto
- Prima di ogni test: snapshot snapper del sistema
- Analisi sempre post-mortem (mai durante esecuzione gioco)
- Log rimangono locali in ~/winmerda (mai pubblici)
