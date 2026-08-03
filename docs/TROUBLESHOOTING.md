# Troubleshooting Reference

Comprehensive troubleshooting guide for GPU passthrough issues.

> **Specialized troubleshooting:** input devices → [INPUT_PASSTHROUGH.md](INPUT_PASSTHROUGH.md) · USB → [USB_PASSTHROUGH.md](USB_PASSTHROUGH.md) · audio → [AUDIO.md](AUDIO.md) · networking → [NETWORKING.md](NETWORKING.md) · performance → [PERFORMANCE.md](PERFORMANCE.md) · backups → [SNAPSHOTS_BACKUPS.md](SNAPSHOTS_BACKUPS.md)

---

## Table of Contents

- [VM Does Not Start](#vm-does-not-start)
- [Black Screen After Driver Install](#black-screen-after-driver-install)
- [NVIDIA Error Code 43](#nvidia-error-code-43)
- [GPU Does Not Reset](#gpu-does-not-reset)
- [AMD GPU Not Initializing in VM](#amd-gpu-not-initializing-in-vm)
- [GPU Bound to Host After Reboot](#gpu-bound-to-host-after-reboot)
- [VM is Slow or Stuttering](#vm-is-slow-or-stuttering)
- [BSOD During Installation](#bsod-during-installation)
- [VFIO Module Errors](#vfio-module-errors)
- [IOMMU Not Enabled](#iommu-not-enabled)
- [Bad IOMMU Groups](#bad-iommu-groups)
- [Guest Display Flickering](#guest-display-flickering)
- [Network Not Working in Guest](#network-not-working-in-guest)
- [USB Passthrough Issues](#usb-passthrough-issues)
- [Audio Issues](#audio-issues)
- [Input/evdev Issues](#inputevdev-issues)
- [virtiofs Issues](#virtiofs-issues)
- [Anti-Cheat / Error 43 Variants](#anti-cheat--error-43-variants)

---

## VM Does Not Start

### Symptoms

- `virsh start` returns an error
- VM exits immediately after starting
- libvirt reports "internal error"

### Diagnosis

```bash
# Check libvirt logs
sudo journalctl -u libvirtd --since "5 minutes ago" --no-pager

# Check QEMU process output
sudo virsh start win11-gpu 2>&1

# Check audit logs (SELinux/AppArmor)
sudo ausearch -m avc --ts recent
sudo cat /var/log/audit/audit.log | grep denied
```

### Common Causes

| Cause | Symptom in Log | Fix |
|-------|----------------|-----|
| GPU bound to host driver | `Failed to set up IOMMU` | Rebuild initramfs, verify VFIO config |
| Wrong PCI IDs | `vfio: unknown device` | Re-check `lspci -nn` |
| Missing audio function | `vfio: failed to configure` | Add audio device to VFIO IDs |
| OVMF not found | `Could not find OVMF` | Install `ovmf` package |
| Permission denied | `internal error: Access denied` | Add user to `libvirt` group |
| AppArmor blocking | `denied` in audit log | Set `security_driver = "none"` in `/etc/libvirt/qemu.conf` |

### Quick Fix Checklist

```bash
# 1. Verify user is in libvirt group
groups $USER | grep libvirt

# 2. Verify OVMF is installed
ls /usr/share/OVMF/OVMF_CODE.fd 2>/dev/null || \
ls /usr/share/edk2/ovmf/OVMF_CODE.fd 2>/dev/null || \
echo "OVMF not found - install ovmf package"

# 3. Verify VFIO is bound
lspci -k | grep -A 3 -i 'vga' | grep 'vfio-pci'

# 4. Check for SELinux/AppArmor denials
sudo ausearch -m avc --ts recent 2>/dev/null
sudo journalctl -k | grep -i denied

# 5. Try starting manually
sudo virsh start win11-gpu --console
```

---

## Black Screen After Driver Install

### Symptoms

- Display goes black after installing NVIDIA/AMD driver
- SPICE console shows nothing
- VM is still running but no visible output

### Cause

The display output has switched from the virtual display (SPICE) to the physical GPU. This is normal behavior.

### Fix

1. **Connect a monitor to the passthrough GPU** -- you should see the Windows desktop
2. **Use remote access** -- SSH, RDP, or Sunshine/Moonlight
3. **Use SPICE fallback** -- the SPICE display may still be available through virt-manager

### Preventing This

To keep SPICE as the primary display during setup, delay GPU driver installation until all remote access is configured.

---

## NVIDIA Error Code 43

### Symptoms

- Device Manager shows "This device cannot start. (Code 43)"
- NVIDIA driver refuses to initialize
- GPU appears in Device Manager but with a warning icon

### Cause

NVIDIA drivers detect virtualization and refuse to work in a VM.

### Fix

Edit the VM XML:

```bash
sudo virsh edit win11-gpu
```

Add/modify these blocks:

```xml
<features>
  <hyperv mode='custom'>
    <vendor_id state='on' value='123456789ab'/>
    <relaxed state='on'/>
    <vapic state='on'/>
    <spinlocks state='on' retries='8191'/>
    <vpindex state='on'/>
    <synic state='on'/>
    <stimer state='on'/>
  </hyperv>
  <kvm>
    <hidden state='on'/>
  </kvm>
</features>
```

Then **shut down the VM completely** (not just reboot) and start it again.

### Additional Fixes

If the above does not work:

1. Try an older NVIDIA driver version
2. Make sure `kvm` module is loaded: `lsmod | grep kvm`
3. Verify the CPU model is set to `host-passthrough`
4. Check that the vendor_id value is not a recognized pattern (use a random string)
5. Add `<vmport state='off'/>` to the `<features>` block

---

## GPU Does Not Reset

### Symptoms

- First VM session works fine
- Subsequent sessions fail to initialize the GPU
- Host reboot is required between VM sessions

### Affected GPUs

Known problematic models:
- NVIDIA GTX 900 series
- NVIDIA GTX 1050/1060 (some models)
- AMD Polaris (RX 400/500)
- AMD Vega

### Workarounds

1. **Reboot the host** between VM sessions (most reliable)
2. **AMD vendor-reset module:**
   ```bash
   git clone https://github.com/gnif/vendor-reset.git
   cd vendor-reset
   make
   sudo make install
   sudo modprobe vendor-reset
   ```
3. **Check for vendor quirks:**
   ```bash
   dmesg | grep -i 'reset\|quirk'
   ```

### Long-Term Solution

Use a GPU model with proper FLR (Function Level Reset) support. Check the [VFIO GPU Reset Wiki](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#GPU_does_not_reset) for your specific model.

---

## AMD GPU Not Initializing in VM

### Symptoms

- VM fails to start with GPU-related QEMU errors
- `dmesg` in the host shows VFIO probing errors for the GPU
- GPU works when bound to `amdgpu` but fails when bound to `vfio-pci` at boot
- Common on **AMD RX 9000 series** GPUs

### Cause

Some AMD GPUs (particularly RDNA 4 / RX 9000 series) require `amdgpu` to initialize the GPU firmware and PCIe topology during boot. If `vfio-pci` claims the device before `amdgpu` can init it, the GPU stays in an uninitialized state and cannot be used by QEMU.

### Fix: Use Dynamic Late Binding

Instead of binding the GPU to `vfio-pci` at boot via kernel parameters, let `amdgpu` bind normally, then dynamically unbind/bind to `vfio-pci` just before starting the VM.

**Option 1 — Manual (before starting VM):**
```bash
sudo bash scripts/bind_vfio.sh unbind 0000:01:00.0 0000:01:00.1
sudo virsh start win11-gpu
```

**Option 2 — Libvirt hook (automatic):**
```bash
# /etc/libvirt/hooks/qemu
#!/bin/bash
VM_NAME="win11-gpu"
GPU_ADDR="0000:01:00.0"
GPU_AUDIO="0000:01:00.1"
GPU_IDS="1002:XXXX,1002:XXXX"
case "$1/$2" in
  "$VM_NAME/prepare")
    echo "$GPU_ADDR" > /sys/bus/pci/devices/$GPU_ADDR/driver/unbind 2>/dev/null
    echo "$GPU_AUDIO" > /sys/bus/pci/devices/$GPU_AUDIO/driver/unbind 2>/dev/null
    modprobe vfio-pci
    for ID in $(echo "$GPU_IDS" | tr ',' ' '); do
      echo "${ID%:*}" "${ID#*:}" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null
    done
    echo "$GPU_ADDR" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null
    echo "$GPU_AUDIO" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null
    ;;
esac
```

**Important:** Do NOT blacklist `amdgpu` or use `vfio-pci.ids` for these GPUs in your kernel parameters. Remove them from `/etc/modprobe.d/vfio.conf` and `/etc/default/grub`.

### Verification

```bash
# After the hook/script runs:
lspci -k -s 0000:01:00.0 | grep "Kernel driver in use"
# Should show: vfio-pci
```

If the GPU is still bound to `amdgpu`, the unbind failed — check if another process is using the GPU.

---

## GPU Bound to Host After Reboot

### Symptoms

- `lspci -k` shows the host driver (nvidia, amdgpu, nouveau) instead of vfio-pci
- VFIO binding was working before reboot

### Diagnosis

```bash
# Check if kernel parameters are applied
cat /proc/cmdline | grep vfio-pci

# Check if VFIO modules are in initramfs
lsinitramfs /boot/initrd.img-$(uname -r) | grep vfio
# Or on Fedora:
lsinitrd /boot/initramfs-$(uname -r) | grep vfio
# Or on Arch:
lsinitcpio -g /dev/stdout | grep vfio

# Check VFIO config
cat /etc/modprobe.d/vfio.conf
```

### Fix

```bash
# 1. Verify kernel parameters in /etc/default/grub
# Make sure vfio-pci.ids=XXXX:XXXX,XXXX:XXXX is present

# 2. Verify VFIO config
cat /etc/modprobe.d/vfio.conf
# Should contain: options vfio-pci ids=XXXX:XXXX,XXXX:XXXX

# 3. Rebuild initramfs
sudo update-initramfs -u    # Debian/Ubuntu
sudo mkinitcpio -P          # Arch
sudo dracut -f              # Fedora

# 4. Rebuild bootloader
sudo update-grub            # Debian/Ubuntu
sudo grub2-mkconfig -o /boot/grub2/grub.cfg    # Fedora
sudo grub-mkconfig -o /boot/grub/grub.cfg      # Arch

# 5. Reboot
sudo reboot
```

### Common Pitfalls

- Typo in PCI IDs (compare with `lspci -nn` output)
- Missing the audio device ID
- `/etc/modprobe.d/vfio.conf` not loaded (check file permissions)
- Another modprobe file overriding the settings

---

## VM is Slow or Stuttering

### Diagnosis

```bash
# Check CPU governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Check if vCPUs are pinned
virsh vcpupin win11-gpu

# Check NUMA topology
lstopo
numactl --hardware

# Check for host CPU throttling
dmesg | grep -i 'cpu.*throttl'
```

### Fixes

| Problem | Solution |
|---------|----------|
| CPU on powersave | `sudo cpupower frequency-set -g performance` |
| No CPU pinning | Add `<cputune>` section to VM XML |
| Memory ballooning | Remove balloon device or set to fixed |
| Bad I/O scheduler | Set NVMe to `none`: `echo none > /sys/block/nvme0n1/queue/scheduler` |
| Host background tasks | Stop CUPS, Bluetooth, avahi-daemon |
| NUMA mismatch | Pin vCPUs to the same NUMA node as the GPU |

---

## BSOD During Installation

### Possible Causes

1. Wrong VirtIO driver for the disk bus
2. Corrupted Windows ISO
3. Too many vCPUs assigned
4. Hyper-V enlightenments interfering during setup

### Fixes

1. Try `vioscsi` instead of `viostor` (or vice versa)
2. Re-download the Windows ISO
3. Reduce vCPUs to 4 during installation
4. Remove `<features><hyperv>` block during install, add after
5. Try a different VirtIO ISO version

---

## VFIO Module Errors

### "vfio: failed to set up container"

```bash
# Ensure all VFIO modules are loaded
sudo modprobe vfio
sudo modprobe vfio_pci
sudo modprobe vfio_iommu_type1

# Verify
lsmod | grep vfio
```

### "vfio: IOMMU group X is not valid"

The IOMMU group contains devices that cannot be safely passed through together.

```bash
# Check what's in the group
bash scripts/check_iommu_groups.sh

# Solutions:
# 1. Move GPU to a different slot
# 2. Enable ACS in BIOS
# 3. Use ACS override patch
```

### "vfio-pci: probe failed"

```bash
# Check if another driver is already bound
lspci -k -s 01:00.0

# Unbind manually if needed
echo "0000:01:00.0" > /sys/bus/pci/devices/0000:01:00.0/driver/unbind

# Bind to vfio-pci
echo "10de 1af2" > /sys/bus/pci/drivers/vfio-pci/new_id
echo "0000:01:00.0" > /sys/bus/pci/drivers/vfio-pci/bind
```

---

## IOMMU Not Enabled

### Symptoms

- `dmesg | grep iommu` shows nothing
- All devices are in IOMMU group 0
- VFIO binding works but VM cannot access the device

### Diagnosis

```bash
# Check if IOMMU is in kernel params
cat /proc/cmdline | grep -i iommu

# Check kernel support
ls /sys/kernel/iommu_groups/

# Check dmesg for errors
dmesg | grep -Ei 'iommu|dmar|amd-vi|vt-d'
```

### Fix

1. Enable VT-d/AMD-Vi in BIOS
2. Add `intel_iommu=on iommu=pt` (Intel) to kernel params. On AMD there's no enable flag — the IOMMU auto-enables from the BIOS (AMD-Vi), so just use `iommu=pt`.
3. Rebuild initramfs and reboot
4. Some motherboards require enabling "Above 4G Decoding" for IOMMU to work

---

## Bad IOMMU Groups

### Symptoms

- GPU is grouped with essential host devices (USB, SATA)
- Cannot isolate the GPU without breaking host functionality

### Solutions (in order of preference)

1. **Move the GPU** to a different PCIe slot
2. **Update BIOS** -- newer firmware may fix IOMMU group assignment
3. **Enable ACS** in BIOS if available
4. **Use ACS override patch** (understand the security implications):
   ```bash
   # This is a kernel patch, not a simple config change
   # See: https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Bypassing_the_IOMMU_group_limitations
   ```
5. **Try a different motherboard** -- some boards have better IOMMU support

---

## Guest Display Flickering

### Causes

- SPICE display conflicting with GPU output
- Incorrect display resolution
- Virtio GPU driver conflict

### Fix

1. Remove the `<video>` device from VM XML if using a passed-through GPU
2. Or set `<video><model type='none'/>` to disable the virtual display
3. Ensure the monitor is connected directly to the passed-through GPU

---

## Network Not Working in Guest

### Symptoms

- No network adapter in Windows Device Manager
- Network adapter shows warning icon

### Fix

1. Install VirtIO network driver from the virtio-win.iso
2. Or use an emulated NIC: change `<model type='virtio'/>` to `<model type='rtl8139'/>` in the VM XML
3. Reboot the VM

---

## USB Passthrough Issues

### Symptoms

- USB device not visible in the VM
- USB device connects but disconnects randomly

### Fix

1. Use a dedicated USB controller for the VM (passed through via PCI)
2. Or use `virt-manager` to redirect USB devices: Virtual Machine > Redirect USB Device
3. For stable USB passthrough, pass through an entire USB controller PCI device

---

## Audio Issues

### Symptoms

- No audio in the VM
- Audio crackling or stuttering

### Fix

```bash
# Install PulseAudio/PipeWire user modules for libvirt
sudo usermod -aG audio $USER
sudo usermod -aG pulse-access $USER

# For PipeWire (recommended)
sudo apt install pipewire-pulse   # Debian/Ubuntu
```

In VM XML, add audio configuration:

```xml
<audio id='1' type='spice'/>
```

For the passed-through GPU, audio comes through HDMI/DisplayPort automatically when the GPU driver is installed.

---

## Input/evdev Issues

### Symptoms

- Keyboard/mouse not captured by the VM
- Input works only when the virt-manager window has focus
- Host keyboard "stolen" and impossible to get back

### Fixes

```bash
# 1. Verify the device paths exist
ls -l /dev/input/by-id/

# 2. Confirm your user is in the input/kvm group
groups $USER

# 3. Reload udev rules after installing the example rule
sudo udevadm control --reload-rules && sudo udevadm trigger
```

| Symptom | Fix |
|---------|-----|
| Not captured at all | Wrong `/dev/input/by-id` path; use `evtest` to identify |
| Only works when focused | Use `grab='all'` in the evdev `<source>` |
| Devices captured but dead | Swap the event nodes (keyboard/mouse reversed) |
| Cannot release devices back to host | Press Ctrl+Alt (default toggle); check libvirt docs for your version |
| AppArmor blocks access | Add the virt-aa-helper local rule (see [INPUT_PASSTHROUGH.md](INPUT_PASSTHROUGH.md)) |
| Host unusable after grab | Use `grab='toggle'`; keep an SSH session ready |

---

## virtiofs Issues

### Symptoms

- `mount -t virtiofs` fails in the guest
- Shared folder not visible
- VM fails to start after adding `<filesystem>`

### Fixes

1. **Kernel too old:** virtiofs needs guest kernel 5.4+ (Ubuntu 22.04, Fedora 36+, Arch, openSUSE TW all fine)
2. **XML missing the driver type:**
   ```xml
   <filesystem type='mount' accessmode='passthrough'>
     <driver type='virtiofs'/>
     <source dir='/home/you/shared'/>
     <target dir='shared'/>
   </filesystem>
   ```
3. **Module not loaded in guest:** `sudo modprobe virtiofs`
4. **libvirt too old to expose virtiofs:** upgrade libvirt/QEMU (needs QEMU 5.0+)
5. **AppArmor denies source dir access:** add a local profile rule for the shared directory
6. **Windows guest:** virtiofs is Linux-only — use SMB instead (see [REMOTE_ACCESS.md](REMOTE_ACCESS.md))

---

## Anti-Cheat / Error 43 Variants

### Error 43 persists after adding kvm=hidden

```bash
# 1. Full power cycle (not just reboot):
sudo virsh shutdown win11-gpu && sleep 5 && sudo virsh start win11-gpu

# 2. Verify the CPU model:
sudo virsh edit win11-gpu   # <cpu mode='host-passthrough' check='none'/>

# 3. Complete hyperv block with vendor_id (README §10)
# 4. Add <vmport state='off'/>
# 5. Try an older driver version
```

### Game/Vanguard says "VM detected"

- Confirm `<kvm><hidden state='on'/></kvm>` is present **after** the hyperv block
- Some anti-cheats detect the hypervisor CPUID even when hidden; no reliable workaround exists — treat this as an unsupported configuration for that title
- Do **not** attempt to bypass anti-cheat by spoofing further (see [GAMING_OPTIMIZATIONS.md](GAMING_OPTIMIZATIONS.md) and [SECURITY.md](SECURITY.md))
