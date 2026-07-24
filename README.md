<p align="center">
  <strong>The Complete Guide to GPU Passthrough for KVM/QEMU on Linux</strong><br>
  <em>Run Windows with near-native GPU performance on a Linux host</em>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/platform-Linux-blue.svg" alt="Platform: Linux">
  <img src="https://img.shields.io/badge/VM-Windows_10%2F11-0078d4.svg" alt="Guest: Windows 10/11">
  <img src="https://img.shields.io/badge/GPU-NVIDIA%20%7C%20AMD-76b900.svg" alt="GPU: NVIDIA | AMD">
  <img src="https://img.shields.io/badge/kernel-5.15+-orange.svg" alt="Kernel: 5.15+">
  <img src="https://img.shields.io/badge/contributions-welcome-brightgreen.svg" alt="Contributions Welcome">
  <img src="https://img.shields.io/badge/version-2.0.0-blue.svg" alt="Version 2.0.0">
</p>

<details>
<summary><strong>Changelog — v2.0.0 (July 2026)</strong></summary>

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
  - [7. Verify VFIO Binding](#7-verify-vfio-binding)
  - [8. Install Virtualization Packages](#8-install-virtualization-packages)
  - [9. Create the Virtual Machine](#9-create-the-virtual-machine)
  - [10. Optimize the VM Configuration](#10-optimize-the-vm-configuration)
  - [11. Install Windows](#11-install-windows)
  - [12. Install GPU Drivers in the Guest](#12-install-gpu-drivers-in-the-guest)
  - [13. Set Up Remote Display Access](#13-set-up-remote-display-access)
  - [14. Performance Tuning](#14-performance-tuning)
- [Scripts](#scripts)
- [Single-GPU Passthrough](#single-gpu-passthrough)
- [Troubleshooting](#troubleshooting) — see also [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)
- [FAQ](#faq) — see also [`docs/FAQ.md`](docs/FAQ.md)
- [Repository Structure](#repository-structure)
- [Contributing](#contributing)
- [License](#license)

---

## Why This Repository

GPU passthrough on Linux is well-documented across dozens of blog posts, forum threads, and wikis, but the information is scattered, often outdated, and frequently incomplete. This repository consolidates everything into a single, tested, and structured reference.

The goal is simple: give you a reproducible path from a bare Linux install to a Windows VM with full GPU acceleration, with clear recovery steps at every stage.

**This guide is for you if:**

- You want to play Windows games on Linux without dual-booting
- You need GPU-accelerated Windows applications (CAD, video editing, machine learning) on a Linux workstation
- You want to run a Windows VM for development or testing with real GPU access
- You are tired of forum posts that solve one problem but create three more

---

## What You Will End Up With

- A Linux host running its desktop on the primary/integrated GPU
- A Windows 10 or 11 VM with a dedicated GPU passed through via VFIO
- Near-native GPU performance for gaming, rendering, or compute workloads
- Remote display access via Sunshine/Moonlight, Looking Glass, or Parsec
- A system that survives reboots without manual intervention

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

### Recommended

- **CPU**: Modern quad-core or better with 8+ threads (e.g., Intel 12th gen+, AMD Ryzen 5000+)
- **RAM**: 32 GB DDR4/DDR5
- **Storage**: NVMe SSD for the VM disk
- **GPU (guest)**: NVIDIA RTX 30/40 series or AMD RX 6000/7000 series
- **GPU (host)**: Intel integrated graphics or any secondary GPU
- **Motherboard**: Known good IOMMU grouping (check the [Level1Techs forum](https://forums.level1techs.com) or [r/VFIO](https://reddit.com/r/vfio) for your specific board)

### Important Notes

**Dual-GPU is strongly recommended.** Single-GPU passthrough is possible but significantly more complex and fragile. If you attempt single-GPU passthrough, expect to troubleshoot display manager shutdown, GPU rebinding, and recovery scenarios.

**Check your motherboard's IOMMU grouping before buying hardware.** Some boards group the PCIe slots with critical host devices (USB controllers, SATA controllers), making clean passthrough impossible without ACS override.

---

## Software Requirements

| Component | Purpose |
|-----------|---------|
| **Linux kernel** | 5.15 or newer (6.x recommended for better VFIO support) |
| **QEMU/KVM** | Virtualization backend |
| **libvirt** | VM management layer |
| **virt-manager** or **virt-install** | GUI/CLI for VM creation |
| **OVMF** | UEFI firmware for the guest |
| **virtio-win** | Paravirtualized drivers for the Windows guest |
| **Windows ISO** | Windows 10 or 11 installation media |

### Supported Distributions

All instructions in this guide work on:

- **Debian** 11+ / **Ubuntu** 22.04+
- **Arch Linux** / **Manjaro**
- **Fedora** 38+
- **openSUSE Tumbleweed**

Distribution-specific differences are noted where they exist.

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
# GRUB_CMDLINE_LINUX_DEFAULT="quiet splash intel_iommu=on iommu=pt vfio-pci.ids=XXXX:XXXX,XXXX:XXXX"

# 5. Add to /etc/modprobe.d/vfio.conf:
# options vfio-pci ids=XXXX:XXXX,XXXX:XXXX

# 6. Update initramfs and reboot
sudo update-initramfs -u && sudo reboot

# 7. Verify VFIO binding
lspci -k -d $(lspci -nn | grep VGA | awk '{print $1}')

# 8. Create VM with virt-install (see Section 9 for full command)
```

**If this is your first time, follow the full step-by-step guide below.**

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
- Try adding `iommu=1` to the kernel command line

**Do not proceed until this step passes.**

---

### 3. Identify Your GPU

List all PCI devices and find your target GPU and its associated audio controller.

```bash
# List all PCI devices with vendor/device IDs
lspci -nn
```

Find lines matching your GPU. Example for an NVIDIA card:

```
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation TU106 [GeForce RTX 2070] [10de:1af2] (rev a1)
01:00.1 Audio device [0403]: NVIDIA Corporation TU106 High Definition Audio Controller [10de:1af9] (rev a1)
```

Example for an AMD card:

```
01:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 22 [Radeon RX 6700 XT] [1002:73df] (rev c3)
01:00.1 Audio device [0403]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 22 HDMI Audio [1002:ab28]
```

**Write down:**
- PCI addresses (e.g., `01:00.0` and `01:00.1`)
- Vendor IDs and device IDs (e.g., `10de:1af2` and `10de:1af9`)
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
    01:00.0 VGA compatible controller [0300]: NVIDIA Corporation TU106 [GeForce RTX 2070] [10de:1af2] (rev a1)
    01:00.1 Audio device [0403]: NVIDIA Corporation TU106 High Definition Audio Controller [10de:1af9] (rev a1)
```

**What you do NOT want to see:**

The GPU grouped with essential host devices:

```
IOMMU Group 1:
    00:01.0 PCI bridge [0604]: Intel Corporation ... [8086:15e8]
    01:00.0 VGA compatible controller [0300]: NVIDIA Corporation ... [10de:1af2]
    01:00.1 Audio device [0403]: NVIDIA Corporation ... [10de:1af9]
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

**Intel systems:**

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash intel_iommu=on iommu=pt vfio-pci.ids=10de:1af2,10de:1af9 rd.driver.pre=vfio-pci"
```

**AMD systems:**

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_iommu=on iommu=pt vfio-pci.ids=10de:1af2,10de:1af9 rd.driver.pre=vfio-pci"
```

> **Replace `10de:1af2,10de:1af9` with your actual GPU vendor:device IDs.**

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

```
options root=UUID=xxxx-xxxx rw quiet splash intel_iommu=on iommu=pt vfio-pci.ids=10de:1af2,10de:1af9 rd.driver.pre=vfio-pci
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
01:00.0 VGA compatible controller: NVIDIA Corporation TU106 [GeForce RTX 2070]
    Subsystem: ...
    Kernel driver in use: vfio-pci
    Kernel modules: nvidiafb, nouveau, nvidia_drm, nvidia
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

**NVIDIA:**

1. Download the driver from [nvidia.com/drivers](https://www.nvidia.com/drivers) inside the VM
2. Run the installer
3. If the installer complains about not finding compatible hardware:
   - Make sure KVM hidden state is enabled in the VM XML
   - Make sure the vendor_id is set in the Hyper-V enlightenments
   - Try downloading an older driver version
4. Reboot after installation

**AMD:**

1. Download the driver from [amd.com/support](https://www.amd.com/support) inside the VM
2. Run the installer
3. Reboot after installation

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

#### Looking Glass (Best for Local Use)

Looking Glass captures the guest GPU output and displays it on the host with near-zero latency.

**Host (Linux):**

```bash
# Install Looking Glass host
# Follow https://looking-glass.io/docs/Build

# The host needs a shared memory device in the VM XML:
# <shmem name='looking-glass'>
#   <model type='ivshmem-plain'/>
#   <size unit='M'>64</size>
# </shmem>
```

**Guest (Windows):**

1. Download Looking Glass client from [looking-glass.io](https://looking-glass.io)
2. Install the IVSHMEM driver if needed
3. Run `looking-glass-client.exe`

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

---

## Scripts

This repository includes helper scripts for common tasks:

| Script | Purpose |
|--------|---------|
| `scripts/detect_gpu.sh` | Detects GPUs and displays vendor:device IDs |
| `scripts/check_iommu_groups.sh` | Lists all IOMMU groups and their devices |
| `scripts/check_vfio_binding.sh` | Verifies the GPU is bound to vfio-pci |
| `scripts/bind_vfio.sh` | Manually binds/unbinds GPU to VFIO (single-GPU) |
| `scripts/install_packages.sh` | Installs all required virtualization packages |
| `scripts/generate_vm_xml.sh` | Generates a starter VM XML with optimal settings |

All scripts require root privileges where noted. Run with `sudo bash scripts/<script>.sh`.

---

## Single-GPU Passthrough

Single-GPU passthrough is an advanced setup where the same GPU is used for the host desktop and the VM. The GPU is unbound from the host driver, passed to the VM, and recovered when the VM shuts down.

**This is significantly more complex than dual-GPU passthrough.**

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
        modprobe -r amdgpu
        echo "$GPU_ADDR" > /sys/bus/pci/devices/$GPU_ADDR/driver/unbind 2>/dev/null
        echo "$GPU_AUDIO" > /sys/bus/pci/devices/$GPU_AUDIO/driver/unbind 2>/dev/null
        echo "10de 1af2" > /sys/bus/pci/drivers/vfio-pci/new_id
        echo "10de 1af9" > /sys/bus/pci/drivers/vfio-pci/new_id
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
| GPU stuck after VM shutdown (reset bug) | Reboot host, or install `vendor-reset` kernel module | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#gpu-does-not-reset) |
| GPU bound to host driver after reboot | Verify kernel params, rebuild initramfs and bootloader | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#gpu-bound-to-host-after-reboot) |
| VM is slow or stuttering | Set CPU governor to `performance`, pin vCPUs, disable balloon | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#vm-is-slow-or-stuttering) |
| Windows BSOD during install | Use correct VirtIO driver, reduce vCPUs temporarily | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#bsod-during-installation) |
| `vfio: failed to set up container` | Load modules: `modprobe vfio vfio_pci vfio_iommu_type1` | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#vfio-module-errors) |
| IOMMU not enabled | Enable VT-d/AMD-Vi in BIOS, add kernel parameters | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#iommu-not-enabled) |
| Bad IOMMU groups | Move GPU to different slot, enable ACS, update BIOS | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#bad-iommu-groups) |
| Guest display flickering | Remove or disable virtual video device | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#guest-display-flickering) |
| Network not working in guest | Install VirtIO net driver or switch to emulated NIC | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#network-not-working-in-guest) |
| USB passthrough issues | Pass through a full USB controller via PCI | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#usb-passthrough-issues) |
| Audio issues | Add user to `audio`/`pulse-access` groups | [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#audio-issues) |

---

## FAQ

For the complete FAQ, see [`docs/FAQ.md`](docs/FAQ.md).

**Highlights:**
- **Single-GPU passthrough?** Possible but complex — see the [Single-GPU Passthrough](#single-gpu-passthrough) section.
- **Which GPU to buy?** NVIDIA RTX 30/40 series and AMD RX 6000/7000 series are well-supported.
- **Do I need to pass through audio too?** Yes, include the `.1` audio function.
- **Performance overhead?** 2-5% GPU, negligible CPU/storage/network with proper tuning.
- **Secure Boot?** Generally no — disable it in BIOS.
- **Bad IOMMU groups?** Move GPU to another slot, enable ACS, update BIOS, or apply the ACS override patch.

---

## Repository Structure

```
gpu-passthrough-kvm/
|-- README.md                         # This guide
|-- LICENSE                           # MIT License
|-- CONTRIBUTING.md                   # Contribution guidelines
|-- .gitignore                        # Git ignore rules
|-- .editorconfig                     # Editor style consistency
|-- .shellcheckrc                     # ShellCheck project rules
|-- install.sh                        # Environment verification

|-- docs/
|   |-- GUIDE.md                      # Condensed quick-reference guide
|   |-- TROUBLESHOOTING.md            # Extended troubleshooting reference
|   `-- FAQ.md                        # Frequently asked questions

|-- scripts/
|   |-- detect_gpu.sh                 # GPU detection and ID listing
|   |-- check_iommu_groups.sh         # IOMMU group inspection
|   |-- check_vfio_binding.sh         # VFIO binding verification
|   |-- bind_vfio.sh                  # Manual GPU bind/unbind (single-GPU)
|   |-- install_packages.sh           # Package installation (multi-distro)
|   |-- generate_vm_xml.sh            # VM XML template generator

`-- setup/
    |-- debian-ubuntu.sh              # Debian/Ubuntu host setup
    |-- arch.sh                       # Arch Linux host setup
    `-- fedora.sh                     # Fedora host setup
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

When reporting issues, include:
- Distribution and version
- Kernel version (`uname -r`)
- CPU and GPU model
- Motherboard model and BIOS version
- Output of `lspci -nnk`
- Output of `dmesg | grep -Ei 'vfio|iommu|dmar'`
- Exact steps to reproduce the problem

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

<p align="center">
  <sub>If this guide helped you, consider giving it a star on GitHub.</sub><br>
  <sub>GPU passthrough is complex. This repository makes it manageable.</sub><br>
  <sub>Last updated: 2026</sub>
</p>
