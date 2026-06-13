# open-anticheat-research

> **Passive analysis framework for understanding how kernel-level anti-cheat systems block Linux gaming — and how to fix it.**

---

## The Problem

If you're a Linux user who loves gaming, you know the feeling.

You install a game. You press Play. And then:

```
This game requires anti-cheat software that is not supported on your platform.
```

Not because Linux is insecure. Not because you're a cheater.
Because **someone decided you don't deserve to play**.

Games like Destiny 2, Valorant, Rainbow Six Siege — blocked not by a technical limitation,
but by a **corporate policy** that treats Linux as a second-class citizen.

We're tired of it.

---

## What We Hate (And Why It Matters)

- **We hate** that BattlEye has Linux modules ready to go, and Bungie simply refuses to enable them.
- **We hate** that anti-cheat software has Ring 0 access to your kernel while you get nothing in return.
- **We hate** that thousands of hours of gaming history are locked behind a Windows-only gate.
- **We hate** that every time someone finds a workaround, it gets patched in 24 hours because the community is scattered and uncoordinated.
- **We hate** that "just use Windows" is considered an acceptable answer in 2024.

But hatred without action is just noise.

---

## What We're Building

This project is a **passive analysis framework** — not a cheat, not a bypass, not a hack.

We use legal, standard Linux tools (`strace`, `tcpdump`, `wireshark`) to:

1. **Map** exactly what anti-cheat systems check when they detect Linux
2. **Document** every syscall, network packet, and registry key they scan
3. **Build** a public threat model that the community can use to develop proper compatibility layers
4. **Contribute** findings to projects like Proton, Wine, and SteamLinuxRuntime

We don't want to cheat. We want to **play**.

---

## Current Target: Destiny 2 / BattlEye

Destiny 2 is the "final boss" of Linux gaming compatibility.
BattlEye technically supports Linux — Bungie simply flipped the switch to OFF.

Our analysis so far:

| What BattlEye checks | Our finding |
|----------------------|-------------|
| Network ports | MasterPort: **3074**, BasePort: **3077** |
| Game identifier | GameID: **d2** |
| Target binary | **destiny2.exe** (64-bit) |
| Privacy mode | PrivacyBox: **1** |
| Client DLL | BEClient_x64.dll (~6.1MB) |
| Service binary | BEService_x64.exe (~9.9MB) |

Full threat model: [`bungie_threat_model.md`](./bungie_threat_model.md)

---

## How It Works

### The Analysis Pipeline

```
[Destiny 2 Launch]
       │
       ├──► tcpdump (ports 3074/3077)  ──► battleye_net_TIMESTAMP.pcap
       │
       └──► strace (read-only syscalls) ──► strace_TIMESTAMP.log
                                                    │
                                                    └──► filtered_TIMESTAMP.log
                                                         (wine, proton, linux,
                                                          /home/, /proc/, /sys/)
```

### Run It

```bash
git clone https://github.com/YOUR_USERNAME/open-anticheat-research
cd open-anticheat-research
chmod +x log_destiny.sh
./log_destiny.sh
```

**Requirements**: `strace`, `ltrace`, `wireshark-cli` (tcpdump)

On Arch/Garuda:
```bash
sudo pacman -S strace ltrace wireshark-cli
```

---

## Threat Model

We maintain a living document of every detection vector BattlEye uses and our proposed countermeasures:

| Detection Vector | Status |
|-----------------|--------|
| File Integrity Check (hash) | PENDING analysis |
| Process Audit (debugger detection) | PENDING analysis |
| Hardware Fingerprinting (GPU/CPU serial) | PENDING analysis |
| Kernel Driver (Ring 0) | PENDING analysis |
| CPU Timing (RDTSC anti-VM) | PENDING analysis |
| Registry Scan (Wine strings) | PENDING analysis |
| Network Telemetry (Linux path leak) | PENDING analysis |
| Filesystem Check (/proc, /sys) | PENDING analysis |
| CPU Flags (hypervisor bit) | PENDING analysis |
| Handshake Verification | PENDING analysis |

Full details: [`bungie_threat_model.md`](./bungie_threat_model.md)

---

## Rules of Engagement

This project has strict rules:

- **Zero memory modification** — we never write to game process memory
- **Zero file modification** — we never touch game binaries or DLLs
- **Zero public logs** — raw logs stay local, only sanitized findings get published
- **No cheating** — our goal is compatibility, not advantage
- **Test accounts only** — never risk your main account

---

## The Bigger Picture

This is not just about Destiny 2.

The same methodology applies to:
- **Easy Anti-Cheat** (Fortnite, Apex Legends, Rust)
- **Vanguard** (Valorant)
- **nProtect GameGuard** (many Korean MMOs)

If we build a complete, documented map of how these systems detect Linux,
we give the open-source community the data it needs to build proper compatibility layers —
without asking permission from anyone.

Linux gaming deserves better. **Steam Deck proved there's a market.**
The only thing standing between Linux and AAA gaming is corporate inertia.

Let's document it, publish it, and let the data speak.

---

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md)

Every log, every finding, every identified syscall is valuable.
You don't need to be a kernel developer — you just need to run the script and share what you find.

---

## License

MIT — See [`LICENSE`](./LICENSE)

---

## Acknowledgements

Built on the shoulders of:
- [Wine](https://www.winehq.org/) / [Proton](https://github.com/ValveSoftware/Proton)
- [DXVK](https://github.com/doitsujin/dxvk)
- [ProtonDB](https://www.protondb.com/)
- [GamingOnLinux](https://www.gamingonlinux.com/)
- Every Linux gamer who ever hit that wall and refused to go back to Windows.
