#!/bin/bash
# restore_vm.sh -- Restore a VM from a backup created by backup_vm.sh
# Usage: sudo bash scripts/restore_vm.sh BACKUP_DIR [VM_NAME]
#   BACKUP_DIR  The directory containing the backup (e.g. /mnt/backup/win11-gpu)
#   VM_NAME     Optional override for the restored VM name (default: from backup)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: sudo bash $0 BACKUP_DIR [VM_NAME]"
    echo ""
    echo "  BACKUP_DIR  Backup directory created by backup_vm.sh"
    echo "  VM_NAME     Optional new VM name"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

BACKUP_DIR="$1"
VM_NAME_OVERRIDE="${2:-}"

if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}Backup directory not found: $BACKUP_DIR${NC}"
    exit 1
fi

XML_FILE=$(find "$BACKUP_DIR" -maxdepth 1 -name "*.xml" | head -1)
if [ -z "$XML_FILE" ]; then
    echo -e "${RED}No domain XML found in $BACKUP_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}Restoring from: $BACKUP_DIR${NC}"
echo "  XML: $XML_FILE"
echo ""

# Determine VM name
if [ -n "$VM_NAME_OVERRIDE" ]; then
    VM_NAME="$VM_NAME_OVERRIDE"
else
    VM_NAME=$(basename "$BACKUP_DIR")
fi
echo -e "  Target VM name: ${GREEN}$VM_NAME${NC}"
echo ""

# Check if VM already exists
if virsh dominfo "$VM_NAME" >/dev/null 2>&1; then
    echo -e "${RED}VM '$VM_NAME' already exists.${NC}"
    echo "Shut it down and undefine it first, or use a different VM name."
    echo "  sudo virsh shutdown $VM_NAME"
    echo "  sudo virsh undefine $VM_NAME"
    exit 1
fi

# Copy disk images
echo -e "${YELLOW}[1/3] Restoring disk images...${NC}"
DISK_IMAGES=$(find "$BACKUP_DIR" -maxdepth 1 -name "*.qcow2" -o -maxdepth 1 -name "*.raw" | sort)
if [ -n "$DISK_IMAGES" ]; then
    while IFS= read -r IMG; do
        echo "  Copying $(basename "$IMG") -> /var/lib/libvirt/images/"
        cp --reflink=auto "$IMG" "/var/lib/libvirt/images/$(basename "$IMG")"
        chown libvirt-qemu:kvm "/var/lib/libvirt/images/$(basename "$IMG")" 2>/dev/null || true
    done <<< "$DISK_IMAGES"
else
    echo "  No disk images found in backup (block-device VM?)."
fi

# Restore NVRAM
NVRAM_FILE="$BACKUP_DIR/${VM_NAME}_VARS.fd"
if [ -f "$NVRAM_FILE" ]; then
    echo -e "${YELLOW}[2/3] Restoring NVRAM...${NC}"
    mkdir -p /var/lib/libvirt/qemu/nvram/
    cp "$NVRAM_FILE" "/var/lib/libvirt/qemu/nvram/${VM_NAME}_VARS.fd"
    chown libvirt-qemu:kvm "/var/lib/libvirt/qemu/nvram/${VM_NAME}_VARS.fd" 2>/dev/null || true
else
    echo -e "${YELLOW}[2/3] No NVRAM file in backup, skipping.${NC}"
fi

# Define VM
echo -e "${YELLOW}[3/3] Defining VM...${NC}"
if [ -n "$VM_NAME_OVERRIDE" ]; then
    sed "s|<name>.*</name>|<name>${VM_NAME}</name>|" "$XML_FILE" > "/tmp/${VM_NAME}.xml"
    virsh define "/tmp/${VM_NAME}.xml"
    rm -f "/tmp/${VM_NAME}.xml"
else
    virsh define "$XML_FILE"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Restore complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "  Start the VM with:"
echo "    sudo virsh start ${VM_NAME}"
echo ""
echo "  If disk paths in the XML point elsewhere, fix with:"
echo "    sudo virsh edit ${VM_NAME}"
echo ""
