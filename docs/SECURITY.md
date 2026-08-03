# Security Considerations

GPU passthrough trades some host isolation for performance. This document explains the trade-offs and how to keep your system reasonably safe.

---

## Table of Contents

- [What Passthrough Means for Security](#what-passthrough-means-for-security)
- [ACS Override Risks](#acs-override-risks)
- [SELinux / AppArmor](#selinux--apparmor)
- [UEFI Secure Boot](#uefi-secure-boot)
- [Hypervisor CPUID and vmport](#hypervisor-cpuid-and-vmport)
- [Network Exposure](#network-exposure)
- [Guest to Host Attack Surface](#guest-to-host-attack-surface)
- [Minimal Risk Checklist](#minimal-risk-checklist)

---

## What Passthrough Means for Security

Normally QEMU emulates every device and the guest never touches hardware directly. **With VFIO passthrough, the guest directly controls a physical PCI device** (the GPU), DMA-ing into memory the host has explicitly assigned to it via the IOMMU.

- The IOMMU restricts what memory the GPU can touch (good)
- The guest's GPU driver is bug-for-bug the same as bare metal — a compromised guest GPU driver has the same access as on a real machine
- **There is no hypervisor between the guest and the GPU**

**Conclusion:** treat the guest as a semi-trusted machine, like a second physical computer. Don't put sensitive host data in a guest you don't control.

---

## ACS Override Risks

The ACS override patch (and the `pcie_acs_override=downstream,multifunction` kernel parameter) forces the kernel to split IOMMU groups that the hardware did not separate.

**What it breaks:**
- Devices that were designed to share an IOMMU group can now DMA into each other's regions
- If a hostile device (or a malicious driver on the host for that device) targets another device in the "same" group, the IOMMU no longer protects it
- This is exactly the protection VFIO is supposed to guarantee

**Mitigations:**
- Use ACS override **only** when you cannot achieve clean groups by moving slots or updating the BIOS
- Prefer enabling ACS in the firmware if the board exposes it
- Never run ACS override on a host that holds data you cannot afford to lose
- Understand: this is a per-boot workaround, not a permanent security feature

**Related kernel parameters (equally scoped):**
```
pcie_acs_override=downstream,multifunction
```

---

## SELinux / AppArmor

Linux hardening can silently break passthrough. Two directions:

**1. They block QEMU from accessing hardware:**
- AppArmor denies `/dev/vfio/*` or `/dev/input/*` access
- SELinux denies VFIO device access

**2. They protect the host from the guest:**
- This is **good** — keep them enabled and tune, do not disable wholesale

**Recommended approach — keep the MAC system on, allow QEMU:**

Debian/Ubuntu (AppArmor):
```bash
# Check for denials
sudo dmesg | grep -i apparmor
sudo aa-status

# Allow QEMU access (libvirt usually ships a profile that already works)
# If denied, create a local override:
# /etc/apparmor.d/local/usr.lib.libvirt.virt-aa-helper
/var/lib/libvirt/** rwk,
```

Fedora/RHEL (SELinux):
```bash
sudo ausearch -m avc --ts recent
# Allow QEMU/VFIO if blocked:
sudo setsebool -P virt_use_sysfs 1
# Or check audit2allow for a targeted module
```

> Disabling SELinux/AppArmor entirely (`setenforce 0` / `aa-disable`) is the last resort. It fixes denials but removes real protection.

---

## UEFI Secure Boot

**Host:** Secure Boot can remain **enabled** if your distro signs its kernel (Ubuntu, Fedora, Arch with sbctl). The kernel parameters still apply; only unsigned out-of-tree modules (like `vendor-reset` or a custom ACS override build) require Secure Boot to be off or the module signed.

**Guest:** Windows 11 requires Secure Boot + TPM in the guest. Both are supported by libvirt:

```xml
<os>
  <loader readonly='yes' type='pflash'>/usr/share/OVMF/OVMF_CODE.secboot.fd</loader>
  <nvram>/var/lib/libvirt/qemu/nvram/win11_VARS.fd</nvram>
  <secure boot='yes'/>
</os>
```

And a virtual TPM:

```xml
<tpm model='tpm-crb'>
  <backend type='emulator' version='2.0'/>
</tpm>
```

**Note:** NVIDIA Error 43 fix is independent of Secure Boot — they can coexist.

---

## Hypervisor CPUID and vmport

The `kvm=hidden` + `vendor_id` settings are about NVIDIA driver detection, but they also slightly reduce guest awareness of the hypervisor — a marginal hardening bonus, not a security boundary.

`<vmport state='off'/>` disables VMware's virtual mouse port — nothing to do with security, but recommended for correctness.

---

## Network Exposure

- If the guest is bridged to your LAN, it is a first-class citizen on the network — firewall it like a real PC
- NAT networking hides the guest behind the host — the safer default
- Never expose SPICE/virt-manager ports to the internet
- Sunshine/Moonlight: put them behind your LAN or a VPN, never port-forward without a strong password
- Parsec uses E2E encryption by design

---

## Guest to Host Attack Surface

The guest can attack the host through:
- **Kernel bugs** in QEMU/KVM (rare, patched — keep the host updated)
- **vfio-pci DMA bugs** (the IOMMU limits but does not eliminate risk)
- **USB redirection** — a malicious USB device could exploit the usbredir stack
- **virtiofs shared folders** — the guest can read/write host files in shared dirs (that's the point; keep shared dirs scoped)

**Practical hardening:**
- Keep host kernel + libvirt + QEMU updated
- Scope shared folders to a dedicated directory
- Don't give the guest host-only SSH keys
- Run untrusted guests with fewer vCPUs/RAM and no shared folders
- Consider running the VM as a dedicated user with no extra privileges

---

## Minimal Risk Checklist

- [ ] IOMMU groups clean **without** ACS override if possible
- [ ] If ACS override used, understand the risk and accept it consciously
- [ ] SELinux/AppArmor enabled and tuned, not disabled
- [ ] Host kernel/QEMU/libvirt up to date
- [ ] Guest on NAT or firewalled bridge
- [ ] Shared folders scoped to a dedicated directory
- [ ] Remote tools (Sunshine/Parsec/SPICE) not exposed publicly
- [ ] Guest treated as untrusted data-wise (back up important guest data)
