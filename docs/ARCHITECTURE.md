# Architecture: How GPU Passthrough Actually Works

Skip this if you just want things running. Read it if you're trying to figure
out *why* something broke — half the troubleshooting battles go away once you
understand what each piece does.

## The stack, top to bottom

```
Windows/Linux guest  (drives the real GPU)
        │  PCI accesses
        ▼
QEMU (emulates a PC, forwards real PCI to the guest)
        │  ioctl
        ▼
KVM (kernel virtual machine, runs your vCPUs as native threads)
        │
        ▼
VFIO (user-space driver that maps a real PCI device into the guest)
        │  IOMMU page tables
        ▼
IOMMU (remaps DMA: the GPU can only touch memory the guest owns)
        ▼
Host Linux kernel + your real hardware
```

The GPU is **never emulated**. QEMU hands it to the guest essentially raw, and
the guest installs real NVIDIA/AMD/Intel drivers for it. That's why you get
full native performance and why the device is fully *gone* from the host.

## The three things that have to line up

### 1. IOMMU (vt-d / AMD-Vi)

The IOMMU does DMA remapping. The GPU lives on the PCI bus and does direct
memory access — without an IOMMU it would scribble on the whole host RAM.
With one, the host kernel can map only the guest's memory to the device.

- **Intel:** `intel_iommu=on iommu=pt` on the kernel cmdline
- **AMD:** `iommu=pt` (and `amd_iommu=on` only if it's somehow not already on)
- If `/sys/kernel/iommu_groups` is empty or missing, the IOMMU isn't on. Nothing
  else matters until this works.

### 2. The VFIO kernel driver

The `vfio-pci` driver replaces the GPU's normal driver on the host. This is
what makes the device available to QEMU. Two ways to get there:

- **Static** (classic): bind in modprobe.conf via vendor/device IDs before
  boot. Simple, but the GPU is taken even when you're not running the VM.
- **Dynamic** (hooks): bind only when the VM starts, unbind when it stops.
  Lets you use the GPU on the host too. Required on NVIDIA consumer cards if
  you want the GPU back after the VM exits — their reset behavior is bad.

### 3. UEFI / OVMF

Passthrough needs UEFI firmware, not SeaBIOS, and Windows 11 *requires* it.
Install `OVMF`, then in the domain XML:

```xml
<os>
  <type arch='x86_64' machine='pc-q35'>hvm</type>
  <loader readonly='yes' type='pflash'>/usr/share/OVMF/OVMF_CODE.fd</loader>
  <nvram>/var/lib/libvirt/qemu/nvram/win11_VARS.fd</nvram>
</os>
```

(That's what `scripts/generate_vm_xml.sh` produces.)

## Where the pieces live on disk

| Piece | Location |
|---|---|
| Kernel cmdline | `/etc/default/grub` or your bootloader config |
| vfio-pci static binding | `/etc/modprobe.d/vfio.conf` |
| CPU isolation | `GRUB_CMDLINE_LINUX` (`isolcpus`) |
| Hugepages | `/sys/vm/nr_hugepages` or `examples/systemd/hugepages.service` |
| libvirt hooks | `/etc/libvirt/hooks/qemu` (see `examples/libvirt-hooks/`) |
| VM XML | `/etc/libvirt/qemu/<vm>.xml` |

## The single-GPU case

With one GPU you can't run the VM and the desktop at the same time. The flow is:

1. Boot the host normally (GPU is yours).
2. Start the VM — libvirt hooks unbind the GPU from its host driver and bind
   it to `vfio-pci` first.
3. VM grabs the GPU; you lose your display (or use a second iGPU/basic console).
4. VM stops — hooks reverse it and your desktop comes back.

This is why the hooks script exists. Without hooks, a single-GPU card can also
leave the machine with a black screen on reboot (NVIDIA especially), which is
why `examples/libvirt-hooks/qemu` unbinds + rebinds `_sysfs_`.

## Why does my GPU reset sometimes (error -2 / -110)?

GPUs generally lack a clean software reset. After a VM exits, the GPU can be
left in a state the host driver can't reclaim, so the *next* boot into the VM
sometimes needs a machine reboot. This is a hardware/firmware thing, not your
config. Flashing your card's original vBIOS (`romfile=` in the hostdev) or
using `vendor-reset` for the affected AMD cards helps. See
[`docs/HARDWARE_DATABASE.md`](./HARDWARE_DATABASE.md).

## Related reading

- [docs/GUIDE.md](./GUIDE.md) — the actual setup steps
- [docs/PERFORMANCE.md](./PERFORMANCE.md) — making it fast
- [docs/TROUBLESHOOTING.md](./TROUBLESHOOTING.md) — when it isn't
- [docs/GLOSSARY.md](./GLOSSARY.md) — terms used everywhere
