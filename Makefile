# Makefile -- one command for everything GPU passthrough
#
# Usage:
#   make            # same as `make help`
#   make help
#   make check      # run the health check
#   make setup      # run the interactive VFIO setup
#   make detect     # detect GPUs and IOMMU groups
#   make status     # VM status (alias: vm-status)
#   make vm-start   # start win11-gpu (uses start_vm.sh)
#   make vm-stop    # stop win11-gpu
#   make vm-reboot  # reboot win11-gpu
#   make backup     # cold backup win11-gpu
#   make restore    # restore win11-gpu from a backup
#   make info       # dump all diagnostics for a support thread
#   make lint       # shellcheck all scripts locally (needs shellcheck installed)
#
# Override the VM name, e.g. `make vm-start VM=gaming`
VM ?= win11-gpu

.PHONY: help check setup detect status vm-status vm-start vm-stop vm-reboot backup restore info lint

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make <target>\n\nTargets:\n" } /^[a-zA-Z0-9_-]+:.*?##/ { printf "  %-12s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

check: ## One-command health check
	sudo bash scripts/status_check.sh

setup: ## Interactive VFIO setup (kernel params + modprobe)
	sudo bash scripts/setup_vfio.sh

detect: ## Detect GPUs and IOMMU groups
	bash scripts/detect_gpu.sh
	bash scripts/check_iommu_groups.sh

status vm-status: ## Show VM lifecycle status
	virsh list --all

vm-start: ## Start the VM (binds GPU first if args provided via GPU=...)
	sudo bash scripts/start_vm.sh $(VM) $(GPU) $(AUDIO)

vm-stop: ## Stop the VM and optionally rebind GPU (set DRIVER=amdgpu,nvidia,...)
	sudo bash scripts/stop_vm.sh $(VM) $(GPU) $(AUDIO) $(DRIVER)

vm-reboot: ## Reboot the VM
	virsh reboot $(VM)

backup: ## Cold backup the VM (VM must be stopped): DEST=/mnt/backup
	sudo bash scripts/backup_vm.sh $(VM) $(DEST)

restore: ## Restore the VM from a backup: SRC=/mnt/backup
	sudo bash scripts/restore_vm.sh $(VM) $(SRC)

info: ## Dump diagnostics for a support thread
	bash scripts/collect_info.sh

lint: ## Run shellcheck on all scripts (install shellcheck first)
	shellcheck scripts/*.sh setup/*.sh install.sh
