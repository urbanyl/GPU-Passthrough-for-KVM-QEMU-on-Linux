#!/bin/bash
# status_check.sh -- One-command health check for a GPU passthrough setup
# Usage: bash scripts/status_check.sh [--verbose]
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

VERBOSE=false
[ "${1:-}" = "--verbose" ] && VERBOSE=true

PASS=0
WARN=0
FAIL=0

section() { echo -e "\n${CYAN}==== $1 ====${NC}"; }
ok()       { echo -e "  ${GREEN}[OK]${NC} $1"; PASS=$((PASS+1)); }
warn()     { echo -e "  ${YELLOW}[WARN]${NC} $1"; WARN=$((WARN+1)); }
fail()     { echo -e "  ${RED}[FAIL]${NC} $1"; FAIL=$((FAIL+1)); }

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  GPU Passthrough Status Check${NC}"
echo -e "${CYAN}========================================${NC}"

# 1. Kernel
section "Kernel"
echo "  $(uname -r) ($(uname -m))"
if grep -qE 'vmx|svm' /proc/cpuinfo; then
    ok "CPU virtualization supported"
else
    fail "CPU virtualization (VT-x/AMD-V) not detected"
fi
if [ -e /dev/kvm ]; then
    ok "/dev/kvm present"
else
    fail "/dev/kvm missing"
fi

# 2. IOMMU
section "IOMMU"
if [ -d /sys/kernel/iommu_groups ]; then
    GROUP_COUNT=$(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d 2>/dev/null | wc -l)
    ok "IOMMU groups directory present ($GROUP_COUNT groups)"
else
    fail "/sys/kernel/iommu_groups missing (IOMMU not enabled?)"
fi
if dmesg 2>/dev/null | grep -qiE 'dmar|amd-vi|vt-d'; then
    ok "IOMMU active in dmesg"
else
    warn "IOMMU not seen in dmesg (need root to read dmesg?)"
fi

# 3. VFIO modules
section "VFIO Modules"
if lsmod 2>/dev/null | grep -q vfio_pci; then
    ok "vfio-pci loaded"
else
    warn "vfio-pci not loaded (normal if using AMD dynamic late binding)"
fi
if [ -f /etc/modprobe.d/vfio.conf ]; then
    ok "/etc/modprobe.d/vfio.conf present"
    if $VERBOSE; then
        echo "  Content:"
        grep -v '^#' /etc/modprobe.d/vfio.conf | sed 's/^/    /'
    fi
else
    warn "/etc/modprobe.d/vfio.conf missing"
fi

# 4. Kernel parameters
section "Kernel Parameters"
if grep -qiE 'iommu|dmar' /proc/cmdline; then
    ok "IOMMU kernel parameter present"
else
    fail "No IOMMU kernel parameter (check /etc/default/grub or systemd-boot entry)"
fi
if grep -q 'vfio-pci.ids' /proc/cmdline; then
    ok "vfio-pci.ids on command line"
else
    warn "vfio-pci.ids not on command line (OK for AMD late-binding setups)"
fi

# 5. GPU binding
section "GPU Binding"
GPUS=$(lspci 2>/dev/null | grep -iE 'vga|3d' | awk '{print $1}' || true)
if [ -z "$GPUS" ]; then
    fail "No VGA/3D controllers found"
else
    for PCI in $GPUS; do
        DESC=$(lspci -s "$PCI" | sed 's/^[^ ]* *[0-9a-f]*: *//')
        DRIVER=$(lspci -k -s "$PCI" 2>/dev/null | grep "Kernel driver in use" | awk -F': ' '{print $2}' || echo "none")
        if [ "$DRIVER" = "vfio-pci" ]; then
            ok "$PCI vfio-pci -- $DESC"
        elif [ "$DRIVER" = "none" ]; then
            warn "$PCI no driver -- $DESC"
        else
            warn "$PCI bound to $DRIVER (host driver; normal if it is the host GPU or late-binding)"
        fi
    done
fi

# 6. Virtualization packages
section "Virtualization Tools"
for TOOL in qemu-system-x86_64 virsh virt-install virt-manager; do
    if command -v "$TOOL" >/dev/null 2>&1; then
        ok "$TOOL installed"
    else
        warn "$TOOL missing"
    fi
done

# 7. libvirtd
section "libvirt"
if systemctl is-active --quiet libvirtd 2>/dev/null; then
    ok "libvirtd active"
else
    fail "libvirtd not active"
fi

# 8. VMs
section "VMs"
VMS=$(virsh list --all 2>/dev/null | tail -n +3 | grep -v '^$' || true)
if [ -z "$VMS" ]; then
    warn "No VMs defined"
else
    echo "  $VMS"
fi

# Summary
section "Summary"
echo -e "  ${GREEN}OK: $PASS${NC}  ${YELLOW}WARN: $WARN${NC}  ${RED}FAIL: $FAIL${NC}"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}Some checks failed. Fix these before proceeding.${NC}"
    echo "  - IOMMU: enable VT-d/AMD-Vi in BIOS + add kernel parameters (README step 5)"
    echo "  - vfio-pci binding: see TROUBLESHOOTING.md 'GPU Bound to Host After Reboot'"
elif [ "$WARN" -gt 0 ]; then
    echo -e "${YELLOW}Some warnings. Review the output above.${NC}"
else
    echo -e "${GREEN}All checks passed. Your setup looks good.${NC}"
fi
echo ""
