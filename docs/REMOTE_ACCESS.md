# Remote Access

Every way to see and use your GPU passthrough VM from a distance, compared and configured.

---

## Table of Contents

- [Comparison Table](#comparison-table)
- [Looking Glass (local, near-zero latency)](#looking-glass-local-near-zero-latency)
- [Sunshine + Moonlight (best for streaming)](#sunshine--moonlight-best-for-streaming)
- [Parsec (easiest)](#parsec-easiest)
- [RDP (remote desktop)](#rdp-remote-desktop)
- [SPICE / VNC (setup and admin)](#spice--vnc-setup-and-admin)
- [File Sharing](#file-sharing)

---

## Comparison Table

| Tool | Latency | Best for | Guest required |
|------|---------|----------|----------------|
| **Looking Glass** | ~1-5 ms | Local, high-refresh gaming on the host monitor | `looking-glass-client` (Win) |
| **Sunshine + Moonlight** | 5-20 ms | Remote/local streaming, game streaming | Moonlight or a client |
| **Parsec** | 5-15 ms | Easiest remote play | Parsec app |
| **RDP** | 50-150 ms | Productivity/admin, no GPU gaming | Built into Windows |
| **SPICE** | 100+ ms | Setup, install, fallback | spice-vdagent |
| **VNC** | 100+ ms | Legacy/admin fallback | Any VNC server |

---

## Looking Glass (local, near-zero latency)

The best option when the VM runs on the same machine you sit at: captures the GPU output via shared memory and renders it on the host with minimal overhead.

> **Follow the official docs.** They are always current, cover both stable and bleeding-edge builds, and this summary is only a starting point:
> - https://looking-glass.io/docs/stable
> - https://looking-glass.io/docs/bleeding
>
> **Important:** the Looking Glass project recommends the **KVMFR kernel module** for the shared memory device — it uses your GPU's DMA engine, which matters especially on iGPU hosts. Plain `ivshmem-plain` shmem is legacy/deprecated and only kept for special cases (VM-to-VM). Setup: https://looking-glass.io/docs/B7/ivshmem_kvmfr/

**1. Add the shared memory device to the VM XML (KVMFR method):**

```xml
<qemu:commandline>
  <qemu:arg value='-device'/>
  <qemu:arg value='{"driver":"ivshmem-plain","id":"shmem0","memdev":"looking-glass"}'/>
  <qemu:arg value='-object'/>
  <qemu:arg value='{"qom-type":"memory-backend-file","id":"looking-glass","mem-path":"/dev/kvmfr0","size":33554432,"share":true}'/>
</qemu:commandline>
```

Your `<domain>` element needs the QEMU namespace:

```xml
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
```

**2. Host prerequisites (once):**

```bash
# Load the kvmfr module; 32 MiB fits 1080p, use the official formula for higher res
echo "options kvmfr static_size_mb=32" | sudo tee /etc/modprobe.d/kvmfr.conf
sudo modprobe kvmfr

# Let QEMU open /dev/kvmfr0
#   /etc/libvirt/qemu.conf  -> cgroup_device_acl += "/dev/kvmfr0"
#   AppArmor: echo "/dev/kvmfr0 rw," >> /etc/apparmor.d/local/abstractions/libvirt-qemu
sudo systemctl restart libvirtd
```

The size formula from the docs: `(width × height × pixel size × 2) / 1 MiB + 10 MiB`, with pixel size 4 (SDR) or 8 (HDR). The `size` value in the XML (bytes) must match `static_size_mb`.

**3. Host:** build/install looking-glass-client ([looking-glass.io](https://looking-glass.io), GitHub [gnif/LookingGlass](https://github.com/gnif/LookingGlass)):

```bash
git clone --recursive https://github.com/gnif/LookingGlass.git
cd LookingGlass
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
# run: ./looking-glass-client
```

**4. Guest:** install the Windows client and, when it asks, the IVSHMEM driver if not already present.

**5. Run:**

```bash
cd LookingGlass/build
./looking-glass-client
```

**Troubleshooting:** `Unable to start server` usually means the shared memory block is missing or the IVSHMEM driver is not installed in the guest. `Fatal: no shared memory` means the VM didn't get the shmem device (reboot it). Missing `/dev/kvmfr0` means the module isn't loaded or QEMU can't open it (check cgroup/AppArmor). For anything else, read the official docs first — they are the source of truth.

---

## Sunshine + Moonlight (best for streaming)

Streams the guest GPU output over your network — great for gaming on another machine or a second room.

**Host:** run Sunshine on the Linux host, stream from the VM.

```bash
# Install Sunshine (see https://github.com/LizardByte/Sunshine)
# Debian/Ubuntu: use the LizardByte release package or flatpak
flatpak install flathub dev.lizardbyte.app.Sunshine
```

**Guest:** install Moonlight on the Windows VM and pair it:

```bash
# In the VM
winget install MoonlightGameStreaming.Moonlight
```

On the client, add the host (the Linux machine running Sunshine), enter the PIN shown in Sunshine's web UI (default http://localhost:47990).

**Recommended settings:**
- 4K/120 if the client supports it, otherwise 1440p/1080p
- HEVC/H.265 encoding on NVIDIA/AMD GPUs for lower bitrate at same quality
- Low latency mode: enabled
- If your VM is the *host* of Moonlight sessions, install Moonlight directly in the guest and stream that — even lower latency because the stream originates in the guest.

---

## Parsec (easiest)

Host-agnostic streaming that just works:

1. Create a Parsec account
2. Install Parsec on the host (Linux) and the guest (Windows) — sign in on both
3. Connect from any device

Parsec uses E2E encryption and works well behind NAT. Gaming latency is excellent (5-15 ms locally).

**Note:** Parsec's Linux host support historically lagged Windows; verify current status on [parsec.app](https://parsec.app). Many users run Parsec directly inside the guest and stream the guest, with the Linux host running Moonlight/Sunshine for general desktop access.

---

## RDP (remote desktop)

Built into Windows — ideal for admin, office work, and remote maintenance. No GPU acceleration for games.

**Enable in the guest:**

```powershell
# Enable Remote Desktop
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
# Allow in firewall
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
```

**Connect:**
```bash
# Linux client
xfreerdp /v:10.0.2.15 /u:YourUser /w:1920 /h:1080
```

**Tips:**
- With NAT networking, forward host port 33890 -> guest 3389 (see [NETWORKING.md](NETWORKING.md))
- Use the "RemoteFX"/hardware encoding if offered — RDP can use the guest GPU for encoding on modern Windows

---

## SPICE / VNC (setup and admin)

Already configured by virt-manager — best during installation and driver setup, not for gaming.

```bash
# Show display info
sudo virsh domdisplay win11-gpu

# Connect with the SPICE client
spicy --host 127.0.0.1 --port 5900
```

For headless access, keep SPICE for console-level access and use Sunshine/Looking Glass for real work.

---

## File Sharing

| Method | Direction | Notes |
|--------|-----------|-------|
| **SMB (guest -> host)** | Windows guest shares to host/LAN | Built into Windows; best for Windows guests |
| **SMB (host -> guest)** | Host shares to guest | Run `samba` on host, map drive in guest |
| **virtiofs** | Linux host <-> Linux guest | Near-native, see [LINUX_GUESTS.md](LINUX_GUESTS.md) |
| **SPICE folder share** | Host -> guest | Slow, use for small files only |
| **rsync/scp** | Any -> host | Simplest for files out of the VM |

---

## Recommended Remote Setup

- **Same desk, host monitor:** Looking Glass
- **Gaming from another room:** Moonlight (client on the other device) + Sunshine, or Parsec
- **Admin/maintenance:** RDP or SPICE
- **Always keep:** at least one console path (SPICE) and one file path (SMB)
