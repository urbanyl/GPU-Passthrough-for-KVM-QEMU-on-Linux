#!/bin/bash
# bind_vfio.sh -- Manually bind/unbind GPU to/from vfio-pci (for single-GPU passthrough)
# Usage:
#   sudo bash scripts/bind_vfio.sh unbind PCI_GPU PCI_AUDIO [VENDOR:DEVICE ...]
#   sudo bash scripts/bind_vfio.sh rebind PCI_GPU PCI_AUDIO [DRIVER]
#
# Examples:
#   sudo bash scripts/bind_vfio.sh unbind 0000:01:00.0 0000:01:00.1
#   sudo bash scripts/bind_vfio.sh unbind 0000:01:00.0 0000:01:00.1 10de:1af2 10de:1af9
#   sudo bash scripts/bind_vfio.sh rebind 0000:01:00.0 0000:01:00.1 nvidia
#
# WARNING: This script stops the display manager. Ensure SSH access before running.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage:"
    echo "  sudo bash $0 unbind PCI_GPU PCI_AUDIO [VENDOR:DEVICE ...]"
    echo "  sudo bash $0 rebind PCI_GPU PCI_AUDIO [DRIVER]"
    echo ""
    echo "Examples:"
    echo "  sudo bash $0 unbind 0000:01:00.0 0000:01:00.1"
    echo "  sudo bash $0 unbind 0000:01:00.0 0000:01:00.1 10de:1af2 10de:1af9"
    echo "  sudo bash $0 rebind 0000:01:00.0 0000:01:00.1 nvidia"
    exit 1
}

