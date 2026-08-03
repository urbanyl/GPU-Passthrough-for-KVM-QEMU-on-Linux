# Glossary

Quick definitions of every acronym and term used in this repository.

---

| Term | Meaning |
|------|---------|
| **ACS** | Access Control Services. A PCIe feature that lets the kernel isolate devices into separate IOMMU groups. Boards without proper ACS lump unrelated devices together. |
| **AMD-V** | AMD's CPU virtualization extension (the AMD equivalent of VT-x). |
| **AMD-Vi** | AMD's IOMMU implementation (the AMD equivalent of VT-d). |
| **Ballooning** | Memory reclaim where the host "inflates" a driver in the guest to free RAM. Removed in passthrough VMs for performance. |
| **DMA** | Direct Memory Access. The GPU writes/reads host memory directly, protected by the IOMMU. |
| **Error 43** | NVIDIA's Windows driver refusing to work because it detects virtualization. Fixed with `kvm=hidden` + `vendor_id`. |
| **FLR** | Function Level Reset. A PCIe mechanism that resets a device function. GPUs that do not implement FLR may fail to re-initialize after the VM stops. |
| **Huge pages** | Memory pages larger than 4 KB (2 MB / 1 GB), reducing TLB pressure for big VMs. |
| **Hyper-V enlightenments** | A set of paravirtualized features QEMU exposes so Windows performs as if on Hyper-V. Needed for the NVIDIA workaround. |
| **IOMMU** | I/O Memory Management Unit. The hardware that isolates and remaps device DMA. The foundation of safe passthrough. |
| **KVM** | Kernel-based Virtual Machine. The Linux kernel's hypervisor. |
| **libvirt** | The management toolkit (API + daemon) that QEMU/KVM VMs run under. |
| **MAC** | Mandatory Access Control (SELinux, AppArmor). Linux hardening that can block VFIO. |
| **MSI / MSI-X** | Message Signaled Interrupts. Faster than legacy pin-based IRQs; important for GPU passthrough. |
| **NAT** | Network Address Translation. The default libvirt network: the guest shares the host's IP. |
| **NVMe** | Non-Volatile Memory Express. The fast storage interface; preferred backing for guest disks. |
| **OVMF** | Open Virtual Machine Firmware. The UEFI firmware that Windows 10/11 require in QEMU. |
| **Passthrough mode** | `iommu=pt` kernel parameter: the IOMMU passes DMA through instead of remapping per-group, reducing overhead. |
| **PCIe ACS override** | A kernel parameter that forces IOMMU groups to split; a security trade-off. See [SECURITY.md](SECURITY.md). |
| **QEMU** | The machine emulator / virtualizer that works with KVM. |
| **qcow2** | QEMU Copy-On-Write image format (sparse, snapshot-capable). |
| **ReBAR** | Resizable BAR. Lets a GPU map all VRAM into the address space. Requires BIOS + hardware support. |
| **SMT** | Simultaneous Multi-Threading (Intel Hyper-Threading / AMD SMT). Sharing one physical core between two logical CPUs. |
| **SPICE** | The Simple Protocol for Independent Computing Environments — libvirt's default display protocol for setup. |
| **SR-IOV** | Single Root I/O Virtualization. Splits one physical device into multiple virtual functions; rarely used on consumer GPUs. |
| **TPM** | Trusted Platform Module. Windows 11 requires TPM 2.0; libvirt can emulate one. |
| **usbredir** | USB redirection over the SPICE channel — software USB passthrough. |
| **VFIO** | Virtual Function I/O. The kernel framework that safely hands a PCI device to a VM. |
| **vfio-pci** | The driver that claims the GPU so it can be passed to a guest. |
| **VirtIO** | Paravirtualized drivers (disk, net, serial) that give near-native I/O performance in guests. |
| **virtio-win** | The ISO with Windows VirtIO drivers (viostor, NetKVM, balloon, etc.). |
| **VT-d** | Intel's IOMMU implementation. |
| **VT-x** | Intel's CPU virtualization extension. |
