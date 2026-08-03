#!/bin/bash
# start_vm.sh -- Start a GPU passthrough VM, optionally binding the GPU first
# Usage: sudo bash scripts/start_vm.sh VM_NAME [GPU_PCI AUDIO_PCI] [VENDOR:DEVICE ...]
#
# For AMD RX 9000+ / dynamic binding setups:
#   sudo bash scripts/start_vm.sh win11-gpu 0000:01:00.0 0000:01:00.1
#
# For standard early-binding setups:
#   sudo bash scripts/start_vm.sh win11-gpu
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: sudo bash $0 VM_NAME [GPU_PCI AUDIO_PCI [VENDOR:DEVICE ...]]"
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

# If the VM is already running, do nothing.
if virsh domstate "$VM_NAME" | grep -q "running"; then
    echo -e "${YELLOW}VM '$VM_NAME' is already running.${NC}"
    exit 0
fi

# If GPU addresses were supplied, bind them to vfio-pci first.
if [ $# -ge 2 ]; then
    GPU_PCI="$1"
    AUDIO_PCI="$2"
    shift 2
    echo -e "${YELLOW}Binding $GPU_PCI + $AUDIO_PCI to vfio-pci...${NC}"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    sudo bash "$SCRIPT_DIR/bind_vfio.sh" unbind "$GPU_PCI" "$AUDIO_PCI" "$@"
fi

echo -e "${GREEN}Starting VM: $VM_NAME${NC}"
virsh start "$VM_NAME"

echo ""
echo -e "${GREEN}VM started.${NC}"
echo "  Console (SPICE):"
virsh domdisplay "$VM_NAME" 2>/dev/null || true
echo "  Wait for the guest OS to boot, then connect the display:"
echo "    Looking Glass: looking-glass-client"
echo "    Sunshine: http://localhost:47990"
echo ""
