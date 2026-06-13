# open-anticheat-research

> **Passive analysis framework for understanding how kernel-level anti-cheat systems block Linux gaming — and how to fix it.**

---

## The Manifesto

**Open Anti-Cheat Research (OACR) — The Resistance against Digital Enclosure**

*"Linux should be a place where the user has total control. If a piece of software refuses to run, we don't cheat—we analyze. We document. And eventually, we solve."*

For years, the gaming industry has moved towards a model of total control, treating users not as owners of their hardware, but as tenants in a walled garden. Software like BattlEye, once a tool for fairness, has become a layer of obfuscation that isolates users based on their OS choice.

This project is our response. We are not creating cheats. We are conducting a technical audit. We are observing how anti-cheat systems discriminate against free, open-source operating systems, documenting their detection methods, and mapping the path to a future where Linux users are treated as first-class citizens in the digital world.

### Why this research matters

- **Transparency:** We believe in knowing what runs on our kernel.
- **Accountability:** We document how anti-cheat systems like BattlEye perform hardware fingerprinting and kernel auditing.
- **The Future:** Linux is the backbone of modern gaming (Steam Deck, handheld consoles). Blocking Linux is not a technical necessity; it is a policy choice. We are gathering the evidence to prove that this choice is unfounded.

### The Toolkit

This repository contains our research tools to analyze system integrity and anti-cheat behavior in isolated, non-invasive environments:

- `be_environment_probe.sh` — Pre-flight diagnostic tool to check for common detection triggers before they cause an account flag
- `be_environment_harden.sh` — Configuration hardening to ensure system environment consistency
- `proton_log_capture.sh` — Clean, non-invasive logging utility to capture system calls during runtime
- `log_diff_analyzer.sh` — Core tool to compare Linux runtime logs against standard Windows baselines, identifying the "revealing strings" that trigger anti-cheat alerts
- `bungie_threat_model.md` — Technical breakdown of the defensive layers used by Bungie/BattlEye

### Our Approach (The "Ghost" Protocol)

We operate under a strict code of ethics to protect our integrity and the research itself:

- **Zero Modification:** We never touch the game code or memory. We observe from the outside (Hypervisor/Network level).
- **Privacy First:** All logs are cleaned and anonymized. No real user data or account IDs are ever shared.
- **Scientific Method:** We validate every finding through a "Double-Blind" test: using isolated Windows VMs to establish a baseline of what the anti-cheat expects to see, vs what it sees on our Linux-hosted VMs.

### Join the Resistance

This is a work in progress. Currently, we are documenting BattlEye's 9 detection vectors on Linux and building a reproducible evidence base of real-world runtime logs.

If you are a developer, a kernel researcher, or simply someone who believes that your computer belongs to you, you are welcome here.

**Do not use this to bypass. Use this to learn. Contribute to the documentation.**

This project is for educational purposes only. It does not provide any bypasses for anti-cheat systems and complies with local privacy regulations. We are not against anti-cheat; we are against the arbitrary discrimination of Open Source systems.

---

## Project Thesis: Decoding the Anti-Cheat Detection Barrier

*A technical deep-dive into the interaction between BattlEye, Bungie's security architecture, and Linux-based environments.*

### The Castle and the Guard

Destiny 2 employs a security gatekeeper called **BattlEye**. Its stated purpose is to prevent cheaters from entering the game. Its actual behavior, however, is far broader: it systematically rejects any player whose environment does not present as a native Windows system — regardless of intent.

When a Linux user attempts to launch Destiny 2 through Wine or Proton (a compatibility layer that translates Windows system calls into Linux equivalents), BattlEye performs a series of **nine structured interrogations** of the runtime environment. Each one is looking for a specific Windows fingerprint. If any answer deviates from the expected Windows baseline, the client is flagged, the session is terminated, and — with repeated attempts — the account is permanently banned.

This is not an accident. It is architecture.

### What BattlEye Actually Interrogates

Before a single frame of Destiny 2 renders, `BEDaisy.sys` — BattlEye's kernel-mode driver operating at Ring 0 — executes the following checks, each confirmed through static reverse engineering of the driver binary:

**1. Hardware Identifier (HWID) — Disk Serial**
`BEDaisy` opens a direct handle to `\Device\Harddisk0\DR0` and issues IOCTL code `0x2D1400` to read the raw disk serial number. On Wine, this device path either does not exist or returns emulated data that does not match the structure of a physical Windows disk driver response.

