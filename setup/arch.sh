#!/bin/bash
# setup/arch.sh -- Complete host setup for Arch Linux
# Run: sudo bash setup/arch.sh
set -euo pipefail

echo "============================================"
echo "  GPU Passthrough Host Setup - Arch Linux"
echo "============================================"
echo ""

# Update system
echo "[1/8] Updating system..."
sudo pacman -Syu --noconfirm

# Install essential packages
echo "[2/8] Installing essential packages..."
sudo pacman -S --noconfirm \
    base-devel \
    git \
    curl \
    wget \
    linux-headers \
    pciutils \
    usbutils

# Install virtualization packages
echo "[3/8] Installing virtualization packages..."
sudo pacman -S --noconfirm \
    qemu-full \
    libvirt \
    virt-manager \
    virt-install \
    edk2-ovmf \
    bridge-utils \
    libguestfs \
    dnsmasq \
    spice-spicevdagent \
    ebtables

# Enable and start libvirt
echo "[4/8] Configuring libvirt..."
sudo systemctl enable --now libvirtd
sudo systemctl start libvirtd

# Add user to required groups
echo "[5/8] Adding user to groups..."
sudo usermod -aG libvirt "$USER"
sudo usermod -aG kvm "$USER"
sudo usermod -aG input "$USER"

# Configure default network
echo "[6/8] Configuring default virtual network..."
if ! virsh net-info default &>/dev/null; then
    echo "  Default network not found."
else
    if ! virsh net-info default | grep -q "Active:.*yes"; then
        sudo virsh net-start default
    fi
    sudo virsh net-autostart default
fi

# Verify IOMMU support
echo "[7/8] Checking IOMMU support..."
if dmesg | grep -qi 'iommu\|dmar\|amd-vi\|vt-d'; then
    echo "  IOMMU appears to be active."
else
    echo "  WARNING: IOMMU may not be enabled."
    echo "  Ensure VT-d/AMD-Vi is enabled in BIOS and add kernel parameters."
fi

# Check KVM
echo "[8/8] Verifying KVM..."
if [ -e /dev/kvm ]; then
    echo "  KVM device found: /dev/kvm"
    if lsmod | grep -q kvm; then
        echo "  KVM modules loaded:"
        lsmod | grep kvm
    fi
else
    echo "  WARNING: /dev/kvm not found."
    echo "  Load KVM modules: sudo modprobe kvm && sudo modprobe kvm_intel (or kvm_amd)"
fi

echo ""
echo "============================================"
echo "  Setup Complete"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Log out and log back in"
echo "  2. Enable IOMMU in BIOS (VT-d for Intel, AMD-Vi for AMD)"
echo "  3. Add kernel parameters to /boot/loader/entries/*.conf"
echo "  4. Run: sudo bootctl update && sudo reboot"
echo "  5. Run: bash scripts/detect_gpu.sh"
echo "  6. Run: bash scripts/check_iommu_groups.sh"
echo ""
