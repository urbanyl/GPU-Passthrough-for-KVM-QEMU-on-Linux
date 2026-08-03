#!/bin/bash
# create_disk.sh -- Create a VM disk image
# Usage: bash scripts/create_disk.sh PATH SIZE_GB [qcow2|raw] [preallocation]
# Examples:
#   bash scripts/create_disk.sh /var/lib/libvirt/images/win11.qcow2 100
#   bash scripts/create_disk.sh /var/lib/libvirt/images/win11.qcow2 100 qcow2 metadata
#   bash scripts/create_disk.sh /var/lib/libvirt/images/win11.raw 100 raw
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: bash $0 PATH SIZE_GB [qcow2|raw] [preallocation]"
    echo ""
    echo "  PATH           Full path to the disk image"
    echo "  SIZE_GB        Size in gigabytes"
    echo "  FORMAT         qcow2 (default) or raw"
    echo "  PREALLOCATION  full | metadata | off (qcow2 only, default metadata)"
    exit 1
}

if [ $# -lt 2 ]; then
    usage
fi

DISK_PATH="$1"
SIZE_GB="$2"
FORMAT="${3:-qcow2}"
PREALLOC="${4:-metadata}"

if ! command -v qemu-img >/dev/null 2>&1; then
    echo -e "${RED}qemu-img not found. Install qemu-utils (Debian/Ubuntu) or qemu (Arch).${NC}"
    exit 1
fi

# Validate size
if ! [[ "$SIZE_GB" =~ ^[0-9]+$ ]] || [ "$SIZE_GB" -le 0 ]; then
    echo -e "${RED}Invalid size: $SIZE_GB (must be a positive integer)${NC}"
    exit 1
fi

# Check target directory
DIRNAME_PATH=$(dirname "$DISK_PATH")
if [ ! -d "$DIRNAME_PATH" ]; then
    echo -e "${YELLOW}Directory $DIRNAME_PATH does not exist. Creating it...${NC}"
    mkdir -p "$DIRNAME_PATH"
fi

if [ -e "$DISK_PATH" ]; then
    echo -e "${RED}File already exists: $DISK_PATH${NC}"
    echo "Choose a different path or remove the file first."
    exit 1
fi

echo -e "${GREEN}Creating $FORMAT disk image: $DISK_PATH (${SIZE_GB}G)${NC}"

case "$FORMAT" in
    qcow2)
        qemu-img create -f qcow2 -o preallocation="$PREALLOC" "$DISK_PATH" "${SIZE_GB}G"
        ;;
    raw)
        qemu-img create -f raw -o preallocation="$PREALLOC" "$DISK_PATH" "${SIZE_GB}G"
        ;;
    *)
        echo -e "${RED}Unsupported format: $FORMAT (use qcow2 or raw)${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Disk created.${NC}"
echo ""
echo "To attach to a VM, add to the domain XML:"
echo ""
case "$FORMAT" in
    qcow2)
        echo "  <disk type='file' device='disk'>"
        echo "    <driver name='qemu' type='qcow2' cache='none' io='native' discard='unmap'/>"
        echo "    <source file='${DISK_PATH}'/>"
        echo "    <target dev='vda' bus='virtio'/>"
        echo "  </disk>"
        ;;
    raw)
        echo "  <disk type='file' device='disk'>"
        echo "    <driver name='qemu' type='raw' cache='none' io='native' discard='unmap'/>"
        echo "    <source file='${DISK_PATH}'/>"
        echo "    <target dev='vda' bus='virtio'/>"
        echo "  </disk>"
        ;;
esac
echo ""
echo "Or with virt-install:"
echo "  --disk path=${DISK_PATH},size=${SIZE_GB},bus=virtio,format=${FORMAT}"
echo ""
