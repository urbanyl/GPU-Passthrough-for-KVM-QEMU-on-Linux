# Performance Tuning

This guide covers every performance lever available for a GPU passthrough VM, from CPU pinning to PCIe configuration. Apply these in the order presented — each builds on the previous.

> **Read the full setup first.** Performance tuning assumes your VM already works. See [README.md](../README.md) and [GUIDE.md](GUIDE.md) before tuning.

---

## Table of Contents

- [Measure First, Optimize Second](#measure-first-optimize-second)
- [CPU Optimization](#cpu-optimization)
- [Memory: Huge Pages and Ballooning](#memory-huge-pages-and-ballooning)
- [Storage Optimization](#storage-optimization)
- [Network Optimization](#network-optimization)
- [PCIe and GPU Optimization](#pcie-and-gpu-optimization)
- [Interrupt Handling (IRQ Tuning)](#interrupt-handling-irq-tuning)
- [Windows Guest Tuning](#windows-guest-tuning)
- [Linux Guest Tuning](#linux-guest-tuning)
- [Host Services to Disable](#host-services-to-disable)
- [Benchmarking](#benchmarking)

---

## Measure First, Optimize Second

Never tune blindly. Establish a baseline, change one thing at a time, and measure.

**Host:**
```bash
# CPU
mpstat -P ALL 1
# Memory
free -h
# Disk
iostat -x 1
# Network
sar -n DEV 1
```

**Guest (Windows):**
- `Task Manager > Performance` for CPU/memory/GPU
- `latencymon` for DPC latency (excellent for finding audio/video stutter causes)
- `Cinebench R23` for CPU
- `3DMark` or game-specific benchmarks for GPU
- `CrystalDiskMark` for storage

**Guest (Linux):**
```bash
sudo apt install -y sysbench stress-ng    # Debian/Ubuntu
sudo pacman -S sysbench stress-ng          # Arch
glxgears                                   # quick GPU sanity (not a real benchmark)
```

Record the numbers, change one variable, re-measure.

---

## CPU Optimization

### 1. Set the CPU governor to performance

The default `powersave`/`ondemand` governor introduces latency spikes that are very visible in passthrough VMs.

```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

sudo cpupower frequency-set -g performance   # after installing cpupower/linux-cpupower

# Permanent (Debian/Ubuntu)
echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpupower
sudo systemctl enable --now cpupower
```

### 2. Understand your topology

```bash
lscpu -e                 # logical CPU list with core/socket/numa
lstopo                   # graphical topology map (package: hwloc/lstopo)
numactl --hardware       # NUMA nodes and memory ranges
```

Take note of:
- **Physical cores vs threads (SMT)** — prefer pinning vCPUs to distinct physical cores
- **NUMA nodes** — pin the VM to the same node as the passthrough GPU
- **Cores used by the host** — leave some for the desktop/host services

### 3. Pin vCPUs (cputune)

Edit the VM XML:

```bash
sudo virsh edit win11-gpu
```

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

> The example pins 8 vCPUs to cores 2-7 and 10-11, leaving cores 0-1 for the host. **Adjust to your own topology** using `lscpu -e`.

### 4. Isolate cores from the host scheduler

Add to the kernel command line (`/etc/default/grub` or systemd-boot entry):

```
isolcpus=2-7,10-11
```

This tells the host scheduler to never place host tasks on those cores. Combined with pinning, the VM effectively gets dedicated cores.

> **Important:** `isolcpus` can make the host desktop sluggish if you isolate too many cores. Leave 2-4 cores for the host.

### 5. Reduce host noise on VM cores

```
nohz_full=2-7,10-11 rcu_nocbs=2-7,10-11
```

- `nohz_full` disables timer ticks on those cores
- `rcu_nocbs` moves RCU callbacks off those cores

### 6. Disable SMT / hyperthreading sharing

If the host and VM share physical cores through SMT, both fight for the same execution resources.

```
nosmt=force
```

Or only disable SMT when the VM is running, via a libvirt hook (`echo off > /sys/devices/system/cpu/smt/control`).

> **Trade-off:** Disabling SMT reduces total host throughput but improves VM latency and consistency.

### 7. NUMA — keep it on one node

If your CPU has multiple NUMA nodes, pin the VM entirely to one node to avoid cross-node memory traffic:

```xml
<cpu mode='host-passthrough' check='none'>
  <topology sockets='1' cores='8' threads='1'/>
  <numa>
    <cell id='0' cpus='0-7' memory='16' unit='GiB'/>
  </numa>
</cpu>
```

And allocate memory from the same node on the host (see huge pages below).

---

## Memory: Huge Pages and Ballooning

### 1. Use huge pages

Default 4 KB pages cause frequent TLB misses for a VM using 16+ GB of RAM. Huge pages (2 MB or 1 GB) dramatically reduce that overhead.

**Allocate 2 MB huge pages:**
```bash
echo 8192 | sudo tee /proc/sys/vm/nr_hugepages      # 8192 × 2 MB = 16 GB
```

**Allocate 1 GB huge pages (best for VMs, requires reserving at boot):**
```
# kernel parameter
default_hugepagesz=1G hugepagesz=1G hugepages=16
```

**Persist via sysctl:**
```bash
echo 'vm.nr_hugepages = 8192' | sudo tee /etc/sysctl.d/99-hugepages.conf
```

**Use the helper script:**
```bash
sudo bash scripts/setup_hugepages.sh 16384
```

**Tell the VM to use them** — in the domain XML:

```xml
<memoryBacking>
  <hugepages>
    <page size='2048' unit='KiB'/>
  </hugepages>
</memoryBacking>
```

> On some kernels/libvirt versions you may also need `<memoryBacking><source type='memfd' access='shared'/></memoryBacking>` when sharing memory with Looking Glass or other host tools.

**Verify:**
```bash
cat /proc/meminfo | grep -i huge
# HugePages_Total:    8192
# HugePages_Free:     8192
```

### 2. Disable memory ballooning

The balloon driver lets the host reclaim guest memory on demand, but it hurts performance and can cause instability in passthrough VMs. Remove it:

```bash
sudo virsh detach-device win11-gpu --current --live
# Device type: memballoon
```

Or in the XML, delete the `<memballoon model='virtio'/>` block (or set `<memballoon model='none'/>`).

### 3. Give the guest enough memory

- Windows 10/11 gaming: 16 GB minimum, 32 GB recommended
- Never overcommit memory the host cannot provide — the host needs RAM for its own desktop + the huge page pool
- Set the `<memory>` and `<currentMemory>` values to the same number (static allocation)

---

## Storage Optimization

### 1. Use VirtIO, not emulated SATA/IDE

VirtIO gives near-native disk performance:

```xml
<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2' cache='none' io='native' discard='unmap'/>
  <source file='/var/lib/libvirt/images/win11.qcow2'/>
  <target dev='vda' bus='virtio'/>
</disk>
```

### 2. Prefer raw over qcow2 for maximum throughput

`qcow2` adds copy-on-write and metadata overhead. For pure performance:

```bash
qemu-img create -f raw /var/lib/libvirt/images/win11.raw 100G
```

You lose snapshots/compression but gain speed. Many users keep qcow2 for its features — the difference is small on NVMe. Your choice.

### 3. Back the disk with NVMe

Put the guest disk on an NVMe SSD. PCIe 4.0/5.0 NVMe drives deliver guest sequential reads at 5000-14000 MB/s.

### 4. Use multiple queues (iothreads)

Dedicate a thread per disk to parallelize I/O:

```xml
<iothreads>4</iothreads>

<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2' cache='none' io='native' iothread='1'/>
  ...
</disk>
```

### 5. Cache modes — what they actually mean

| Mode | Behavior | Best for |
|------|----------|----------|
| `none` | Bypass host page cache, direct I/O | Most setups (recommended) |
| `writeback` | Host caches writes | Fast but risky on host crash |
| `writethrough` | Writes hit cache then disk | Safe but slower |
| `unsafe` | Host does not flush at all | Disposable VMs only |
| `directsync` | Synchronous direct I/O | Consistency over speed |

With `cache='none'` + `io='native'` + `discard='unmap'` you get the best balance of performance and safety.

### 6. NVMe emulation

Newer kernels/QEMU can emulate an NVMe controller which Windows handles better for TRIM and queue depth:

```xml
<disk type='file' device='nvme'>
  <driver name='qemu' type='raw'/>
  <source file='/var/lib/libvirt/images/win11.raw'/>
  <target dev='nvm0' bus='nvme'/>
</disk>
```

Requires recent virtio-win / built-in Windows NVMe driver. Many find it slightly faster than virtio-blk for Windows guests.

---

## Network Optimization

### 1. Use VirtIO with multi-queue

```xml
<interface type='network'>
  <source network='default'/>
  <model type='virtio'/>
  <driver name='vhost' queues='4'>
    <host mq='on'/>
    <guest mq='on'/>
  </driver>
  <alias name='net0'/>
</interface>
```

### 2. Set queue count to match vCPUs

The number of `queues` should equal the number of vCPUs (or at least the number of cores you want doing network I/O). On the Windows guest:

```
Windows Device Manager > NetKVM > Properties > Advanced
Set "Receive Buffers" and "Transmit Buffers" to maximum
Enable RSS (Receive Side Scaling) with 4-8 queues
```

### 3. Consider bridged networking for latency

NAT adds translation overhead. A bridge gives the guest a direct path:

```xml
<interface type='bridge'>
  <source bridge='br0'/>
  <model type='virtio'/>
</interface>
```

See [NETWORKING.md](NETWORKING.md) for full bridge setup.

### 4. Multiqueue via `-netdev`

For raw QEMU users:

```
-netdev user,id=net0 -device virtio-net-pci,netdev=net0,mq=on,vectors=10
```

---

## PCIe and GPU Optimization

### 1. Enable Resizable BAR (ReBAR)

ReBAR allows the GPU to access its full VRAM address space, eliminating PCIe windowing overhead. On AMD hosts, letting `amdgpu` init the card first sets up ReBAR in a VFIO-safe way (see [README §6a](../README.md#6a-amd-gpu-dynamic-binding-late-binding)).

- Enable **Resizable BAR** and **Above 4G Decoding** in BIOS
- NVIDIA: check the card supports ReBAR (RTX 30/40 do; GTX 10/16 generally do not)
- AMD: RX 6000+ supports ReBAR

### 2. Use a x16 slot at full link speed

```bash
lspci -vv -s 01:00.0 | grep LnkSta
# LnkSta: Speed 16GT/s (x16)   <- PCIe 4.0 x16
# LnkSta: Speed 8GT/s (x16)    <- PCIe 3.0 x16
```

If the GPU runs at x8 or lower, it may be in a slot shared with other devices. Move it.

### 3. Disable the EFI/VESA framebuffer

```bash
# kernel parameters
video=efifb:off
```

Or the more aggressive:

```
initcall_blacklist=sysfb_init
```

This prevents host framebuffer drivers from touching the passthrough GPU, which can cause reset and initialization problems.

### 4. Fix GPU reset issues

Some GPUs (GTX 900, Polaris, Vega) do not implement FLR correctly. Options:
- Host reboot between VM sessions
- [vendor-reset](https://github.com/gnif/vendor-reset) kernel module for AMD Polaris/Vega
- BIOS workarounds (if your board exposes them)

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#gpu-does-not-reset).

### 5. Pin the GPU's MSI IRQs

For low-latency GPU work, move the GPU's interrupt to an isolated core:

```bash
cat /proc/interrupts | grep -i 'vfio'
# Note the IRQ number, then:
echo 22 > /proc/irq/22/smp_affinity   # or use the hex CPU mask
```

---

## Interrupt Handling (IRQ Tuning)

### 1. Check IRQ distribution

```bash
cat /proc/interrupts
```

### 2. Prevent IRQ storms on pinned cores

For the VM's vCPUs, make sure no host IRQ is mapped to them:

```bash
# Find the IRQ for your network card / GPU / NVMe
grep -i nvme /proc/interrupts
# Set affinity to host-only cores (e.g. CPU 0-1):
echo 3 > /proc/irq/24/smp_affinity
```

### 3. Use `irqbalance` correctly

If you use `irqbalance`, exclude the isolated cores:

```
# /etc/default/irqbalance
IRQBALANCE_BANNED_CPUS=fc00      # hex mask of cores 2-7,10-11
```

Or just disable irqbalance and hand-tune affinities.

---

## Windows Guest Tuning

Once Windows is installed:

1. **Power plan → High performance**
   - Control Panel > Power Options > High performance
   - Or: `powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c`

2. **Disable Game Bar / background apps** that steal GPU time

3. **NVIDIA: enable "Prefer maximum performance"** in the power management mode of the driver's control panel

4. **Disable Windows Defender real-time scanning** for the game directories (or disable it entirely for a dedicated gaming VM)

5. **Reduce Windows timer resolution** — Windows 10/11 requests 15.6 ms timers by default; games and tools like `timerresolution` or running a high-resolution game typically fix this automatically. A tuned guest can use 0.5 ms timers.

6. **Set NVIDIA Low Latency Mode to "Ultra"** in the 3D settings (adds latency reduction, can slightly reduce frame pacing smoothness on some titles)

7. **Disable fullscreen optimizations** for specific .exe files (Properties > Compatibility)

8. **Disable memory compression and SysMain (Superfetch)** if you experience high disk activity:
   ```powershell
   Disable-MMAgent -MemoryCompression
   Stop-Service SysMain -Force
   Set-Service SysMain -StartupType Disabled
   ```

9. **Install the latest chipset drivers** (AMD/Intel) inside the guest

---

## Linux Guest Tuning

For a Linux guest, apply the same host-side ideas inside the VM:

```bash
# CPU governor in guest
sudo cpupower frequency-set -g performance

# I/O scheduler in guest
echo none | sudo tee /sys/block/vda/queue/scheduler

# Transparent huge pages in guest (helps with huge pages host-side)
echo always | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
```

---

## Host Services to Disable

```bash
sudo systemctl stop cups
sudo systemctl stop bluetooth
sudo systemctl stop avahi-daemon
sudo systemctl stop power-profiles-daemon   # conflicts with manual governor
sudo systemctl stop switcheroo-control
```

Disable permanently only if you do not need them:

```bash
sudo systemctl disable cups bluetooth avahi-daemon
```

> Do **not** disable `libvirtd`, `systemd-udevd`, or kernel modules. Over-aggressive service removal breaks the host.

---

## Benchmarking

**Host sanity:** `glmark2`, `geekbench5` (Linux)

**Windows guest:**
- CPU: Cinebench R23 / Geekbench 6
- GPU: 3DMark Time Spy / Superposition
- Storage: CrystalDiskMark
- Latency: LatencyMon

**Compare guest vs bare metal.** A healthy passthrough setup should show:
- GPU: 95-98% of bare metal
- CPU: 98-100% of bare metal
- Storage: 90-100% of bare metal (VirtIO + NVMe)

If you see a large gap, walk through this guide again — the usual culprits are cache mode, ballooning, governor, and missing pinning.

---

## Checklist

- [ ] CPU governor set to `performance`
- [ ] vCPUs pinned to physical cores (`cputune`)
- [ ] Host cores isolated (`isolcpus`)
- [ ] Huge pages allocated and enabled in XML
- [ ] Balloon device removed
- [ ] Disk uses VirtIO with `cache='none' io='native'`
- [ ] Backing storage is NVMe
- [ ] Network uses VirtIO multi-queue (or bridge)
- [ ] ReBAR + Above 4G Decoding enabled in BIOS
- [ ] GPU at full x16 link speed
- [ ] Windows power plan set to High performance
- [ ] Benchmarked before/after each change
