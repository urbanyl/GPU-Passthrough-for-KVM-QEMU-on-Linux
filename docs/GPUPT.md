# gpupt — one command for everything

`scripts/gpupt` is a single CLI that drives the whole GPU-passthrough workflow:
health checks, profile management, dynamic GPU binding, VM start/stop, libvirt
hooks, and recovery. Instead of remembering which helper script takes which
argument order, you define a *profile* once and then say `gpupt bind win11`.

Everything is safe to explore: `--dry-run` prints exactly what a command would
do, and commands that change the host refuse to run without root.

```
gpupt <command> [options]
```

Run it from the repo with `bash scripts/gpupt <command>` (or copy the script to
your PATH and run `gpupt <command>` directly). Anything that stops a display
manager, rebinds drivers, or writes libvirt hooks needs `sudo`.

---

## Quick start

```bash
# 1. Health check -- exit 0 ok, 1 warn, 2 fail
sudo bash scripts/gpupt doctor

# 2. Define a profile (interactive wizard if you omit --gpu)
bash scripts/gpupt profile add win11 \
    --vm win11-gpu \
    --gpu 0000:01:00.0 --audio 0000:01:00.1 \
    --driver amdgpu --late-bind

# 3. Preview, then do the single-GPU dance
bash scripts/gpupt bind win11 --dry-run
sudo bash scripts/gpupt bind win11        # stops the DM, hands GPU to vfio-pci

# 4. Run the VM
sudo bash scripts/gpupt start win11

# 5. Tear down
sudo bash scripts/gpupt stop win11
sudo bash scripts/gpupt unbind win11      # restores host driver + restarts DM
```

---

## Commands

### Environment check / info

| Command | What it does |
|---------|--------------|
| `doctor [--json]` | Full health check with hints. Exit code: `0` all ok, `1` warnings only, `2` failures |
| `detect [--json\|--compact]` | GPUs with vendor:device IDs, kernel drivers, IOMMU groups, audio pair |
| `groups [PCI ...]` | All IOMMU groups, or just the group(s) a device lives in |
| `config show` | Config file, state file, and log locations |

### Profiles

Profiles are stored in the config file (default `/etc/gpupt/config`,
override with `GPUPT_CONFIG`). The format is INI-style:

```ini
[profile "win11"]
vm = win11-gpu
gpu = 0000:01:00.0
audio = 0000:01:00.1
extra = 0000:01:00.2
driver = amdgpu
mode = single
late_bind = true
on_prepare = /path/to/script
on_release = /path/to/script
```

| Command | What it does |
|---------|--------------|
| `profile list` | Table of profiles, VMs, GPUs |
| `profile show NAME` | Full details of one profile |
| `profile add NAME [flags]` | Create a profile; no `--gpu` starts an interactive wizard |
| `profile edit NAME --set key=value [--set ...]` | Change one or more settings |
| `profile rm NAME` | Delete a profile (asks for confirmation) |

`profile add` flags: `--vm VM`, `--gpu PCI`, `--audio PCI`, `--extra PCI...`
(repeatable), `--driver DRV` (`amdgpu`/`nvidia`/`i915`/...), `--mode
single|dual|auto`, `--late-bind`, `--on-prepare CMD`, `--on-release CMD`.

- `mode single` — the GPU drives the host too (single-GPU passthrough); the host
  driver is unloaded and `vfio-pci` takes over. `mode dual` — the GPU never
  drives the host; no driver dance needed. `mode auto` — `gpupt` inspects
  whether the GPU is currently the host display and picks per run.
- `late_bind` — for AMD RX 9000 (and ReBAR-era RX 6000/7000) cards: let
  `amdgpu` initialize the card at boot, then hand it to vfio-pci on demand.
- `on_prepare` / `on_release` — arbitrary hooks run before the GPU is handed to
  the VM and after it comes back (e.g. suspend USB controllers, toggle a KVM
  switch).

### Lifecycle

| Command | What it does |
|---------|--------------|
| `bind [PROFILE\|PCI...]` | Stop the DM, hand GPU to vfio-pci (per profile mode) |
| `unbind [PROFILE\|PCI...]` | Restore the host driver, restart the DM |
| `start PROFILE [--no-bind]` | Start the VM; skips binding if `--no-bind` (already bound) |
| `stop PROFILE [--no-unbind] [--force]` | Stop the VM; skips rebinding if `--no-unbind`; `--force` = `virsh destroy` |
| `status [PROFILE]` | VMs, GPUs, and profiles in one view |

`bind`/`unbind` flags (accepted before or after the profile/PCI arguments):
`--driver DRV`, `--mode M`, `--no-dm` (skip stopping/restarting the display
manager — you handle the console yourself), `--dry-run` (print the plan without
touching anything).

```bash
bash scripts/gpupt bind win11 --dry-run
sudo bash scripts/gpupt bind 0000:01:00.0 --driver amdgpu --no-dm
```

### Integration

| Command | What it does |
|---------|--------------|
| `hooks install\|remove\|status` | Generate/remove the libvirt `qemu` hook at `/etc/libvirt/hooks/qemu` |
| `recover GPU [AUDIO] [DRIVER]` | Force-unbind + PCI reset + rebind a stuck GPU after a crash |
| `log [N]` | Last N log lines (default 50) |
| `complete [profiles]` | Shell-completion helper (print the command word list) |
| `version` | Print the version |

The generated libvirt hook runs the profile's `bind` before the VM starts and
`unbind` after it stops, so the GPU is handed over automatically instead of
typing `gpupt bind`/`gpupt unbind` around every `virsh start`.

`recover` is the same routine as `scripts/gpu_recovery.sh`: stop any VM holding
the device, force-unbind from vfio-pci, fire the PCI reset quirk, rebind the
host driver, and restart the DM.

---

## Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `GPUPT_CONFIG` | `/etc/gpupt/config` | Profile/config file |
| `GPUPT_STATE` | `/var/lib/gpupt/state` | Bind/unbind state tracking |
| `GPUPT_LOG` | `/var/log/gpupt.log` | Where `gpupt log` reads from |

Global flags: `--quiet` (suppress progress output), `--no-color` (also honor
the `NO_COLOR` environment variable).

`gpupt doctor` is a good final sanity check after setup — it checks CPU
virtualization, IOMMU, kernel parameters, vfio modules, packages, libvirt, and
reports a pass/warn/fail summary with exit codes you can script against.
