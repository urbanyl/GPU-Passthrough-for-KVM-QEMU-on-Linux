#!/bin/bash
# snapshot_vm.sh -- Create, list, revert or delete libvirt VM snapshots.
# Internal snapshots live inside the qcow2 image (no extra files, but the
# image keeps growing while they exist). For big VMs prefer backup_vm.sh.
#
# Usage:
#   bash scripts/snapshot_vm.sh list VM
#   bash scripts/snapshot_vm.sh create VM SNAPSHOT
#   bash scripts/snapshot_vm.sh revert VM SNAPSHOT
#   bash scripts/snapshot_vm.sh delete VM SNAPSHOT
#   bash scripts/snapshot_vm.sh delete VM current
set -euo pipefail

ACTION="${1:-}"
VM="${2:-}"
SNAP="${3:-}"

if [ -z "$ACTION" ] || [ -z "$VM" ]; then
    echo "Usage: $0 <list|create|revert|delete> <VM> [SNAPSHOT]"
    exit 1
fi

require_snapshot() {
    if [ -z "$SNAP" ]; then
        echo "Error: snapshot name required for '$ACTION'"
        exit 1
    fi
}

case "$ACTION" in
    list)
        echo "Snapshots for $VM:"
        virsh snapshot-list --domain "$VM"
        ;;
    create)
        require_snapshot
        if [ -z "$SNAP" ] || [ "$SNAP" = "current" ]; then
            echo "Error: give a real snapshot name, 'current' is reserved"
            exit 1
        fi
        echo "Creating snapshot '$SNAP' for $VM..."
        virsh snapshot-create-as --domain "$VM" --name "$SNAP" --atomic
        echo "Done."
        ;;
    revert)
        require_snapshot
        if [ "$SNAP" = "current" ]; then
            SNAP=$(virsh snapshot-current --domain "$VM" --name)
        fi
        echo "Reverting $VM to '$SNAP'..."
        virsh snapshot-revert --domain "$VM" --snapshotname "$SNAP"
        echo "Done."
        ;;
    delete)
        require_snapshot
        echo "Deleting snapshot '$SNAP' of $VM..."
        virsh snapshot-delete --domain "$VM" --snapshotname "$SNAP"
        echo "Done."
        ;;
    *)
        echo "Usage: $0 <list|create|revert|delete> <VM> [SNAPSHOT]"
        exit 1
        ;;
esac
