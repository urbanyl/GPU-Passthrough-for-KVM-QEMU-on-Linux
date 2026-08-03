#!/bin/bash
# vmctl.sh -- Unified VM lifecycle + GPU passthrough controller.
# One entry point for the common passthrough operations instead of remembering
# which script does what. Wraps virsh and the repo helper scripts.
#
# Usage:
#   vmctl.sh status          list VMs (running + shut off)
#   vmctl.sh state NAME      show NAME's runtime state
#   vmctl.sh start NAME [GPU AUDIO [VID:DEV ...]]
#   vmctl.sh stop  NAME [GPU AUDIO [DRIVER]]
#   vmctl.sh reboot NAME
#   vmctl.sh shutdown NAME   clean ACPI shutdown
#   vmctl.sh poweroff NAME   force power-off (destroy)
#   vmctl.sh suspend NAME
#   vmctl.sh resume NAME
#   vmctl.sh attach-gpu NAME GPU [AUDIO]
#   vmctl.sh detach-gpu NAME [DRIVER]
#   vmctl.sh info NAME       dump VM details (CPU pinning, XML, display, state)
#
# Examples:
#   sudo bash scripts/vmctl.sh start win11-gpu 0000:01:00.0 0000:01:00.1
#   sudo bash scripts/vmctl.sh stop win11-gpu 0000:01:00.0 0000:01:00.1 amdgpu
#   sudo bash scripts/vmctl.sh attach-gpu win11-gpu 0000:01:00.0 0000:01:00.1
set -euo pipefail

if ! command -v virsh >/dev/null 2>&1; then
    echo "Error: 'virsh' (libvirt) is not installed or not on PATH." >&2
    exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

status() {
    echo -e "${CYAN}All VMs:${NC}"
    virsh list --all
}

require_vm() {
    local name="$1"
    if ! virsh dominfo "$name" >/dev/null 2>&1; then
        echo -e "${RED}VM '$name' does not exist.${NC}"
        echo "Available:"; virsh list --all | tail -n +2
        return 1
    fi
}

state() {
    local name="$1"; require_vm "$name"
    virsh domstate "$name"
}

start() {
    local name="$1"; shift
    require_vm "$name"
    # Reuse start_vm.sh so GPU binding logic stays in one place
    sudo bash "$SCRIPT_DIR/start_vm.sh" "$name" "$@"
}

stop() {
    local name="$1"; shift
    require_vm "$name"
    sudo bash "$SCRIPT_DIR/stop_vm.sh" "$name" "$@"
}

simple_op() {
    local op="$1" name="$2"
    require_vm "$name"
    echo -e "${YELLOW}${op^}ing VM: $name${NC}"
    virsh "$op" "$name"
}

attach_gpu() {
    local name="$1" gpu="$2"; shift 2
    require_vm "$name"
    if virsh domstate "$name" | grep -q "^running"; then
        echo -e "${RED}VM '$name' is running — attach GPU only while the VM is powered off.${NC}"
        echo "Use: ${GREEN}sudo virsh nodedev-detach${NC} ... if the VM is hot-plug capable."
        return 1
    fi
    if [ -z "${3:-}" ]; then
        echo -e "${YELLOW}Attaching GPU $gpu (+ ${3:-none}) to $name...${NC}"
    else
        echo -e "${YELLOW}Attaching GPU $gpu (+ $3) to $name...${NC}"
    fi
    sudo bash "$SCRIPT_DIR/bind_vfio.sh" unbind "$gpu" "${3:-}" "$@"
}

detach_gpu() {
    local name="$1"; shift
    require_vm "$name"
    local gpu audio driver=""
    gpu="${1:-}"
    audio="${2:-}"
    if [ -n "${3:-}" ]; then driver="$3"; fi
    if [ "$gpu" = "auto" ]; then
        # rebind everything currently on vfio via bind_vfio.sh rebind? not supported; warn
        echo -e "${YELLOW}Pass explicit PCI addresses: vmctl.sh detach-gpu NAME GPU [AUDIO] [DRIVER]${NC}"
        return 1
    fi
    echo -e "${YELLOW}Rebinding GPU ($gpu ${audio:-}) to host driver '${driver:-amdgpu}'...${NC}"
    sudo bash "$SCRIPT_DIR/bind_vfio.sh" rebind "$gpu" "$audio" "${driver:-amdgpu}"
}

info() {
    local name="$1"; require_vm "$name"
    echo -e "${CYAN}== $name ==${NC}"
    virsh dominfo "$name"
    echo ""
    echo -e "${CYAN}vCPUs:${NC}"
    virsh vcpuinfo "$name" 2>/dev/null | tail -n +2 || true
    echo ""
    echo -e "${CYAN}Display / Graphics:${NC}"
    virsh domdisplay "$name" 2>/dev/null || true
    echo ""
    echo -e "${CYAN}Attached PCI devices:${NC}"
    virsh dumpxml "$name" | grep -A2 '<hostdev' || echo "(none)"
}

usage() {
    head -1 "$0"
    sed -n 's/^# Usage:/# Usage:/p; /^#   vmctl.sh/,/^# Examples:/p' "$0"
}

[ ${#} -lt 1 ] && { usage; exit 1; }

CMD="$1"
shift || true

case "$CMD" in
    status|ls)            status ;;
    state)                state "$1" ;;
    start)                start "$1" "${@:2}" ;;
    stop)                 stop "$1" "${@:2}" ;;
    reboot)               simple_op reboot "$1" ;;
    shutdown)             simple_op shutdown "$1" ;;
    poweroff)             simple_op destroy "$1" ;;
    suspend)              simple_op suspend "$1" ;;
    resume)               simple_op resume "$1" ;;
    attach-gpu)           attach_gpu "$@" ;;
    detach-gpu)           detach_gpu "$@" ;;
    info)                 info "$1" ;;
    -h|--help|help)       usage ;;
    *)
        echo -e "${RED}Unknown command: $CMD${NC}"
        usage
        exit 1
        ;;
esac
