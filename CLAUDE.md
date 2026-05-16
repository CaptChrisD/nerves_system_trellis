# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Nerves system** package (`nerves_system_trellis`) for the Trellis hardware platform, based on the Allwinner T113-S4 SoC (dual-core ARM Cortex-A7). It defines the entire embedded Linux system: bootloader (U-Boot 2025.04), kernel (Linux 6.12.32), device tree, firmware update strategy, and root filesystem overlay.

This is NOT a typical Elixir application — it is a Nerves system that produces a cross-compiled Linux system image via Buildroot. The Elixir code is minimal (just `mix.exs` for packaging). Most of the project is configuration files: Buildroot defconfig, kernel defconfig, U-Boot config/patches, device tree sources, and fwup firmware update configs.

## Build Commands

```bash
# Build the system (requires Nerves environment)
mix deps.get
mix compile

# Lint the system configuration
mix nerves.system.lint nerves_defconfig

# Generate docs
MIX_ENV=docs mix docs
```

Building this system requires Buildroot and runs a full cross-compilation. It is not a quick build — expect significant time for a clean build. Pre-built artifacts are fetched from GitHub releases when used as a dependency.

## Architecture

### Firmware Layout (A/B Partitioning)

The system uses A/B root filesystem partitioning for safe OTA updates, defined in `fwup.conf`:

```
MBR → SPL+U-Boot (offset 16) → U-Boot env (offset 8192) → Rootfs A → Rootfs B → App Data (ext4)
```

- `fwup.conf` — Factory image creation and OTA upgrade tasks (`complete`, `upgrade.a`, `upgrade.b`, `provision`)
- `fwup-ops.conf` — On-device operations (`factory-reset`, `revert`, `validate`, `status`)
- `fwup_include/provisioning.conf` — Serial number provisioning

### Key Configuration Files

| File | Purpose |
|------|---------|
| `nerves_defconfig` | Buildroot top-level config (packages, toolchain, kernel/U-Boot versions) |
| `linux/linux_defconfig` | Linux kernel config (drivers, networking, CAN, WiFi) |
| `uboot/uboot_defconfig` | U-Boot bootloader config |
| `uboot/uboot.env` | U-Boot environment variables (boot logic, firmware state) |
| `uboot/*.patch` | Custom U-Boot patches (UART4 console, DRAM init, FEL mode) |
| `dts/allwinner/sun8i-t113s-trellis.dts` | Main device tree (pin muxing, peripherals, regulators) |
| `uboot/sun8i-t113s-trellis.dts` | U-Boot device tree (separate from kernel DTS) |
| `rootfs_overlay/` | Files overlaid onto the root filesystem |

### Hardware Interfaces (from device tree)

- **Console:** UART4 on PD7/PD8 at 115200 baud
- **Storage:** MMC0 (SDIO flash, 4-bit)
- **Networking:** Realtek WiFi (RTL8188/RTL8723/RTL8723DU)
- **Buses:** I2C2, SPI1, CAN0, RS485 (UART5), UART1/UART3
- **USB:** OTG (USB-C for FEL mode), USB host (EHCI/OHCI)
- **LEDs:** Green (heartbeat), Blue (user-controllable)
- **Identity:** ATECC508A crypto chip on I2C2 for serial numbers

### Post-Build Pipeline

1. `post-build.sh` — Compiles `fwup-ops.conf` into `ops.fw` placed at `/usr/share/fwup/`
2. `post-createfs.sh` — Standard Nerves post-image processing

### Runtime Configuration

- `rootfs_overlay/etc/erlinit.config` — Erlang VM startup (console ttyS4, hostname `wisteria-<serial>`, mounts app partition)
- `rootfs_overlay/etc/boardid.config` — Serial number sources (ATECC508A first, then SoC SID fallback)
