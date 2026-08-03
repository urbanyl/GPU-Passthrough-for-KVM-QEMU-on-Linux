# Frequently Asked Questions

The usual questions. If yours isn't here, check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) and the specialized docs linked in the [README](../README.md#additional-guides-docs) — and if you still can't find it, open an issue. Someone else has probably hit the same wall.

---

## General

### What is GPU passthrough?

GPU passthrough is a virtualization technique that allows a virtual machine to directly control a physical GPU. The Linux host isolates the GPU using IOMMU (VT-d/AMD-Vi) and assigns it to the VM via the VFIO driver. The VM then uses the GPU as if it were installed directly on bare metal, with near-native performance.

### Does this work with any Linux distribution?

Yes. Any distribution that supports KVM, libvirt, and QEMU will work. This guide includes distribution-specific instructions for Debian/Ubuntu, Arch Linux, and Fedora. The underlying mechanism (VFIO) is a kernel feature, not a distribution feature.

### What Windows versions are supported?

Windows 10 and Windows 11 are tested and supported. Windows 7 and 8.1 may work but are not tested. Windows 11 requires TPM 2.0, which can be emulated in the VM.

### Can I use this for production workloads?

Yes. GPU passthrough is used in data centers for GPU-accelerated compute. For desktop use, it provides near-native performance for gaming, 3D rendering, video editing, and machine learning workloads.

---

## Hardware

### Can I use single-GPU passthrough?

