# Networking Guide

All the ways to give your VM network access, from the default NAT to bridged and macvtap setups.

---

## Table of Contents

- [Default NAT Network](#default-nat-network)
- [Bridged Networking](#bridged-networking)
- [MacVTap](#macvtap)
- [VirtIO Multi-Queue](#virtio-multi-queue)
- [Routed / Static IP Options](#routed--static-ip-options)
- [Firewall Notes](#firewall-notes)
- [Troubleshooting Network](#troubleshooting-network)

---

## Default NAT Network

libvirt ships a NAT network out of the box. The VM shares the host IP and outbound traffic works immediately.

```xml
<interface type='network'>
  <source network='default'/>
  <model type='virtio'/>
</interface>
```

**Check status:**

```bash
virsh net-list --all
virsh net-info default
```

**Enable/start:**

```bash
sudo virsh net-start default
sudo virsh net-autostart default
```

**Pros:** zero configuration, safe, host firewall stays simple.
**Cons:** inbound connections to the guest require port forwarding; slightly more NAT latency.

### Port forwarding with NAT

```bash
# From the host to guest 10.0.2.x (example: forward host 33890 -> guest 3389 RDP)
sudo virsh net-edit default
```

Add to the `<forward>` section (requires `iptables`-based libvirt firewall):

```xml
<forward mode='nat'>
  <port dev='enp3s0'/>
</forward>
```

For a specific service, use a host-side iptables rule:

```bash
sudo iptables -t nat -A PREROUTING -p tcp --dport 33890 -i enp3s0 -j DNAT --to-destination 10.0.2.15:3389
```

---

## Bridged Networking

A bridge puts the guest directly on your LAN with its own IP — no NAT. Best for gaming (lowest latency) and for hosting services.

### Create a persistent bridge (bridge-utils)

```bash
# /etc/network/interfaces.d/br0 (Debian/Ubuntu)
auto br0
iface br0 inet dhcp
    bridge_ports enp3s0
    bridge_stp off
    bridge_fd 0
```

Then in the VM:

```xml
<interface type='bridge'>
  <source bridge='br0'/>
  <model type='virtio'/>
</interface>
```

### Using libvirt's managed bridge (Linux `br0`)

```bash
sudo virsh net-define /dev/stdin <<'EOF'
<network>
  <name>hostbridge</name>
  <forward mode='bridge'/>
  <bridge name='br0'/>
</network>
EOF
sudo virsh net-start hostbridge
sudo virsh net-autostart hostbridge
```

**Pros:** guest on LAN, low latency, works with services.
**Cons:** more setup, needs a physical NIC to bridge.

> **Wireless caveat:** you cannot bridge a Wi-Fi interface the same way you bridge Ethernet. For Wi-Fi hosts use macvtap or a NAT setup.

---

## MacVTap

MacVTap gives the guest direct access to a physical interface without a bridge — often the simplest "bridged-like" option for Wi-Fi or when the host uses a single NIC.

```xml
<interface type='direct'>
  <source dev='wlp2s0' mode='bridge'/>
  <model type='virtio'/>
</interface>
```

**Important caveat:** in macvtap `bridge` mode the **host cannot talk to the guest** over that interface (works both directions with `vepa` on supporting switches, and both directions with `private`). Use macvtap when the guest needs LAN access but the host-to-guest path is not required.

---

## VirtIO Multi-Queue

For throughput and to avoid a single-queue bottleneck:

```xml
<interface type='network'>
  <source network='default'/>
  <model type='virtio'/>
  <driver name='vhost' queues='4'>
    <host mq='on'/>
    <guest mq='on'/>
  </driver>
</interface>
```

In the Windows guest, enable RSS on the NetKVM adapter (Properties > Advanced > RSS = enabled, set 4-8 receive queues). In a Linux guest:

```bash
ethtool -L eth0 combined 4
```

`queues` should not exceed the number of vCPUs (or the physical cores they map to).

---

## Routed / Static IP Options

### Assign a static IP in the guest

Windows: `netsh interface ip set address name="Ethernet" static 192.168.1.50 255.255.255.0 192.168.1.1`

Linux: NetworkManager or `/etc/systemd/network` as usual.

### Multiple NICs

Add several `<interface>` entries for separate networks (LAN + dedicated host-VM link).

---

## Firewall Notes

### libvirt's own firewall (firewalld/nftables)

On Fedora/RHEL and recent Debian, libvirt uses `firewalld` or `nftables`. If the VM has no connectivity:

```bash
sudo firewall-cmd --reload               # Fedora
sudo systemctl restart libvirtd
```

Ensure the `libvirt` zone is active:

```bash
sudo firewall-cmd --list-all --zone=libvirt
```

### AppArmor/SELinux

If the guest loses network after an AppArmor profile update, reload profiles:

```bash
sudo systemctl reload apparmor    # Debian/Ubuntu
sudo systemctl reload selinux     # SELinux-based distros
```

---

## Troubleshooting Network

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#network-not-working-in-guest) for the guest-side checklist.

**Host-side quick checks:**

```bash
# Is the bridge up?
ip link show br0
# Is the default network running?
virsh net-list --all
# Can the VM reach the gateway?
virsh console win11-gpu   # then: ping 10.0.2.2 (NAT gateway)
# Firewall status
sudo firewall-cmd --state
```

**Common fixes:**

| Symptom | Fix |
|---------|-----|
| Guest no internet, host OK | Check NAT forward; restart `libvirtd`; reload firewalld |
| Guest no LAN but internet works | Bridge misconfigured; use NAT or check `br0` config |
| High latency | Use bridge instead of NAT; enable multi-queue |
| Slow transfers | Enable RSS/queues; increase receive buffers |
| macvtap guest unreachable from host | Expected in `bridge` mode; use `vepa` or add second NIC |
