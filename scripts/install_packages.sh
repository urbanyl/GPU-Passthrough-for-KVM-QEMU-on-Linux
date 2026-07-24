#!/bin/bash
# install_packages.sh -- Install required virtualization packages for GPU passthrough
# Usage: sudo bash scripts/install_packages.sh
# Supports: Debian/Ubuntu, Arch Linux, Fedora, openSUSE
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  GPU Passthrough Package Installer${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
else
    echo -e "${RED}Cannot detect distribution. /etc/os-release not found.${NC}"
    exit 1
fi

echo "Detected distribution: $PRETTY_NAME"
echo ""

case "$DISTRO_ID" in
    debian|ubuntu|linuxmint|pop)
        echo -e "${GREEN}[Debian/Ubuntu] Installing packages...${NC}"
        sudo apt update
        sudo apt install -y \
            qemu-kvm \
            libvirt-daemon-system \
            libvirt-clients \
            virt-manager \
            virtinst \
            ovmf \
            bridge-utils \
            libguestfs-tools \
            cpu-checker \
            libspice-server1 \
            dnsmasq-base

        echo ""
        echo -e "${GREEN}[Enabling services]${NC}"
        sudo systemctl enable --now libvirtd
        sudo systemctl start libvirtd

        echo -e "${GREEN}[Adding user to groups]${NC}"
        sudo usermod -aG libvirt "$USER"
        sudo usermod -aG kvm "$USER"
        sudo usermod -aG input "$USER"
        ;;

    arch|manjaro|endeavouros)
        echo -e "${GREEN}[Arch Linux] Installing packages...${NC}"
        sudo pacman -Syu --noconfirm
        sudo pacman -S --noconfirm \
            qemu-full \
            libvirt \
            virt-manager \
            virt-install \
            edk2-ovmf \
            bridge-utils \
            libguestfs \
            dnsmasq \
            spice-vdagent

        echo ""
        echo -e "${GREEN}[Enabling services]${NC}"
        sudo systemctl enable --now libvirtd
        sudo systemctl start libvirtd

        echo -e "${GREEN}[Adding user to groups]${NC}"
        sudo usermod -aG libvirt "$USER"
        sudo usermod -aG kvm "$USER"
        sudo usermod -aG input "$USER"
        ;;

    fedora)
        echo -e "${GREEN}[Fedora] Installing packages...${NC}"
        sudo dnf install -y \
            qemu-kvm \
            libvirt \
            virt-manager \
            virt-install \
            edk2-ovmf \
            bridge-utils \
            libguestfs-tools \
            spice-vdagent \
            dnsmasq

        echo ""
        echo -e "${GREEN}[Enabling services]${NC}"
        sudo systemctl enable --now libvirtd
        sudo systemctl start libvirtd

        echo -e "${GREEN}[Adding user to groups]${NC}"
        sudo usermod -aG libvirt "$USER"
        sudo usermod -aG kvm "$USER"
        sudo usermod -aG input "$USER"
        ;;

    opensuse*|sles)
        echo -e "${GREEN}[openSUSE] Installing packages...${NC}"
        sudo zypper install -y \
            qemu-kvm \
            libvirt \
            virt-manager \
            virt-install \
            ovmf \
            bridge-utils \
            guestfs-tools \
            spice-vdagent

        echo ""
        echo -e "${GREEN}[Enabling services]${NC}"
        sudo systemctl enable --now libvirtd
        sudo systemctl start libvirtd

        echo -e "${GREEN}[Adding user to groups]${NC}"
        sudo usermod -aG libvirt "$USER"
        sudo usermod -aG kvm "$USER"
        sudo usermod -aG input "$USER"
        ;;

    *)
        echo -e "${RED}Unsupported distribution: $DISTRO_ID${NC}"
        echo "Supported: Debian, Ubuntu, Arch, Fedora, openSUSE"
        exit 1
        ;;
esac

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Installation Complete${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Log out and log back in for group changes to take effect"
echo "  2. Verify libvirt is running: virsh list --all"
echo "  3. Check IOMMU groups: bash scripts/check_iommu_groups.sh"
echo "  4. Detect GPUs: bash scripts/detect_gpu.sh"
echo ""
echo -e "${YELLOW}To log out and back in, run:${NC}"
echo "  logout"
echo ""
