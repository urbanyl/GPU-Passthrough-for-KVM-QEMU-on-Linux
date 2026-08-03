# VM XML Snippets

Ready-to-paste blocks for your domain XML (`sudo virsh edit <vm>`). Adapt paths, addresses, and IDs to your hardware.

---

## Shared Memory Device (Looking Glass)

Adds the IVSHMEM device Looking Glass uses to capture the guest GPU output.

**File:** `looking-glass.xml`

```xml
<shmem name='looking-glass'>
  <model type='ivshmem-plain'/>
  <size unit='M'>64</size>
</shmem>
```

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

After editing, validate:

```bash
sudo virsh define /etc/libvirt/qemu/<vm>.xml
sudo virsh start <vm>
```
