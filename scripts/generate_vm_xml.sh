#!/bin/bash
# generate_vm_xml.sh -- Generate a VM XML configuration with GPU passthrough
# Usage: bash scripts/generate_vm_xml.sh [OPTIONS]
#   --name NAME           VM name (default: win11-gpu)
#   --memory MB           RAM in MB (default: 16384)
#   --vcpus N             Number of vCPUs (default: 8)
#   --gpu PCI_ADDR        GPU PCI address (e.g., 0000:01:00.0)
#   --audio PCI_ADDR      Audio device PCI address (e.g., 0000:01:00.1)
#   --disk PATH           Path to disk image (default: /var/lib/libvirt/images/win11.qcow2)
#   --iso PATH            Path to Windows ISO
#   --virtio-iso PATH     Path to VirtIO ISO
#   --output PATH         Output file (default: stdout)
set -euo pipefail

# Defaults
VM_NAME="win11-gpu"
VM_MEMORY=16384
VM_VCPUS=8
GPU_PCI=""
AUDIO_PCI=""
DISK_PATH="/var/lib/libvirt/images/win11.qcow2"
WIN_ISO=""
VIRTIO_ISO=""
OUTPUT=""

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --name)     VM_NAME="$2"; shift 2 ;;
        --memory)   VM_MEMORY="$2"; shift 2 ;;
        --vcpus)    VM_VCPUS="$2"; shift 2 ;;
        --gpu)      GPU_PCI="$2"; shift 2 ;;
        --audio)    AUDIO_PCI="$2"; shift 2 ;;
        --disk)     DISK_PATH="$2"; shift 2 ;;
        --iso)      WIN_ISO="$2"; shift 2 ;;
        --virtio-iso) VIRTIO_ISO="$2"; shift 2 ;;
        --output)   OUTPUT="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --name NAME           VM name (default: win11-gpu)"
            echo "  --memory MB           RAM in MB (default: 16384)"
            echo "  --vcpus N             vCPU count (default: 8)"
            echo "  --gpu PCI_ADDR        GPU PCI address"
            echo "  --audio PCI_ADDR      Audio device PCI address"
            echo "  --disk PATH           Disk image path"
            echo "  --iso PATH            Windows ISO path"
            echo "  --virtio-iso PATH     VirtIO ISO path"
            echo "  --output PATH         Output file (default: stdout)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required fields
if [ -z "$GPU_PCI" ]; then
    echo "Error: --gpu is required. Run with --help for usage."
    exit 1
fi

# Auto-detect audio PCI if not provided
if [ -z "$AUDIO_PCI" ]; then
    GPU_SLOT=$(echo "$GPU_PCI" | cut -d. -f1)
    AUDIO_PCI=$(lspci | grep -E "^${GPU_SLOT}\.[0-9]+ Audio" | awk '{print "0000:" $1}' || echo "")
    if [ -n "$AUDIO_PCI" ]; then
        echo "Auto-detected audio device: $AUDIO_PCI"
    else
        echo "Warning: No audio device auto-detected. The VM may lack GPU audio."
    fi
fi

# Calculate CPU pinning (simple: use cores 1..vcpus, skip core 0 for host)
CPU_PINNING=""
for ((i=0; i<VM_VCPUS; i++)); do
    HOST_CORE=$((i + 1))
    CPU_PINNING="${CPU_PINNING}    <vcpupin vcpu='${i}' cpuset='${HOST_CORE}'/>\n"
done

# Build the XML
XML="<?xml version='1.0' encoding='UTF-8'?>
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  <name>${VM_NAME}</name>
  <memory unit='MiB'>${VM_MEMORY}</memory>
  <vcpu placement='static'>${VM_VCPUS}</vcpu>

  <cputune>
