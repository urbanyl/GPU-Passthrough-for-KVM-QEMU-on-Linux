# libvirt Hooks

libvirt hooks let you run commands when a VM lifecycle event happens (`prepare`, `start`, `release`, `stopped`, etc.). They are the cleanest way to automate single-GPU passthrough and AMD GPU dynamic binding.

## Installation

```bash
sudo mkdir -p /etc/libvirt/hooks
sudo cp qemu /etc/libvirt/hooks/qemu
sudo chmod +x /etc/libvirt/hooks/qemu
```

Edit the variables at the top of the script:

```bash
VM_NAME="win11-gpu"        # must match your VM name
GPU_PCI="0000:01:00.0"     # your GPU PCI address
AUDIO_PCI="0000:01:00.1"   # GPU audio function
GPU_IDS="10de:1af2,10de:1af9"  # lspci -nn IDs
HOST_DRIVER="nvidia"       # nvidia | amdgpu | nouveau
AMD_DYNAMIC_BIND="no"      # "yes" for AMD RX 9000+ (keep amdgpu loaded, just unbind)
```

## Testing

```bash
# Enable verbose hook logging
echo 1 | sudo tee /etc/libvirt/hooks/qemu.d/start.log 2>/dev/null || true
sudo virsh start win11-gpu
sudo journalctl -u libvirtd --since "1 minute ago" --no-pager
```

**Always keep SSH available** while testing single-GPU hooks. If the display manager does not restart, SSH is your only way back in.

## Event Reference

| Event | When it fires |
|-------|---------------|
| `prepare` | Before the VM starts (do the GPU handover here) |
| `start` | Just after the VM starts |
| `started` | VM fully started |
| `stopped` | VM stopped cleanly |
| `release` | After the VM stops (restore the GPU here) |
| `reconnect` | QEMU reconnects (hibernation/resume scenarios) |

## Notes

- Hooks must be **executable** and owned by root
- Always `|| true` on fallible sysfs writes so a missing device does not abort the script
- `modprobe -r vfio-pci` may fail if the module is still in use — the `2>/dev/null || true` guards handle this
- For AMD RX 9000+ set `AMD_DYNAMIC_BIND="yes"` — do not unload `amdgpu`; the card must be initialized by `amdgpu` at boot, then simply unbound and rebound (see [README §6a](../../README.md#6a-amd-gpu-dynamic-binding-late-binding))
