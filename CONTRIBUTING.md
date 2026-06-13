# Contributing to open-anticheat-research

First: **thank you**. Every data point you contribute makes the picture clearer for everyone.

## How to Contribute

### 1. Run the Analysis Script

```bash
chmod +x log_destiny.sh
./log_destiny.sh
```

This generates three files in `logs/`:

- `strace_TIMESTAMP.log` — raw syscall trace
- `battleye_net_TIMESTAMP.pcap` — network capture
- `filtered_TIMESTAMP.log` — pre-filtered for relevant patterns

### 2. Sanitize Your Log

**Before sharing anything**, remove personal identifiers:

```bash
# Remove your username from the log
sed -i 's|/home/YOUR_USERNAME|/home/USER|g' logs/filtered_TIMESTAMP.log

# Remove Steam account ID if present
sed -i 's/[0-9]\{17\}/STEAMID_REDACTED/g' logs/filtered_TIMESTAMP.log
```

### 3. Open an Issue

Open a GitHub Issue with:

- Your **distro and kernel version** (`uname -r`)
- Your **Proton version** (from Steam settings)
- The **error code** you received
- The **filtered log** (sanitized)
- What happened: crash at launch, network refusal, silent exit?

### 4. What We Need Most

- Logs from **different hardware** (AMD vs Intel CPU, different GPUs)
- Logs from **different distros** (Arch, Ubuntu, Fedora, NixOS)
- Logs from **different Proton versions**
- Network captures of the **BattlEye handshake** (ports 3074/3077)

## What We Do NOT Accept

- Cheat code or memory injection tools
- Modified game binaries
- Anything that gives in-game advantage
- Logs containing real Steam account IDs or personal paths

## Code of Conduct

Be technical. Be precise. Be respectful.

We are engineers documenting a system, not soldiers attacking a company.
