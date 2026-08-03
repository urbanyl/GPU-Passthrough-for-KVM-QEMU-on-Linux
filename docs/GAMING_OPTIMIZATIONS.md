# Gaming Optimizations

A checklist of host- and guest-side tweaks that turn a working passthrough VM into a smooth gaming machine.

> For raw performance mechanics (pinning, huge pages, storage, network), read [PERFORMANCE.md](PERFORMANCE.md) first. This file is the gaming-focused version of that.

---

## Table of Contents

- [Host-Side Gaming Tweaks](#host-side-gaming-tweaks)
- [Windows Guest Gaming Tweaks](#windows-guest-gaming-tweaks)
- [NVIDIA-Specific](#nvidia-specific)
- [AMD-Specific](#amd-specific)
- [Latency Measurement](#latency-measurement)
- [Per-Game Notes](#per-game-notes)
- [Anti-Cheat and Online Play](#anti-cheat-and-online-play)

---

## Host-Side Gaming Tweaks

```bash
# CPU governor
sudo cpupower frequency-set -g performance

# Isolate VM cores (kernel parameter)
isolcpus=4-11,14-15

# Huge pages
echo 8192 | sudo tee /proc/sys/vm/nr_hugepages

# I/O scheduler
echo none | sudo tee /sys/block/nvme0n1/queue/scheduler
```

**Stop background noise:**

```bash
sudo systemctl stop cups bluetooth avahi-daemon
```

**Set real-time priority for QEMU** (so scheduler never delays the VM):

```bash
# /etc/security/limits.d/99-qemu.conf
@libvirt - rtprio 99
@libvirt - memlock unlimited
```

---

## Windows Guest Gaming Tweaks

### Power & performance

```powershell
# High performance plan
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# Disable fullscreen optimizations for your games
# (Right-click exe > Properties > Compatibility > Disable fullscreen optimizations)
```

### Reduce background load

```powershell
# Disable memory compression
Disable-MMAgent -MemoryCompression

# Disable SysMain (Superfetch)
Stop-Service SysMain -Force
Set-Service SysMain -StartupType Disabled

# Disable Windows Search indexing if it causes stutter
Set-Service WSearch -StartupType Disabled
```

### Network for gaming

```powershell
# In the NetKVM adapter properties:
#   Receive Buffers: max, Transmit Buffers: max
#   RSS: enabled with 4-8 queues
# Disable Nagle on your local interface (registry):
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -Force | Out-Null
# Set TcpAckFrequency=1 on the interface matching your NIC GUID
```

### Storage

- Enable TRIM on the virtio disk (Windows does this automatically for NVMe, but verify Disk Defragmenter shows it as SSD)
- Keep Windows and games on the same virtio disk or a second virtio data disk
- Never put the pagefile on the virtio C: and expect top performance if RAM is low — just give the VM more RAM instead

---

## NVIDIA-Specific

### Driver settings (NVIDIA Control Panel > Manage 3D Settings)

| Setting | Value |
|---------|-------|
| Low Latency Mode | Ultra |
| Power management mode | Prefer maximum performance |
| Max Frame Rate | Off (or 3 below monitor refresh) |
| Vertical sync | Off (in-game or via driver) |
| Texture quality | High performance |

### G-Sync inside the VM

G-Sync works if the monitor is connected to the passed GPU and the driver + display combination supports it. Set the refresh rate, enable G-Sync in the control panel, and confirm the monitor OSD reports G-Sync active.

### DLSS / Frame Generation

Both work normally inside the guest — they are GPU-side features and do not care about virtualization.

---

## AMD-Specific

### Radeon Software settings

| Setting | Value |
|---------|-------|
| Radeon Anti-Lag | On |
| Power | Max performance |
| Image Sharpening | As preferred |
| FreeSync | On (monitor connected to passed GPU) |

### FSR / AFMF

Work inside the guest like on bare metal. AFMF requires a recent Radeon Software version and a supported game.

---

## Latency Measurement

| Tool | Platform | Use |
|------|----------|-----|
| `LatencyMon` | Windows | Find DPC latency spikes (audio/network drivers) |
| `PresentMon` | Windows | Frame time analysis (Steam overlay alternative) |
| `mangohud` | Linux guest/host | In-game FPS + frame time overlay |
| `ftt` (Frame Time Tester) | Windows | Graph frame pacing |

**Target:** frame times smooth (no 10x outliers), DPC latency < 1 ms, input feels instant (sub-10 ms from click to on-screen).

---

## Per-Game Notes

- **FPS/competitive (CS, Valorant, Overwatch):** use the passed GPU + monitor connected directly; USB controller passthrough for input; game mode on. Host streaming (Moonlight) adds ~5-15 ms — acceptable but not for strict aim.
- **AAA single-player:** Moonlight at 4K/120 or direct monitor both fine; enable G-Sync/FreeSync on the passed display.
- **Vulkan:** works natively in the guest; DXVK via Proton for Windows DX11/12 games still functions inside the Windows VM.
- **VR:** must use direct display on the GPU headset or display duplication; VR headset USB goes through controller passthrough (see [USB_PASSTHROUGH.md](USB_PASSTHROUGH.md)).

---

## Anti-Cheat and Online Play

The `kvm=hidden` + `vendor_id` trick hides QEMU from the guest, which satisfies most anti-cheats that check for "is this a VM".

**However:**

- Some anti-cheats (notably **Valorant/Vanguard**, some others) block VMs outright or use hypervisor-present CPUID checks that `kvm=hidden` does not fully hide
- `vendor_id` must be set to a plausible, non-obvious value
- The `Hyper-V` enlightenments block should be complete (see [README §10](../README.md#10-optimize-the-vm-configuration))
- **BattlEye/EAC**: generally work with hidden state; EAC had kernel-level detection in some titles — check the specific game's subreddit for current status

> **Do not attempt to defeat anti-cheat by additional means.** If a game blocks VMs, the safest option is a separate bare-metal install or acceptance that the title won't run in a VM. This guide does not endorse circumventing anti-cheat software.

---

## The "Gaming VM" Full Checklist

- [ ] CPU pinned + isolated, governor `performance`
- [ ] Huge pages active
- [ ] Balloon removed
- [ ] Disk: VirtIO, `cache=none io=native`, on NVMe
- [ ] Network: VirtIO multi-queue or bridged
- [ ] Guest power plan High performance
- [ ] GPU driver + control panel tuned (low latency, max performance)
- [ ] Input: evdev or USB controller passthrough
- [ ] Monitor connected directly to passed GPU (or Moonlight)
- [ ] LatencyMon < 1 ms DPC
- [ ] Game-specific settings (G-Sync/FreeSync, game mode)
