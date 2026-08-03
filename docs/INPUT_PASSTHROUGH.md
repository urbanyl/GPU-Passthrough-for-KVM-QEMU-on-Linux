# Input Passthrough

Wire your physical keyboard and mouse directly into the guest for low-latency input — or pass whole USB controllers for the ultimate setup.

---

## Table of Contents

- [Why Direct Input Matters](#why-direct-input-matters)
- [Option 1: USB Controller Passthrough (Best)](#option-1-usb-controller-passthrough-best)
- [Option 2: evdev Hooks (Keyboard + Mouse)](#option-2-evdev-hooks-keyboard--mouse)
- [Option 3: SPICE + virtio Input](#option-3-spice--virtio-input)
- [Hybrid Approaches](#hybrid-approaches)
- [Troubleshooting Input](#troubleshooting-input)

---

## Why Direct Input Matters

Games and desktop use feel sluggish through SPICE's virtual tablet because input travels host -> SPICE -> QEMU. Direct input (USB controller or evdev) puts your devices straight into the guest:

- Sub-millisecond input latency
- Full polling rate support (1000 Hz mice)
- No input filtering
- Keyboard layout passthrough

---

## Option 1: USB Controller Passthrough (Best)

Pass the entire USB controller holding your keyboard/mouse into the VM.

```bash
# Find your USB controllers
lspci -nn | grep -i usb

# Check IOMMU groups
bash scripts/check_iommu_groups.sh
```

Attach to the VM:

```bash
sudo virsh attach-device win11-gpu --live /dev/stdin <<'EOF'
<hostdev mode='subsystem' type='pci'>
  <source>
    <address domain='0x0000' bus='0x06' slot='0x00' function='0x0'/>
  </source>
</hostdev>
EOF
```

**Pros:** perfect fidelity, all USB peripherals on that controller go too.
**Cons:** the host loses those ports. Keep a keyboard/mouse on the host's other controller so you can still operate Linux.

---

## Option 2: evdev Hooks (Keyboard + Mouse)

evdev lets libvirt claim specific input devices on the host and feed them directly into the guest at the kernel level.

### Step 1 — Identify your devices

```bash
ls -l /dev/input/by-id/
```

Look for entries like:

```
usb-046d_c52b_event-kbd -> ../event3
usb-046d_c077_event-mouse -> ../event6
usb-046d_c077_event-joystick -> ../event7
```

### Step 2 — Set input permissions

QEMU must be able to read `/dev/input/event*`. Add your user to the `input` group:

```bash
sudo usermod -aG input $USER
```

Or create a udev rule (more robust across reboots):

```bash
# /etc/udev/rules.d/60-qemu-input.rules
KERNEL=="event*", SUBSYSTEM=="input", GROUP="kvm", MODE="0660"
```

Reload:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Step 3 — Add to the VM XML

```xml
<input type='evdev'>
  <source dev='/dev/input/by-id/usb-046d_c52b_event-kbd' grab='all'/>
</input>
<input type='evdev'>
  <source dev='/dev/input/by-id/usb-046d_c077_event-mouse' grab='all'/>
</input>
```

> `grab='all'` captures the devices even if the VM window does not have focus.

### Step 4 — Grab/release shortcut

evdev is **active all the time** once the VM runs — your keyboard/mouse disappear from the host. To release them back to the host, use the default toggle:

- **Ctrl+Alt** (most libvirt builds) — press to release the device to the host, press again to grab

> Some users prefer `grab='toggle'` instead of `grab='all'` if they want the devices to release on focus loss. Choose what fits your workflow.

### Step 5 — Security: qemu.conf lockdown

evdev input requires your user (or `kvm` group) to access `/dev/input/*`. On distros with strict AppArmor, add:

```
# /etc/apparmor.d/local/usr.lib.libvirt.virt-aa-helper
/run/user/*/  rw,
```

If QEMU is blocked, check `dmesg` and the AppArmor log:

```bash
sudo dmesg | grep -i apparmor
sudo aa-status
```

---

## Option 3: SPICE + virtio Input

Default virt-manager setup — a virtual tablet/keyboard over SPICE.

```xml
<input type='mouse' bus='ps2'/>
<input type='keyboard' bus='ps2'/>
```

Or with the virtio input (slightly better):

```xml
<input type='tablet' bus='virtio'>
  <address type='pci' domain='0x0000' bus='0x00' slot='0x0a' function='0x0'/>
</input>
```

Fine for setup and light use. Not for competitive gaming.

---

## Hybrid Approaches

- **USB mouse + evdev keyboard**: pass the mouse's USB device and use evdev for the keyboard
- **SPICE for daily use, evdev toggled for gaming**: `grab='toggle'` lets you switch
- **Two mice**: one for host, one passed to guest — a common dual-GPU luxury

---

## Troubleshooting Input

| Symptom | Fix |
|---------|-----|
| Input devices not captured | Verify paths in `/dev/input/by-id/`; check permissions (`groups` shows `input`?); reload udev |
| Keyboard/mouse work only when VM focused | Use `grab='all'` in evdev source |
| Devices captured but not working | Wrong event node (keyboard vs mouse reversed); use `evtest` to confirm |
| Ctrl+Alt does not release | Check libvirt version; try `grab='toggle'`; some builds use **Ctrl+Alt+G** |
| evdev grabbed at boot, host unusable | Use `grab='toggle'` or don't autostart the VM; keep an SSH login ready |
| High polling mouse drops input | Use USB controller passthrough instead of evdev redirection |
| AppArmor denies input | Add the virt-aa-helper local rule above |

---

## Checklist

- [ ] Method chosen (controller passthrough / evdev / SPICE)
- [ ] Host keeps one working keyboard+mouse
- [ ] User in `input` group or udev rule in place
- [ ] evtest verified device paths
- [ ] Toggle key known (Ctrl+Alt)
- [ ] SSH fallback available for single-GPU/evdev setups