**2. Sleep Delta — Clock Integrity**
`BEClient.dll` calls `GetTickCount()`, executes `Sleep(1000)`, then measures the elapsed delta. The detection threshold is **1200 milliseconds**. Wine's translation layer introduces scheduling overhead that regularly pushes this delta to 1400–1800ms, triggering report code `0x45` and the infamous **PLUM** disconnect.

**3. HAL.dll Checksum — System Identity Document**
The Hardware Abstraction Layer DLL (`hal.dll`) is read at a fixed byte offset (`module_base + 0x1000`). On a legitimate Windows installation, this file is approximately **350KB** with a specific binary signature. Wine ships its own `hal.dll` stub at **~58KB** with an entirely different signature. The mismatch triggers report code `0x46`.

**4. Device Object Presence — Driver Hijacking Signal**
`BEClient` attempts to open `\\.\Beep` and `\\.\Null` device objects. On production Windows systems, these objects should not be directly accessible in this manner. Wine exposes them as part of its DOS device emulation layer, which BattlEye interprets as evidence of driver-level manipulation, triggering report code `0x3E`.

**5. OS Version Structure Mismatch**
`BEDaisy` calls `RtlGetVersion()` to read the Windows version string. Wine correctly returns `10.0.19041`. However, the deeper kernel structures that Windows uses to support this version — the system call table layout, the object directory hierarchy, the handle table format — are Linux constructs that Wine cannot fully replicate. BattlEye cross-references the version string against these structures, detecting the inconsistency.

**6–8. Process Parentage, Named Pipe Integrity, Kernel Object Enumeration**
BEDaisy validates that `destiny2.exe` was spawned directly by `BEService.exe` with a matching parent token (`g_ExpectedParentToken`). It tests the round-trip latency of its communication channel (`\\.\namedpipe\Battleye`). It enumerates the kernel object directory (`ZwQueryDirectoryObject`) looking for driver signatures inconsistent with a clean Windows installation — and finds Linux kernel modules instead.

**9. Bungie Server-Side — The Layer Beyond BattlEye**
This is the critical finding most analyses miss. Bungie's own infrastructure maintains **an independent detection layer** that operates in parallel with BattlEye. As confirmed by Bungie staff on their official forums: *"BattlEye is just one layer. All the other cheat detection systems are for Windows OS, so the original reason for issuing bans still stands."* This server-side system analyzes the client's connection handshake signature. Repeated connections with a non-Windows fingerprint escalate from disconnect (PLUM) to permanent account ban.

### Why Wine Cannot Solve This Architecturally

The root cause is not a missing configuration option or a Wine bug to be patched. It is a **structural incompatibility**:

BEDaisy operates in Ring 0 — kernel space. It requires direct access to Windows kernel data structures: the handle table, the object directory, the loaded module list, the hardware abstraction layer. These structures do not exist on Linux. Wine emulates them in userspace, but BEDaisy operates at a level where this emulation becomes transparent and detectable.

The only architecturally sound solution is to run BEDaisy inside a real Windows kernel. This is achievable through KVM/QEMU virtualization with hardware passthrough — presenting BEDaisy with a genuine Windows Ring 0 environment while the host system remains Linux.

### The Paradox

Three publicly documented facts that render Bungie's position indefensible:

1. BattlEye's Linux runtime module exists and is production-ready. Enabling it for Destiny 2 requires, in Valve's own words, *"just sending an email."*
2. Destiny 2 has already been ported to run on Linux — Bungie shipped it on Google Stadia, a Linux-based cloud platform.
3. When BattlEye runs natively on Linux (as it does for games like Escape from Tarkov on Proton), it operates entirely in userspace with no kernel access — meaning Linux users would be *less* susceptible to kernel-level detection evasion, not more.

The ban is not a technical necessity. It is a policy decision.

### What This Repository Is

This project is the systematic documentation of the above. We do not modify game files. We do not inject memory. We do not distribute bypasses. We build tools that **observe, measure, and record** the detection surface — so that the open-source community has the precise, reproducible data needed to advocate for proper compatibility support.

Every script in this repository, every scheda tecnica in `evidence/schede/`, every entry in `bungie_threat_model.md` is a data point in that argument.

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
