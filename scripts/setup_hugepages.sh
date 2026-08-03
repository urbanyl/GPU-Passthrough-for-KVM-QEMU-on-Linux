#!/bin/bash
# setup_hugepages.sh -- Configure huge pages for the VM
# Usage: sudo bash scripts/setup_hugepages.sh MEMORY_MB [PAGE_SIZE]
#   MEMORY_MB  Amount of guest memory in MB to back with huge pages
#   PAGE_SIZE  KiB (default 2048). Use 1048576 for 1 GB pages.
#
# Also enables the MemoryBacking hugepages option on a VM if a name is given:
#   sudo bash scripts/setup_hugepages.sh 16384 2048 win11-gpu
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: sudo bash $0 MEMORY_MB [PAGE_SIZE_KIB] [VM_NAME]"
    echo ""
    echo "  MEMORY_MB      Guest RAM to back with huge pages (MB)"
    echo "  PAGE_SIZE_KIB  Page size in KiB: 2048 (default) or 1048576 (1G)"
    echo "  VM_NAME        Optional: also set hugepages in the VM XML"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

MEM_MB="$1"
PAGE_SIZE_KIB="${2:-2048}"
VM_NAME="${3:-}"

# Validate
if ! [[ "$MEM_MB" =~ ^[0-9]+$ ]] || [ "$MEM_MB" -le 0 ]; then
    echo -e "${RED}Invalid memory size: $MEM_MB${NC}"
    exit 1
fi

case "$PAGE_SIZE_KIB" in
    2048)    PAGES=$((MEM_MB / 2)) ;;
    1048576) PAGES=$MEM_MB ;;
    *)       echo -e "${RED}Unsupported page size: $PAGE_SIZE_KIB (use 2048 or 1048576)${NC}"; exit 1 ;;
esac

# Check huge pages availability
HUGEPAGES_SUPPORTED=$(grep -c Hugepagesize /proc/meminfo || true)
if [ "$HUGEPAGES_SUPPORTED" -eq 0 ]; then
    echo -e "${RED}Huge pages not supported by this kernel/config.${NC}"
    exit 1
fi

# Current size
CURRENT_SIZE=$(grep Hugepagesize /proc/meminfo | awk '{print $2}')
echo -e "${GREEN}Current huge page size: ${CURRENT_SIZE} kB${NC}"
echo -e "  Allocating ${PAGES} pages (${PAGE_SIZE_KIB} KiB each) = ${MEM_MB} MB"
echo ""

if [ "$PAGE_SIZE_KIB" -eq 2048 ]; then
    echo "  Setting vm.nr_hugepages = $PAGES"
    echo "$PAGES" > /proc/sys/vm/nr_hugepages
    echo "  Persisting via /etc/sysctl.d/99-hugepages.conf"
    echo "vm.nr_hugepages = $PAGES" > /etc/sysctl.d/99-hugepages.conf
    sysctl -p /etc/sysctl.d/99-hugepages.conf >/dev/null
else
    echo -e "${YELLOW}1 GB pages must be reserved at boot via kernel parameters:${NC}"
    echo "  default_hugepagesz=1G hugepagesz=1G hugepages=${PAGES}"
    echo "  Add these to your bootloader config and reboot for 1G pages to take effect."
fi

echo ""
echo "  Current state:"
grep -E 'HugePages_(Total|Free)|Hugepagesize' /proc/meminfo
echo ""

# Optional: set hugepages in the VM XML
if [ -n "$VM_NAME" ]; then
    if ! virsh dominfo "$VM_NAME" >/dev/null 2>&1; then
        echo -e "${YELLOW}VM '$VM_NAME' not found, skipping XML update.${NC}"
    else
        echo -e "${GREEN}Adding hugepages memoryBacking to $VM_NAME XML...${NC}"
        # Insert a <memoryBacking> block before <os> if not present
        virsh dumpxml "$VM_NAME" > /tmp/hp.xml
        if ! grep -q "<memoryBacking>" /tmp/hp.xml; then
            sed -i '0,/<os>/s//<memoryBacking>\n    <hugepages>\n      <page size="'"$PAGE_SIZE_KIB"'" unit="KiB"\/>\n    <\/hugepages>\n  <\/memoryBacking>\n\n  <os>/' /tmp/hp.xml
            virsh define /tmp/hp.xml >/dev/null
            echo "  XML updated. Shut down and restart the VM for it to take effect."
        else
            echo "  VM already has a memoryBacking block. Edit manually if the size differs."
        fi
        rm -f /tmp/hp.xml
    fi
fi

echo ""
echo -e "${GREEN}Done.${NC}"
echo ""
echo "Notes:"
echo "  - The VM must be <memoryBacking><hugepages> enabled in its XML."
echo "  - Reboot the host for sysctl to apply if not applied live."
echo "  - 1G pages: reserve via kernel parameters and reboot."
echo ""
