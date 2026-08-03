# Linux Guests

GPU passthrough is not only for Windows. This guide covers Linux guests, which have some different driver and display considerations.

---

## Table of Contents

- [Why a Linux Guest?](#why-a-linux-guest)
- [Creating a Linux VM](#creating-a-linux-vm)
- [Guest GPU Drivers](#guest-gpu-drivers)
- [Wayland in the Guest](#wayland-in-the-guest)
- [Display Options for Linux Guests](#display-options-for-linux-guests)
- [Shared Folders (virtiofs)](#shared-folders-virtiofs)
- [Clipboard Sharing](#clipboard-sharing)
- [Troubleshooting Linux Guests](#troubleshooting-linux-guests)

---

## Why a Linux Guest?

- Run a second Linux desktop with full GPU acceleration
- Test distributions without rebooting
- AI/ML development with CUDA/ROCm in an isolated VM
- Use the same passthrough setup as Windows but with an open-source stack

---

## Creating a Linux VM

Use `virt-install` the same way as Windows, pointing at a Linux ISO:

```bash
sudo virt-install \
  --name ubuntu-gpu \
  --memory 16384 \
  --vcpus 8 \
  --cpu host-passthrough \
  --machine q35 \
  --boot uefi \
  --disk path=/var/lib/libvirt/images/ubuntu.qcow2,size=80,bus=virtio,format=qcow2 \
  --cdrom /tmp/ubuntu-24.04-desktop-amd64.iso \
  --network network=default,model=virtio \
  --graphics spice,listen.type=none \
  --video virtio \
  --hostdev 0000:01:00.0 \
  --hostdev 0000:01:00.1 \
  --autostart
```

> **No `kvm=hidden` or `vendor_id` needed for Linux guests.** Those exist purely to fool NVIDIA's Windows driver.

---

## Guest GPU Drivers

### NVIDIA (Linux guest)

Use the NVIDIA proprietary driver in the guest:

```bash
# Ubuntu/Debian
sudo apt install -y nvidia-driver-550 nvidia-utils-550

# Arch
sudo pacman -S nvidia nvidia-utils

# Fedora (via RPM Fusion)
sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda
sudo reboot
```

Check it loaded:

```bash
nvidia-smi
```

**Note:** the `kvm hidden` trick is not needed for NVIDIA on Linux — the driver does not refuse to run in VMs on Linux.

### AMD (Linux guest)

AMDGPU is open source and included in the kernel — usually nothing to install:

```bash
glxinfo -B
# OpenGL renderer string should show your GPU, not llvmpipe
```

If it shows `llvmpipe`, the driver failed — see [Troubleshooting](#troubleshooting-linux-guests).

### Intel (Linux guest)

i915 is in-kernel. Nothing to install.

---

## Wayland in the Guest

Wayland works fine inside the guest. The passthrough GPU is treated like any other GPU:

- GDM/KDE/gnome on Wayland will detect and use the NVIDIA/AMD/Intel device
- AMD and Intel: no special config
- NVIDIA under Wayland: use driver 545+; on GDM you may need `NVreg_PreserveVideoMemoryAllocations=1` and `WitnessMemCleanupFix` nvidia kernel module options for suspend/resume

---

## Display Options for Linux Guests

Because Linux guests render natively to the passed GPU, you have three ways to see the screen:

1. **Physical monitor** on the passed GPU (like Windows)
2. **Looking Glass** — works identically to Windows. Use the KVMFR setup the project recommends (see [REMOTE_ACCESS.md](REMOTE_ACCESS.md#looking-glass-local-near-zero-latency) and the [official docs](https://looking-glass.io/docs/stable)); Linux guests need no extra guest driver for the shared memory
3. **SPICE + virtio GPU** — before the GPU drivers take over; the `virgl` accel in `virtio-vga` provides a working fallback console

Recommended XML for a Linux guest that uses both SPICE (setup) and the passed GPU (runtime):

```xml
<graphics type='spice' port='-1' autoport='yes' listen type='none'>
  <image compression='off'/>
</graphics>
<video>
  <model type='virtio' heads='1' primary='yes'/>
</video>
```

---

## Shared Folders (virtiofs)

Share host directories with the guest at near-native speed:

**Add to the domain XML:**

```xml
<filesystem type='mount' accessmode='passthrough'>
  <driver type='virtiofs'/>
  <source dir='/home/you/shared'/>
  <target dir='shared'/>
</filesystem>
```

**Restart the VM, then mount in the guest:**

```bash
sudo mkdir -p /mnt/shared
sudo mount -t virtiofs shared /mnt/shared
```

**Persist (fstab):**

```
shared /mnt/shared virtiofs defaults 0 0
```

> virtiofs requires a recent kernel on both sides (5.4+ guest, modern QEMU/libvirt). It does **not** work on Windows guests — Windows uses SMB (see [REMOTE_ACCESS.md](REMOTE_ACCESS.md)).

---

## Clipboard Sharing

- **SPICE agent** handles shared clipboard over the SPICE channel: install `spice-vdagent` in the guest
  ```bash
  sudo apt install spice-vdagent    # and start it
  ```
- **Looking Glass** shares clipboard too when its client is running
- **Wayland guests**: the spice-vdagent clipboard integration under Wayland can be flaky; `wl-clipboard` + Looking Glass clipboard is a solid alternative

---

## Troubleshooting Linux Guests

| Symptom | Fix |
|---------|-----|
| `llvmpipe` renderer (software) | Check `lspci -k` in guest; driver not loaded — install NVIDIA/check amdgpu loaded |
| Black screen after driver install | Same as Windows: connect monitor to passed GPU or use Looking Glass/SPICE |
| No 3D in SPICE console | `virgl` needs `virtio-vga` (not `qxl`) and guest mesa for virtio |
| Suspend/resume broken (NVIDIA) | Add `NVreg_PreserveVideoMemoryAllocations=1`; set systemd `MemoryZswapWriteback` fix — usually just disable sleep in guest |
| virtiofs mount fails | Check kernel >= 5.4; ensure `<driver type='virtiofs'/>` present; `sudo modprobe virtiofs` |
| Wayland crash loops | Log into Xorg session to debug; check `journalctl -u gdm` |
| Guest can't see GPU | Verify hostdev in XML, IOMMU group clean, vfio-pci bound |

---

## Checklist

- [ ] VirtIO disk and network for the guest
- [ ] Guest GPU driver installed (NVIDIA proprietary / AMDGPU in-kernel)
- [ ] Display: physical monitor, Looking Glass, or SPICE decided
- [ ] virtiofs shared folder configured (if needed)
- [ ] `spice-vdagent` for clipboard (if using SPICE)
