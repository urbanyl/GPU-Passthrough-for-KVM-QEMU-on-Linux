# Audio Guide

Getting sound in and out of a GPU passthrough VM, from HDMI audio on the passed GPU to low-latency network audio with Scream.

---

## Table of Contents

- [HDMI/DisplayPort Audio (from the passed GPU)](#hmidisplayport-audio-from-the-passed-gpu)
- [SPICE Audio](#spice-audio)
- [PulseAudio / PipeWire on the Host](#pulseaudio--pipewire-on-the-host)
- [Scream (network audio)](#scream-network-audio)
- [USB Audio](#usb-audio)
- [Microphone Input](#microphone-input)
- [Troubleshooting Audio](#troubleshooting-audio)

---

## HDMI/DisplayPort Audio (from the passed GPU)

If you pass through the GPU's `.1` audio function, the guest drives the monitor's speakers/headphones directly through HDMI/DP once the GPU driver is installed.

**Requirements:**
- Both `01:00.0` (GPU) and `01:00.1` (audio) passed to the guest
- Guest GPU driver installed (installs the HDMI audio endpoint)
- Sound set to the HDMI output in the guest

**Latency:** lowest possible — no virtualization in the audio path.

**Caveat:** the audio only plays to whatever the GPU is connected to. If you use Looking Glass / Moonlight instead of a physical monitor, there is no HDMI sink, so use Scream or SPICE audio instead.

---

## SPICE Audio

Simple and works with the virtio display; quality is fine for most use.

**In the domain XML:**

```xml
<audio id='1' type='spice'/>
```

**Host prerequisites:**

```bash
# PulseAudio
sudo usermod -aG audio $USER
sudo usermod -aG pulse-access $USER

# PipeWire (modern default on most distros)
sudo apt install pipewire-pulse      # Debian/Ubuntu
sudo pacman -S pipewire pipewire-pulse    # Arch
sudo dnf install pipewire-pulse      # Fedora
```

Then restart the VM and select the SPICE audio device in the guest.

**Caveat:** SPICE audio can stutter under load. For gaming, prefer Scream or HDMI audio.

---

## PulseAudio / PipeWire on the Host

For host audio routing (and to hear the guest through the host's speakers), libvirt connects to the user session's sound server automatically via the `QEMU_AUDIO` variables.

**PipeWire users often need:**

```
# /etc/libvirt/qemu.conf
user = "yourusername"
group = "libvirt"
```

And ensure your user owns the session (`loginctl enable-linger $USER` on systemd distros so the session audio server survives reboots for headless hosts).

**Direct host playback of guest audio** (rarely needed now that Scream exists) uses PulseAudio with:

```bash
pactl load-module module-null-sink sink_name=vm
# Route QEMU to the sink, then monitor the sink on the host speakers
```

---

## Scream (network audio)

Scream streams the Windows guest's audio over the network to a host receiver — the best latency path for gaming audio when the monitor is not connected to the GPU.

**Guest (Windows):** install the Scream driver ([github.com/duncanthrax/scream](https://github.com/duncanthrax/scream)), set it as the default playback device.

**Host (Linux):** install the receiver:

```bash
# Debian/Ubuntu
sudo apt install scream   # if packaged; otherwise build from source

# Build from source
git clone https://github.com/duncanthrax/scream
cd scream/Receivers/unix
make
```

Run the receiver (optionally pointed at a multicast group):

```bash
./scream -i multicast
```

Audio from the guest now appears as a host playback device.

**Latency:** roughly equivalent to local audio for most games; requires guest and host on the same LAN (the default libvirt NAT works fine).

---

## USB Audio

Passing a USB audio interface or headset into the guest gives low-latency audio with zero host audio stack involvement.

```bash
# Identify the USB device
lsusb

# Redirect through virt-manager: VM > Redirect USB Device
```

For stable, always-on audio, pass through the entire USB controller the device is attached to (see [USB_PASSTHROUGH.md](USB_PASSTHROUGH.md)). This is the go-to solution for USB DACs and gaming headsets.

---

## Microphone Input

Microphones are audio *input* — the same transport options apply in reverse:

- **SPICE**: guest mic -> SPICE channel -> host mic. Simple, but latency varies.
- **Scream**: currently playback-only (no mic). Use SPICE or USB passthrough for mic.
- **USB passthrough**: lowest latency, best quality.

For Discord/game chat, USB headset passthrough is the recommended path.

---

## Troubleshooting Audio

| Symptom | Fix |
|---------|-----|
| No audio at all | Set HDMI output in guest; ensure `.1` audio function passed; restart VM |
| Crackling/stuttering | Prefer HDMI or USB audio over SPICE; set CPU governor to performance |
| SPICE audio works only after login | Start the guest audio session before login (enable-linger) |
| No audio over Moonlight/Parsec | Moonlight/Parsec carry audio only if the host streams it; use Scream for host-independent audio |
| Audio device missing in guest | Install guest drivers (GPU driver for HDMI, Scream driver, or virtio-win audio) |
| Headset mic not working | Pass the USB controller through instead of redirecting the device |

---

## Recommended Setup by Use Case

| Scenario | Recommendation |
|----------|----------------|
| Monitor connected to passed GPU | HDMI audio (built-in, zero config) |
| Looking Glass / host speakers | Scream |
| Gaming headset / mic | USB controller passthrough |
| Quick setup | SPICE audio |
