#!/bin/bash
# install.sh -- Verify environment and print next steps
# Usage: bash install.sh
# This script does NOT make system changes. It checks your environment
# and tells you what to do next.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  GPU Passthrough Environment Check${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

PASS=0
FAIL=0
WARN=0

check() {
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo -e "  ${GREEN}[PASS]${NC} $name"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} $name"
        FAIL=$((FAIL + 1))
    fi
}

warn_check() {
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo -e "  ${GREEN}[PASS]${NC} $name"
        PASS=$((PASS + 1))
    else
        echo -e "  ${YELLOW}[WARN]${NC} $name"
        WARN=$((WARN + 1))
    fi
}

# System checks
echo -e "${CYAN}[System Requirements]${NC}"
warn_check "CPU virtualization (VT-x/AMD-V)" grep -qiE 'vmx|svm' /proc/cpuinfo
check "Kernel modules directory" test -d /lib/modules
warn_check "IOMMU active" dmesg | grep -qiE 'iommu|dmar|amd-vi|vt-d'
echo ""

# Tool checks
echo -e "${CYAN}[Required Tools]${NC}"
check "lspci installed" which lspci
check "lsmod installed" which lsmod
check "modprobe available" which modprobe
warn_check "qemu-system-x86_64 installed" which qemu-system-x86_64
warn_check "virsh installed" which virsh
warn_check "virt-manager installed" which virt-manager
echo ""

# File checks
echo -e "${CYAN}[System Files]${NC}"
check "KVM device exists" test -e /dev/kvm
warn_check "VFIO modules available" test -d /sys/module/vfio_pci
warn_check "IOMMU groups directory" test -d /sys/kernel/iommu_groups
echo ""

# GPU detection
echo -e "${CYAN}[GPU Detection]${NC}"
if command -v lspci &>/dev/null; then
    VGA_COUNT=$(lspci | grep -ciE 'vga|3d' || true)
    if [ "$VGA_COUNT" -gt 0 ]; then
        echo -e "  ${GREEN}Found $VGA_COUNT VGA/3D controller(s):${NC}"
        lspci | grep -iE 'vga|3d' | while IFS= read -r line; do
            PCI_ADDR=$(echo "$line" | awk '{print $1}')
            VENDOR_ID=$(lspci -n -s "$PCI_ADDR" 2>/dev/null | grep -oE '\[[0-9a-f]{4}:[0-9a-f]{4}\]' | head -1 | tr -d '[]' || echo "??:??")
            DRIVER=$(lspci -k -s "$PCI_ADDR" 2>/dev/null | grep "Kernel driver in use" | awk -F': ' '{print $2}' || echo "none")
            echo "    $PCI_ADDR [$VENDOR_ID] driver=$DRIVER -- $(echo "$line" | sed 's/^[^ ]* *[0-9a-f]*: *//')"
        done
    else
        echo -e "  ${RED}No VGA/3D controllers detected.${NC}"
    fi
else
    echo -e "  ${RED}lspci not available. Install pciutils.${NC}"
fi
echo ""

# Summary
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Summary${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "  ${GREEN}Passed: $PASS${NC}"
echo -e "  ${RED}Failed: $FAIL${NC}"
echo -e "  ${YELLOW}Warnings: $WARN${NC}"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}Some checks failed. Review the output above.${NC}"
fi

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Next Steps${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo "  1. Run the setup script for your distro:"
echo "       sudo bash setup/debian-ubuntu.sh   (Debian/Ubuntu)"
echo "       sudo bash setup/arch.sh            (Arch Linux)"
echo "       sudo bash setup/fedora.sh          (Fedora)"
echo ""
echo "  2. Enable IOMMU in BIOS/UEFI"
echo ""
echo "  3. Configure kernel parameters (see README.md Step 5)"
echo ""
echo "  4. Rebuild initramfs and reboot"
echo ""
echo "  5. Verify VFIO binding:"
echo "       bash scripts/check_vfio_binding.sh"
echo ""
echo "  6. Create your VM (see README.md Step 9)"
echo ""
