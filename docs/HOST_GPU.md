# Host Display: Keeping a Working Screen While Your GPU is in the VM

The GPU you pass to the VM is gone from the host. So you need *something* for
the host to draw on. Pick your poison here before you start tearing your hair
out over "everything turns black when I start the VM".

## Option 1: Second GPU (the "classic" way)

Two GPUs. One stays with the host, one goes to the VM.

- **Best host GPU:** an Intel integrated GPU if your CPU has one. Free, no
  setup beyond leaving the iGPU as the primary display, and it doesn't care
  about your passthrough card.
- If you have two discrete GPUs, the VFIO card should be the one NOT driving
  the primary display. In BIOS, set the boot/primary GPU to the host card and
  let the other one get picked up by vfio-pci.
- Pro tip: `lspci` will show your two cards as e.g. `00:02.0` (iGPU) and
  `01:00.0` (discrete). Give the *discrete* one to the VM.

## Option 2: Single GPU + second monitor off the iGPU

If your CPU has an iGPU but your motherboard only routes the *discrete* card's
outputs to real monitors... the iGPU still works for headless/remote. Combine
with `docs/REMOTE_ACCESS.md` and you have a fully working setup with one GPU.

## Option 3: Headless host

No host display at all. The host runs as a server (SSH only), and the guest
GPU is the only display. Works great for:

- Gaming rigs that are really just a console
- vGPU/no-monitor servers
- Any setup where the host screen is never needed

If you go this route: enable a basic serial console or SSH for the host so you
can still debug when the GPU is passed.

## Setting the primary display in BIOS

The exact setting name varies by motherboard vendor, but it's usually under:

- **ASUS:** `Advanced > NB Configuration > Primary Display`
- **MSI:** `Settings > Advanced > Integrated Graphics Configuration > Initiate
  Graphics Adapter`
- **Gigabyte:** `Settings > Miscellaneous > Init Display First`
- **ASRock:** `Advanced > Chipset Configuration > Primary Graphics Adapter`

Set it to the *host* GPU (iGPU if you have one). This is the #1 thing people
miss when they "lose display on the host".

## NVIDIA driver on the host

NVIDIA's host driver is picky. If the host is also running the NVIDIA driver
and you pass a second NVIDIA card, set the VM card's `kernel driver in use` to
`vfio-pci` BEFORE the NVIDIA driver grabs it — the dynamic hooks in
`examples/libvirt-hooks/qemu` handle this automatically at VM start.

## "Black screen after reboot"

Almost always one of these:

1. Primary display still set to the card you pass to the VM
2. `vfio-pci` binding a card the host needs for boot
3. NVIDIA reset state (see ARCHITECTURE.md — flashing your original vBIOS helps)
4. The card not bound to vfio-pci *before* the display manager starts

Fix order: check BIOS primary display, check `lspci -nnk` shows `vfio-pci` on
the VM card, then look at the hooks.

## Related reading

- [docs/GUIDE.md](./GUIDE.md) — full setup steps
- [docs/REMOTE_ACCESS.md](./REMOTE_ACCESS.md) — headless/remote host usage
- [docs/TROUBLESHOOTING.md](./TROUBLESHOOTING.md) — black screen, no output
- [docs/HARDWARE_DATABASE.md](./HARDWARE_DATABASE.md) — known-good combos
