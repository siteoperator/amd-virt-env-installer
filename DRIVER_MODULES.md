# AMDGPU / amdkfd Kernel Modules

This document explains the core Linux kernel modules that power AMD GPUs under ROCm, how to inspect them, and recommended parameters especially for Ryzen APUs on CachyOS / Arch Linux.

## Core Modules

| Module | Purpose | Notes |
|--------|---------|-------|
| **amdgpu** | Main open-source DRM driver | Handles KMS, Display Core, memory management, SDMA, GC engines, power management. Loaded automatically for AMD PCI devices (vendor `1002`). |
| **amdkfd** | Kernel Fusion Driver | Compute interface used by ROCm / HSA. Manages queues, doorbells, process contexts, SVM. Exposes `/dev/kfd`. Usually loaded together with `amdgpu` when `CONFIG_HSA_AMD` is enabled. |

Both modules are part of the mainline Linux kernel (and the ROCm `amdgpu` fork for newer features). On CachyOS / Arch they come with the kernel + `linux-firmware` (or `linux-firmware-amdgpu`).

### Quick Checks

```bash
# Are the modules loaded?
lsmod | grep -E 'amdgpu|amdkfd'

# Device nodes
ls -l /dev/kfd /dev/dri/

# Detailed info
rocminfo
rocm-smi
```

If `/dev/kfd` is missing, `amdkfd` is not active. Common causes: user not in `render`/`video` groups, or driver failed to load.

## Important Module Parameters

Parameters can be set via kernel command line (GRUB) or `/etc/modprobe.d/amdgpu.conf`.

| Parameter | Description | Typical / Recommended |
|-----------|-------------|-----------------------|
| `ppfeaturemask` | Bitmask for power features (DPM, overdrive, GFXOFF, …) | Default = stable set. For overdrive: OR current value with `0x4000`. Full `0xffffffff` can be unstable. |
| `gpu_recovery` | GPU reset / recovery | `1` recommended for compute and virtualized workloads |
| `runpm` | Runtime power management (mainly dGPUs) | `0` to disable power-down when idle (useful for some passthrough / stability cases) |
| `virtual_display` | Virtual CRTCs for headless / virt | e.g. `0000:03:00.0,4` |
| `dc` | Display Core | Usually leave at auto (`-1`) |
| `dpm` | Dynamic power management | Usually auto |

### Recommended modprobe config (Ryzen APUs / CachyOS)

Create `/etc/modprobe.d/amdgpu.conf`:

```bash
# Recommended for ROCm / compute on Ryzen APUs
options amdgpu gpu_recovery=1

# Optional: enable overdrive (clocks / voltages) – safer than full 0xffffffff
# First check current mask, then OR with 0x4000:
# printf 'amdgpu.ppfeaturemask=0x%x\n' "$(($(cat /sys/module/amdgpu/parameters/ppfeaturemask) | 0x4000))"
# options amdgpu ppfeaturemask=0x0007ffff   # example

# Optional for discrete GPUs or certain stability issues:
# options amdgpu runpm=0
```

After changes on Arch/CachyOS:

```bash
sudo mkinitcpio -P
# or reboot
```

On Ubuntu/Debian:

```bash
sudo update-initramfs -u
```

### Checking Active Parameters

```bash
cat /sys/module/amdgpu/parameters/ppfeaturemask
cat /sys/module/amdgpu/parameters/gpu_recovery
cat /sys/module/amdgpu/parameters/runpm
cat /sys/module/amdgpu/parameters/dpm
```

## Ryzen APU Notes

For the models supported by this installer (680M / 780M / 890M):

- The same `amdgpu` + `amdkfd` stack is used.
- No special SI/CIK parameters are needed (those are only for very old GCN 1.x cards).
- The critical userspace variable remains `HSA_OVERRIDE_GFX_VERSION` (see main README).
- Ensure the latest `linux-firmware` is installed.
- On CachyOS the recent kernels usually work out of the box.

## Virtualization Reminder

When using VFIO passthrough, the host must **not** bind `amdgpu` to the GPU that is passed through. Use `vfio-pci` instead and blacklist or soft-depend `amdgpu` for that device. See `VIRTUALIZATION.md`.

## References

- Kernel documentation: Module Parameters for amdgpu
- ArchWiki: AMDGPU
- ROCm documentation
