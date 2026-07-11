#!/bin/bash
# detect_gpu.sh -- Detect GPUs and display vendor:device IDs for VFIO passthrough
# Usage: bash scripts/detect_gpu.sh
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  GPU Detection for VFIO Passthrough${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Detect all VGA/3D controllers
echo -e "${GREEN}[VGA/3D Controllers]${NC}"
echo "--------------------------------------------"
VGA_DEVICES=$(lspci | grep -iE 'vga|3d' || true)

if [ -z "$VGA_DEVICES" ]; then
    echo -e "${RED}No VGA/3D controllers found.${NC}"
    exit 1
fi

while IFS= read -r line; do
    PCI_ADDR=$(echo "$line" | awk '{print $1}')
    VENDOR_ID=$(lspci -n -s "$PCI_ADDR" | grep -oE '\[[0-9a-f]{4}:[0-9a-f]{4}\]' | head -1 | tr -d '[]')
    VENDOR=$(echo "$VENDOR_ID" | cut -d: -f1)
    DEVICE=$(echo "$VENDOR_ID" | cut -d: -f2)

    if [ "$VENDOR" = "10de" ]; then
        VENDOR_NAME="NVIDIA"
    elif [ "$VENDOR" = "1002" ]; then
        VENDOR_NAME="AMD"
    elif [ "$VENDOR" = "8086" ]; then
        VENDOR_NAME="Intel"
    else
        VENDOR_NAME="Unknown"
    fi

    echo "  PCI Address:  $PCI_ADDR"
    echo "  Vendor:Device: $VENDOR_ID ($VENDOR_NAME)"
    echo "  Description:  $(echo "$line" | sed 's/^[^ ]* *[0-9a-f]*: *//')"
    echo "  VFIO ID:      $VENDOR:$DEVICE"
    echo ""
done <<< "$VGA_DEVICES"

# Detect audio devices that may belong to GPUs
echo -e "${GREEN}[Audio Devices]${NC}"
echo "--------------------------------------------"
AUDIO_DEVICES=$(lspci | grep -i 'audio' || true)

if [ -n "$AUDIO_DEVICES" ]; then
    while IFS= read -r line; do
        PCI_ADDR=$(echo "$line" | awk '{print $1}')
        VENDOR_ID=$(lspci -n -s "$PCI_ADDR" | grep -oE '\[[0-9a-f]{4}:[0-9a-f]{4}\]' | head -1 | tr -d '[]')
        VENDOR=$(echo "$VENDOR_ID" | cut -d: -f1)
        DEVICE=$(echo "$VENDOR_ID" | cut -d: -f2)

        if [ "$VENDOR" = "10de" ]; then
            VENDOR_NAME="NVIDIA"
        elif [ "$VENDOR" = "1002" ]; then
            VENDOR_NAME="AMD"
        elif [ "$VENDOR" = "8086" ]; then
            VENDOR_NAME="Intel"
        else
            VENDOR_NAME="Unknown"
        fi

        # Check IOMMU group to see if it's likely paired with a GPU
        IOMMU_GROUP=$(basename "$(readlink -f /sys/bus/pci/devices/0000:${PCI_ADDR}/iommu_group)" 2>/dev/null || echo "?")

        echo "  PCI Address:  $PCI_ADDR"
        echo "  Vendor:Device: $VENDOR_ID ($VENDOR_NAME)"
        echo "  IOMMU Group:  $IOMMU_GROUP"
        echo "  Description:  $(echo "$line" | sed 's/^[^ ]* *[0-9a-f]*: *//')"
        echo "  VFIO ID:      $VENDOR:$DEVICE"
        echo ""
    done <<< "$AUDIO_DEVICES"
else
    echo "  No audio devices found."
    echo ""
fi

# Generate suggested VFIO config
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Suggested VFIO Configuration${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${YELLOW}Review the VGA and audio devices above.${NC}"
echo -e "${YELLOW}Add the vendor:device IDs of the GPU you want to pass through.${NC}"
echo ""
echo "# /etc/modprobe.d/vfio.conf"
echo "# options vfio-pci ids=VENDOR:DEVICE,VENDOR:DEVICE"
echo ""
echo "# /etc/default/grub (append to GRUB_CMDLINE_LINUX_DEFAULT)"
echo "# intel_iommu=on iommu=pt vfio-pci.ids=VENDOR:DEVICE,VENDOR:DEVICE rd.driver.pre=vfio-pci"
echo ""
echo -e "${GREEN}Replace VENDOR:DEVICE with actual IDs from above.${NC}"
