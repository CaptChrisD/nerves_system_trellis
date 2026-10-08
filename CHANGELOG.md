# Changelog

This project does NOT follow semantic versioning. The version increases as
follows:

1. Major version updates are breaking updates to the build infrastructure. These
   should be very rare.
2. Minor version updates are made for every major Buildroot release. This may
   also include Erlang/OTP and Linux kernel updates. These are made four times a
   year shortly after the Buildroot releases.
3. Patch version updates are made for Buildroot minor releases, Erlang/OTP
   releases, and Linux kernel updates. They're also made to fix bugs and add
   features to the build infrastructure.

## v0.5.0-mm.1

Rebase the Metro Marine F-Series system onto upstream
[nerves_system_trellis v0.5.0](https://github.com/nerves-project/nerves_system_trellis/releases/tag/v0.5.0)
(upstream moved from `protolux-electronics` to `nerves-project`).

IMPORTANT: This is a non-backwards compatible release. Devices running any
`0.3.1-mm.x` firmware must be reflashed (FEL/SD); they cannot OTA to this
release. The boot layout changed from extlinux in the rootfs to raw FIT image
slots, and firmware validation now uses U-Boot's `upgrade_available`/`bootcount`
rollback instead of `nerves_fw_validated`.

* Changes
  * The F-Series device tree now lives in its own file,
    `dts/allwinner/sun8i-t113s-mm-fseries.dts`, selected by the `mm-fseries`
    FIT configuration (`trellis.its`) and `fit_config=mm-fseries` in
    `uboot/uboot.env`. Upstream's `sun8i-t113s-trellis.dts` and NSK trees are
    carried unmodified and are not booted.
  * U-Boot console stays on PD7/PD8 (`uart4_pd_pins`); U-Boot status LED stays on
    PD18. Upstream switched its defaults to the Nerves Starter Kit pins.
  * `CONFIG_POWER_RESET` / `CONFIG_POWER_RESET_GPIO` from upstream.
  * esp-hosted host driver stays pinned to ng-1.0.4.0.0 (it must match the
    firmware on the ESP32-C6). Buildroot 2026.05 moved its package to 1.0.6 and
    dropped both the `ESP_SLAVE` make option and the "Fix ng build for 6.15"
    Makefile patch, so `package/esp-hosted/esp-hosted.mk` now passes `ESP_SLAVE`
    itself and the patch is carried in `patches/esp-hosted/`. The removed
    `BR2_PACKAGE_ESP_HOSTED_TARGET_ESP32C6` option is dropped from `nerves_defconfig`.
  * All prior `-mm` customizations are retained: esp-hosted SDIO WiFi package
    and patches, DWMAC ethernet + DP83825I PHY, CAN, USB mass storage/VFAT, LED
    triggers, modprobe/pre-run overlay, product/author metadata.

* Package updates
  * nerves_system_br 1.34.4, GCC 15.3.0, U-Boot 2025.10 (see upstream v0.4.0 to
    v0.5.0 entries below)

## v0.5.0

IMPORTANT: This is a non-backwards compatible release. You will have to reflash
your NSK or Goatmire badge.

* Changes
  * Change U-Boot failure recovery to use U-Boot's upgrade_available feature.
    This fixes an issue preventing first-boot rollback.
  * Use FIT images rather than read kernels from the rootfs. This adds
    flexibility to kernel/dts configurations and possible future initrd use.
  * Allow booting from EROFS root filesystems. This will be supported with
    Nerves 2.
  * Trim U-Boot wait time to 0 seconds. It's still possible to break into
    U-Boot, and this saves 2 seconds of boot time.
  * Add balance bot device tree configuration. This is not enabled by default.
  * Add a redundant U-Boot environment block to protect against corruption
    there.
  * Allow Nerves 2 pre-releases to be used

* Package updates
  * [nerves_system_br 1.34.4](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.34.4)

## v0.4.2

This is a security and bug fix release.

* Changes
  * Include rootfs.tar for use with Nerves 2.0 development builds (ignored by Nerves 1.x)

* Package updates
  * [nerves_system_br 1.34.1](https://github.com/nerves-project/nerves_system_br/releases/tag/v1.34.1)

## v0.4.1

* Changes
  * Disable UART0 to avoid conflict with expansion GPIOs. In the future, the
    plan is to allow it to be enabled via a DTS overlay.
  * Add GPIO labels for PE2 - PE13 to make it easier to refer to them with
    Circuits.GPIO.

## v0.4.0

This is a major update with support for the Nerves Starter Kit. It still
supports the Goatmire badge on OTA updates from previous versions and if you
modify the U-Boot start script before flashing a new device. The plan is to
autodetect the device in the next release.

* Changes
  * linux 6.18.35
  * GCC 15.3.0
  * nerves_system_br v1.34.0

## v0.3.1-mm.6

Back out the kernel-side MCP7940N binding added in mm.5. Keeping
`CONFIG_RTC_DRV_DS1307=y` plus the `rtc@6f` node put kernel I2C traffic on the
bus roughly 230ms before erlinit runs `boardid`, after which `boardid` could no
longer read the ATECC508A at 0x60 and fell through to the SoC-SID backend — so
the device came up with the wrong hostname. Reproduced on 3/3 cold boots; warm
reboots were unaffected, which is why it went unnoticed during development.

`CONFIG_RTC_INTF_SYSFS=y` is retained — it costs nothing and `/sys/class/rtc/*/name`
is the only way to tell the two RTCs apart on a running unit.

The RTC itself is unaffected and still keeps time across a power loss: it is
driven entirely from userspace by `Firmware.RTC.MCP7940N` via
`config :nerves_time, rtc:`, which runs long after `boardid`. The only thing
given up is `RTC_HCTOSYS` setting the clock in the ~2 seconds before the BEAM
starts.

## v0.3.1-mm.5

Add support for the MCP7940N battery-backed RTC on the Metro Marine board:

* `CONFIG_RTC_DRV_DS1307=y` so the chip at I2C2 0x6F is bound and read into the
  system clock at boot via `RTC_HCTOSYS`.
* `CONFIG_RTC_INTF_SYSFS=y` so `/sys/class/rtc/rtcN/name` exists — without it
  there is no way to tell the two RTCs apart on a running unit.
* An `rtc@6f` node under `&i2c2`, plus `rtc0`/`rtc1` aliases. **Both aliases are
  required**: the SoC RTC is a platform device and probes before the I2C bus
  enumerates, so without pinning it takes `rtc0` and becomes the
  `CONFIG_RTC_HCTOSYS_DEVICE` — which has no battery on this board.

Nothing kernel-side writes the RTC back (there is no `hwclock` in the image and
`nerves_time` does not engage the kernel's NTP discipline path); that is done by
`Firmware.RTC.MCP7940N` in the application.

## v0.3.1

Bump `nerves_system_br` and `nerves`. This also adds support for the hardware
PWM, and fixes several clock issues relating to the RTC that slowed down the
initial startup time. Additionally, this renames the default hostname to
`nerves-SERIALNUM` to follow convention of other nerves systems.

This is the final release with primary support for the 2025 Goatmire name
badges. Future releases will target the Nerves Starter Kit.

## v0.3.0

Bump `nerves_system_br` version to latest. This release also relaxes the fwup
checks for the platform name changed in v0.2.0, so upgrading from v0.1.x should
no longer result in errors when upgrading via OTA.

## v0.2.0

Bump `nerves_system_br` and `nerves` versions to latest. This update provides
support for OTP 28 and Elixir 1.19.

Additionally, this changes the platform name from `vitis` to `trellis` in
`fwup.conf`. This may result in an error when upgrading firmware OTA via fwup.
Please reflash any affected boards using FEL mode and
[`usb_fel_loaders`](https://github.com/gworkman/usb_fel_loaders)

## v0.1.1

Add support for RTL8723 wifi modules.

## v0.1.0

This is the initial release.
