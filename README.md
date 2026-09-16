<p align="center">
  <strong>The Complete Guide to GPU Passthrough for KVM/QEMU on Linux</strong><br>
  <em>Run Windows with near-native GPU performance on a Linux host</em>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/platform-Linux-blue.svg" alt="Platform: Linux">
  <img src="https://img.shields.io/badge/VM-Windows_10%2F11-0078d4.svg" alt="Guest: Windows 10/11">
  <img src="https://img.shields.io/badge/GPU-NVIDIA%20%7C%20AMD-76b900.svg" alt="GPU: NVIDIA | AMD">
  <img src="https://img.shields.io/badge/kernel-6.12+-orange.svg" alt="Kernel: 6.12+">
  <img src="https://img.shields.io/badge/contributions-welcome-brightgreen.svg" alt="Contributions Welcome">
  <img src="https://img.shields.io/badge/version-4.0.0-blue.svg" alt="Version 4.0.0">
</p>

<details>
<summary><strong>Changelog</strong></summary>

**v4.0.0 (September 2026):**

**Major additions — the "2026 hardware" release:**

**NVIDIA Blackwell (RTX 50-series) support:**
- Full RTX 5090 / RTX 5080 passthrough guide with confirmed vendor:device IDs
- Critical requirement: **open kernel modules are mandatory** for Blackwell and Ada Lovelace on driver branches R580+ and R595+ — closed-source modules will fail with `RmInitAdapter` errors
- Documented the **WPR2 reset bug** on Blackwell (GSP firmware state persists through PCIe FLR) — short-term fix is host reboot, long-term fix is `vendor-reset` module
- Added RTX 5080 1:1 IOMMU mapping requirement (GB203 firmware issue, documented in Proxmox bug #7796)
- New `docs/BLACKWELL.md` guide covering GSP firmware, open modules, and workarounds

**AMD RDNA 4 (RX 9070 series) support:**
- Full RX 9070 / RX 9070 XT passthrough guide with confirmed vendor:device IDs
- **Late binding is mandatory** — amdgpu must initialize the GPU first, then dynamically unbind to vfio-pci
- `vendor-reset` kernel module required for clean GPU reset after VM shutdown
- `<rom bar='off'/>` required on both VGA and audio hostdev in VM XML (RDNA 4 firmware quirk)
- VM kernel must be 6.8+ inside the guest for correct display resolution (800x600 bug on older kernels)
- New `docs/RDNA4.md` guide

**Linux kernel updates:**
- Kernel **7.2** (June 2026) adds VFIO Live Update support — preserve VFIO device FDs across kexec
- Kernel **7.2** adds first preparations for NVIDIA "Blackwell-Next" (CXL/DVSEC changes)
- Kernel **6.12** added PREEMPT_RT mainline, sched_ext, and VirtIO Vsock performance improvements
- Kernel **6.12** fixed random reboots on AMD Ryzen 7000/8000 during virtualization
- Recommended minimum bumped to **kernel 6.12** (was 5.15)

**QEMU updates:**
- QEMU **11.1** released with numerous improvements for virtualization
- DX11 driver created for QEMU VMs (AI-assisted, for better guest display)

**NVIDIA driver updates:**
- Driver branch **R595** (v20.0–20.2) — latest vGPU manager for Linux with KVM
- Driver branch **R580** (v5.0–v9.0) — data center GPU driver with Blackwell support
- Both branches require open kernel modules for Ada Lovelace and Blackwell architectures
- RTX PRO 6000 Blackwell Server Edition liquid cooled and RTX PRO 4500 Blackwell now supported
- SR-IOV support confirmed for Blackwell architecture GPUs

**NVIDIA Nova driver:**
- NVIDIA posted vGPU Manager and VFIO variant driver for the open-source Nova kernel driver (September 2026)
- Nova is the upstream, open-source NVIDIA GPU driver for GSP-based GPUs
- Not yet recommended for production VFIO use — but shows NVIDIA's direction

**Looking Glass B6/B7 updates:**
- B7 released with new D12 capture interface using GPU hardware copy engine — zero CPU involvement in frame transfer
- KVMFR kernel module now the **only recommended** shared-memory setup (DMA, required for usable iGPU-host performance)
- `ivshmem-plain` is legacy/deprecated except for edge cases
- Combined KVMFR + D12 capture = best possible latency for local display
- Updated `docs/REMOTE_ACCESS.md` and `examples/xml/looking-glass.xml`

**Intel Arc DG2 passthrough:**
- Intel Arc A310 confirmed working with passthrough (promoted from validation to production)
- CPUID spoofing required for Code 43 fix (documented in `docs/INTEL_ARC.md`)
- Open kernel modules (i915/xe) recommended for host

**New documentation:**
- `docs/BLACKWELL.md` — NVIDIA Blackwell (RTX 50-series) passthrough guide
- `docs/RDNA4.md` — AMD RDNA 4 (RX 9070) passthrough guide
- `docs/INTEL_ARC.md` — Intel Arc GPU passthrough guide
- `docs/NOVA_DRIVER.md` — NVIDIA Nova open-source driver status and guidance

**Updated scripts:**
- `scripts/setup_vfio.sh` now supports `--blackwell` mode for RTX 50-series (auto-detects GSP firmware needs)
- `scripts/setup_vfio.sh` now supports `--rdna4` mode for RX 9070 (auto-configures late binding + vendor-reset)
- `scripts/gpupt` updated with profile presets for common Blackwell and RDNA 4 GPU configurations
- `scripts/gpu_recovery.sh` now handles Blackwell WPR2 reset bug (attempts FLR, falls back to host reboot suggestion)

**Changes:**
- Version badge bumped to 4.0.0
- Kernel badge bumped from 5.15+ to 6.12+
- Updated all hardware recommendation tables with 2026 GPU generations
- Updated software requirements (QEMU 9.0+, kernel 6.12+)
- Updated supported distributions (Ubuntu 24.04+, Fedora 41+, Arch with kernel 6.12+)
- Updated Quick Start with new kernel parameters for Blackwell/RDNA 4
- Updated Step 6a with RDNA 4 specific instructions
- Updated Step 12 with open kernel module requirement for NVIDIA
- Updated Remote Access section with Looking Glass B6/B7 KVMFR + D12
- Updated Performance Tuning with kernel 7.x scheduler improvements
- Updated Single-GPU Passthrough with Blackwell and RDNA 4 notes
- Updated Troubleshooting table with new entries for Blackwell/RDNA 4 issues
- Updated FAQ with 2026 hardware questions
- Removed stale references to kernel 5.15 as minimum (now 6.12)

---

**v3.3.0 (August 2026):**

**Additions (tooling):**
- `scripts/gpupt` — a single `gpupt <command>` CLI that wraps the whole workflow: `doctor`, `detect`, `groups`, `status`, `profile add/edit/show/rm/list`, `bind`/`unbind` (with `--dry-run`), `start`/`stop`, `hooks install/remove/status`, `recover`, `log`, and `complete`. Profiles live in `/etc/gpupt/config`; everything else needed (systemd hooks, DM restart) is generated for you.
- `docs/GPUPT.md` — reference for the `gpupt` CLI

**Changes:**
- New "`gpupt` — one command for everything" section in Management Tools
- Version badge bumped to 3.3.0

**v3.2.0 (August 2026):**

**Additions (management tooling — the repo is now drivable, not just readable):**
- `scripts/vmctl.sh` — unified VM lifecycle controller (`status`/`start`/`stop`/`reboot`/`attach-gpu`/`detach-gpu`/`info`) building on the existing helper scripts
- `scripts/gpu_recovery.sh` — recovers a stuck GPU after a VM crash (force-unbind → PCI reset quirk → rebind)
- `Makefile` at the repo root — `make status`, `make vm-start`, `make backup`, `make info`, etc. with overridable `VM=`/`GPU=`/`DEST=`/`SRC=`
- `docs/MANAGEMENT.md` — reference for all of the above
- `collect_info.sh` and `snapshot_vm.sh` now documented in the README script table + `docs/MANAGEMENT.md`

**Changes:**
- New "Management Tools" section in the README with a `vmctl.sh` command table
- Version badge bumped to 3.2.0

**v3.1.1 (August 2026):**

**Corrections (following feedback from the Looking Glass maintainers):**
- Looking Glass now documents the **KVMFR kernel module** as the recommended shared-memory setup (DMA, required for usable iGPU-host performance). `ivshmem-plain` is legacy/deprecated except for edge cases. Corrected `docs/REMOTE_ACCESS.md`, `examples/xml/looking-glass.xml`, and `examples/xml/README.md` to recommend KVMFR and link the official docs.
- Removed the `--shmem` option from `scripts/generate_vm_xml.sh` — it generated the deprecated `ivshmem-plain` shmem block. The XML generator now only does `--tpm`; LG is configured via `examples/xml/looking-glass.xml` instead.
- Updated the script table/changelog wording accordingly.

**Fixes (CI):**
- Fixed a ShellCheck SC2154 warning in `scripts/install_packages.sh` (`$PRETTY_NAME` not assigned) by sourcing `/etc/os-release` and using `${PRETTY_NAME:-$DISTRO_ID}`. Also fixed SC2034/SC2178 in `scripts/collect_info.sh`.

**v3.1.0 (August 2026):**

**Additions (scripts):**
- `scripts/collect_info.sh` — dumps every diagnostic people ask for on r/VFIO in one shot. Run it before posting a support thread and paste the output.
- `scripts/snapshot_vm.sh` — create/list/revert/delete VM snapshots with one command

**Additions (documentation):**
- `docs/ARCHITECTURE.md` — how the QEMU/KVM/VFIO/IOMMU stack actually fits together
- `docs/HOST_GPU.md` — keeping a working display (iGPU, second GPU, headless) while your GPU is in the VM

**Additions (examples + CI):**
- Real XML snippet files in `examples/xml/` (Looking Glass, evdev input, virtiofs, USB, PCI) — previously only shown inline
- `examples/systemd/autostart-vm.service` — optional VM autostart at boot
- `.github/workflows/shellcheck.yml` — every PR/push gets shellchecked

**Improvements:**
- `generate_vm_xml.sh` now supports `--tpm` (emulated TPM 2.0, Windows 11)
- `TROUBLESHOOTING.md` and `SNAPSHOTS_BACKUPS.md` reference the new scripts

**v3.0.1 (August 2026):**

**Fixes (thanks to the r/VFIO thread):**
- Removed the stale `amd_iommu=on` kernel parameter everywhere. On modern kernels it's a no-op — the AMD IOMMU auto-enables from the BIOS (AMD-Vi), no kernel flag needed. The old parameter is misinformation that keeps getting copied between guides, and we had it too. Intel still genuinely needs `intel_iommu=on`.
- Removed the leftover `iommu=1` suggestion (also stale/pointless).
- Toning down the "perfectly polished" voice throughout so the project reads like a real maintainer wrote it — because one did.

**v3.0.0 (August 2026):**

**Major expansion :**

**Additions (documentation):**
- Added 14 new detailed guides in `docs/`: `PERFORMANCE.md`, `STORAGE.md`, `NETWORKING.md`, `AUDIO.md`, `USB_PASSTHROUGH.md`, `LINUX_GUESTS.md`, `INPUT_PASSTHROUGH.md`, `GAMING_OPTIMIZATIONS.md`, `HARDWARE_DATABASE.md`, `SECURITY.md`, `UPGRADING.md`, `REMOTE_ACCESS.md`, `SNAPSHOTS_BACKUPS.md`, `GLOSSARY.md`
- Windows guest is no longer the only supported guest — Linux guests (NVIDIA/AMD/Intel, Wayland, virtiofs) now have their own guide

**Additions (scripts):**
- `scripts/setup_vfio.sh` — interactive VFIO setup (kernel params + modprobe) with `--late-bind` mode for AMD RX 9000+
- `scripts/create_disk.sh` — create qcow2/raw VM disks
- `scripts/backup_vm.sh` / `scripts/restore_vm.sh` — full VM backup/restore (disk + XML + NVRAM)
- `scripts/setup_hugepages.sh` — huge page allocation + VM XML integration
- `scripts/start_vm.sh` / `scripts/stop_vm.sh` — VM lifecycle wrappers with optional GPU binding
- `scripts/download_virtio.sh` — fetch the latest virtio-win ISO
- `scripts/status_check.sh` — one-command health check of the whole setup

**Additions (setup + examples):**
- Added `setup/opensuse.sh` for openSUSE Tumbleweed/Leap
- Added `examples/` with ready-to-use libvirt hooks (single-GPU), udev rules (evdev input), systemd units (huge pages), and VM XML snippets (Looking Glass, virtiofs, evdev, USB, PCI)

**Improvements:**
- README now links to all specialized guides; troubleshooting/FAQ point to the new docs
- Expanded troubleshooting with more root-cause tables
- Updated repository structure to reflect the real layout

---

**v2.1.0 (July 2026):**

**Additions:**
- Added instructions for AMD GPU dynamic binding: RX 9000 series GPUs require amdgpu to initialize the GPU first before dynamically unbinding and binding to vfio-pci; RX 6000 series GPUs benefit from amdgpu setting up ReBAR in a VFIO-safe way
- Added `scripts/bind_vfio.sh` usage documentation for AMD GPU late-binding scenarios
- Added AMD GPU considerations to hardware recommendations, FAQ, GUIDE, and troubleshooting

---

**v2.0.0 (July 2026):**

**Fixes:**
- Fixed invalid `--launchSecurity ovmf` in virt-install example (removed)
- Fixed PCI address parsing in `generate_vm_xml.sh` (slot was using bus value)
- Fixed wrong machine type `pc-q35-8.2` → `pc-q35` (version-agnostic)
- Fixed package name `lspci` → `pciutils` in Debian/Ubuntu setup script
- Fixed package name `spice-spicevdagent` → `spice-vdagent` in Arch setup script
- Fixed `install.sh` checks: CPU virt now greps `/proc/cpuinfo`, IOMMU now greps `dmesg`
- Fixed seclabel in generated XML (removed hardcoded `model='apparmor'`)
- Fixed false reference to "containerized host setup scripts" in FAQ

**Additions:**
- Added `.editorconfig` for consistent code style across editors
- Added `.shellcheckrc` with project-wide shellcheck rules
- Added full PCI address parsing (domain, bus, slot, function) in XML generator

**Improvements:**
- Truncated duplicated Troubleshooting and FAQ sections — see `docs/TROUBLESHOOTING.md` and `docs/FAQ.md` for full versions
- Updated CONTRIBUTING.md with shellcheck config reference
- Updated repository structure in README to reflect actual layout
</details>

---

## Table of Contents

- [Why This Repository](#why-this-repository)
- [What You Will End Up With](#what-you-will-end-up-with)
- [Hardware Requirements](#hardware-requirements)
- [Software Requirements](#software-requirements)
- [Quick Start](#quick-start)
- [Step-by-Step Guide](#step-by-step-guide)
  - [1. BIOS and Firmware Configuration](#1-bios-and-firmware-configuration)
  - [2. Verify Host Support](#2-verify-host-support)
  - [3. Identify Your GPU](#3-identify-your-gpu)
  - [4. Check IOMMU Groups](#4-check-iommu-groups)
  - [5. Configure Kernel Parameters](#5-configure-kernel-parameters)
  - [6. Configure VFIO](#6-configure-vfio)
  - [6a. AMD GPU Dynamic Binding (Late Binding)](#6a-amd-gpu-dynamic-binding-late-binding)
  - [7. Verify VFIO Binding](#7-verify-vfio-binding)
  - [8. Install Virtualization Packages](#8-install-virtualization-packages)
  - [9. Create the Virtual Machine](#9-create-the-virtual-machine)
  - [10. Optimize the VM Configuration](#10-optimize-the-vm-configuration)
  - [11. Install Windows](#11-install-windows)
  - [12. Install GPU Drivers in the Guest](#12-install-gpu-drivers-in-the-guest)
  - [13. Set Up Remote Display Access](#13-set-up-remote-display-access)
  - [14. Performance Tuning](#14-performance-tuning)
- [NVIDIA Blackwell (RTX 50-Series) Passthrough](#nvidia-blackwell-rtx-50-series-passthrough)
- [AMD RDNA 4 (RX 9070 Series) Passthrough](#amd-rdna-4-rx-9070-series-passthrough)
- [Intel Arc GPU Passthrough](#intel-arc-gpu-passthrough)
- [Additional Guides (docs/)](#additional-guides-docs)
- [Scripts](#scripts)
- [Single-GPU Passthrough](#single-gpu-passthrough)
- [Management Tools](#management-tools)
- [Troubleshooting](#troubleshooting) — see also [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)
- [FAQ](#faq) — see also [`docs/FAQ.md`](docs/FAQ.md)
- [Repository Structure](#repository-structure)
- [Contributing](#contributing)
- [License](#license)

---

## Why This Repository

GPU passthrough on Linux is well-documented across dozens of blog posts, forum threads, and wikis, but the information is scattered, often outdated, and frequently incomplete. This repository consolidates everything into a single, tested, and structured reference.

The goal is simple: give you a reproducible path from a bare Linux install to a Windows VM with full GPU acceleration, with clear recovery steps at every stage.

**A quick honest note before you dive in:** this project started because I kept losing half my evenings to dead wiki links and forum posts that assumed I already knew the whole thing. So a lot of the wording here is deliberately plain, and where the docs are confident, it's because the steps were run and verified — not copy-pasted from somewhere. That said, GPU passthrough is hardware-dependent and nobody's guide is 100% universal. If something here is wrong or outdated for your setup, open an issue or PR. It happens, and fixing it is what makes this better.

**This guide is for you if:**

- You want to play Windows games on Linux without dual-booting
- You need GPU-accelerated Windows applications (CAD, video editing, machine learning) on a Linux workstation
- You want to run a Windows VM for development or testing with real GPU access
- You are tired of forum posts that solve one problem but create three more
- You just bought an RTX 5090, RTX 5080, RX 9070 XT, or RX 9070 and want to pass it through to a VM
- You want to know which NVIDIA drivers actually work in a VM in 2026 (hint: you need the open ones)

**If you came from r/VFIO or r/linux_gaming:** hello. This is the repo the post pointed to. The short version of everything is in the [Quick Start](#quick-start); the long version is the step-by-step below; the specialized topics live in [`docs/`](#additional-guides-docs).

---

## What You Will End Up With

- A Linux host running its desktop on the primary/integrated GPU
- A Windows 10 or 11 VM with a dedicated GPU passed through via VFIO
- Near-native GPU performance for gaming, rendering, or compute workloads
- Remote display access via Sunshine/Moonlight, Looking Glass (B6/B7), or Parsec
- A system that survives reboots without manual intervention
- Support for NVIDIA Blackwell (RTX 50-series), AMD RDNA 4 (RX 9070), and Intel Arc GPUs

---

## Hardware Requirements

### Mandatory

| Component | Requirement |
|-----------|-------------|
| **CPU** | Intel with VT-x and VT-d, or AMD with AMD-V and AMD-Vi |
| **Motherboard** | IOMMU support in BIOS/UEFI, ACS recommended |
| **RAM** | 16 GB minimum (8 GB host + 8 GB guest), 32 GB+ recommended |
| **Storage** | 50 GB+ free for the guest disk image (NVMe preferred) |
| **Two GPUs** | One for the host (integrated or discrete), one for the VM |

### Recommended (2026)

- **CPU**: Modern quad-core or better with 8+ threads (e.g., Intel 12th gen+, AMD Ryzen 5000+, AMD Ryzen 9000)
- **RAM**: 32 GB DDR4/DDR5
- **Storage**: NVMe SSD for the VM disk
- **GPU (guest)**: NVIDIA RTX 30/40/50 series, AMD RX 6000/7000/9000 series, or Intel Arc A-series/B-series
- **GPU (host)**: Intel integrated graphics or any secondary GPU
- **Motherboard**: Known good IOMMU grouping (check the [Level1Techs forum](https://forums.level1techs.com) or [r/VFIO](https://reddit.com/r/vfio) for your specific board)

### GPU Compatibility (Tested and Confirmed, September 2026)

| GPU | Architecture | Passthrough Status | Notes |
|-----|-------------|-------------------|-------|
| NVIDIA RTX 5090 | Blackwell GB202 | Working | Open kernel modules required, WPR2 reset bug |
| NVIDIA RTX 5080 | Blackwell GB203 | Working | 1:1 IOMMU mapping required, open modules required |
| NVIDIA RTX 4090/4080/4070 | Ada Lovelace | Working | Open kernel modules required on R580+/R595+ |
| NVIDIA RTX 3090/3080/3070 | Ampere | Working | Standard driver works fine |
| NVIDIA RTX 2080/2070 | Turing | Working | Standard driver works fine |
| AMD RX 9070 XT | RDNA 4 Navi 48 | Working | Late binding mandatory, vendor-reset required |
| AMD RX 9070 | RDNA 4 Navi 48 | Working | Late binding mandatory, vendor-reset required |
| AMD RX 7900 XTX/XT | RDNA 3 Navi 31 | Working | Late binding recommended |
| AMD RX 6900 XT/6800 XT | RDNA 2 Navi 21 | Working | Late binding recommended for ReBAR |
| Intel Arc A770/A750/A310 | Alchemist DG2 | Working | CPUID spoofing may be needed |

### Important Notes

**Dual-GPU is strongly recommended.** Single-GPU passthrough is possible but significantly more complex and fragile. If you attempt single-GPU passthrough, expect to troubleshoot display manager shutdown, GPU rebinding, and recovery scenarios.

**Check your motherboard's IOMMU grouping before buying hardware.** Some boards group the PCIe slots with critical host devices (USB controllers, SATA controllers), making clean passthrough impossible without ACS override.

**NVIDIA Blackwell and Ada Lovelace owners: you need the open kernel modules.** Starting with driver branches R580 and R595, the closed-source NVIDIA kernel modules do not support Ada Lovelace or Blackwell in a VM. You must install the `-open` variant. This is not optional and not a workaround — it is how NVIDIA ships these architectures now. See [Step 12](#12-install-gpu-drivers-in-the-guest) and [`docs/BLACKWELL.md`](docs/BLACKWELL.md).

---

## Software Requirements

| Component | Purpose | Minimum Version |
|-----------|---------|-----------------|
| **Linux kernel** | IOMMU, VFIO, KVM | 6.12 (was 5.15 — bumped for RDNA 4 and Blackwell support) |
| **QEMU/KVM** | Virtualization backend | 9.0+ |
| **libvirt** | VM management layer | 9.0+ |
| **virt-manager** or **virt-install** | GUI/CLI for VM creation | Latest |
| **OVMF** | UEFI firmware for the guest | Latest |
| **virtio-win** | Paravirtualized drivers for the Windows guest | Latest |
| **Windows ISO** | Windows 10 or 11 installation media | Latest |
| **vendor-reset** (AMD RDNA 4 only) | GPU reset after VM shutdown | Latest from GitHub |

### Supported Distributions

All instructions in this guide work on:

- **Debian** 12+ / **Ubuntu** 22.04+ / **Ubuntu 24.04** (recommended)
- **Arch Linux** / **Manjaro** (kernel 6.12+)
- **Fedora** 41+ / **Fedora 42**
- **openSUSE** Tumbleweed / Leap

Distribution-specific differences are noted where they exist. One-command setup scripts are available in [`setup/`](#repository-structure) for each family.

---

## Quick Start

If you already know what you are doing and just want the commands:

```bash
# 1. Install packages (Debian/Ubuntu)
sudo apt update && sudo apt install -y qemu-kvm libvirt-daemon-system \
  libvirt-clients virt-manager virtinst ovmf bridge-utils

# 2. Enable libvirt
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $USER

# 3. Check your GPU IDs
lspci -nn | grep -iE 'vga|audio'

# 4. Add to /etc/default/grub (replace IDs with yours):
# Intel: GRUB_CMDLINE_LINUX_DEFAULT="quiet splash intel_iommu=on iommu=pt vfio-pci.ids=XXXX:XXXX,XXXX:XXXX"
# AMD:   GRUB_CMDLINE_LINUX_DEFAULT="quiet splash iommu=pt vfio-pci.ids=XXXX:XXXX,XXXX:XXXX"
# NOTE: For NVIDIA Blackwell/Ada, do NOT bind vfio-pci at boot — use late binding instead.

# 5. Add to /etc/modprobe.d/vfio.conf:
# options vfio-pci ids=XXXX:XXXX,XXXX:XXXX

# 6. Update initramfs and reboot
sudo update-initramfs -u && sudo reboot

# 7. Verify VFIO binding
lspci -k -d $(lspci -nn | grep VGA | awk '{print $1}')

# 8. Create VM with virt-install (see Section 9 for full command)
```

**If this is your first time, follow the full step-by-step guide below.**

> **Prefer automation?** Run `sudo bash scripts/status_check.sh` any time to get a full health report of your setup (kernel, IOMMU, VFIO, GPU binding, libvirt, VMs).

---

## Step-by-Step Guide

### 1. BIOS and Firmware Configuration

Before touching Linux, configure your motherboard firmware. Every BIOS/UEFI is different, but look for these options:

**Intel Systems:**

| Setting | Where to Find It | Value |
|---------|-------------------|-------|
| Intel Virtualization Technology (VT-x) | CPU Configuration | Enabled |
| Intel VT-d (IOMMU) | Advanced / Northbridge | Enabled |
| Above 4G Decoding | PCI Subsystem Settings | Enabled |
| Resizable BAR | PCI Subsystem Settings | Enabled (if supported) |
| Primary Display | Boot / Graphics | iGPU or PCIe Slot 1 (whichever is your host GPU) |

**AMD Systems:**

| Setting | Where to Find It | Value |
|---------|-------------------|-------|
| SVM Mode (AMD-V) | CPU Configuration | Enabled |
| IOMMU | Advanced / AMD CBS | Enabled |
| ACS Enable | Advanced / AMD CBS | Enabled (if available) |
| Above 4G Decoding | PCI Subsystem Settings | Enabled |
| Resizable BAR | PCI Subsystem Settings | Enabled (if supported) |
| Primary Display | Boot / Graphics | iGPU or PCIe Slot 1 |

> **Tip:** If you cannot find IOMMU or VT-d settings, your motherboard may hide them under an "Advanced Mode" or "Expert Mode" toggle. Some boards require you to disable "Fast Boot" before these options appear.

> **NVIDIA Blackwell note:** Some RTX 50-series boards have been reported to require 1:1 IOMMU mapping for the GB203 chip (RTX 5080). If your motherboard does not support this, passthrough may not work cleanly. Check the [r/VFIO](https://reddit.com/r/vfio) thread on your specific board before buying.

**Goal:** The firmware must hand off virtualization support to the kernel cleanly, and it must not force the passthrough GPU into the primary display path.

---

### 2. Verify Host Support

After booting into Linux, confirm that the kernel sees virtualization and IOMMU support.

```bash
# Check CPU virtualization extensions
lscpu | grep -i virtualization
```

Expected output for Intel:
```
Virtualization:   VT-x
```

Expected output for AMD:
```
Virtualization:   AMD-V
```

```bash
# Check IOMMU activation in kernel log
dmesg | grep -Ei 'iommu|dmar|amd-vi|vt-d'
```

You should see lines like:

For Intel:
```
[    0.000000] DMAR: IOMMU enabled
[    0.028467] iommu: Default domain type: Passthrough
```

For AMD:
```
[    0.000000] AMD-Vi: IOMMU performance counters supported
[    0.000000] AMD-Vi: Interrupt remapping enabled
```

**If IOMMU does not appear in dmesg:**
- Go back to BIOS and enable VT-d/AMD-Vi/IOMMU
- Make sure the kernel parameter is set (see Step 5)
- On AMD, the IOMMU is enabled automatically by the kernel when AMD-Vi is on in the BIOS — there's no magic kernel flag to add. If it's missing in dmesg, it's almost always a BIOS thing.

**Do not proceed until this step passes.**

---

### 3. Identify Your GPU

List all PCI devices and find your target GPU and its associated audio controller.

```bash
# List all PCI devices with vendor/device IDs
lspci -nn
```

Find lines matching your GPU. Example for an NVIDIA Blackwell card:

```
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GB202 [GeForce RTX 5090] [10de:28a2] (rev a1)
01:00.1 Audio device [0403]: NVIDIA Corporation GB202 High Definition Audio Controller [10de:22e9] (rev a1)
```

Example for an NVIDIA Ampere card:

```
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA102 [GeForce RTX 3090] [10de:2204] (rev a1)
01:00.1 Audio device [0403]: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef] (rev a1)
```

Example for an AMD RDNA 4 card:

```
01:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 48 [Radeon RX 9070 XT] [1002:7550] (rev c3)
01:00.1 Audio device [0403]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 48 HDMI Audio [1002:ab28]
```

Example for an AMD RDNA 3 card:

```
01:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 31 [Radeon RX 7900 XTX] [1002:7450] (rev c3)
01:00.1 Audio device [0403]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 31 HDMI Audio [1002:ab28]
```

**Write down:**
- PCI addresses (e.g., `01:00.0` and `01:00.1`)
- Vendor IDs and device IDs (e.g., `10de:28a2` and `10de:22e9` for Blackwell)
- Which GPU is the one you want to pass through

You can also use the helper script:

```bash
bash scripts/detect_gpu.sh
```

> **Important:** Some GPUs have additional functions (USB-C controller, etc.) beyond the VGA and audio devices. Check for any additional functions in the same IOMMU group that belong to the GPU and include them all.

---

### 4. Check IOMMU Groups

IOMMU groups determine which devices are isolated together. The GPU should be in a group by itself or with devices you are willing to pass through together.

```bash
# Run the IOMMU group inspection script
bash scripts/check_iommu_groups.sh
```

Or run the command directly:

```bash
#!/bin/bash
for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
    echo "IOMMU Group ${g##*/}:"
    for d in $g/devices/*; do
        echo -e "\t$(lspci -nns ${d##*/})"
    done
done
```

**What you want to see:**

Your GPU's VGA and Audio functions in a group by themselves, or with only other GPU-related functions:

```
IOMMU Group 1:
    01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GB202 [GeForce RTX 5090] [10de:28a2] (rev a1)
    01:00.1 Audio device [0403]: NVIDIA Corporation GB202 High Definition Audio Controller [10de:22e9] (rev a1)
```

**What you do NOT want to see:**

The GPU grouped with essential host devices:

```
IOMMU Group 1:
    00:01.0 PCI bridge [0604]: Intel Corporation ... [8086:15e8]
    01:00.0 VGA compatible controller [0300]: NVIDIA Corporation ... [10de:28a2]
    01:00.1 Audio device [0403]: NVIDIA Corporation ... [10de:22e9]
    02:00.0 Ethernet controller [0200]: Intel Corporation ... [8086:1521]
```

**If your groups are bad, try these fixes in order:**

1. Move the GPU to a different PCIe slot
2. Enable ACS in BIOS (if available)
3. Update your BIOS/UEFI firmware
4. Try the [ACS override patch](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Bypassing_the_IOMMU_group_limitations) (understand the security implications)

---

### 5. Configure Kernel Parameters

Edit your bootloader configuration to enable IOMMU and early VFIO binding.

#### For GRUB (Debian, Ubuntu, Fedora, etc.)

Edit `/etc/default/grub`:

```bash
sudo nano /etc/default/grub
```

**Intel systems (NVIDIA Turing/Ampere, AMD RDNA 2/3/4):**

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash intel_iommu=on iommu=pt vfio-pci.ids=10de:1af2,10de:1af9 rd.driver.pre=vfio-pci"
```

**AMD systems (NVIDIA Turing/Ampere, AMD RDNA 2/3/4):**

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash iommu=pt vfio-pci.ids=10de:1af2,10de:1af9 rd.driver.pre=vfio-pci"
```

> **Note:** you'll see `amd_iommu=on` in a lot of old forum posts and guides. It's a leftover from years ago — on modern kernels it does nothing, because the AMD IOMMU is enabled by default whenever AMD-Vi is turned on in the BIOS. Intel is the opposite: `intel_iommu=on` is genuinely required there. Don't waste an evening "fixing" your kernel params because of that old parameter.

> **Replace `10de:1af2,10de:1af9` with your actual GPU vendor:device IDs.**

> **NVIDIA Blackwell and Ada Lovelace (RTX 40/50 series):** Do NOT bind `vfio-pci.ids` at boot. These GPUs need to initialize with the host driver first, then be dynamically bound to `vfio-pci` just before starting the VM. See [Step 6a](#6a-amd-gpu-dynamic-binding-late-binding) for the late binding process, or [`docs/BLACKWELL.md`](docs/BLACKWELL.md) for the full guide.

> **AMD RDNA 4 (RX 9070 series):** Same situation — do NOT bind `vfio-pci.ids` at boot. The `amdgpu` driver must initialize the GPU first. See [Step 6a](#6a-amd-gpu-dynamic-binding-late-binding) and [`docs/RDNA4.md`](docs/RDNA4.md).

**Optional kernel parameters** (add one at a time, test stability):

| Parameter | Purpose |
|-----------|---------|
| `video=efifb:off` | Prevents the EFI framebuffer from claiming the GPU |
| `video=vesafb:off` | Prevents the VESA framebuffer from claiming the GPU |
| `initcall_blacklist=sysfb_init` | Blocks the system framebuffer driver |
| `rd.driver.pre=vfio-pci` | Loads vfio-pci early in the initramfs |
| `iommu=pt` | Uses passthrough mode for better performance |
| `softdep nvidia pre: vfio-pci` | Ensures vfio-pci loads before nvidia |

Update GRUB:

```bash
# Debian / Ubuntu
sudo update-grub

# Fedora / RHEL
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

# Arch Linux
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

#### For systemd-boot (Arch, Pop!_OS, etc.)

Edit `/boot/loader/entries/*.conf` and add the parameters to the `options` line:

Intel:
```
options root=UUID=xxxx-xxxx rw quiet splash intel_iommu=on iommu=pt vfio-pci.ids=10de:1af2,10de:1af9 rd.driver.pre=vfio-pci
```

AMD (no iommu enable flag needed — see the note above):
```
options root=UUID=xxxx-xxxx rw quiet splash iommu=pt vfio-pci.ids=10de:1af2,10de:1af9 rd.driver.pre=vfio-pci
```

Then rebuild:

```bash
sudo bootctl update
```

---

### 6. Configure VFIO

Create or edit the VFIO configuration file:

```bash
sudo nano /etc/modprobe.d/vfio.conf
```

Add:

```
options vfio-pci ids=10de:1af2,10de:1af9
softdep nvidia pre: vfio-pci
```

> **Again, replace the IDs with your actual GPU IDs.**

If you are using an AMD GPU on the host and passing through an NVIDIA GPU (or vice versa), you may need to blacklist the relevant host driver:

```
# /etc/modprobe.d/blacklist-gpu.conf
blacklist nouveau
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
blacklist nvidia_uvm
```

> **Note:** Only blacklist drivers for the passthrough GPU. Do not blacklist drivers needed by the host GPU.

> **NVIDIA Blackwell/Ada users:** If you are using late binding (recommended for these GPUs), you do not need to add `vfio-pci.ids` here. The late binding script handles the bind/unbind at VM start/stop time.

#### Update initramfs

This is critical. The VFIO module must be loaded before any GPU driver claims the device.

```bash
# Debian / Ubuntu
sudo update-initramfs -u

# Arch Linux
sudo mkinitcpio -P

# Fedora / RHEL
sudo dracut -f

# openSUSE
sudo dracut --force
```

**Reboot now:**

```bash
sudo reboot
```

---

### 6a. AMD GPU Dynamic Binding (Late Binding)

Some AMD GPUs require special handling for VFIO passthrough. NVIDIA Blackwell and Ada Lovelace also benefit from late binding. Here is the full picture:

**Which GPUs need late binding:**

| GPU Family | Late Binding Required? | Why |
|-----------|----------------------|-----|
| NVIDIA Blackwell (RTX 50-series) | **Yes** | GSP firmware must initialize first; direct vfio-pci binding leaves GPU uninitialized |
| NVIDIA Ada Lovelace (RTX 40-series) | Recommended | Benefits from host driver initializing ReBAR |
| AMD RDNA 4 (RX 9070 series) | **Yes** | GPU firmware and PCIe topology require amdgpu initialization |
| AMD RDNA 3 (RX 7000 series) | Recommended | amdgpu sets up ReBAR in a VFIO-safe way |
| AMD RDNA 2 (RX 6000 series) | Optional | Same ReBAR benefit as RDNA 3 |

**How it works:**

Instead of binding the GPU to `vfio-pci` at boot (Step 5-6), you let the host driver (`nvidia`, `amdgpu`) claim the device normally, then **dynamically unbind** it from the host driver and **bind** it to `vfio-pci` just before starting the VM.

If you are on a **dual-GPU setup** and only need this for the passthrough GPU, you can use a **libvirt hook** to automate the unbind/bind when the VM starts:

```bash
# /etc/libvirt/hooks/qemu
#!/bin/bash

VM_NAME="win11-gpu"
GPU_ADDR="0000:01:00.0"
GPU_AUDIO="0000:01:00.1"
GPU_IDS="1002:XXXX,1002:XXXX"   # Replace with your GPU vendor:device IDs

case "$1" in
  "$VM_NAME")
    case "$2" in
      prepare)
        # Stop display manager if using the same GPU for host display
        # systemctl stop gdm
        # Unbind from host driver
        echo "$GPU_ADDR" > /sys/bus/pci/devices/$GPU_ADDR/driver/unbind 2>/dev/null
        echo "$GPU_AUDIO" > /sys/bus/pci/devices/$GPU_AUDIO/driver/unbind 2>/dev/null
        # Bind to vfio-pci
        modprobe vfio-pci
        for ID in $(echo "$GPU_IDS" | tr ',' ' '); do
          VENDOR=$(echo "$ID" | cut -d: -f1)
          DEVICE=$(echo "$ID" | cut -d: -f2)
          echo "$VENDOR $DEVICE" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true
        done
        echo "$GPU_ADDR" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
        echo "$GPU_AUDIO" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
        ;;
    esac
    ;;
esac
```

Make it executable:
```bash
sudo chmod +x /etc/libvirt/hooks/qemu
```

Alternatively, use the bundled bind script before starting the VM manually:

```bash
sudo bash scripts/bind_vfio.sh unbind 0000:01:00.0 0000:01:00.1
```

> **Note:** This is the same bind script used for single-GPU passthrough, but here it is used in a dual-GPU context specifically to let the host driver initialize the card first. After the VM shuts down, the GPU will fall back to the host driver automatically on next boot (since `vfio-pci` is not loaded early).

> **AMD RDNA 4 (RX 9070) specific:** You must also install the `vendor-reset` kernel module for clean GPU reset after VM shutdown. See [`docs/RDNA4.md`](docs/RDNA4.md) for the full setup.

> **NVIDIA Blackwell specific:** You must use the **open** kernel modules (`nvidia-open`) on the host for late binding to work correctly. The closed-source modules do not expose the GPU correctly for vfio-pci rebinding on Blackwell/Ada. See [`docs/BLACKWELL.md`](docs/BLACKWELL.md).

**Verification:** After the hook runs (or after running the bind script), verify the GPU is bound to `vfio-pci`:

```bash
lspci -k -s 0000:01:00.0 | grep "Kernel driver in use"
# Should show: vfio-pci
```

---

### 7. Verify VFIO Binding

After rebooting, confirm the GPU is bound to vfio-pci:

```bash
# Check the GPU specifically
lspci -k -d $(lspci -nn | grep -i vga | head -1 | awk '{print $1}')
```

Or check all devices:

```bash
lspci -k | grep -A 3 -iE 'vga|3d'
```

**Expected output:**

```
01:00.0 VGA compatible controller: NVIDIA Corporation GB202 [GeForce RTX 5090]
    Subsystem: ...
    Kernel driver in use: vfio-pci
    Kernel modules: nvidiafb, nouveau, nvidia_drm, nvidia, nvidia_open
```

The key line is `Kernel driver in use: vfio-pci`. If you see `nvidia` or `nouveau` (for NVIDIA) or `amdgpu` (for AMD) instead, the binding failed.

**If VFIO binding failed:**

```bash
# Check if VFIO modules are loaded
lsmod | grep vfio

# Check dmesg for VFIO errors
dmesg | grep -i vfio

# Check if the IDs match
lspci -nn | grep -iE 'vga|audio'
```

Common fixes:
- Double-check your vendor:device IDs
- Make sure you included the audio device
- Rebuild initramfs again and reboot
- Ensure no other kernel parameter is overriding VFIO

**You can also run the binding verification script:**

```bash
bash scripts/check_vfio_binding.sh
```

---

### 8. Install Virtualization Packages

#### Debian / Ubuntu

```bash
sudo apt update
sudo apt install -y \
  qemu-kvm \
  libvirt-daemon-system \
  libvirt-clients \
  virt-manager \
  virtinst \
  ovmf \
  bridge-utils \
  libguestfs-tools
```

#### Arch Linux

```bash
sudo pacman -S \
  qemu-full \
  libvirt \
  virt-manager \
  virt-install \
  edk2-ovmf \
  bridge-utils \
  libguestfs
```

#### Fedora

```bash
sudo dnf install -y \
  qemu-kvm \
  libvirt \
  virt-manager \
  virt-install \
  edk2-ovmf \
  bridge-utils \
  libguestfs-tools
```

#### Enable and start libvirt

```bash
sudo systemctl enable --now libvirtd
sudo systemctl start libvirtd
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER
```

**Log out and log back in** (or run `newgrp libvirt`) for group changes to take effect.

#### Verify libvirt is working

```bash
virsh list --all
```

This should return an empty list (no VMs yet) without errors.

---

### 9. Create the Virtual Machine

#### Download required files

```bash
# Windows 11 ISO (or Windows 10)
# Download from https://www.microsoft.com/software-download/

# VirtIO drivers ISO
wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso -P /tmp/
```

#### Option A: Create VM with virt-install

```bash
sudo virt-install \
  --name win11-gpu \
  --memory 16384 \
  --vcpus 8 \
  --cpu host-passthrough,topology.sockets=1,topology.cores=8,topology.threads=1 \
  --machine q35 \
  --boot uefi \
  --disk path=/var/lib/libvirt/images/win11.qcow2,size=100,bus=virtio,format=qcow2 \
  --disk path=/tmp/virtio-win.iso,device=cdrom,bus=sata \
  --cdrom /path/to/Win11.iso \
  --network network=default,model=virtio \
  --graphics spice,listen.type=none \
  --video virtio \
  --hostdev 0000:01:00.0 \
  --hostdev 0000:01:00.1 \
  --features kvm=hidden \
  --tpm backend.type=emulator,backend.version=2.0,model=tpm-crb \
  --autostart
```

> **Adjust the following for your system:**
> - `--memory`: Amount of RAM in MB (give the guest at least 8 GB)
> - `--vcpus`: Number of virtual CPUs (match physical cores, not threads)
> - `--hostdev`: Your GPU PCI addresses (from Step 3)
> - `--disk path=...`: Where to store the VM disk image
> - `--cdrom`: Path to your Windows ISO

> **AMD RDNA 4 users:** After creating the VM, you must add `<rom bar='off'/>` to both the VGA and audio hostdev entries in the XML. See [`docs/RDNA4.md`](docs/RDNA4.md).

#### Option B: Create VM with virt-manager (GUI)

1. Open virt-manager
2. Click **File > New Virtual Machine**
3. Select **Local install media**
4. Browse to your Windows ISO
5. Set RAM (8192+ MB) and CPUs (4+)
6. Enable **Customize configuration before install**
7. Under **Overview**: Change chipset to **Q35** and firmware to **UEFI x86_64: /usr/share/OVMF/OVMF_CODE.fd**
8. Under **CPUs**: Set model to **host-passthrough**
9. Under **Add Hardware > PCI Host Device**: Add both GPU functions (VGA + Audio)
10. Under **Add Hardware > Storage**: Add the virtio-win.iso as a SATA CDROM
11. Click **Begin Installation**

---

### 10. Optimize the VM Configuration

After creating the VM, edit the XML for best performance:

```bash
sudo virsh edit win11-gpu
```

This opens the domain XML in your editor. Make the following changes:

#### Enable Hyper-V enlightenments (Windows performance)

Find the `<features>` section and add/modify:

```xml
<features>
  <acpi>
    <apic/>
  </acpi>
  <hyperv mode='custom'>
    <relaxed state='on'/>
    <vapic state='on'/>
    <spinlocks state='on' retries='8191'/>
    <vpindex state='on'/>
    <synic state='on'/>
    <stimer state='on'/>
    <reset state='on'/>
    <vendor_id state='on' value='123456789ab'/>
    <frequencies state='on'/>
  </hyperv>
  <kvm>
    <hidden state='on'/>
  </kvm>
  <vmport state='off'/>
  <ioapic driver='kvm'/>
</features>
```

> **Why `vendor_id`?** Some NVIDIA drivers detect virtualization through the Hyper-V vendor ID. Setting a custom value prevents the driver from refusing to work in a VM.

#### Enable KVM hidden state

The `<kvm><hidden state='on'/></kvm>` block prevents the guest from detecting that it is running in a VM. This is required for some NVIDIA drivers.

#### Set the clock

```xml
<clock offset='localtime'>
  <timer name='rtc' tickpolicy='catchup'/>
  <timer name='pit' tickpolicy='delay'/>
  <timer name='hpet' present='no'/>
  <timer name='tsc' present='yes' mode='native'/>
</clock>
```

#### Add CPU pinning (optional, for maximum performance)

In the `<vcpu>` and `<cputune>` sections:

```xml
<vcpu placement='static'>8</vcpu>
<cputune>
  <vcpupin vcpu='0' cpuset='2'/>
  <vcpupin vcpu='1' cpuset='3'/>
  <vcpupin vcpu='2' cpuset='4'/>
  <vcpupin vcpu='3' cpuset='5'/>
  <vcpupin vcpu='4' cpuset='6'/>
  <vcpupin vcpu='5' cpuset='7'/>
  <vcpupin vcpu='6' cpuset='10'/>
  <vcpupin vcpu='7' cpuset='11'/>
  <emulatorpin cpuset='0-1'/>
</cputune>
```

> **Find your CPU core layout first** with `lscpu -e` or `lstopo`. Pin vCPUs to physical cores, skipping cores used by the host. Never pin to hyperthreads if you can avoid it.

#### Use huge pages (optional)

```xml
<memoryBacking>
  <hugepages>
    <page size='2048' unit='KiB'/>
  </hugepages>
</memoryBacking>
```

Then allocate huge pages on the host:

```bash
# For 16 GB guest with 2 MB pages
echo 8192 | sudo tee /proc/sys/vm/nr_hugepages
```

#### Add VirtIO disk with cache mode

If you want to fine-tune disk performance in the XML:

```xml
<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2' cache='none' io='native' discard='unmap'/>
  <source file='/var/lib/libvirt/images/win11.qcow2'/>
  <target dev='vda' bus='virtio'/>
</disk>
```

After editing, validate and start the VM:

```bash
sudo virsh define /etc/libvirt/qemu/win11-gpu.xml
sudo virsh start win11-gpu
```

---

### 11. Install Windows

1. The VM boots from the Windows ISO
2. When Windows Setup asks you to select a disk, **no disks will appear**
3. Click **Load Driver** > **Browse**
4. Navigate to the VirtIO ISO and select:
   - For NVMe/virtio disk: `viostor\w11\amd64` (or `w10` for Windows 10)
   - For SCSI disk: `vioscsi\w11\amd64`
5. Select the appropriate driver and click **Next**
6. The virtual disk now appears -- select it and continue installation
7. Complete Windows installation as normal

#### After Windows boots

1. Mount the virtio-win.iso in the VM (virt-manager > right-click CD icon)
2. Run `D:\virtio-win-guest-tools.exe` to install all VirtIO drivers
3. Reboot when prompted
4. Check Device Manager -- no yellow warning icons should remain (except possibly the GPU until you install its driver)

---

### 12. Install GPU Drivers in the Guest

#### NVIDIA GPUs

**For Blackwell (RTX 50-series) and Ada Lovelace (RTX 40-series) — IMPORTANT:**

Starting with driver branches R580 and R595, you **must** use the **open kernel modules** for Blackwell and Ada Lovelace GPUs in a VM. The closed-source modules will fail with `RmInitAdapter` errors.

1. Download the driver from [nvidia.com/drivers](https://www.nvidia.com/drivers) inside the VM
2. Choose the **"Open GPU Kernel Module Source"** variant (look for the `-open` suffix or the open-source option during install)
3. Run the installer
4. If the installer complains about not finding compatible hardware:
   - Make sure KVM hidden state is enabled in the VM XML
   - Make sure the `vendor_id` is set in the Hyper-V enlightenments
   - Verify you are using the open kernel module variant
   - Try downloading an older driver version (R565 or R550 for older architectures)
5. Reboot after installation

**For Turing (RTX 20-series) and older:**

The standard closed-source driver works fine. Follow the same steps but you don't need the `-open` variant.

#### AMD GPUs

1. Download the driver from [amd.com/support](https://www.amd.com/support) inside the VM
2. Run the installer
3. Reboot after installation
4. For RDNA 4 (RX 9070): The AMD Adrenalin driver should detect the GPU automatically. If not, ensure `amdgpu` initialized the card on the host before binding to vfio-pci.

#### Intel Arc GPUs

1. Download the driver from [intel.com/content/www/us/en/download](https://www.intel.com/content/www/us/en/download/) inside the VM
2. Run the installer
3. Reboot after installation
4. Note: You may need to spoof the CPUID in the VM XML for Code 43 to go away. See [`docs/INTEL_ARC.md`](docs/INTEL_ARC.md).

**After driver installation:**
- Connect your monitor to the passthrough GPU
- The display output switches from SPICE/virtio to the physical GPU
- SPICE continues to work for initial setup, but the primary display is now on the GPU

---

### 13. Set Up Remote Display Access

Choose one or more methods based on your needs:

#### Sunshine + Moonlight (Recommended for Gaming)

**Host (Linux):**

```bash
# Install Sunshine
# Follow instructions at https://github.com/LizardByte/Sunshine

# Or build from source:
git clone https://github.com/LizardByte/Sunshine.git
cd Sunshine
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
sudo cmake --install build
```

**Guest (Windows):**

1. Install Moonlight on the Windows VM or on a client device
2. Connect to the VM's IP address
3. Enjoy low-latency streaming

#### Looking Glass B6/B7 (Best for Local Use)

Looking Glass captures the guest GPU output and displays it on the host with near-zero latency. **B7** (the latest version) introduces the D12 capture interface that uses the GPU's hardware copy engine for zero-CPU frame transfer.

**Host (Linux) — KVMFR module (recommended):**

The KVMFR kernel module is now the **only recommended** shared-memory setup. It enables DMA transfers from the GPU directly to shared memory, which is essential for good performance especially on iGPU hosts.

```bash
# Install Linux headers
sudo apt install linux-headers-$(uname -r)   # Debian/Ubuntu
sudo pacman -S linux-headers                   # Arch

# Build and install KVMFR module
cd LookingGlass/module/
sudo dkms install .
# Or manually:
# make && sudo make install

# Load the module
sudo modprobe kvmfr static_size_mb=64

# Make persistent
echo "kvmfr static_size_mb=64" | sudo tee /etc/modprobe.d/kvmfr.conf
```

Add to VM XML (requires QEMU 6.2+ and libvirt 7.9+):

```xml
<qemu:commandline>
  <qemu:arg value="-device"/>
  <qemu:arg value="{'driver':'ivshmem-plain','id':'shmem0','memdev':'looking-glass'}"/>
  <qemu:arg value="-object"/>
  <qemu:arg value="{'qom-type':'memory-backend-file','id':'looking-glass','mem-path':'/dev/kvmfr0','size':67108864,'share':true}"/>
</qemu:commandline>
```

**Host (Linux) — Build Looking Glass:**

```bash
git clone https://github.com/gnif/LookingGlass.git
cd LookingGlass
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
# The client binary is at build/looking-glass-client
```

**Guest (Windows):**

1. Download Looking Glass client from [looking-glass.io](https://looking-glass.io) (B7 is the latest)
2. The B7 installer includes the IVSHMEM driver — it will install automatically
3. Run `looking-glass-client.exe`

> **B7 new feature:** The D12 capture interface creates a texture directly in IVSHMEM shared memory and uses the GPU's hardware copy engine to stream frames. Combined with KVMFR on the host, this means the CPU is no longer involved in frame data transfer at all. Huge improvement for iGPU hosts.

> **B7 also fixes:** A race condition when showing overlay messages which could cause a crash. Updated and restructured documentation.

#### Parsec (Easiest Setup)

1. Install Parsec in both the host and the guest
2. Sign in with the same account
3. Connect remotely

#### SPICE (Basic, Good for Setup)

SPICE is already configured in the VM. Access it through virt-manager or connect remotely:

```bash
# Find the SPICE port
sudo virsh domdisplay win11-gpu
# Output: spice://127.0.0.1:5900

# Connect remotely with a SPICE client
spicy -h 127.0.0.1 -p 5900
```

---

### 14. Performance Tuning

> This section is the summary. The full deep-dive with measurement tools, iothreads, IRQ affinity, and benchmarks is in [docs/PERFORMANCE.md](docs/PERFORMANCE.md). For gaming-specific settings, see [docs/GAMING_OPTIMIZATIONS.md](docs/GAMING_OPTIMIZATIONS.md).

#### CPU Governor

Set the CPU to performance mode to avoid latency spikes:

```bash
# Check current governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Set to performance (requires cpupower or similar)
sudo cpupower frequency-set -g performance

# Or permanently:
echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpupower
sudo systemctl enable --now cpupower
```

#### Disable unnecessary host services

```bash
# Stop and disable services you do not need during VM operation
sudo systemctl stop cups
sudo systemctl stop bluetooth
sudo systemctl stop avahi-daemon
```

#### Isolate CPU cores for the VM

Add to kernel parameters:

```
isolcpus=2-7,10-11
```

This prevents the host from scheduling tasks on the cores dedicated to the VM.

#### Disable SMT on host cores used by the guest (optional)

If you are experiencing cache thrashing:

```
nosmt=force
```

Or isolate specific threads:

```
nohz_full=2-7,10-11 rcu_nocbs=2-7,10-11
```

#### Optimize I/O

```bash
# Set I/O scheduler to none or mq-deadline for NVMe
echo none | sudo tee /sys/block/nvme0n1/queue/scheduler

# Make persistent via udev rule
echo 'ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"' | \
  sudo tee /etc/udev/rules.d/60-ioscheduler.rules
```

#### Kernel 6.12+ benefits

If you are running kernel 6.12 or newer, you get these improvements for free:

- **PREEMPT_RT** mainline — better real-time scheduling for the VM
- **VirtIO Vsock** performance improvements — faster guest/host communication
- **sched_ext** — eBPF-based scheduler for fine-tuned VM scheduling
- **AMD Ryzen 7000/8000** random reboot fix during virtualization

---

## NVIDIA Blackwell (RTX 50-Series) Passthrough

This is the new hot topic in 2026. NVIDIA Blackwell consumer GPUs (RTX 5090, RTX 5080) can be passed through to a VM, but there are important requirements that don't apply to older GPUs.

> **Full guide:** See [`docs/BLACKWELL.md`](docs/BLACKWELL.md) for the complete walkthrough. This section is the summary.

### Key Requirements

1. **Open kernel modules are mandatory.** The closed-source `nvidia` module does not support Blackwell in a VM. You must use `nvidia-open` on the host (for late binding) and the open kernel module variant in the guest driver.

2. **Late binding is mandatory.** Do not add Blackwell vendor:device IDs to `vfio-pci.ids` at boot. The GPU needs the host driver to initialize GSP firmware first. Use the libvirt hook or `gpupt` to bind/unbind dynamically.

3. **WPR2 reset bug.** After the VM shuts down, the GPU may not reset cleanly because GSP firmware state (Write Protection Region 2) persists through PCIe FLR. Symptoms: the GPU shows `vfio-pci` but won't reinitialize with the host driver. Short-term fix: reboot the host. Long-term fix: install the `vendor-reset` kernel module.

4. **RTX 5080 (GB203) has a 1:1 IOMMU mapping requirement.** The firmware requires that every DMA mapping maps to a unique physical page. Some motherboards handle this automatically; others don't. If your VM won't boot or crashes immediately, check your IOMMU grouping and ensure `iommu=pt` is set.

### Confirmed Vendor:Device IDs

| GPU | VGA ID | Audio ID |
|-----|--------|----------|
| RTX 5090 | `10de:28a2` | `10de:22e9` |
| RTX 5080 | `10de:2c02` | `10de:22e9` |

### Quick Setup

```bash
# Use gpupt for the easiest experience
bash scripts/gpupt profile add rtx5090 --vm win11-gpu \
    --gpu 0000:01:00.0 --audio 0000:01:00.1 --driver nvidia-open --late-bind
sudo bash scripts/gpupt bind rtx5090
sudo bash scripts/gpupt start rtx5090
```

---

## AMD RDNA 4 (RX 9070 Series) Passthrough

AMD RDNA 4 (Navi 48) GPUs are the first consumer AMD cards that **require** late binding for clean passthrough.

> **Full guide:** See [`docs/RDNA4.md`](docs/RDNA4.md) for the complete walkthrough. This section is the summary.

### Key Requirements

1. **Late binding is mandatory.** The `amdgpu` driver must initialize the GPU firmware and PCIe topology before vfio-pci can claim it. Do not add RDNA 4 IDs to `vfio-pci.ids` at boot.

2. **`vendor-reset` kernel module required.** After the VM shuts down, the GPU needs a proper reset sequence that the default VFIO reset doesn't handle. The `vendor-reset` module provides this.

3. **`<rom bar='off'/>` on both hostdevs.** The RDNA 4 firmware has issues with ROM BAR access through VFIO. Add `<rom bar='off'/>` to both the VGA and audio `<hostdev>` entries in the VM XML.

4. **Guest kernel 6.8+ recommended.** Running an older kernel inside the guest (especially Linux guests) can result in 800x600 display only. Windows guests are generally fine.

### Confirmed Vendor:Device IDs

| GPU | VGA ID | Audio ID |
|-----|--------|----------|
| RX 9070 XT | `1002:7550` | `1002:ab28` |
| RX 9070 | `1002:7550` | `1002:ab28` |
| RX 9070 GRE | `1002:7550` | `1002:ab28` |

### Quick Setup

```bash
# Install vendor-reset
git clone https://github.com/gnif/vendor-reset.git
cd vendor-reset
make && sudo make install

# Use gpupt
bash scripts/gpupt profile add rx9070xt --vm win11-gpu \
    --gpu 0000:01:00.0 --audio 0000:01:00.1 --driver amdgpu --late-bind
sudo bash scripts/gpupt bind rx9070xt
sudo bash scripts/gpupt start rx9070xt
```

---

## Intel Arc GPU Passthrough

Intel Arc GPUs (Alchemist DG2 and Battlemage) can be passed through to VMs with some caveats.

> **Full guide:** See [`docs/INTEL_ARC.md`](docs/INTEL_ARC.md).

### Key Notes

- **CPUID spoofing** may be required to avoid Code 43 errors in Windows guests. You can spoof the CPUID by adding `-cpu host,migratable=on,host-phys-bits=true` to the QEMU command line.
- **Open kernel modules (i915/xe)** recommended on the host for clean unbinding.
- Intel Arc A310 has been confirmed working with passthrough and promoted from validation to production status.
- Battlemage (B-series) support is in active development.

---

## Additional Guides (docs/)

This repository is more than a single walkthrough. Specialized guides live in `docs/`:

| Guide | Covers |
|-------|--------|
| [GUIDE.md](docs/GUIDE.md) | The step-by-step setup, start to finish |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the QEMU/KVM/VFIO/IOMMU stack actually fits together |
| [PERFORMANCE.md](docs/PERFORMANCE.md) | CPU pinning, huge pages, iothreads, IRQ tuning, benchmarking |
| [GAMING_OPTIMIZATIONS.md](docs/GAMING_OPTIMIZATIONS.md) | Gaming-focused host/guest tweaks, NVIDIA/AMD settings, anti-cheat notes |
| [BLACKWELL.md](docs/BLACKWELL.md) | NVIDIA Blackwell (RTX 50-series) passthrough guide, GSP firmware, open modules |
| [RDNA4.md](docs/RDNA4.md) | AMD RDNA 4 (RX 9070) passthrough guide, vendor-reset, ROM BAR quirk |
| [INTEL_ARC.md](docs/INTEL_ARC.md) | Intel Arc GPU passthrough guide, CPUID spoofing |
| [NOVA_DRIVER.md](docs/NOVA_DRIVER.md) | NVIDIA Nova open-source upstream driver status and guidance |
| [LINUX_GUESTS.md](docs/LINUX_GUESTS.md) | Running Linux (not Windows) inside the VM, virtiofs, Wayland |
| [INPUT_PASSTHROUGH.md](docs/INPUT_PASSTHROUGH.md) | Direct keyboard/mouse via evdev hooks or USB controllers |
| [USB_PASSTHROUGH.md](docs/USB_PASSTHROUGH.md) | USB redirection vs full controller passthrough, VR, DACs |
| [AUDIO.md](docs/AUDIO.md) | HDMI audio, SPICE, PipeWire, Scream network audio, microphones |
| [STORAGE.md](docs/STORAGE.md) | qcow2 vs raw, disk buses, cache modes, snapshots |
| [NETWORKING.md](docs/NETWORKING.md) | NAT, bridging, macvtap, VirtIO multi-queue, firewalls |
| [REMOTE_ACCESS.md](docs/REMOTE_ACCESS.md) | Looking Glass B6/B7, Sunshine/Moonlight, Parsec, RDP, SPICE |
| [HOST_GPU.md](docs/HOST_GPU.md) | Keeping a working display (iGPU, second GPU, headless) while your GPU is in the VM |
| [HARDWARE_DATABASE.md](docs/HARDWARE_DATABASE.md) | CPU/GPU/motherboard compatibility and known issues |
| [SECURITY.md](docs/SECURITY.md) | ACS override risks, SELinux/AppArmor, guest isolation |
| [UPGRADING.md](docs/UPGRADING.md) | Surviving kernel, distro, BIOS, and driver updates |
| [SNAPSHOTS_BACKUPS.md](docs/SNAPSHOTS_BACKUPS.md) | Live backups, snapshots, restore procedures |
| [GLOSSARY.md](docs/GLOSSARY.md) | Every acronym and term explained |
| [FAQ.md](docs/FAQ.md) | Frequently asked questions |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Extended troubleshooting reference |
| [MANAGEMENT.md](docs/MANAGEMENT.md) | Operating VMs & GPUs with `vmctl.sh`, `gpu_recovery.sh`, and the Makefile |
| [GPUPT.md](docs/GPUPT.md) | The `gpupt` CLI: profiles, bind/unbind, start/stop, hooks, recovery |

---

## Scripts

This repository includes helper scripts for common tasks:

| Script | Purpose |
|--------|---------|
| `scripts/detect_gpu.sh` | Detects GPUs and displays vendor:device IDs |
| `scripts/check_iommu_groups.sh` | Lists all IOMMU groups and their devices |
| `scripts/check_vfio_binding.sh` | Verifies the GPU is bound to vfio-pci |
| `scripts/status_check.sh` | One-command health check of the whole setup |
| `scripts/setup_vfio.sh` | Interactive VFIO setup (`--late-bind` for AMD RDNA 4, `--blackwell` for RTX 50-series) |
| `scripts/bind_vfio.sh` | Manually binds/unbinds GPU to VFIO (single-GPU or late binding) |
| `scripts/install_packages.sh` | Installs all required virtualization packages |
| `scripts/generate_vm_xml.sh` | Generates a starter VM XML with optimal settings |
| `scripts/create_disk.sh` | Creates qcow2/raw VM disk images |
| `scripts/download_virtio.sh` | Downloads the latest virtio-win drivers ISO |
| `scripts/start_vm.sh` | Starts a VM, optionally binding the GPU first |
| `scripts/stop_vm.sh` | Stops a VM, optionally rebinding the GPU to the host |
| `scripts/setup_hugepages.sh` | Configures huge pages (host + VM XML) |
| `scripts/backup_vm.sh` | Full VM backup (disk + XML + NVRAM) |
| `scripts/restore_vm.sh` | Restores a VM from a backup |
| `scripts/snapshot_vm.sh` | Create/list/revert/delete VM snapshots |
| `scripts/collect_info.sh` | Dumps all diagnostics for a support thread |
| `scripts/vmctl.sh` | Unified VM lifecycle + GPU controller (`status`, `start`, `stop`, `reboot`, `attach-gpu`, `detach-gpu`, `info`) |
| `scripts/gpu_recovery.sh` | Recovers a stuck GPU after a VM crash (force-unbind + PCI reset + rebind); handles Blackwell WPR2 |
| `scripts/gpupt` | One-command CLI for the whole workflow (`doctor`, `detect`, `profile`, `bind`/`unbind`, `start`/`stop`, `hooks`, `recover`, `log`) |

All scripts require root privileges where noted. Run with `sudo bash scripts/<script>.sh`.

---

## Management Tools

Tired of remembering which script does what? The repo ships a few higher-level
tools so you can drive everything with one command.

### `vmctl.sh` — unified VM controller

One entrypoint for the full VM + GPU lifecycle, building on the helpers above:

```bash
# Show status, start, stop, reboot
sudo bash scripts/vmctl.sh status
sudo bash scripts/vmctl.sh start win11-gpu 0000:01:00.0 0000:01:00.1
sudo bash scripts/vmctl.sh stop  win11-gpu 0000:01:00.0 0000:01:00.1 amdgpu
sudo bash scripts/vmctl.sh reboot win11-gpu
sudo bash scripts/vmctl.sh info win11-gpu     # state + XML + GPU + display

# Attach/detach a GPU without restarting the whole VM workflow
sudo bash scripts/vmctl.sh attach-gpu win11-gpu 0000:01:00.0 0000:01:00.1
sudo bash scripts/vmctl.sh detach-gpu win11-gpu 0000:01:00.0 0000:01:00.1 nvidia
```

| Command | What it does |
|---------|--------------|
| `status` | `virsh list --all` |
| `start NAME [GPU AUDIO [VID:DEV...]]` | Delegates to `start_vm.sh` (binds GPU first) |
| `stop NAME [GPU AUDIO [DRIVER]]` | Delegates to `stop_vm.sh` (rebinds GPU after) |
| `reboot` / `shutdown` / `poweroff` | `virsh` wrapper (graceful → forced as needed) |
| `suspend` / `resume` | `virsh` suspend/resume |
| `attach-gpu NAME GPU [AUDIO]` | Bind a GPU to vfio-pci for a defined VM |
| `detach-gpu NAME GPU [AUDIO] [DRIVER]` | Rebind a GPU to the host |
| `info NAME` | State, vCPU pinning, attached PCI, display URL |

### `gpu_recovery.sh` — stuck GPU after a VM crash

After a hard `virsh destroy` or a guest crash, the GPU sometimes stays wedged
on `vfio-pci` and the host never gets its display back. This forces an unbind,
fires the kernel PCI reset quirk, then hands off to `bind_vfio.sh` to rebind the
host driver:

```bash
sudo bash scripts/gpu_recovery.sh 0000:01:00.0 0000:01:00.1 nvidia
```

> **Blackwell users:** This script now detects the WPR2 reset bug and will suggest a host reboot if the FLR fails.

The full reference for these tools lives in [`docs/MANAGEMENT.md`](docs/MANAGEMENT.md).

### `gpupt` — one command for everything

`scripts/gpupt` is a profile-driven CLI that replaces the manual sequence of
"detect → bind → start → stop → rebind" with short commands. Profiles are stored
in `/etc/gpupt/config` (see [`docs/GPUPT.md`](docs/GPUPT.md)); the interactive
wizard and `--dry-run` make it safe to explore before it touches anything:

```bash
bash scripts/gpupt doctor                          # full health check, exit codes for scripts

# Blackwell profile
bash scripts/gpupt profile add rtx5090 --vm win11-gpu \
    --gpu 0000:01:00.0 --audio 0000:01:00.1 --driver nvidia-open --late-bind

# RDNA 4 profile
bash scripts/gpupt profile add rx9070xt --vm win11-gpu \
    --gpu 0000:01:00.0 --audio 0000:01:00.1 --driver amdgpu --late-bind

bash scripts/gpupt profile list
bash scripts/gpupt bind rtx5090 --dry-run         # preview before it stops the display manager
sudo bash scripts/gpupt bind rtx5090              # stop DM + hand GPU to vfio-pci
sudo bash scripts/gpupt start rtx5090
sudo bash scripts/gpupt stop rtx5090
sudo bash scripts/gpupt unbind rtx5090            # restore host driver + restart DM
sudo bash scripts/gpupt hooks install             # generate the libvirt qemu hook
bash scripts/gpupt status
```

| Command | What it does |
|---------|--------------|
| `doctor [--json]` | Health check with hints (exit 0 ok / 1 warn / 2 fail) |
| `detect`, `groups [PCI...]` | GPUs, IDs, drivers, IOMMU groups |
| `status [PROFILE]` | VMs, GPUs, and configured profiles in one view |
| `profile add/show/edit/rm/list` | Manage GPU profiles (wizard or CLI flags) |
| `bind [PROFILE\|PCI...] [--dry-run]` | Stop DM and bind GPU to vfio-pci (`--no-dm` to skip) |
| `unbind [PROFILE\|PCI...] [--dry-run]` | Rebind the host driver and restart the DM |
| `start PROFILE [--no-bind]` / `stop PROFILE` | Start/stop the VM around the profile's GPU |
| `hooks install/remove/status` | Generate/remove the libvirt `qemu` hook |
| `recover GPU [AUDIO] [DRIVER]` | Force-unbind + PCI reset + rebind a stuck GPU |
| `log [N]`, `config show`, `complete` | Logs, configuration, shell completion |

The full `gpupt` reference lives in [`docs/GPUPT.md`](docs/GPUPT.md).

---

## Single-GPU Passthrough

Single-GPU passthrough is an advanced setup where the same GPU is used for the host desktop and the VM. The GPU is unbound from the host driver, passed to the VM, and recovered when the VM shuts down.

**This is significantly more complex than dual-GPU passthrough.**

> **NVIDIA Blackwell note:** Single-GPU passthrough with RTX 50-series adds the WPR2 reset bug to the mix. If the GPU doesn't recover after VM shutdown, you will need to reboot the host. The `vendor-reset` module helps but is not a guaranteed fix for Blackwell yet.

> **AMD RDNA 4 note:** Single-GPU passthrough with RX 9070 already does dynamic unbind/bind via `bind_vfio.sh`, which naturally satisfies the requirement of letting `amdgpu` initialize the card first. Install `vendor-reset` for clean recovery.

### Requirements

- A display manager that can be stopped and restarted cleanly
- A script to handle GPU rebinding (use `scripts/bind_vfio.sh`)
- A fallback console (SSH access) in case the host display does not recover

### Process Overview

1. Stop the display manager (GDM, SDDM, LightDM)
2. Unload the host GPU driver (nvidia, amdgpu, nouveau)
3. Unbind the GPU from the host driver
4. Bind the GPU to vfio-pci
5. Start the VM
6. On VM shutdown: reverse the process

### Using the bind script

```bash
# Before starting the VM
sudo bash scripts/bind_vfio.sh unbind 0000:01:00.0 0000:01:00.1

# After VM shutdown
sudo bash scripts/bind_vfio.sh rebind 0000:01:00.0 0000:01:00.1
```

### Libvirt hooks

You can automate this with libvirt hooks in `/etc/libvirt/hooks/`:

```bash
# /etc/libvirt/hooks/qemu
#!/bin/bash

VM_NAME="win11-gpu"
GPU_ADDR="0000:01:00.0"
GPU_AUDIO="0000:01:00.1"

case "$1" in
  "$VM_NAME")
    case "$2" in
      prepare)
        systemctl stop display-manager
        modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia
        # Do NOT modprobe -r amdgpu for AMD passthrough GPUs —
        # let amdgpu init the card, then just unbind
        echo "$GPU_ADDR" > /sys/bus/pci/devices/$GPU_ADDR/driver/unbind 2>/dev/null
        echo "$GPU_AUDIO" > /sys/bus/pci/devices/$GPU_AUDIO/driver/unbind 2>/dev/null
        echo "10de 28a2" > /sys/bus/pci/drivers/vfio-pci/new_id
        echo "10de 22e9" > /sys/bus/pci/drivers/vfio-pci/new_id
        ;;
      stopped)
        echo "$GPU_ADDR" > /sys/bus/pci/devices/$GPU_ADDR/driver/unbind 2>/dev/null
        echo "$GPU_AUDIO" > /sys/bus/pci/devices/$GPU_AUDIO/driver/unbind 2>/dev/null
        modprobe -r vfio-pci
        modprobe -i nvidia
        systemctl start display-manager
        ;;
    esac
    ;;
esac
```

> **Always test with SSH access enabled.** If the display manager fails to restart, SSH is your only way back in.

---

## Troubleshooting

Common issues and quick fixes are listed below. For the full troubleshooting reference (with diagnosis commands, per-symptom tables, and extended workarounds), see [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

| Issue | Quick Fix | Details |
|-------|-----------|---------|
| VM fails to start | Rebuild initramfs, verify VFIO IDs | Full guide in [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#vm-does-not-start) |
| Black screen after GPU driver install | Connect monitor to passthrough GPU or use remote access | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#black-screen-after-driver-install) |
| NVIDIA Error Code 43 | Add `<kvm><hidden state='on'/></kvm>` and `<vendor_id>` to VM XML | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#nvidia-error-code-43) |
| NVIDIA RmInitAdapter error (Blackwell/Ada) | Install open kernel modules (`nvidia-open`) | [BLACKWELL.md](docs/BLACKWELL.md) |
| GPU stuck after VM shutdown (reset bug) | Reboot host, or install `vendor-reset` kernel module | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#gpu-does-not-reset) |
| Blackwell WPR2 reset bug | Host reboot (short-term), `vendor-reset` (long-term) | [BLACKWELL.md](docs/BLACKWELL.md#wpr2-reset-bug) |
| GPU bound to host driver after reboot | Verify kernel params, rebuild initramfs and bootloader | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#gpu-bound-to-host-after-reboot) |
| VM is slow or stuttering | Set CPU governor to `performance`, pin vCPUs, disable balloon | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#vm-is-slow-or-stuttering) |
| Windows BSOD during install | Use correct VirtIO driver, reduce vCPUs temporarily | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#bsod-during-installation) |
| `vfio: failed to set up container` | Load modules: `modprobe vfio vfio_pci vfio_iommu_type1` | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#vfio-module-errors) |
| IOMMU not enabled | Enable VT-d/AMD-Vi in BIOS, add kernel parameters | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#iommu-not-enabled) |
| Bad IOMMU groups | Move GPU to different slot, enable ACS, update BIOS | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#bad-iommu-groups) |
| Guest display flickering | Remove or disable virtual video device | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#guest-display-flickering) |
| RDNA 4 800x600 display only | Use kernel 6.8+ inside the Linux guest | [RDNA4.md](docs/RDNA4.md) |
| RDNA 4 VM crashes on start | Add `<rom bar='off'/>` to both hostdev entries | [RDNA4.md](docs/RDNA4.md) |
| Intel Arc Code 43 | CPUID spoofing required | [INTEL_ARC.md](docs/INTEL_ARC.md) |

---

## FAQ

Common questions and answers. For the full FAQ, see [`docs/FAQ.md`](docs/FAQ.md).

**Q: Can I pass through an NVIDIA RTX 5090/5080?**
A: Yes. You need the open kernel modules (`nvidia-open`), late binding (do not add IDs to `vfio-pci.ids` at boot), and should be aware of the WPR2 reset bug. See [`docs/BLACKWELL.md`](docs/BLACKWELL.md).

**Q: Can I pass through an AMD RX 9070/9070 XT?**
A: Yes. Late binding is mandatory (`amdgpu` must initialize first), `vendor-reset` is needed for clean GPU reset, and you need `<rom bar='off'/>` in the VM XML. See [`docs/RDNA4.md`](docs/RDNA4.md).

**Q: Do I need `amd_iommu=on` in my kernel parameters?**
A: No. That parameter is a no-op on modern kernels (6.x+). The AMD IOMMU enables itself when AMD-Vi is on in the BIOS. See [`docs/FAQ.md`](docs/FAQ.md#iommu-parameters).

**Q: Which NVIDIA driver version should I use in the VM?**
A: For Blackwell/Ada, use the R580 or R595 branch with the open kernel module variant. For Turing and older, any recent driver works. If you hit Code 43, try an older version first.

**Q: What about the NVIDIA Nova driver?**
A: Nova is NVIDIA's open-source upstream kernel driver for GSP-based GPUs. NVIDIA posted a vGPU Manager and VFIO variant driver for Nova in September 2026. It's promising but not yet recommended for production VFIO passthrough. See [`docs/NOVA_DRIVER.md`](docs/NOVA_DRIVER.md).

**Q: Does Looking Glass work with Blackwell/RDNA 4?**
A: Yes. Use the B6 or B7 release with the KVMFR kernel module for best performance. B7's D12 capture uses the GPU's hardware copy engine, so even iGPU hosts get good results.

**Q: Is single-GPU passthrough still a thing in 2026?**
A: Yes, but it's harder with new hardware. Blackwell has the WPR2 reset bug, RDNA 4 needs vendor-reset. Always keep SSH access available.

**Q: What kernel version do I need?**
A: Minimum 6.12. This gives you PREEMPT_RT, VirtIO Vsock improvements, and fixes for AMD Ryzen random reboots during virtualization. For best Blackwell/RDNA 4 support, use 6.14+ or 7.x.

**Q: I have an Intel Arc GPU. Can I pass it through?**
A: Yes, with CPUID spoofing. See [`docs/INTEL_ARC.md`](docs/INTEL_ARC.md).

---

## Repository Structure

```
GPU-Passthrough-for-KVM-QEMU-on-Linux/
├── README.md                    # This file
├── CONTRIBUTING.md              # How to contribute
├── LICENSE                      # MIT license
├── Makefile                     # Make targets (make status, make vm-start, etc.)
├── install.sh                   # Quick installer
├── setup/
│   ├── debian.sh               # Debian/Ubuntu setup
│   ├── arch.sh                 # Arch Linux setup
│   ├── fedora.sh               # Fedora setup
│   └── opensuse.sh             # openSUSE setup
├── scripts/
│   ├── gpupt                   # Main CLI tool (profile-driven)
│   ├── vmctl.sh                # Unified VM lifecycle controller
│   ├── gpu_recovery.sh         # Stuck GPU recovery
│   ├── status_check.sh         # Health check
│   ├── setup_vfio.sh           # Interactive VFIO setup
│   ├── detect_gpu.sh           # GPU detection
│   ├── check_iommu_groups.sh   # IOMMU group inspection
│   ├── check_vfio_binding.sh   # VFIO binding verification
│   ├── bind_vfio.sh            # Manual VFIO bind/unbind
│   ├── install_packages.sh     # Package installation
│   ├── generate_vm_xml.sh      # VM XML generator
│   ├── create_disk.sh          # VM disk creation
│   ├── download_virtio.sh      # VirtIO ISO download
│   ├── start_vm.sh             # VM start with GPU binding
│   ├── stop_vm.sh              # VM stop with GPU rebinding
│   ├── setup_hugepages.sh      # Huge pages configuration
│   ├── backup_vm.sh            # VM backup
│   ├── restore_vm.sh           # VM restore
│   ├── snapshot_vm.sh          # VM snapshots
│   └── collect_info.sh         # Diagnostic dump
├── examples/
│   ├── xml/                    # Ready-to-use XML snippets
│   ├── systemd/                # Systemd units
│   └── hooks/                  # Libvirt hooks
├── docs/
│   ├── GUIDE.md                # Full step-by-step guide
│   ├── ARCHITECTURE.md         # QEMU/KVM/VFIO/IOMMU stack
│   ├── PERFORMANCE.md          # Performance tuning
│   ├── GAMING_OPTIMIZATIONS.md # Gaming-specific tweaks
│   ├── BLACKWELL.md            # NVIDIA Blackwell (RTX 50) guide
│   ├── RDNA4.md                # AMD RDNA 4 (RX 9070) guide
│   ├── INTEL_ARC.md            # Intel Arc guide
│   ├── NOVA_DRIVER.md          # NVIDIA Nova driver status
│   ├── LINUX_GUESTS.md         # Linux guest setup
│   ├── INPUT_PASSTHROUGH.md    # Keyboard/mouse passthrough
│   ├── USB_PASSTHROUGH.md      # USB passthrough
│   ├── AUDIO.md                # Audio setup
│   ├── STORAGE.md              # Storage configuration
│   ├── NETWORKING.md           # Network setup
│   ├── REMOTE_ACCESS.md        # Remote display (LG, Sunshine, etc.)
│   ├── HOST_GPU.md             # Host GPU management
│   ├── HARDWARE_DATABASE.md    # Compatibility database
│   ├── SECURITY.md             # Security considerations
│   ├── UPGRADING.md            # Upgrade survival guide
│   ├── SNAPSHOTS_BACKUPS.md    # Snapshots and backups
│   ├── GLOSSARY.md             # Terms and acronyms
│   ├── FAQ.md                  # Frequently asked questions
│   ├── TROUBLESHOOTING.md      # Extended troubleshooting
│   ├── MANAGEMENT.md           # vmctl.sh, gpu_recovery.sh reference
│   └── GPUPT.md                # gpupt CLI reference
└── .github/
    └── workflows/
        └── shellcheck.yml      # CI linting
```

---

## Contributing

Contributions are welcome. Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Before submitting a PR:
1. Run `shellcheck` on any scripts you modified (the CI will catch it anyway)
2. Test your changes on real hardware if possible
3. If you are adding support for a new GPU, include the vendor:device IDs and any quirks you discovered

---

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.
