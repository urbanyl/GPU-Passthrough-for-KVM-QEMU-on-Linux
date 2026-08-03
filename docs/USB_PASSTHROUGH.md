# USB Passthrough Guide

Passing USB devices into your VM — from quick per-device redirection to rock-solid full controller passthrough.

---

## Table of Contents

- [When to Use Which Method](#when-to-use-which-method)
- [Method 1: USB Redirection (usbredir)](#method-1-usb-redirection-usbredir)
- [Method 2: USB Controller (PCI) Passthrough](#method-2-usb-controller-pci-passthrough)
- [Method 3: Persistent USB Device in XML](#method-3-persistent-usb-device-in-xml)
- [Special Cases](#special-cases)
- [Troubleshooting USB](#troubleshooting-usb)

---

## When to Use Which Method

| Method | Latency | Stability | Best for |
|--------|---------|-----------|----------|
| Redirection (usbredir) | Medium | Good | Occasional devices, quick setup |
| Controller passthrough | Lowest | Excellent | Controllers, VR, DACs, race wheels |
| XML static device | Low | Good | Always-connected devices |

---

## Method 1: USB Redirection (usbredir)

The simplest way. The device stays on the host but is routed into the guest by the SPICE agent.

**GUI:** `virt-manager > VM window > View > Details > Add Hardware > USB Host Device > select device`

**CLI (one-shot):**

```bash
# List USB devices
lsusb

# Redirect
virsh usb-redirect win11-gpu --devname "Kingston DataTraveler"
```

**Persistent redirection via XML** (SPICE channel + `<redirdev>`):

```xml
<redirdev bus='usb' type='spicevmc'>
  <alias name='redir0'/>
  <address type='usb' bus='0' port='1'/>
</redirdev>
```

**Pros:** no IOMMU concerns, hot-pluggable.
**Cons:** extra hop through the host USB stack + SPICE; VR and high-polling devices (mice at 1000 Hz) may feel worse than direct passthrough.

---

## Method 2: USB Controller (PCI) Passthrough

Pass the entire USB controller into the VM. The guest drives the physical ports directly — best latency and stability.

**1. Find your USB controllers:**

```bash
lspci -nn | grep -i usb
```

Example:
```
04:00.0 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] X570 USB 4.0
06:00.0 USB controller [0c03]: Advanced Micro Devices, Inc. [AMD] X570 USB 3.2
```

**2. Check IOMMU groups** — the controller must be in a group you can pass:

```bash
bash scripts/check_iommu_groups.sh
```

**3. Add to the VM:**

```bash
sudo virsh attach-device win11-gpu --live /dev/stdin <<'EOF'
<hostdev mode='subsystem' type='pci'>
  <source>
    <address domain='0x0000' bus='0x06' slot='0x00' function='0x0'/>
  </source>
</hostdev>
EOF
```

**4. (Optional) bind to vfio-pci** so the host never grabs it:

```
# /etc/modprobe.d/vfio.conf
options vfio-pci ids=1022:149c,1022:149c
```

**5. Plug devices into the passed-through ports.**

**Pros:** hardware-level passthrough, best for VR (the HMD is really two USB devices), DACs, race wheels, multiple devices.
**Cons:** that USB controller (and everything on it) is unavailable to the host; requires a spare USB controller (most boards have 2+); controller must be in a clean IOMMU group.

> **Keep one USB controller on the host** for your keyboard/mouse so you always have a way to control Linux.

---

## Method 3: Persistent USB Device in XML

For an always-connected single device without controller passthrough:

```xml
<hostdev mode='subsystem' type='usb' managed='yes'>
  <source>
    <vendor id='0x046d'/>
    <product id='0xc539'/>
  </source>
</hostdev>
```

Find IDs with `lsusb`:
```
Bus 003 Device 002: ID 046d:c539 Logitech, Inc. Lightspeed Receiver
```

---

## Special Cases

### USB Hubs

Passing through a USB hub device passes the hub itself; devices plugged into it after boot may not appear. Controller passthrough avoids this.

### Power management / sleep

USB devices that sleep (some docks, external drives) can drop out of the VM. Disable USB autosuspend on the host if you redirect:

```bash
# /etc/udev/rules.d/60-usb-autosuspend.rules
ACTION=="add", SUBSYSTEM=="usb", ATTR{power/autosuspend}="-1"
```

### Bluetooth controllers

Bluetooth is a USB controller internally. Pass the `Bluetooth Host Controller` PCI device or a USB BT dongle through.

### Tablets / pens / VR

- Wacom tablets: redirection usually works; controller passthrough is more stable for continuous pressure streams
- VR headsets: **always** use controller passthrough — they expose multiple USB interfaces and need the low latency

### Printers

Redirection works, but a network printer (AirPrint, IPP, SMB) avoids USB entirely — recommended.

---

## Troubleshooting USB

| Symptom | Fix |
|---------|-----|
| Device not visible in guest | Verify it appears in `lsusb` on host; use redirection; check guest USB device manager |
| Device appears but disconnects randomly | Disable host autosuspend; use controller passthrough; try a powered hub |
| Device passes through on boot but drops | Use `managed='yes'` in hostdev XML; keep it plugged at boot |
| VR headset stutters | Use controller passthrough, not redirection |
| Host can't find the USB controller to pass | Some controllers are grouped with the GPU or SATA — check IOMMU groups |
| USB 3.0 runs at USB 2.0 speed in guest | Ensure the full controller (both xHCI functions) is passed, or use redirection for that device |
| No USB at all in VM after reboot | Re-add the hostdev entry; verify libvirt defined the XML (was it `--live` only?) |

---

## Checklist

- [ ] Decide: redirection vs controller passthrough
- [ ] Keep one USB controller for the host
- [ ] For VR: controller passthrough mandatory
- [ ] Disable USB autosuspend for redirected devices
- [ ] Verify devices survive reboot (`managed='yes'`)
