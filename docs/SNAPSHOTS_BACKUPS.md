# Snapshots and Backups

Protecting your VM. Because the day you skip a backup is the day a driver update bricks the guest.

---

## Table of Contents

- [What to Back Up](#what-to-back-up)
- [Cold Backups](#cold-backups)
- [Live Backups (snapshot-based)](#live-backups-snapshot-based)
- [Snapshots (external vs internal)](#snapshots-external-vs-internal)
- [Automation](#automation)
- [Restoring](#restoring)
- [Best Practices](#best-practices)

---

## What to Back Up

| Item | Why | Path/Command |
|------|-----|--------------|
| Disk image | The VM's data | `/var/lib/libvirt/images/*.qcow2` |
| Domain XML | The VM definition | `sudo virsh dumpxml win11-gpu > win11-gpu.xml` |
| NVRAM | UEFI vars (Secure Boot keys) | `/var/lib/libvirt/qemu/nvram/*_VARS.fd` |
| Hooks | Custom start/stop logic | `/etc/libvirt/hooks/` |
| Host config | The recipe to rebuild | `/etc/modprobe.d/`, `/etc/default/grub` |

---

## Cold Backups

Shut the VM down, copy the disk, boot it back up:

```bash
sudo virsh shutdown win11-gpu
sudo bash scripts/backup_vm.sh win11-gpu /mnt/backup
sudo virsh start win11-gpu
```

The bundled script copies the disk image, exports the XML, and saves the NVRAM.

**Pros:** 100% consistent. **Cons:** downtime.

---

## Live Backups (snapshot-based)

Zero downtime using external snapshots:

```bash
# 1. Create an external snapshot; the VM keeps running writing to an overlay
sudo virsh snapshot-create-as win11-gpu live-backup --disk-only --atomic

# 2. The base qcow2 is now frozen and safe to copy
sudo cp /var/lib/libvirt/images/win11.qcow2 /mnt/backup/

# 3. Merge the overlay back into the base (the "pivot" stops writes to the overlay)
sudo virsh blockcommit win11-gpu vda --active --pivot

# 4. Clean up the snapshot metadata
sudo virsh snapshot-delete win11-gpu live-backup
```

**Pros:** no downtime, consistent. **Cons:** requires qcow2, a bit of discipline (finish the blockcommit!).

> **Warning:** leaving an external snapshot around forever is fine as a rollback point, but never delete the base file while an overlay references it.

---

## Snapshots (external vs internal)

### External snapshots (recommended)

Create a new overlay file; the base stays untouched:

```bash
sudo virsh snapshot-create-as win11-gpu "pre-update" "before driver update" --disk-only --atomic
```

Revert to the snapshot state = start from the base (discard the overlay).

### Internal snapshots

Stored inside the qcow2 file itself:

```bash
sudo virsh snapshot-create-as win11-gpu "working" --disk-only --atomic --diskspec vda,snapshot=internal
```

**Compare:**

| | External | Internal |
|--|----------|----------|
| Creation speed | Fast | Slower |
| File count | 2+ files | 1 file |
| Backup simplicity | Copy base only | Copy single file |
| Corruption risk spread | Separate files | One file, one failure |

For most users: **external snapshots** for live backups, internal snapshots for simple rollback points.

The bundled `scripts/snapshot_vm.sh` wraps the common operations:

```bash
bash scripts/snapshot_vm.sh list win11-gpu
bash scripts/snapshot_vm.sh create win11-gpu pre-driver-update
bash scripts/snapshot_vm.sh revert win11-gpu pre-driver-update
bash scripts/snapshot_vm.sh delete win11-gpu pre-driver-update
```

Internal snapshots live inside the qcow2, so the image keeps growing while they exist — `delete` them when you're done testing.

---

## Automation

### Cron-based cold backup (nightly, guest shutdown required — use for low-use VMs)

```bash
# /etc/cron.d/vm-backup
0 3 * * * root virsh shutdown win11-gpu; sleep 30; bash /opt/scripts/backup_vm.sh win11-gpu /mnt/backup; virsh start win11-gpu
```

### systemd timer for a live snapshot + copy

```ini
# /etc/systemd/system/vm-live-backup.service
[Unit]
Description=Live backup of win11-gpu

[Service]
Type=oneshot
ExecStart=/usr/local/bin/live-backup.sh

# /usr/local/bin/live-backup.sh
#!/bin/bash
set -euo pipefail
VM="win11-gpu"
DEST="/mnt/backup/$(date +%F)"
mkdir -p "$DEST"
virsh snapshot-create-as "$VM" auto --disk-only --atomic
cp /var/lib/libvirt/images/win11.qcow2 "$DEST/"
virsh blockcommit "$VM" vda --active --pivot
virsh snapshot-delete "$VM" auto
```

---

## Restoring

```bash
# Stop the VM
sudo virsh shutdown win11-gpu

# Restore the disk image
sudo cp /mnt/backup/win11.qcow2 /var/lib/libvirt/images/win11.qcow2
sudo chown libvirt-qemu:kvm /var/lib/libvirt/images/win11.qcow2

# Restore the XML if the VM definition is gone
sudo virsh define /mnt/backup/win11-gpu.xml

# Start
sudo virsh start win11-gpu
```

**Restoring from a snapshot overlay:** if the overlay is the bad state and you want the base:

```bash
sudo virsh shutdown win11-gpu
sudo rm /var/lib/libvirt/images/win11.qcow2        # the overlay
sudo virsh snapshot-list win11-gpu
sudo virsh snapshot-delete win11-gpu "pre-update" --metadata   # clear metadata only
# Re-point the disk to the base image in the XML
```

---

## Best Practices

1. **Export the XML** after every VM change (`virsh dumpxml`)
2. **Never** let an external snapshot chain grow unbounded — commit or delete regularly
3. Test a restore at least once — an untested backup is a guess
4. Store backups on a different disk/device than the VM
5. Keep the guest's own file-level backup (Windows: File History / shadow copies) for small recovery
6. Version your backups by date (`/mnt/backup/2026-08-03/`)

---

## Checklist

- [ ] XML exported (`virsh dumpxml`)
- [ ] NVRAM included in backup
- [ ] Cold OR live snapshot procedure decided
- [ ] Automation in place (cron/systemd timer)
- [ ] Restore tested once
- [ ] Backups on separate storage
