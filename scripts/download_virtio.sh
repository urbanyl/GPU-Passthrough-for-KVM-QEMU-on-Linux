#!/bin/bash
# download_virtio.sh -- Download the latest virtio-win drivers ISO
# Usage: bash scripts/download_virtio.sh [DEST_DIR]
#   DEST_DIR  Destination directory (default: /tmp)
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DEST_DIR="${1:-/tmp}"
BASE_URL="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio"

usage() {
    echo "Usage: bash $0 [DEST_DIR]"
    exit 1
}

# Fetch the directory listing and find the latest virtio-win ISO
echo -e "${GREEN}Fetching latest virtio-win version list...${NC}"

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    echo -e "${RED}Neither curl nor wget found. Install one of them.${NC}"
    exit 1
fi

# Get the listing (try curl first, fall back to wget)
LISTING=""
if command -v curl >/dev/null 2>&1; then
    LISTING=$(curl -fsSL "$BASE_URL/" 2>/dev/null || true)
else
    LISTING=$(wget -qO- "$BASE_URL/" 2>/dev/null || true)
fi

if [ -z "$LISTING" ]; then
    echo -e "${RED}Could not fetch version list from $BASE_URL${NC}"
    echo "Download manually:"
    echo "  $BASE_URL/virtio-win.iso"
    exit 1
fi

# The directory listing contains links to numbered folders; pick the newest
LATEST_VERSION=$(echo "$LISTING" | grep -oE 'virtio-win-[0-9]+\.[0-9]+' | sort -uV | tail -1)
if [ -z "$LATEST_VERSION" ]; then
    echo -e "${YELLOW}Could not parse version list; using stable-virtio root.${NC}"
    ISO_URL="$BASE_URL/virtio-win.iso"
else
    # Check if the numbered subfolder has virtio-win.iso; the layout has changed over time.
    ISO_URL="$BASE_URL/virtio-win.iso"
    echo -e "  Latest detected version: ${GREEN}${LATEST_VERSION}${NC} (falling back to root ISO if subfolder 404s)"
fi

mkdir -p "$DEST_DIR"
OUTPUT="$DEST_DIR/virtio-win.iso"

echo -e "${GREEN}Downloading:${NC} $ISO_URL"
echo -e "To: $OUTPUT"

if command -v curl >/dev/null 2>&1; then
    curl -fL --progress-bar "$ISO_URL" -o "$OUTPUT"
else
    wget --show-progress -O "$OUTPUT" "$ISO_URL"
fi

if [ -f "$OUTPUT" ]; then
    SIZE_MB=$(du -m "$OUTPUT" | cut -f1)
    echo ""
    echo -e "${GREEN}Download complete: $OUTPUT (${SIZE_MB} MB)${NC}"
    echo ""
    echo "To attach it to a VM:"
    echo "  sudo virsh attach-disk win11-gpu $OUTPUT sdb --type cdrom --config"
    echo ""
else
    echo -e "${RED}Download failed.${NC}"
    exit 1
fi
