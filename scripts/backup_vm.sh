#!/bin/bash
# backup_vm.sh -- Backup a VM: disk image + XML + NVRAM
# Usage: sudo bash scripts/backup_vm.sh VM_NAME DEST_DIR
#   Best practice: shut the VM down first for a consistent backup.
#   sudo virsh shutdown win11-gpu
#   sudo bash scripts/backup_vm.sh win11-gpu /mnt/backup
#   sudo virsh start win11-gpu
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: sudo bash $0 VM_NAME DEST_DIR"
    echo ""
    echo "  VM_NAME   Name of the VM to back up"
    echo "  DEST_DIR  Destination directory (e.g. /mnt/backup/2026-08-03)"
    exit 1
}

if [ $# -lt 2 ]; then
    usage
fi

VM_NAME="$1"
DEST_DIR="$2"

if ! virsh dominfo "$VM_NAME" >/dev/null 2>&1; then
    echo -e "${RED}VM '$VM_NAME' does not exist.${NC}"
    exit 1
fi

# Create destination
BACKUP_DIR="${DEST_DIR}/${VM_NAME}"
mkdir -p "$BACKUP_DIR"
echo -e "${GREEN}Backing up $VM_NAME -> $BACKUP_DIR${NC}"
echo ""

# 1. Domain XML
echo -e "${YELLOW}[1/3] Exporting domain XML...${NC}"
virsh dumpxml "$VM_NAME" > "$BACKUP_DIR/${VM_NAME}.xml"
echo "  Saved: $BACKUP_DIR/${VM_NAME}.xml"

# 2. NVRAM (UEFI variables)
NVRAM_FILE="/var/lib/libvirt/qemu/nvram/${VM_NAME}_VARS.fd"
if [ -f "$NVRAM_FILE" ]; then
    echo -e "${YELLOW}[2/3] Backing up NVRAM...${NC}"
    cp "$NVRAM_FILE" "$BACKUP_DIR/${VM_NAME}_VARS.fd"
    echo "  Saved: $BACKUP_DIR/${VM_NAME}_VARS.fd"
else
    echo -e "${YELLOW}[2/3] No NVRAM file found (legacy BIOS VM?), skipping.${NC}"
fi

# 3. Disk images
echo -e "${YELLOW}[3/3] Backing up disk images...${NC}"
DISK_PATHS=$(virsh dumpxml "$VM_NAME" | grep -oP "(?<=<source file=')[^']+" || true)
if [ -z "$DISK_PATHS" ]; then
    echo "  No file-backed disks found (using LVM/raw block devices?)."
    echo "  Backup those block devices separately."
else
    while IFS= read -r DISK; do
        if [ -f "$DISK" ]; then
            echo "  Copying $DISK ..."
            cp --reflink=auto "$DISK" "$BACKUP_DIR/$(basename "$DISK")"
            echo "  Done: $(basename "$DISK")"
        else
            echo -e "${YELLOW}  Skipping $DISK (not a regular file)${NC}"
        fi
    done <<< "$DISK_PATHS"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Backup complete: $BACKUP_DIR${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "To restore:"
echo "  sudo virsh shutdown ${VM_NAME}   # if running"
echo "  sudo cp $BACKUP_DIR/${VM_NAME}.qcow2 /var/lib/libvirt/images/"
echo "  sudo chown libvirt-qemu:kvm /var/lib/libvirt/images/*"
echo "  sudo virsh define $BACKUP_DIR/${VM_NAME}.xml"
echo "  sudo virsh start ${VM_NAME}"
echo ""
