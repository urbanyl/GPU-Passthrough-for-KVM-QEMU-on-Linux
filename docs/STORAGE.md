# Storage Guide

How to choose, create, and manage virtual disks for your GPU passthrough VM.

---

## Table of Contents

- [Disk Image Formats](#disk-image-formats)
- [Creating Disks](#creating-disks)
- [Disk Buses: VirtIO, SATA, NVMe Emulation](#disk-buses-virtio-sata-nvme-emulation)
- [Driver and Cache Options](#driver-and-cache-options)
- [I/O Threads](#io-threads)
- [Snapshots](#snapshots)
- [Backups](#backups)
- [Moving the Disk Between Hosts](#moving-the-disk-between-hosts)

---

## Disk Image Formats

### qcow2 (default)

| Pros | Cons |
|------|------|
| Sparse (grows on demand) | Slight metadata overhead |
| Snapshots, compression, encryption | Copy-on-write fragmentation |
| Thin provisioning | Needs `discard=unmap` + TRIM in guest to reclaim space |

```bash
qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/win11.qcow2 100G
```

### raw

| Pros | Cons |
|------|------|
| Fastest (no COW overhead) | Full size allocated (unless sparse file) |
| Simple, portable | No snapshots |
| Zero fragmentation | |

```bash
qemu-img create -f raw /var/lib/libvirt/images/win11.raw 100G
```

### Sparse raw (hybrid)

```bash
qemu-img create -f raw -o preallocation=off /var/lib/libvirt/images/win11.raw 100G
truncate -s 100G /var/lib/libvirt/images/win11.raw
```

### qcow2 with backing file

Chain a snapshot on top of a base image — excellent for testing updates:

```bash
# Base image (unchanging)
qemu-img create -f qcow2 -o size=100G base.qcow2

# Overlay
qemu-img create -f qcow2 -b base.qcow2 -F qcow2 overlay.qcow2
```

The overlay holds only changes. Discard the overlay to "revert" to the base.

---

## Creating Disks

Use the bundled helper:

```bash
bash scripts/create_disk.sh /var/lib/libvirt/images/win11.qcow2 100 qcow2
# or
bash scripts/create_disk.sh /var/lib/libvirt/images/win11.raw 100 raw
```

Or manually with virt-install creating the disk automatically:

```bash
sudo virt-install ... --disk path=/var/lib/libvirt/images/win11.qcow2,size=100,bus=virtio,format=qcow2
```

---

## Disk Buses: VirtIO, SATA, NVMe Emulation

### VirtIO (recommended default)

Near-native performance, requires `viostor` driver (from the virtio-win ISO) in Windows.

```xml
<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2' cache='none' io='native' discard='unmap'/>
  <source file='/var/lib/libvirt/images/win11.qcow2'/>
  <target dev='vda' bus='virtio'/>
</disk>
```

### VirtIO SCSI

Better for multiple disks and passthrough of raw devices; uses the `vioscsi` driver.

```xml
<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2' cache='none' io='native'/>
  <source file='/var/lib/libvirt/images/win11.qcow2'/>
  <target dev='sda' bus='scsi'/>
  <address type='drive' controller='0' bus='0' target='0' unit='0'/>
</disk>
```

### NVMe emulation

Windows has a built-in NVMe driver, which some find slightly faster and more stable than virtio-blk on Windows:

```xml
<disk type='file' device='nvme'>
  <driver name='qemu' type='raw'/>
  <source file='/var/lib/libvirt/images/win11.raw'/>
  <target dev='nvm0' bus='nvme'/>
</disk>
```

### Emulated SATA/IDE

Only for compatibility (legacy Windows). Slow. Avoid unless required.

---

## Driver and Cache Options

| Attribute | Values | Notes |
|-----------|--------|-------|
| `cache` | `none`, `writeback`, `writethrough`, `unsafe`, `directsync` | `none` recommended |
| `io` | `native`, `threads` | `native` recommended (uses O_DIRECT/libaio) |
| `discard` | `unmap`, `ignore` | `unmap` lets TRIM shrink qcow2 |
| `iothread` | 1..N | Parallel I/O per disk (requires `<iothreads>`) |

Recommended baseline:

```xml
<driver name='qemu' type='qcow2' cache='none' io='native' discard='unmap'/>
```

---

## I/O Threads

Dedicated threads keep disk I/O off the vCPU threads:

```xml
<iothreads>4</iothreads>

<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2' cache='none' io='native' iothread='1' discard='unmap'/>
  ...
</disk>
```

Then pin the iothreads (optional):

```xml
<cputune>
  <iothreadpin iothread='1' cpuset='6'/>
  ...
</cputune>
```

---

## Snapshots

### External snapshots (libvirt)

```bash
# Create
sudo virsh snapshot-create-as win11-gpu "after-drivers" "Snapshot after GPU drivers" --disk-only --atomic

# List
sudo virsh snapshot-list win11-gpu

# Revert (shutdown VM first)
sudo virsh shutdown win11-gpu
sudo virsh snapshot-revert win11-gpu "after-drivers"

# Delete
sudo virsh snapshot-delete win11-gpu "after-drivers"
```

> **External snapshots create a new overlay disk.** The base qcow2 plus the overlay must stay together. Back up both.

### Internal snapshots

```bash
sudo virsh snapshot-create-as win11-gpu "working-state" --disk-only --atomic --diskspec vda,snapshot=internal
```

Internal snapshots store data inside the qcow2 file. Fewer files to manage, but slower to create.

### Full disk copies

```bash
# Shutdown the VM first
sudo virsh shutdown win11-gpu
cp /var/lib/libvirt/images/win11.qcow2 win11-backup.qcow2
sudo virsh start win11-gpu
```

---

## Backups

### 1. Cold backup (most reliable)

```bash
sudo virsh shutdown win11-gpu
sudo bash scripts/backup_vm.sh win11-gpu /mnt/backup
sudo virsh start win11-gpu
```

### 2. Live backup with blockcommit

While the VM runs, create a snapshot overlay then merge it back:

```bash
sudo virsh snapshot-create-as win11-gpu live-backup --disk-only --atomic
# The VM now writes to a new overlay; base qcow2 is stable — copy it
cp /var/lib/libvirt/images/win11.qcow2 /mnt/backup/
# Merge the overlay back into the base
sudo virsh blockcommit win11-gpu vda --active --pivot
```

### 3. rsync a running VM (acceptable, not perfect)

```bash
rsync -aP /var/lib/libvirt/images/ /mnt/backup/
```

Quiescing is not guaranteed — prefer snapshot-based backups for integrity.

### What to back up

| Item | Path |
|------|------|
| Disk image(s) | `/var/lib/libvirt/images/` |
| Domain XML | `/etc/libvirt/qemu/*.xml` |
| NVRAM vars | `/var/lib/libvirt/qemu/nvram/*_VARS.fd` |
| libvirt hooks | `/etc/libvirt/hooks/` |
| modprobe config | `/etc/modprobe.d/vfio.conf` and friends |
| GRUB/bootloader | `/etc/default/grub` |
| Machine-readable domain config | `sudo virsh dumpxml win11-gpu > win11-gpu.xml` |

> **Always export the XML** (`virsh dumpxml`) — it is the recipe for recreating the VM on another host.

---

## Moving the Disk Between Hosts

```bash
# On the source host
sudo virsh dumpxml win11-gpu > win11-gpu.xml
sudo virsh shutdown win11-gpu

# Copy the disk + XML to the new host, then:
sudo virsh define win11-gpu.xml
sudo chown -R libvirt-qemu:kvm /var/lib/libvirt/images/
sudo virsh start win11-gpu
```

Paths in the XML must match the new host. Fix with `sudo virsh edit win11-gpu` or edit the XML before defining.

> **Windows activation:** a passed-through GPU change or core count change may trigger Windows reactivation. This is expected behavior.

---

## Checklist

- [ ] Disk format chosen deliberately (qcow2 for snapshots, raw for raw speed)
- [ ] Disk on NVMe storage
- [ ] VirtIO bus used
- [ ] `cache='none' io='native' discard='unmap'` applied
- [ ] I/O threads configured if multiple disks
- [ ] `virsh dumpxml` exported
- [ ] Backup strategy decided (cold, snapshot, or rsync)
