#!/bin/bash
# gpu_recovery.sh -- Recover a GPU that feels "stuck" after a VM crash.
#
# After a hard VM poweroff (virsh destroy or a guest crash) the GPU sometimes
# stays bound to vfio-pci, the host driver won't claim it again, and the host
# keeps a black screen. This script:
#   1. makes sure no VM still holds the device
#   2. forcibly unbinds the GPU (and audio) from vfio-pci
#   3. fires the kernel PCI reset quirk to clear the device
#   4. delegates the actual host-driver rebinding to bind_vfio.sh
#
# Usage:
#   sudo bash scripts/gpu_recovery.sh GPU [AUDIO] [DRIVER]
#   sudo bash scripts/gpu_recovery.sh 0000:01:00.0 0000:01:00.1 nvidia
#
# DRIVER defaults to: nvidia, amdgpu, or i915, detected by GPU vendor id.
set -euo pipefail

if [ "$#" -lt 1 ] || [ "${1}" = "-h" ] || [ "${1}" = "--help" ]; then
    echo "Usage: sudo bash $0 GPU [AUDIO] [DRIVER]"
    echo "  GPU    GPU PCI address    (0000:01:00.0)"
    echo "  AUDIO  audio PCI address  (0000:01:00.1, optional)"
    echo "  DRIVER host driver to restore (nvidia|amdgpu|...) — auto-detected if omitted"
    exit 0
fi

GPU="$1"
AUDIO="${2:-}"
DRIVER="${3:-}"

if ! command -v lspci >/dev/null 2>&1; then
    echo "Error: lspci (pciutils) not installed." >&2
    exit 1
fi

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Auto-detect the host driver from the PCI vendor id.
if [ -z "$DRIVER" ]; then
    VENDOR=$(lspci -n -s "${GPU##0000:}" 2>/dev/null | awk '{print $3}' | cut -d: -f1)
    case "$VENDOR" in
        10de) DRIVER="nvidia" ;;
        1002) DRIVER="amdgpu" ;;
        8086) DRIVER="i915"   ;;
        *)    DRIVER="amdgpu" ;;
    esac
    echo "Auto-detected host driver: $DRIVER"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

force_reset_device() {
    local addr="$1"
    # Fire the kernel PCI reset quirk when available to clear a wedged device.
    if [ -f "/sys/bus/pci/devices/$addr/reset" ]; then
        echo -e "${YELLOW}Triggering PCI reset for $addr...${NC}"
        echo 1 > "/sys/bus/pci/devices/$addr/reset" 2>/dev/null || \
            echo -e "${RED}Reset not permitted for $addr (needs a reboot).${NC}"
    fi
}

unbind_from_vfio() {
    local addr="$1"
    if [ -L "/sys/bus/pci/drivers/vfio-pci/$addr" ]; then
        echo -e "${YELLOW}Unbinding $addr from vfio-pci...${NC}"
        echo "$addr" > /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || \
            echo -e "${RED}Failed to unbind $addr — the VFIO driver still holds it.${NC}"
    fi
}

echo "=== GPU recovery ==="

# 1. If a VM still lists the device, stop it so the GPU is free.
RUNNING=$(virsh list --name 2>/dev/null | grep -E -i "${GPU##0000:}" || true)
if [ -n "$RUNNING" ]; then
    echo -e "${YELLOW}VM '$RUNNING' may still be using the GPU. Stopping it...${NC}"
    sudo virsh destroy "$RUNNING" 2>/dev/null || true
    sleep 2
fi

# 2. Force-unbind from vfio-pci and try a device reset.
unbind_from_vfio "${GPU##0000:}"
if [ -n "$AUDIO" ]; then
    unbind_from_vfio "${AUDIO##0000:}"
fi
force_reset_device "${GPU##0000:}"
if [ -n "$AUDIO" ]; then
    force_reset_device "${AUDIO##0000:}"
fi

# 3. Delegate the actual host-driver rebinding to the existing bind script.
echo -e "${GREEN}Handing off to bind_vfio.sh to rebind to $DRIVER...${NC}"
sudo bash "$SCRIPT_DIR/bind_vfio.sh" rebind "${GPU}" "${AUDIO:-${GPU}}" "$DRIVER"

echo ""
echo -e "${GREEN}Recovery attempted for $GPU ${AUDIO:+$AUDIO} -> $DRIVER${NC}"
echo "Check dmesg / the display manager to confirm the host reclaimed the GPU."
