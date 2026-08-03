# GPU Passthrough Quick Reference

A condensed reference for experienced users. For the full guide, see [README.md](../README.md). If you already did this once and just need the commands, this is the page. If this is your first time, honestly, start with the README — this one skips all the explanation and that explanation is usually what saves you.

> **Deep dives:** performance → [PERFORMANCE.md](PERFORMANCE.md) · gaming → [GAMING_OPTIMIZATIONS.md](GAMING_OPTIMIZATIONS.md) · Linux guests → [LINUX_GUESTS.md](LINUX_GUESTS.md) · input → [INPUT_PASSTHROUGH.md](INPUT_PASSTHROUGH.md) · USB → [USB_PASSTHROUGH.md](USB_PASSTHROUGH.md) · audio → [AUDIO.md](AUDIO.md) · storage → [STORAGE.md](STORAGE.md) · networking → [NETWORKING.md](NETWORKING.md) · remote access → [REMOTE_ACCESS.md](REMOTE_ACCESS.md) · hardware → [HARDWARE_DATABASE.md](HARDWARE_DATABASE.md) · security → [SECURITY.md](SECURITY.md) · upgrades → [UPGRADING.md](UPGRADING.md) · backups → [SNAPSHOTS_BACKUPS.md](SNAPSHOTS_BACKUPS.md) · glossary → [GLOSSARY.md](GLOSSARY.md)

## Minimal Steps

```bash
# 1. Identify GPU
lspci -nn | grep -iE 'vga|audio'

# 2. Check IOMMU groups
bash scripts/check_iommu_groups.sh

# 3. Configure GRUB (replace IDs with yours)
# Intel: intel_iommu=on iommu=pt vfio-pci.ids=XXXX:XXXX,XXXX:XXXX rd.driver.pre=vfio-pci
# AMD:   iommu=pt vfio-pci.ids=XXXX:XXXX,XXXX:XXXX rd.driver.pre=vfio-pci
#   (ignore old guides that say amd_iommu=on — no-op on modern kernels)

# 4. Configure VFIO
echo 'options vfio-pci ids=XXXX:XXXX,XXXX:XXXX' | sudo tee /etc/modprobe.d/vfio.conf

# 5. Rebuild initramfs
sudo update-initramfs -u    # Debian/Ubuntu
sudo mkinitcpio -P          # Arch
sudo dracut -f              # Fedora

# 6. Reboot and verify
sudo reboot
lspci -k | grep -A 3 -i 'vga'    # Should show "Kernel driver in use: vfio-pci"

# 7. Install packages
sudo apt install -y qemu-kvm libvirt-daemon-system virt-manager virtinst ovmf bridge-utils

# 8. Create VM
sudo virt-install \
  --name win11-gpu \
  --memory 16384 --vcpus 8 \
  --cpu host-passthrough --machine q35 --boot uefi \
  --disk path=/var/lib/libvirt/images/win11.qcow2,size=100,bus=virtio,format=qcow2 \
  --disk path=/tmp/virtio-win.iso,device=cdrom,bus=sata \
  --cdrom /path/to/Win11.iso \
  --network network=default,model=virtio \
  --graphics spice,listen.type=none --video virtio \
  --hostdev 0000:01:00.0 --hostdev 0000:01:00.1 \
  --features kvm=hidden
```

## AMD GPU Note (RX 9000+)

RX 9000 series GPUs need `amdgpu` to initialize the card first — binding directly to `vfio-pci` at boot will leave the GPU uninitialized and the VM won't boot. RX 6000/7000 also benefit from this (amdgpu sets up ReBAR safely).

Instead of `vfio-pci.ids=...` in Step 3, let `amdgpu` claim the GPU and use **dynamic late binding**:

```bash
# Before starting the VM (or via libvirt hook):
sudo bash scripts/bind_vfio.sh unbind 0000:01:00.0 0000:01:00.1
```

See [README.md §6a](../README.md#6a-amd-gpu-dynamic-binding-late-binding) for libvirt hook integration.

## Key Files

| File | Purpose |
|------|---------|
| `/etc/default/grub` | Kernel boot parameters |
| `/etc/modprobe.d/vfio.conf` | VFIO PCI IDs and module options |
| `/etc/modprobe.d/blacklist-gpu.conf` | Driver blacklisting (if needed) |
| `/etc/libvirt/hooks/qemu` | Libvirt hooks for single-GPU passthrough |

## Critical Commands

```bash
# Verify VFIO binding
lspci -k -d $(lspci -nn | grep VGA | awk '{print $1}')

# Check kernel parameters
cat /proc/cmdline

# Verify initramfs has VFIO
lsinitramfs /boot/initrd.img-$(uname -r) | grep vfio

# Check VFIO modules loaded
lsmod | grep vfio

# Check VFIO errors
dmesg | grep -iE 'vfio|iommu'
```

## NVIDIA Error 43 Fix

Add to VM XML:

```xml
<hyperv mode='custom'>
  <vendor_id state='on' value='123456789ab'/>
</hyperv>
<kvm>
  <hidden state='on'/>
</kvm>
```

## Useful Resources

- [Arch Wiki: PCI Passthrough via OVMF](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [r/VFIO](https://reddit.com/r/vfio)
- [Level1Techs Forums](https://forums.level1techs.com)
- [Looking Glass](https://looking-glass.io)
- [Sunshine/Moonlight](https://github.com/LizardByte/Sunshine)
