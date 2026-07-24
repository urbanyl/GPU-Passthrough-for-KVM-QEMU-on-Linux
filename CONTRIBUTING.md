# Contributing

Contributions are welcome. This project values accuracy, reproducibility, and clarity over novelty.

## Guidelines

- Keep instructions distribution-agnostic where possible.
- Include the exact commands used and the expected output.
- Test changes on real hardware or document the assumptions clearly.
- Do not add third-party binaries or proprietary dependencies.
- Use POSIX-compatible shell in scripts unless a specific distribution context is stated.

## Pull Requests

- Describe the problem your change solves.
- Include hardware context when relevant (CPU, GPU, motherboard, kernel version).
- Keep commits focused. One logical change per commit.
- Run `shellcheck` on any shell script before submitting (see `.shellcheckrc` for project rules).

## Issues

When opening an issue, include:

- Distribution and version
- Kernel version
- CPU and GPU model
- Motherboard model and BIOS version
- Output of `dmesg | grep -Ei 'vfio|iommu|dmar'`
- Output of `lspci -nnk`
- A description of the exact steps that failed

## Code of Conduct

Be respectful. Help others debug without blame. Focus on the problem, not the person.