if [ $# -lt 3 ]; then
    usage
fi

ACTION="$1"
GPU_PCI="$2"
AUDIO_PCI="$3"
shift 3

# Detect display manager
detect_display_manager() {
    if systemctl is-active --quiet gdm 2>/dev/null || systemctl is-active --quiet gdm3 2>/dev/null; then
        echo "gdm"
    elif systemctl is-active --quiet sddm 2>/dev/null; then
        echo "sddm"
    elif systemctl is-active --quiet lightdm 2>/dev/null; then
        echo "lightdm"
    elif systemctl is-active --quiet display-manager 2>/dev/null; then
        echo "display-manager"
    else
        echo ""
    fi
}

case "$ACTION" in
    unbind)
        echo -e "${YELLOW}=== Unbinding GPU from host ===${NC}"
        echo "  GPU:  $GPU_PCI"
        echo "  Audio: $AUDIO_PCI"
        echo ""

        # Step 1: Stop display manager
        DM=$(detect_display_manager)
        if [ -n "$DM" ]; then
            echo -e "${YELLOW}[1/5] Stopping display manager ($DM)...${NC}"
            sudo systemctl stop "$DM"
            sleep 2
        else
            echo -e "${YELLOW}[1/5] No display manager detected, skipping.${NC}"
        fi

        # Step 2: Unload host GPU drivers
        echo -e "${YELLOW}[2/5] Unloading host GPU drivers...${NC}"
        sudo modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia 2>/dev/null || true
        sudo modprobe -r nouveau 2>/dev/null || true
        sudo modprobe -r amdgpu 2>/dev/null || true
        sleep 1

        # Step 3: Unbind devices from current driver
        echo -e "${YELLOW}[3/5] Unbinding PCI devices...${NC}"
        for PCI in "$GPU_PCI" "$AUDIO_PCI"; do
            DRIVER_PATH="/sys/bus/pci/devices/$PCI/driver"
            if [ -d "$DRIVER_PATH" ]; then
                CURRENT_DRIVER=$(basename "$(readlink "$DRIVER_PATH")" 2>/dev/null || echo "")
                if [ -n "$CURRENT_DRIVER" ]; then
                    echo "  Unbinding $PCI from $CURRENT_DRIVER"
                    echo "$PCI" > "$DRIVER_PATH/unbind" 2>/dev/null || echo "  Warning: failed to unbind $PCI"
                fi
            else
                echo "  $PCI is not bound to any driver"
            fi
        done

        # Step 4: Bind to vfio-pci
        echo -e "${YELLOW}[4/5] Binding to vfio-pci...${NC}"
        sudo modprobe vfio-pci
        sleep 1

        # If vendor:device IDs were provided, use new_id
        if [ $# -gt 0 ]; then
            for VID_PID in "$@"; do
                VENDOR=$(echo "$VID_PID" | cut -d: -f1)
                DEVICE=$(echo "$VID_PID" | cut -d: -f2)
                echo "  Registering VFIO ID: $VENDOR $DEVICE"
                echo "$VENDOR $DEVICE" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true
            done
        else
            # Auto-detect IDs from PCI addresses
            for PCI in "$GPU_PCI" "$AUDIO_PCI"; do
                VENDOR_ID=$(lspci -n -s "$PCI" | grep -oE '\[[0-9a-f]{4}:[0-9a-f]{4}\]' | head -1 | tr -d '[]')
                VENDOR=$(echo "$VENDOR_ID" | cut -d: -f1)
                DEVICE=$(echo "$VENDOR_ID" | cut -d: -f2)
                echo "  Auto-detected VFIO ID for $PCI: $VENDOR $DEVICE"
                echo "$VENDOR $DEVICE" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true
            done
        fi

        # Bind each device
        for PCI in "$GPU_PCI" "$AUDIO_PCI"; do
            echo "  Binding $PCI to vfio-pci"
            echo "$PCI" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || echo "  Warning: failed to bind $PCI"
        done

        # Step 5: Verify
        echo -e "${YELLOW}[5/5] Verifying binding...${NC}"
        for PCI in "$GPU_PCI" "$AUDIO_PCI"; do
            DRIVER=$(lspci -k -s "$PCI" 2>/dev/null | grep "Kernel driver in use" | awk -F': ' '{print $2}' || echo "unknown")
            if [ "$DRIVER" = "vfio-pci" ]; then
                echo -e "  ${GREEN}$PCI: bound to vfio-pci${NC}"
            else
                echo -e "  ${RED}$PCI: bound to $DRIVER (expected vfio-pci)${NC}"
            fi
        done

        echo ""
        echo -e "${GREEN}GPU unbound from host. You can now start the VM.${NC}"
        ;;

    rebind)
        DRIVER="${1:-nvidia}"
        echo -e "${YELLOW}=== Rebinding GPU to host driver ===${NC}"
        echo "  GPU:  $GPU_PCI"
        echo "  Audio: $AUDIO_PCI"
        echo "  Driver: $DRIVER"
        echo ""

        # Step 1: Unbind from vfio-pci
        echo -e "${YELLOW}[1/4] Unbinding from vfio-pci...${NC}"
        for PCI in "$GPU_PCI" "$AUDIO_PCI"; do
            DRIVER_PATH="/sys/bus/pci/devices/$PCI/driver"
            if [ -d "$DRIVER_PATH" ]; then
                CURRENT_DRIVER=$(basename "$(readlink "$DRIVER_PATH")" 2>/dev/null || echo "")
                if [ "$CURRENT_DRIVER" = "vfio-pci" ]; then
                    echo "$PCI" > "$DRIVER_PATH/unbind" 2>/dev/null || true
                    echo "  Unbound $PCI from vfio-pci"
                fi
            fi
        done

        # Step 2: Remove vfio-pci driver
        echo -e "${YELLOW}[2/4] Removing vfio-pci module...${NC}"
        sudo modprobe -r vfio-pci 2>/dev/null || true
        sleep 1

        # Step 3: Load host driver
        echo -e "${YELLOW}[3/4] Loading $DRIVER driver...${NC}"
        case "$DRIVER" in
            nvidia)
                sudo modprobe nvidia
                sudo modprobe nvidia_modeset
                sudo modprobe nvidia_uvm
                sudo modprobe nvidia_drm
                ;;
            amdgpu)
                sudo modprobe amdgpu
                ;;
            nouveau)
                sudo modprobe nouveau
                ;;
            *)
                sudo modprobe "$DRIVER"
                ;;
        esac
        sleep 2

        # Step 4: Start display manager
        echo -e "${YELLOW}[4/4] Starting display manager...${NC}"
        DM=$(detect_display_manager)
        if [ -z "$DM" ]; then
            # Try to detect configured DM
            if [ -f /etc/X11/default-display-manager ]; then
                DM="lightdm"
            else
                DM="gdm"
            fi
        fi
        sudo systemctl start "$DM" 2>/dev/null || true
        sleep 3

        # Verify
        echo ""
        echo -e "${GREEN}GPU rebinding complete.${NC}"
        for PCI in "$GPU_PCI" "$AUDIO_PCI"; do
            DRIVER_ACTIVE=$(lspci -k -s "$PCI" 2>/dev/null | grep "Kernel driver in use" | awk -F': ' '{print $2}' || echo "unknown")
            echo "  $PCI: $DRIVER_ACTIVE"
        done
        ;;

    *)
        echo -e "${RED}Unknown action: $ACTION${NC}"
        usage
        ;;
esac
