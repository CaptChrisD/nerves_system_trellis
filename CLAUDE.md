# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Nerves system** package (`nerves_system_trellis_mm`), a fork of upstream `nerves-project/nerves_system_trellis` (remote `upstream`; `origin` is `CaptChrisD/nerves_system_trellis`) targeting the Metro Marine F-Series Gateway board, based on the Allwinner T113-S4 SoC (dual-core ARM Cortex-A7). It defines the entire embedded Linux system: bootloader (U-Boot 2025.10), kernel (Linux 6.18.x), device tree, firmware update strategy, and root filesystem overlay. Toolchain is GCC 15.3 via nerves_system_br 1.34.x.

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
MBR → SPL+U-Boot (blk 16) → U-Boot env 1 (blk 8192) → U-Boot env 2 → FIT A (blk 10240) → FIT B → p1 Rootfs A → p2 Rootfs B → p3 App Data (ext4)
```

The kernel and device trees are packaged as a FIT image (`trellis.its` → `trellis.itb`,
built by `post-createfs.sh` with `mkimage`) written to raw slots, not stored in the
rootfs. U-Boot picks the board via `fit_config` in `uboot/uboot.env`; for this fork the
default is `mm-fseries`. Rollback uses U-Boot's `upgrade_available`/`bootcount`/`bootlimit`
(Nerves validates on boot and sets `upgrade_available=0`). Device paths use the generic
`/dev/rootdisk0` symlink.

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
| `dts/allwinner/sun8i-t113s-mm-fseries.dts` | **F-Series board device tree (the one that boots).** Pin muxing, peripherals, regulators, LEDs |
| `dts/allwinner/sun8i-t113s-trellis.dts`, `*-nerves-starter-kit.dts`, `*-goatmire-badge.dts`, `*-nsk-balance-bot.dts` | Upstream board trees, carried unmodified and not booted. Never use them as a base for F-Series changes |
| `trellis.its` | FIT image description; `mm-fseries` config is the default |
| `uboot/sun8i-t113s-trellis.dts` | U-Boot device tree (separate from kernel DTS). Ours: console on `uart4_pd_pins` (PD7/PD8), status LED PD18. Upstream defaults to NSK PG2/PG3; keep ours on merges |
| `rootfs_overlay/` | Files overlaid onto the root filesystem |

### Hardware Interfaces (from device tree)

- **Console:** UART4 on PD7/PD8 at 115200 baud
- **Storage:** MMC0 (on-board flash, 4-bit); `mmc0`/`mmc1` aliases are pinned so MMC1 is always the WiFi
- **Networking:** 100M Ethernet (DWMAC/RMII + DP83825I PHY, MAC from SoC SID); ESP32-C6 WiFi over SDIO on MMC1 via the `esp-hosted` Buildroot package (`package/esp-hosted`, `patches/esp-hosted`)
- **Buses:** I2C2 (PD20/PD21), CAN0, UART1 (ESP control), UART2 (STM32 coprocessor), UART3 (Bluetooth), SPI1 disabled
- **USB:** OTG (USB-C for FEL mode), USB host (EHCI/OHCI) with mass storage + VFAT for USB firmware updates
- **LEDs:** `mm-fseries:*` status (PC7), ethernet (PD9), can (PD6), audio (PB7), trigger1-4 (PD16-PD19)
- **Identity:** ATECC508A crypto chip on I2C2 for serial numbers
- **RTC:** MCP7940N on I2C2 at 0x6F, deliberately NOT bound in-kernel (see the comment in
  the DTS and the v0.3.1-mm.6 changelog). It is driven from userspace by the firmware app.

### Post-Build Pipeline

1. `post-build.sh` — Compiles `fwup-ops.conf` into `ops.fw` placed at `/usr/share/fwup/`
2. `post-createfs.sh` — Builds `trellis.itb` from `trellis.its`, then standard Nerves post-image processing

### Runtime Configuration

- `rootfs_overlay/etc/erlinit.config` — Erlang VM startup (console ttyS4, hostname `nerves-<serial>`, mounts app partition)
- `rootfs_overlay/etc/boardid.config` — Serial number sources (ATECC508A first, then SoC SID fallback)
- `rootfs_overlay/etc/modprobe.d/esp-hosted.conf`, `rootfs_overlay/usr/bin/pre-run.sh` — ESP32 SDIO driver options / erlinit pre-run hook

## Merging from upstream

`git fetch upstream --tags && git merge vX.Y.Z`. Keep: `@app`/`@github_organization` in `mix.exs`, `NERVES_FW_PRODUCT`/`NERVES_FW_AUTHOR` in `fwup.conf`, `fit_config=mm-fseries` in `uboot.env`, the `mm-fseries` entries in `trellis.its`, our U-Boot DTS pins/LED, and everything in `package/`, `patches/`, `external.mk`. Let upstream's own DTS files take upstream's content. Bump `VERSION` to `<upstream>-mm.N`.
