# VM XML Snippets

Ready-to-paste blocks for your domain XML (`sudo virsh edit <vm>`). Adapt paths, addresses, and IDs to your hardware.

---

## Shared Memory Device (Looking Glass)

The Looking Glass project **recommends the KVMFR kernel module** for the shared
memory device — it gives DMA transfers, which are critical when your host runs
on an iGPU. The plain `ivshmem-plain` shmem device is considered legacy and
only supported for special edge cases (e.g. VM-to-VM).

**File:** `looking-glass.xml` — KVMFR commandline block

```xml
<qemu:commandline>
  <qemu:arg value='-device'/>
  <qemu:arg value='{"driver":"ivshmem-plain","id":"shmem0","memdev":"looking-glass"}'/>
  <qemu:arg value='-object'/>
  <qemu:arg value='{"qom-type":"memory-backend-file","id":"looking-glass","mem-path":"/dev/kvmfr0","size":33554432,"share":true}'/>
</qemu:commandline>
```

The `<domain>` element must carry the QEMU namespace for this to parse:

```xml
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
```

**Prerequisites:**

```bash
# 1. Load the kvmfr module (32 MiB = 33554432 bytes, adjust to your resolution)
echo "options kvmfr static_size_mb=32" | sudo tee /etc/modprobe.d/kvmfr.conf
sudo modprobe kvmfr

# 2. Let QEMU open /dev/kvmfr0
#    /etc/libvirt/qemu.conf: uncomment cgroup_device_acl and add "/dev/kvmfr0"
#    AppArmor: echo "/dev/kvmfr0 rw," >> /etc/apparmor.d/local/abstractions/libvirt-qemu
sudo systemctl restart libvirtd
```

**Official docs (always current):**
- https://looking-glass.io/docs/stable
- https://looking-glass.io/docs/bleeding
- KVMFR setup: https://looking-glass.io/docs/B7/ivshmem_kvmfr/

**Size formula** (must match `static_size_mb`): `(width × height × pixel size × 2) / 1 MiB + 10 MiB`, where pixel size is 4 for SDR or 8 for HDR.

## evdev Input Passthrough

Feeds your physical keyboard/mouse directly into the guest. Requires the [udev rule](../udev/60-qemu-input.rules) and your user in the input group.

**File:** `input-evdev.xml`

```xml
<input type='evdev'>
  <source dev='/dev/input/by-id/usb-046d_c52b_event-kbd' grab='all'/>
</input>
<input type='evdev'>
  <source dev='/dev/input/by-id/usb-046d_c077_event-mouse' grab='all'/>
</input>
```

Replace the device paths with your own (`ls -l /dev/input/by-id/`).

## virtiofs Shared Folder

Near-native shared folder between the Linux host and a Linux guest.

**File:** `virtiofs.xml`

```xml
<filesystem type='mount' accessmode='passthrough'>
  <driver type='virtiofs'/>
  <source dir='/home/you/shared'/>
  <target dir='shared'/>
</filesystem>
```

In the guest:

```bash
sudo mkdir -p /mnt/shared
sudo mount -t virtiofs shared /mnt/shared
```

## Persistent USB Device Passthrough

Attach a specific USB device to the VM at boot.

**File:** `usb-device.xml`

```xml
<hostdev mode='subsystem' type='usb' managed='yes'>
  <source>
    <vendor id='0x046d'/>
    <product id='0xc539'/>
  </source>
</hostdev>
```

## PCI Host Device (GPU function)

Pass a single PCI function. `0000:01:00.0` and `0000:01:00.1` are the GPU and its audio.

**File:** `pci-hostdev.xml`

```xml
<hostdev mode='subsystem' type='pci' managed='yes'>
  <source>
    <address domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
  </source>
</hostdev>
```

## Enable for the whole VM

| Snippet | How to apply |
|---------|--------------|
| Any `<devices>` snippet | Paste inside the `<devices>` element, then `virsh start <vm>` |
| `<memoryBacking>` | Paste before the `<os>` element |
| `<qemu:commandline>` (Looking Glass) | Paste after the `</devices>` element; add the `xmlns:qemu` namespace to `<domain>` |

After editing, validate:

```bash
sudo virsh define /etc/libvirt/qemu/<vm>.xml
sudo virsh start <vm>
```
