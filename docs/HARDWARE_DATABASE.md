# Hardware Database

Community-known hardware behavior for GPU passthrough. Always cross-check with [r/VFIO](https://reddit.com/r/vfio), [Level1Techs](https://forums.level1techs.com), and the [VFIO GPU reset list](https://docs.google.com/spreadsheets/d/1uvS2UCw2tHh4t1U3v0N1jCdOqUj1BcB0X6L3W4v3Qj8) for your exact model.

---

## Table of Contents

- [CPU Support](#cpu-support)
- [Motherboard Considerations](#motherboard-considerations)
- [NVIDIA GPUs](#nvidia-gpus)
- [AMD GPUs](#amd-gpus)
- [Intel GPUs](#intel-gpus)
- [Known Problematic Hardware](#known-problematic-hardware)
- [Community Resources](#community-resources)

---

## CPU Support

| CPU | Virtualization | IOMMU | Notes |
|-----|----------------|-------|-------|
| Intel Core (K series) | VT-x | VT-d | VT-d present on most desktop SKUs |
| Intel Core (non-K, U/H mobile) | VT-x | Sometimes disabled | Check BIOS/ARK; some mobile chips lack VT-d |
| Intel Xeon | VT-x | VT-d | Full support; good for multiple VMs |
| AMD Ryzen (all) | AMD-V | AMD-Vi | Best value — full support everywhere |
| AMD EPYC | AMD-V | AMD-Vi | Full support |

**Laptop caveats:** many laptops do not expose VT-d/IOMMU to the OS or have it fused off. GPU passthrough on laptops is hit-or-miss. Desktops are the reliable platform.

---

## Motherboard Considerations

The motherboard decides most of your passthrough experience:

- **IOMMU group quality** — how many devices share a group (see [README §4](../README.md#4-check-iommu-groups))
- **ACS support** — present on most modern boards; enables clean group separation
- **BIOS options** — VT-d/AMD-Vi, Above 4G Decoding, Resizable BAR, ACS, Primary Display
- **PCIe slot layout** — the x16 slot should be directly wired to the CPU (not through the chipset) for best bandwidth

**Before buying, search for:**
- `"[motherboard model] IOMMU groups"`
- `"[motherboard model] VFIO"`
- Check [Level1Techs board thread](https://forums.level1techs.com/c/pci-passthrough/5)

---

## NVIDIA GPUs

| Generation | Passthrough Quality | Notes |
|-----------|---------------------|-------|
| GTX 700 (Kepler) | Poor | Reset issues on many models |
| GTX 900 (Maxwell) | Fair | Known reset bugs; needs workarounds |
| GTX 10 (Pascal) | Good | Error 43 workaround needed; no ReBAR |
| GTX 16 (Turing) | Good | Error 43 workaround needed |
| RTX 20 (Turing) | Good | Works well |
| RTX 30 (Ampere) | Very good | ReBAR supported; excellent |
| RTX 40 (Ada) | Very good | ReBAR supported; excellent |
| RTX 50 (Blackwell) | Good | Newer — check reports |

**Key facts:**
- **All GeForce cards need the `kvm=hidden` + `vendor_id` workaround** (Error 43)
- RTX 30/40/50 support Resizable BAR
- Quadro/Tesla/RTX A-series: designed for virtualization, work out of the box, no Error 43
- If your card is also the host display GPU, you must do single-GPU passthrough (complex) or add a second GPU

---

## AMD GPUs

| Generation | Passthrough Quality | Notes |
|-----------|---------------------|-------|
| RX 400/500 (Polaris) | Poor-Fair | vendor-reset module helps; many reset bugs |
| RX Vega | Fair | Reset issues on reference cards; vendor-reset |
| RX 5000 (RDNA1) | Good | Some reset issues |
| RX 6000 (RDNA2) | Very good | ReBAR set up via amdgpu init; dynamic binding recommended |
| RX 7000 (RDNA3) | Very good | Dynamic binding recommended |
| RX 9000 (RDNA4) | Good | **Requires** amdgpu init first (dynamic late binding) |

**Key facts:**
- AMD GPUs do **not** need the Error 43 workaround (open-source-friendly)
- **RX 9000 series must use dynamic binding** — bind directly to vfio-pci at boot and the GPU stays uninitialized (see [README §6a](../README.md#6a-amd-gpu-dynamic-binding-late-binding))
- Polaris/Vega: install [vendor-reset](https://github.com/gnif/vendor-reset) if reset fails between VM sessions
- Some AMD cards expose extra functions (USB-C controller, etc.) — pass all functions in the same IOMMU group

---

## Intel GPUs

| GPU | Passthrough Quality | Notes |
|-----|---------------------|-------|
| Intel iGPU (any recent) | N/A as guest | Best used as the **host** display GPU (free) |
| Arc A-series (dGPU) | Fair | Support improving; check current reports |

**Best practice:** use the Intel iGPU for the host desktop and pass a discrete NVIDIA/AMD card to the VM. This is the cheapest and cleanest dual-GPU setup — the iGPU needs no special handling.

If you want to pass an Intel iGPU itself (for Intel Quick Sync in a Linux guest), that is supported on some platforms but is more involved and beyond this guide's scope.

---

## Known Problematic Hardware

| Hardware | Issue | Workaround |
|----------|-------|-----------|
| NVIDIA GTX 900 | Reset bug | Host reboot between sessions |
| NVIDIA GTX 1050/1060 (some) | Reset bug | Reboot, or try newer driver |
| AMD Polaris RX 400/500 | Reset bug | vendor-reset module |
| AMD Vega reference | Reset bug | vendor-reset module |
| Some X470/B450 boards | Bad IOMMU groups | ACS override patch or BIOS update |
| Older Intel mobile (laptops) | VT-d missing | No passthrough possible |
| GPU with USB-C on die | Extra PCI function | Pass the USB-C function too |

---

## Community Resources

- [r/VFIO](https://reddit.com/r/vfio) — the main community
- [Level1Techs Passthrough forum](https://forums.level1techs.com/c/pci-passthrough/5)
- [Arch Wiki: PCI passthrough via OVMF](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [VFIO GPU reset database](https://docs.google.com/spreadsheets/d/1uvS2UCw2tHh4t1U3v0N1jCdOqUj1BcB0X6L3W4v3Qj8) — check your GPU's FLR behavior
- [vendor-reset](https://github.com/gnif/vendor-reset) — AMD reset fix

---

## Buying Advice Summary

1. **CPU:** any Ryzen or modern Intel desktop (needs VT-x/VT-d or AMD-V/AMD-Vi)
2. **Motherboard:** known-good IOMMU grouping, ACS, Above 4G Decoding, ReBAR
3. **Guest GPU:** NVIDIA RTX 30/40/50 or AMD RX 6000/7000/9000
4. **Host GPU:** Intel iGPU (free) or a cheap secondary card
5. **RAM:** 32 GB+ (host + 16 GB+ guest)
6. **Storage:** NVMe for the guest disk
