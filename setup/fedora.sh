#!/bin/bash
# setup/fedora.sh -- Complete host setup for Fedora
# Run: sudo bash setup/fedora.sh
set -euo pipefail

echo "============================================"
echo "  GPU Passthrough Host Setup - Fedora"
echo "============================================"
echo ""

# Update system
echo "[1/8] Updating system..."
sudo dnf upgrade -y

# Install essential packages
echo "[2/8] Installing essential packages..."
sudo dnf install -y \
    gcc \
    make \
    git \
    curl \
    wget \
    kernel-devel-"$(uname -r)" \
    pciutils \
    usbutils

# Install virtualization packages
echo "[3/8] Installing virtualization packages..."
sudo dnf groupinstall -y "Virtualization Host"
sudo dnf install -y \
    qemu-kvm \
    libvirt \
    virt-manager \
    virt-install \
    edk2-ovmf \
    bridge-utils \
    libguestfs-tools \
    spice-vdagent \
    dnsmasq \
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
else
    echo "  WARNING: /dev/kvm not found."
fi

echo ""
echo "============================================"
echo "  Setup Complete"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Log out and log back in"
echo "  2. Enable IOMMU in BIOS (VT-d for Intel, AMD-Vi for AMD)"
echo "  3. Add kernel parameters in /etc/default/grub"
echo "  4. Run: sudo grub2-mkconfig -o /boot/grub2/grub.cfg && sudo reboot"
echo "  5. Run: bash scripts/detect_gpu.sh"
echo "  6. Run: bash scripts/check_iommu_groups.sh"
echo ""
