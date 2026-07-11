#!/bin/bash
# check_iommu_groups.sh -- List all IOMMU groups and their devices
# Usage: bash scripts/check_iommu_groups.sh
# Requires: root or read access to /sys/kernel/iommu_groups
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  IOMMU Group Inspection${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if IOMMU is active
if [ ! -d /sys/kernel/iommu_groups ]; then
    echo -e "${RED}ERROR: /sys/kernel/iommu_groups does not exist.${NC}"
    echo ""
    echo "IOMMU may not be enabled. Check:"
    echo "  1. BIOS: Enable VT-d (Intel) or AMD-Vi (AMD)"
    echo "  2. Kernel parameters: intel_iommu=on iommu=pt"
    echo "  3. dmesg | grep -i iommu"
    exit 1
fi

GROUP_COUNT=$(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d 2>/dev/null | wc -l)
echo "Total IOMMU groups: $GROUP_COUNT"
echo ""

if [ "$GROUP_COUNT" -eq 0 ]; then
    echo -e "${RED}No IOMMU groups found. IOMMU may not be active.${NC}"
    exit 1
fi

GPU_GROUPS=""

for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
    GROUP_NUM=${g##*/}
    DEVICES=""

    for d in $g/devices/*; do
        if [ -d "$d" ]; then
            DEVICE_INFO=$(lspci -nns "${d##*/}")
            DEVICES="${DEVICES}    ${DEVICE_INFO}\n"

            # Check if this device is a VGA or 3D controller (likely a GPU)
            if echo "$DEVICE_INFO" | grep -qiE 'vga|3d'; then
                GPU_GROUPS="${GPU_GROUPS} ${GROUP_NUM}"
            fi
        fi
    done

    echo -e "${GREEN}IOMMU Group ${GROUP_NUM}:${NC}"
    echo -e "$DEVICES"
done

# Highlight GPU groups
if [ -n "$GPU_GROUPS" ]; then
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  GPU IOMMU Groups:${NC}"
    echo -e "${YELLOW}========================================${NC}"
    for GROUP in $GPU_GROUPS; do
        echo -e "  ${YELLOW}Group ${GROUP}${NC}"
        for d in /sys/kernel/iommu_groups/"$GROUP"/devices/*; do
            if [ -d "$d" ]; then
                echo "    $(lspci -nns "${d##*/}")"
            fi
        done
        echo ""
    done

    echo -e "${YELLOW}For passthrough, your GPU should ideally be isolated in its own group${NC}"
    echo -e "${YELLOW}or grouped only with devices you can also pass through.${NC}"
fi
