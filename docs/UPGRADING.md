# Upgrading and Maintenance

What happens to your passthrough setup when you upgrade the kernel, the distro, or the BIOS — and how to keep it working.

---

## Table of Contents

- [Kernel Upgrades](#kernel-upgrades)
- [Distro Upgrades (major versions)](#distro-upgrades-major-versions)
- [BIOS / Firmware Updates](#bios--firmware-updates)
- [GPU Driver Updates (host)](#gpu-driver-updates-host)
- [libvirt / QEMU Upgrades](#libvirt--qemu-upgrades)
- [Rebuilding After Anything Breaks](#rebuilding-after-anything-breaks)
- [Moving Between Hosts](#moving-between-hosts)

---

## Kernel Upgrades

After a kernel update, your VFIO config persists (it lives in modprobe + bootloader), but the initramfs must be rebuilt for the **new** kernel.

```bash
# Debian/Ubuntu (auto-rebuilds on kernel install, but do it manually if unsure)
sudo update-initramfs -u

# Arch
sudo mkinitcpio -P

# Fedora
sudo dracut -f
```

**Verify after reboot:**

```bash
uname -r
cat /proc/cmdline | grep vfio-pci
bash scripts/check_vfio_binding.sh
```

### Kernel regressions

Kernel updates occasionally change VFIO behavior:
- If binding silently fails after a kernel upgrade, test the previous kernel from GRUB
- Some distros ship out-of-tree modules (NVIDIA) that must match the new kernel (`dkms` auto-rebuilds, but check `dkms status`)

---

## Distro Upgrades (major versions)

Major distro upgrades change packages, configs, and possibly the bootloader.

**Before upgrading:**
```bash
sudo virsh dumpxml win11-gpu > win11-gpu.xml   # backup
sudo bash scripts/backup_vm.sh win11-gpu /mnt/backup
cp /etc/modprobe.d/vfio.conf /mnt/backup/
cp /etc/default/grub /mnt/backup/
```

**After upgrading:**
1. Re-apply kernel parameters if the bootloader config was reset (check `cat /proc/cmdline`)
2. Re-add `/etc/modprobe.d/*` entries if wiped (rare, but possible with new installs)
3. Rebuild initramfs
4. Verify binding
5. Check OVMF path (some distros move it):
   ```bash
   find /usr/share -name "OVMF_CODE.fd" 2>/dev/null
   ```
6. If the VM XML references an old OVMF path, `sudo virsh edit win11-gpu` and fix it

---

## BIOS / Firmware Updates

BIOS updates can change:
- IOMMU group assignments (usually better, sometimes worse)
- Default kernel parameters (some boards inject their own)
- ACS behavior

**After a BIOS update:**
```bash
# Re-check groups
bash scripts/check_iommu_groups.sh

# Re-verify binding
bash scripts/check_vfio_binding.sh
```

**If groups get worse:** reorder slots, re-enable ACS/Above 4G Decoding in the new BIOS menu, or report the regression to the vendor.

> Always reset the BIOS to your desired defaults after a flash — vendors often restore factory defaults.

---

## GPU Driver Updates (host)

For NVIDIA host drivers, a driver update can claim the passthrough GPU if the kernel is probing it:

```bash
# After driver install
sudo dkms status        # check the nvidia module rebuilt
sudo update-initramfs -u
sudo reboot
```

Your `vfio-pci.ids` in the kernel command line should still claim the GPU first. Verify with `check_vfio_binding.sh`.

---

## libvirt / QEMU Upgrades

QEMU/libvirt occasionally change default behavior or deprecate XML features:

```bash
# After upgrade
sudo virsh list --all
sudo virsh start win11-gpu
sudo journalctl -u libvirtd --since "10 minutes ago" --no-pager
```

**If XML validation fails after an upgrade:**

```bash
sudo virsh edit win11-gpu
# Fix reported fields; then:
sudo virsh define /etc/libvirt/qemu/win11-gpu.xml
```

Common drift points: machine type (`pc-q35` vs `pc-q35-8.2`), OVMF path, deprecated `model='auto'` attributes.

---

## Rebuilding After Anything Breaks

The universal recovery checklist:

```bash
# 1. Kernel params present?
cat /proc/cmdline | grep -i iommu
cat /proc/cmdline | grep vfio-pci

# 2. VFIO config present?
cat /etc/modprobe.d/vfio.conf

# 3. Modules present in initramfs?
lsinitramfs /boot/initrd.img-$(uname -r) | grep -E 'vfio|nvidia'   # Debian/Ubuntu
lsinitrd /boot/initramfs-$(uname -r) | grep vfio                    # Fedora
lsinitcpio -g /dev/stdout 2>/dev/null | grep vfio                   # Arch

# 4. Rebuild + reboot
sudo update-initramfs -u; sudo update-grub; sudo reboot   # Debian/Ubuntu
sudo mkinitcpio -P; sudo grub-mkconfig -o /boot/grub/grub.cfg; sudo reboot   # Arch
sudo dracut -f; sudo grub2-mkconfig -o /boot/grub2/grub.cfg; sudo reboot   # Fedora
```

---

## Moving Between Hosts

1. Export the XML + back up the disk (see [STORAGE.md](STORAGE.md#moving-the-disk-between-hosts))
2. On the new host: define the VM, fix paths, fix OVMF path
3. Re-check IOMMU groups on the new host — they will differ
4. Windows may need reactivation (GPU/core change)

---

## Recommended Maintenance Schedule

| Interval | Task |
|----------|------|
| Monthly | `sudo dnf upgrade` / `sudo apt upgrade` / `sudo pacman -Syu`, rebuild initramfs if kernel changed |
| Monthly | Verify binding: `bash scripts/check_vfio_binding.sh` |
| Quarterly | Cold backup of VM + XML export |
| On BIOS update | Re-check IOMMU groups |
| On kernel update | Rebuild initramfs, verify boot |

---

## Checklist

- [ ] Kernel updated -> initramfs rebuilt -> binding verified
- [ ] Distro upgraded -> kernel params + modprobe re-applied -> OVMF path checked
- [ ] BIOS updated -> groups re-checked -> BIOS defaults reset
- [ ] NVIDIA host driver updated -> dkms status OK -> binding verified
- [ ] Quarterly backup performed
