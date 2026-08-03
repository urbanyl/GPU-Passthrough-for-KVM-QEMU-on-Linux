#!/bin/bash
# collect_info.sh -- Dump every diagnostic people ask for on r/VFIO in one shot.
# Run it BEFORE posting a support thread and paste the output. Saves everyone
# ten rounds of "can you also paste lspci".
#
# Usage: bash scripts/collect_info.sh
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "==========================================================="
echo " GPU Passthrough diagnostics"
echo " Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "==========================================================="

have() { command -v "$1" >/dev/null 2>&1; }

cmd() {
    local name="$1"
    shift
    echo ""
    echo "--- $name ---"
    if have "$1"; then
        "$@" 2>&1
    else
        echo "[${YELLOW}missing${NC}] '$1' not found"
    fi
}

echo ""
echo "--- Kernel ---"
uname -a
cmd "cmdline" cat /proc/cmdline

if [ -d /sys/kernel/iommu_groups ]; then
    GROUPS=$(find /sys/kernel/iommu_groups -mindepth 1 -maxdepth 1 -type d | wc -l)
    echo "IOMMU groups: $GROUPS"
else
    echo "[${RED}IOMMU OFF${NC}] /sys/kernel/iommu_groups does not exist"
fi

cmd "lspci" lspci -nnk
cmd "lspci -t" lspci -tv

echo ""
echo "--- IOMMU groups (GPU only) ---"
if [ -d /sys/kernel/iommu_groups ]; then
    for g in /sys/kernel/iommu_groups/*; do
        group=$(basename "$g")
        for dev in "$g"/devices/*; do
            addr=${dev##*/}
            info=$(lspci -nn -s "$addr" 2>/dev/null || echo "?")
            case "$info" in
                *VGA*|*Display*|*Audio*)
                    echo "Group $group: $addr  $info"
                    ;;
            esac
        done
    done
else
    echo "[${RED}IOMMU disabled${NC}] nothing to show"
fi

echo ""
echo "--- Modules ---"
cmd "vfio modules" lsmod | grep -E '^(vfio|vfio_pci|vfio_iommu)' || echo "no vfio modules loaded"
cmd "modprobe.d" cat /etc/modprobe.d/*.conf 2>/dev/null || echo "no modprobe.d/*.conf"

echo ""
echo "--- vfio-pci binding ---"
if have lspci; then
    lspci -nnk | grep -A3 -E 'VGA|Audio' | grep -E 'Kernel driver|VGA|Audio' || true
fi

echo ""
echo "--- Hugepages ---"
if have grep; then
    grep -i huge /proc/meminfo || true
fi

echo ""
echo "--- libvirt / qemu ---"
cmd "virsh version" virsh version
cmd "virsh list --all" virsh list --all
if [ -d /etc/libvirt ]; then
    cmd "qemu.conf" cat /etc/libvirt/qemu.conf 2>/dev/null | grep -vE '^\s*#|^\s*$' || echo "empty qemu.conf"
fi

echo ""
echo "--- CPU ---"
if have lscpu; then
    lscpu | grep -E 'Model name|Socket|Core|Thread|Virtualization|Vulnerability' || true
fi

echo ""
echo "==========================================================="
echo " Done. Paste all of the above in your support thread."
echo "==========================================================="
