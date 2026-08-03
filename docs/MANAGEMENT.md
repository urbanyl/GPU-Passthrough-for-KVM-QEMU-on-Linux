# Management Tools

Operating a passthrough VM day-to-day shouldn't require memorising a wall of
`virsh` and sysfs commands. The repo bundles a few higher-level helpers that
wrap the repetitive bits, plus a Makefile so the common actions are one `make`
target away.

- [`scripts/vmctl.sh`](#vmctlsh) — unified VM lifecycle controller
- [`scripts/gpu_recovery.sh`](#gpu_recoverysh) — recover a stuck GPU after a crash
- [`scripts/collect_info.sh`](#collect_infosh) — the "paste this in the thread" dumper
- [`scripts/snapshot_vm.sh`](#snapshot_vmsh) — VM snapshots
- [`Makefile`](#makefile) — `make <verb>` for everything

---

## vmctl.sh

One entrypoint for the VM + GPU lifecycle, delegating to the dedicated helper
scripts where the real logic lives.

```
vmctl.sh status                         list all VMs (running + shut off)
vmctl.sh state NAME                     show NAME's runtime state
vmctl.sh start NAME [GPU AUDIO ...]     start VM, binds GPU first if given
vmctl.sh stop  NAME [GPU AUDIO DRIVER]  stop VM, rebinds GPU to host if given
vmctl.sh reboot | shutdown | poweroff NAME   virsh wrappers
vmctl.sh suspend | resume NAME           virsh wrappers
vmctl.sh attach-gpu NAME GPU [AUDIO]    bind a GPU to vfio-pci
vmctl.sh detach-gpu NAME GPU [AUDIO DRIVER]  rebind a GPU to the host
vmctl.sh info NAME                      state + vCPU pinning + PCI + display
```

Examples:

```bash
sudo bash scripts/vmctl.sh start win11-gpu 0000:01:00.0 0000:01:00.1
sudo bash scripts/vmctl.sh stop  win11-gpu 0000:01:00.0 0000:01:00.1 amdgpu
sudo bash scripts/vmctl.sh info win11-gpu
```

**Why not just call `virsh`/`start_vm.sh` directly?** `vmctl.sh` adds the two
things you always forget: it checks the VM exists, and it prints the SPICE /
Looking Glass connection line after `start`. The `attach-gpu`/`detach-gpu`
commands cover the single-GPU and dynamic-binding flows without you having to
remember `bind_vfio.sh`'s exact argument order.

---

## gpu_recovery.sh

After a hard `virsh destroy` or a guest crash, the GPU occasionally stays
wedged on `vfio-pci` and the host display never comes back (black screen, GPU
"stuck" on the VFIO driver). This script:

1. stops any VM that still lists the device,
2. forcibly unbinds GPU + audio from `vfio-pci`,
3. fires the kernel PCI reset quirk (`/sys/bus/pci/devices/<addr>/reset`) to
   clear the device,
4. hands off to `bind_vfio.sh rebind` to restore the host driver and restart
   the display manager.

```bash
sudo bash scripts/gpu_recovery.sh 0000:01:00.0 0000:01:00.1 nvidia
# DRIVER auto-detected from PCI vendor if omitted (10de->nvidia, 1002->amdgpu, 8086->i915)
```

**When this can't help:** the PCI reset file is often not permissioned, and some
NVIDIA laptop / single-slot cards still need a host reboot to recover. If that
happens, `gpu_recovery.sh` is the last attempt before a reboot.

---

## collect_info.sh

The support-thread lifesaver. Dumps kernel cmdline, IOMMU groups, VFIO binding,
loaded modules, hugepages, libvirt/virsh state, and CPU info in one shot. Run it
*before* posting on r/VFIO / GitHub issues and paste the whole output:

```bash
bash scripts/collect_info.sh
```

---

## snapshot_vm.sh

Internal (qcow2-embedded) snapshots — create / list / revert / delete:

```bash
bash scripts/snapshot_vm.sh list       win11-gpu
sudo bash scripts/snapshot_vm.sh create win11-gpu pre-driver-update
sudo bash scripts/snapshot_vm.sh revert win11-gpu pre-driver-update
sudo bash scripts/snapshot_vm.sh delete win11-gpu pre-driver-update
```

Snapshots live inside the qcow2, so the image grows while they exist — delete
them once you're past the risky operation. For whole-VM safety, prefer
[`docs/SNAPSHOTS_BACKUPS.md`](SNAPSHOTS_BACKUPS.md) and `backup_vm.sh`.

---

## Makefile

A thin wrapper so you don't have to remember flags:

```bash
make help        # list every target
make check       # sudo bash scripts/status_check.sh
make setup       # sudo bash scripts/setup_vfio.sh
make detect      # detect_gpu.sh + check_iommu_groups.sh
make status      # virsh list --all
make vm-start    # sudo bash scripts/start_vm.sh $(VM) ...
make vm-stop     # sudo bash scripts/stop_vm.sh $(VM) ...
make vm-reboot   # virsh reboot $(VM)
make backup      # sudo bash scripts/backup_vm.sh $(VM) $(DEST)
make restore     # sudo bash scripts/restore_vm.sh $(VM) $(SRC)
make info        # bash scripts/collect_info.sh
make lint        # shellcheck scripts/*.sh  (needs shellcheck installed)
```

Override variables on the command line:

```bash
make vm-start VM=gaming GPU=0000:01:00.0 AUDIO=0000:01:00.1
make backup   VM=win11-gpu DEST=/mnt/backup
make restore  VM=win11-gpu SRC=/mnt/backup/win11-gpu
```
