#!/bin/bash
# stop_vm.sh -- Stop a GPU passthrough VM, optionally rebinding the GPU to the host
# Usage: sudo bash scripts/stop_vm.sh VM_NAME [GPU_PCI AUDIO_PCI] [DRIVER]
#
#   For single-GPU passthrough, rebind the GPU to the host driver after stopping:
#     sudo bash scripts/stop_vm.sh win11-gpu 0000:01:00.0 0000:01:00.1 amdgpu
#
#   For dual-GPU / AMD dynamic binding, the GPU returns to amdgpu on next boot:
#     sudo bash scripts/stop_vm.sh win11-gpu
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: sudo bash $0 VM_NAME [GPU_PCI AUDIO_PCI [DRIVER]]"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

VM_NAME="$1"
shift

if ! virsh dominfo "$VM_NAME" >/dev/null 2>&1; then
    echo -e "${RED}VM '$VM_NAME' does not exist.${NC}"
    exit 1
fi

if ! virsh domstate "$VM_NAME" | grep -q "running"; then
    echo -e "${YELLOW}VM '$VM_NAME' is not running.${NC}"
else
    echo -e "${YELLOW}Shutting down VM: $VM_NAME${NC}"
    virsh shutdown "$VM_NAME"

    # Wait up to 60 seconds for a clean shutdown
    for _ in $(seq 1 30); do
        if virsh domstate "$VM_NAME" | grep -q "shut off"; then
            break
        fi
        sleep 2
    done

    if virsh domstate "$VM_NAME" | grep -q "running"; then
        echo -e "${YELLOW}VM did not shut down cleanly. Force-stopping...${NC}"
        virsh destroy "$VM_NAME"
    fi

    echo -e "${GREEN}VM stopped.${NC}"
fi

# Optionally rebind the GPU to the host driver (single-GPU passthrough)
if [ $# -ge 2 ]; then
    GPU_PCI="$1"
    AUDIO_PCI="$2"
    DRIVER="${3:-amdgpu}"
    echo -e "${YELLOW}Rebinding $GPU_PCI + $AUDIO_PCI to $DRIVER...${NC}"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    sudo bash "$SCRIPT_DIR/bind_vfio.sh" rebind "$GPU_PCI" "$AUDIO_PCI" "$DRIVER"
fi

echo ""
echo -e "${GREEN}Done.${NC}"