Yes, but it is significantly more complex. You need scripts to stop the display manager, unbind the GPU from the host, and recover the host display after the VM shuts down. See the [Single-GPU Passthrough](../README.md#single-gpu-passthrough) section in the main guide.

### Which GPU should I buy?

**NVIDIA:**
- RTX 30 series and newer: Generally well-supported
- GTX 10 series: Supported with Error 43 workaround
- RTX 40 series: Good support, check specific model reports

**AMD:**
- RX 9000 series: Supported with dynamic binding (see [AMD GPU Dynamic Binding](../README.md#6a-amd-gpu-dynamic-binding-late-binding) in the main guide — requires amdgpu to init the card first, then late-bind to vfio-pci)
- RX 6000/7000 series: Well-supported; dynamic binding recommended for proper ReBAR setup
- RX 5000 series (RDNA 1): Supported, some reset issues
- RX 500 series (Polaris): Known reset issues on some models

Check [r/VFIO](https://reddit.com/r/vfio) for reports on your specific GPU model before purchasing.

### Does the CPU matter?

Yes. You need:
- **Intel:** VT-x (CPU virtualization) + VT-d (IOMMU) -- available on most modern Intel CPUs, but VT-d is typically only on Core i5+ and Xeon
- **AMD:** AMD-V (CPU virtualization) + AMD-Vi (IOMMU) -- available on all Ryzen CPUs

### Do I need two GPUs?

Two GPUs are strongly recommended. One GPU runs the Linux host desktop, the other is passed through to the VM. Single-GPU passthrough works but is fragile and requires manual intervention on every VM start/stop.

### Do I need dynamic binding for my AMD GPU?

**RX 9000 series:** Yes, required. These GPUs must be initialized by `amdgpu` during boot, then dynamically unbound and bound to `vfio-pci` just before the VM starts. Binding directly to `vfio-pci` at boot will leave the GPU uninitialized and break the VM.

**RX 6000 / 7000 series:** Not required, but recommended. When `amdgpu` initializes the card, it configures Resizable BAR (ReBAR) in a way that is safe for VFIO. This can improve guest GPU performance.

See [§6a in the main guide](../README.md#6a-amd-gpu-dynamic-binding-late-binding) for setup instructions.

### Does motherboard model matter?

Significantly. The motherboard determines:
- IOMMU group quality
- BIOS feature availability (VT-d, ACS, Above 4G Decoding)
- PCIe slot layout and bandwidth

Before buying a motherboard, check [r/VFIO](https://reddit.com/r/vfio) or [Level1Techs forums](https://forums.level1techs.com) for reports on IOMMU grouping for that specific model.

---

## Setup

### What does IOMMU do?

IOMMU (I/O Memory Management Unit) isolates PCI devices into groups and allows the host to remap device DMA access. This is what makes it safe to assign a GPU to a VM -- the GPU can only access memory assigned to it, not the host's memory.

### What is the ACS override patch?

ACS (Access Control Services) is a PCIe feature that allows finer-grained IOMMU group separation. Some motherboards do not implement ACS properly, resulting in large IOMMU groups that include unrelated devices. The ACS override patch modifies the kernel to artificially separate these groups. It is a workaround with potential security implications.

### What is VFIO?

VFIO (Virtual Function I/O) is a kernel framework that provides safe, IOMMU-protected access to hardware devices. The `vfio-pci` driver binds to the GPU and allows the VM to take full control of it.

### What is OVMF?

OVMF (Open Virtual Machine Firmware) is an open-source UEFI firmware for QEMU/KVM virtual machines. It provides the UEFI boot environment that Windows 10/11 requires.

### What are VirtIO drivers?

VirtIO drivers are paravirtualized drivers that allow the VM to communicate efficiently with the hypervisor. They provide high-performance storage, networking, and memory ballooning without the overhead of full hardware emulation.

---

## Performance

### Why is my VM slower than expected?

Work through [PERFORMANCE.md](PERFORMANCE.md) in order. The usual suspects are, in order of impact:
1. CPU governor not set to `performance`
2. No CPU pinning (`cputune`) and no core isolation (`isolcpus`)
3. Memory ballooning still active
4. Disk on emulated SATA/IDE instead of VirtIO, or `cache` set to `writeback`
5. Missing huge pages

### What is the fastest disk setup?

VirtIO (or NVMe emulation) backed by an NVMe SSD, with `cache='none' io='native' discard='unmap'`, plus iothreads for multiple disks. See [STORAGE.md](STORAGE.md).

### How much does networking affect games?

NAT adds a small amount of latency. For competitive gaming, use a bridge or macvtap and enable VirtIO multi-queue. See [NETWORKING.md](NETWORKING.md).

### How do I measure latency in the guest?

`LatencyMon` (Windows) and `PresentMon` for frame times. Aim for < 1 ms DPC latency and smooth frame pacing. See [GAMING_OPTIMIZATIONS.md](GAMING_OPTIMIZATIONS.md).

### How much performance do I lose?

With proper configuration:
- **GPU:** 2-5% overhead compared to bare metal
- **CPU:** Negligible with CPU pinning
- **Storage:** Negligible with VirtIO and NVMe backing
- **Network:** Negligible with VirtIO networking

### What is CPU pinning?

CPU pinning assigns specific VM virtual CPUs to specific physical CPU cores. This prevents the host scheduler from moving VM processes around, reducing cache thrashing and latency. It is one of the most impactful performance optimizations for passthrough VMs.

### What are huge pages?

Huge pages are memory pages larger than the default 4KB (typically 2MB or 1GB). They reduce TLB misses and page table overhead. For a passthrough VM, 2MB huge pages provide a measurable improvement in memory-intensive workloads.

### Should I disable hyperthreading?

It depends. If the host and VM share physical cores via hyperthreading, there can be resource contention. For maximum VM performance, consider:
- Pinning vCPUs to physical cores (not hyperthreads)
- Using `isolcpus` to prevent host tasks on VM cores
- Disabling SMT on cores dedicated to the VM

---

## Troubleshooting

### Why does NVIDIA show Error 43?

NVIDIA consumer GPUs (GeForce series) have a driver-level check that detects virtualization and refuses to initialize. The workaround involves hiding the VM environment from the guest using KVM hidden state and a custom Hyper-V vendor ID. See the [Troubleshooting guide](TROUBLESHOOTING.md#nvidia-error-code-43).

### Why does my GPU not reset after VM shutdown?

Some GPUs do not properly implement Function Level Reset (FLR). When the VM shuts down, the GPU remains in an indeterminate state and cannot be re-initialized without a host reboot. This is a hardware/driver limitation. Check the [VFIO GPU Reset Wiki](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#GPU_does_not_reset) for your specific model.

### Why are my IOMMU groups bad?

Poor IOMMU grouping is a motherboard firmware issue. The motherboard's ACPI/IOMMU tables determine how devices are grouped. Solutions include:
1. Moving the GPU to a different slot
2. Updating the BIOS
3. Enabling ACS in BIOS
4. Using the ACS override patch
5. Getting a different motherboard

### Can I use a USB-C GPU port for passthrough?

Some USB-C ports on GPUs are separate PCIe functions. You need to identify and pass through all GPU functions including the USB-C controller. Check your IOMMU groups to see if the USB-C function is in the same group as the GPU.

---

## Advanced

### Can I run a Linux guest instead of Windows?

Yes. Linux guests need no `kvm=hidden` or `vendor_id` workaround. Use virtiofs for shared folders and the guest's native drivers. See [LINUX_GUESTS.md](LINUX_GUESTS.md).

### How do I back up my VM?

Export the XML with `virsh dumpxml`, copy the disk image, and keep the NVRAM. Use `scripts/backup_vm.sh`. For zero-downtime backups use external snapshots + blockcommit. See [SNAPSHOTS_BACKUPS.md](SNAPSHOTS_BACKUPS.md).

### Is GPU passthrough safe?

The IOMMU restricts what the passed GPU can access, but the guest effectively owns the hardware. Treat the guest as a semi-trusted machine, keep SELinux/AppArmor on, and understand the ACS override trade-off. See [SECURITY.md](SECURITY.md).

### How do I keep the setup working after a kernel update?

Rebuild the initramfs after every kernel upgrade and re-verify binding with `scripts/check_vfio_binding.sh`. See [UPGRADING.md](UPGRADING.md).

### How do I pass my keyboard and mouse directly to the guest?

Use evdev hooks or pass a whole USB controller. See [INPUT_PASSTHROUGH.md](INPUT_PASSTHROUGH.md).

### Can I pass through multiple GPUs?

Yes. Each GPU needs to be in its own IOMMU group and bound to vfio-pci. Add each GPU's PCI addresses to the VFIO IDs and the VM XML.

### Can I use GPU passthrough with Docker?

KVM/QEMU runs at the kernel level and is independent of Docker. You can manage libvirt VMs from within a Docker container, but the VM itself runs outside of Docker.

### Can I share a GPU between host and guest?

Not simultaneously. GPU passthrough is exclusive -- the GPU is either controlled by the host or the VM. You can switch between them (single-GPU passthrough), but the GPU cannot be used by both at the same time.

### What is SR-IOV?

SR-IOV (Single Root I/O Virtualization) allows a single physical GPU to present as multiple virtual GPUs. Only a few GPUs support this (notably some Intel and AMD professional cards). For consumer GPUs, traditional passthrough is the standard approach.

### Can I use this with Wayland on the host?

Yes. Wayland compositors work with passthrough setups. The host GPU runs the Wayland session, and the passthrough GPU is entirely assigned to the VM. No special configuration is needed beyond what this guide covers.