$(echo -e "$CPU_PINNING")    <emulatorpin cpuset='0'/>
  </cputune>

  <os>
    <type arch='x86_64' machine='pc-q35-8.2'>hvm</type>
    <loader readonly='yes' type='pflash'>/usr/share/OVMF/OVMF_CODE.fd</loader>
    <nvram>/var/lib/libvirt/qemu/nvram/${VM_NAME}_VARS.fd</nvram>
    <bootmenu enable='no'/>
  </os>

  <features>
    <acpi>
      <apic/>
    </acpi>
    <hyperv mode='custom'>
      <relaxed state='on'/>
      <vapic state='on'/>
      <spinlocks state='on' retries='8191'/>
      <vpindex state='on'/>
      <synic state='on'/>
      <stimer state='on'/>
      <reset state='on'/>
      <vendor_id state='on' value='123456789ab'/>
      <frequencies state='on'/>
    </hyperv>
    <kvm>
      <hidden state='on'/>
    </kvm>
    <vmport state='off'/>
    <ioapic driver='kvm'/>
  </features>

  <clock offset='localtime'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
    <timer name='tsc' present='yes' mode='native'/>
  </clock>

  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>

    <!-- Main disk -->
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='none' io='native' discard='unmap'/>
      <source file='${DISK_PATH}'/>
      <target dev='vda' bus='virtio'/>
    </disk>"

# Add Windows ISO if provided
if [ -n "$WIN_ISO" ]; then
    XML="${XML}

    <!-- Windows ISO -->
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='${WIN_ISO}'/>
      <target dev='sdc' bus='sata'/>
    </disk>"
fi

# Add VirtIO ISO if provided
if [ -n "$VIRTIO_ISO" ]; then
    XML="${XML}

    <!-- VirtIO Drivers ISO -->
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='${VIRTIO_ISO}'/>
      <target dev='sdb' bus='sata'/>
    </disk>"
fi

XML="${XML}

    <!-- Network -->
    <interface type='network'>
      <mac address='52:54:00:$(head -c3 /dev/urandom | od -An -tx1 | tr -d ' ' | head -c5 | sed 's/\(..\)/\1:/g;s/:$//')'/>
      <source network='default'/>
      <model type='virtio'/>
    </interface>

    <!-- SPICE display -->
    <graphics type='spice' port='-1' autoport='yes' listen type='none'>
      <image compression='off'/>
    </graphics>

    <video>
      <model type='none'/>
    </video>

    <!-- USB controller -->
    <controller type='usb' model='qemu-xhci' ports='8'/>

    <!-- Sound -->
    <sound model='ich9'/>

    <!-- Input -->
    <input type='mouse' bus='ps2'/>
    <input type='keyboard' bus='ps2'/>"

# Add GPU passthrough
XML="${XML}

    <!-- GPU passthrough -->
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x0000' bus='0x$(echo "$GPU_PCI" | cut -d: -f2 | cut -d. -f1)' slot='0x$(printf '%02x' "0x$(echo "$GPU_PCI" | cut -d: -f2 | cut -d. -f1 | sed 's/^0*//')" 2>/dev/null || echo "$(echo "$GPU_PCI" | cut -d: -f2 | cut -d. -f1)")' function='0x0'/>
      </source>
      <address type='pci' domain='0x0000' bus='0x01' slot='0x00' function='0x0' multifunction='on'/>
    </hostdev>"

# Add audio device passthrough if available
if [ -n "$AUDIO_PCI" ]; then
    AUDIO_BUS=$(echo "$AUDIO_PCI" | cut -d: -f2 | cut -d. -f1)
    AUDIO_SLOT=$(echo "$AUDIO_PCI" | cut -d: -f2 | cut -d. -f1)
    AUDIO_FUNC=$(echo "$AUDIO_PCI" | cut -d. -f2)
    AUDIO_SLOT_HEX=$(printf '0x%02x' "0x$AUDIO_SLOT" 2>/dev/null || echo "0x$AUDIO_SLOT")
    AUDIO_FUNC_HEX=$(printf '0x%x' "0x$AUDIO_FUNC" 2>/dev/null || echo "0x$AUDIO_FUNC")

    XML="${XML}
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x0000' bus='0x${AUDIO_BUS}' slot='${AUDIO_SLOT_HEX}' function='${AUDIO_FUNC_HEX}'/>
      </source>
      <address type='pci' domain='0x0000' bus='0x01' slot='0x00' function='0x1'/>
    </hostdev>"
fi

XML="${XML}
  </devices>

  <seclabel type='dynamic' model='apparmor' relabel='yes'/>
</domain>"

# Output
if [ -n "$OUTPUT" ]; then
    echo "$XML" > "$OUTPUT"
    echo "VM XML written to: $OUTPUT"
    echo ""
    echo "To apply:"
    echo "  sudo virsh define $OUTPUT"
    echo "  sudo virsh start ${VM_NAME}"
else
    echo "$XML"
fi
