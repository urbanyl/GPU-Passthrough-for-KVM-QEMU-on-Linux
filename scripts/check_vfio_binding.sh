#!/bin/bash
# check_vfio_binding.sh -- Verify that the target GPU is bound to vfio-pci
# Usage: sudo bash scripts/check_vfio_binding.sh [PCI_ADDRESS]
#   If no PCI address is given, checks all VGA/3D controllers
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  VFIO Binding Verification${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if vfio-pci module is loaded
echo -e "${GREEN}[1] VFIO Module Status${NC}"
echo "--------------------------------------------"
if lsmod | grep -q vfio_pci; then
    echo -e "  ${GREEN}vfio-pci module: LOADED${NC}"
else
    echo -e "  ${RED}vfio-pci module: NOT LOADED${NC}"
    echo "  Run: sudo modprobe vfio-pci"
fi
if lsmod | grep -q vfio_iommu; then
    echo -e "  ${GREEN}vfio-iommu module: LOADED${NC}"
else
    echo -e "  ${YELLOW}vfio-iommu module: not loaded (may use alternative IOMMU driver)${NC}"
fi
echo ""

# Check VFIO module parameters
echo -e "${GREEN}[2] VFIO Configuration${NC}"
echo "--------------------------------------------"
if [ -f /etc/modprobe.d/vfio.conf ]; then
    echo "  /etc/modprobe.d/vfio.conf:"
    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        echo "    $line"
    done < /etc/modprobe.d/vfio.conf
else
    echo -e "  ${RED}/etc/modprobe.d/vfio.conf not found${NC}"
fi
echo ""

# Check VGA/3D device binding
echo -e "${GREEN}[3] VGA/3D Controller Binding${NC}"
echo "--------------------------------------------"

TARGET_DEVICES=""
if [ -n "${1:-}" ]; then
    TARGET_DEVICES="$1"
else
    TARGET_DEVICES=$(lspci | grep -iE 'vga|3d' | awk '{print $1}')
fi

if [ -z "$TARGET_DEVICES" ]; then
    echo -e "  ${RED}No VGA/3D controllers found.${NC}"
    exit 1
fi

BINDING_OK=true

for PCI_ADDR in $TARGET_DEVICES; do
    DRIVER=$(lspci -k -s "$PCI_ADDR" 2>/dev/null | grep "Kernel driver in use" | awk -F': ' '{print $2}' || echo "unknown")
    VENDOR_ID=$(lspci -n -s "$PCI_ADDR" | grep -oE '\[[0-9a-f]{4}:[0-9a-f]{4}\]' | head -1 | tr -d '[]')
    DESC=$(lspci -s "$PCI_ADDR" | sed 's/^[^ ]* *[0-9a-f]*: *//')

    echo "  PCI:     $PCI_ADDR"
    echo "  Device:  $DESC"
    echo "  ID:      $VENDOR_ID"

    if [ "$DRIVER" = "vfio-pci" ]; then
        echo -e "  Driver:  ${GREEN}vfio-pci${NC} (CORRECT)"
    elif [ "$DRIVER" = "unknown" ]; then
        echo -e "  Driver:  ${YELLOW}could not determine${NC}"
        BINDING_OK=false
    else
        echo -e "  Driver:  ${RED}${DRIVER}${NC} (WRONG - should be vfio-pci)"
        BINDING_OK=false
    fi
    echo ""
done

# Summary
echo -e "${GREEN}[4] Summary${NC}"
echo "--------------------------------------------"
if $BINDING_OK; then
    echo -e "  ${GREEN}All devices are correctly bound to vfio-pci.${NC}"
    echo -e "  ${GREEN}The GPU is ready for passthrough.${NC}"
else
    echo -e "  ${RED}Some devices are NOT bound to vfio-pci.${NC}"
    echo ""
    echo "  Troubleshooting steps:"
    echo "  1. Verify PCI IDs in /etc/modprobe.d/vfio.conf"
    echo "  2. Verify kernel parameters in /etc/default/grub"
    echo "  3. Rebuild initramfs: sudo update-initramfs -u"
    echo "  4. Reboot: sudo reboot"
    echo "  5. Check: cat /proc/cmdline | grep vfio"
fi
