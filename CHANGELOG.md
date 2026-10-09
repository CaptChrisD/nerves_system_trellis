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

## v0.5.0-mm.3

Replace ESP-Hosted-NG with [trellis-radio](https://pushin.eu/gus/trellis-radio)
(pinned to `f6f3582`) for the ESP32-C6 radio.

IMPORTANT: Requires a matching light_controller_firmware release. The app's
`Firmware.InitEsp32`/`Firmware.FlashEsp32` bring-up must be removed and the AP
moved to `wlan1`; the old app on this system will fail to open `ESP_RESET`.

* Changes
  * `package/trellis_radio` (kernel module built from the pushin.eu git repo over
    https) replaces `package/esp-hosted` + `patches/esp-hosted`.
  * The ESP32-C6 firmware is now a single merged image shipped at
    `/lib/firmware/trellis_radio_fw.bin`, and the driver reflashes the chip
    **over SDIO** whenever the running version differs
    (`/etc/modprobe.d/trellis_radio.conf` sets `fw_autoupdate=1`). First boot
    on a unit still running esp-hosted firmware reflashes it (~45 s). No UART
    flashing or ESP-IDF blobs in the app any more.
  * `trellis_radio` is loaded from `pre-run.sh` before the BEAM starts.
  * Device tree: `ESP_RESET` (PG11) is an `mmc-pwrseq-simple` node on `mmc1`
    and `ESP_BOOT` (PG10) is `boot-gpios` on a `trellis-radio@1` child. Both
    lines are kernel-owned; userspace uses the driver's `esp32_boot_mode`
    sysfs attribute instead of GPIO.
  * Interfaces: `wlan0` is WiFi STA only, `wlan1` is the AP, `hci0` is BLE
    over SDIO (UART3 is no longer used for Bluetooth), `wpan0` is 802.15.4.
    STA and AP are mutually exclusive roles in the firmware.
  * Kernel: `CONFIG_IEEE802154=y`, `CONFIG_MAC802154=y`, `CONFIG_CRYPTO_MD5=y`.
  * Driver patches in `package/trellis_radio/*.patch`, exported from our fork
    of trellis-radio (`../trellis-radio`, branch `mm-ap-mode` on top of
    `f6f3582`), needed for wpa_supplicant 2.12 to run the AP:
    * `WIPHY_FLAG_REPORTS_OBSS`: host-SME hostapd/wpa_supplicant register for
      OBSS beacons before `START_AP` and abort if the kernel refuses; without
      the flag the SSID is never advertised ("Failed to set beacon parameters").
    * `.del_key` answered locally (firmware ignores it) so wpa_supplicant's
      six startup key flushes no longer eat ~3 s of control pacing and trip
      VintageNet's 3 s control-socket wait into a restart loop.
    * `.mgmt_tx` on the AP netdev handles deauth/disassoc itself (broadcast
      completes locally, unicast maps to `AP_DEAUTH_STA`) instead of sending
      them on the firmware's STA interface, which stalled the firmware's
      control task, timed out the GTK install, and ended in the TX
      credit-starvation wedge.
    Later commits in the same fork (all in `package/trellis_radio/*.patch`):
    diagnostic `ap_host_ies` module parameter; AP_ADD_STATION now carries
    the client's supported-rates/HT/VHT/HE IEs (a node added without them is
    an 11b station that never gets its association response); management
    frame TX status is reported to cfg80211 (hostapd only completes
    association and starts the 4-way handshake on that status).
  * `rootfs_overlay/lib/firmware/trellis_radio_fw.bin` is now built from the
    fork (`trellis-radio/firmware`, see its README) on ESP-IDF v5.5.1 with
    esp-hosted NG's patched Wi-Fi libraries. The upstream blob was built on
    stock IDF, whose libraries lack the beacon-slot and AP management-TX
    hooks the host-SME design needs: it never beaconed a usable frame.
    Firmware fixes: AP-sourced management frames go out via
    `ieee80211_send_mgmt_internal(WIFI_IF_AP)` instead of the STA path (which
    hung the Wi-Fi task); the merged image now depends on the binaries it
    merges.
    A STA scan while the AP is up now runs the chip in AP+STA for the scan
    (the setup UI could not list networks in AP mode: STA_SCAN returned EBUSY),
    and the firmware version string is the short commit hash.
    Proposed upstream as https://pushin.eu/gus/trellis-radio/pulls/3 (fork
    `captchrisd/trellis-radio`, branch `mm-ap-mode`, 18 commits); the patches and
    blob here are generated from that branch head.
  * `BR2_GLOBAL_PATCH_DIR` is back to upstream's value and `patches/` is gone;
    the fork no longer carries any Buildroot package patches, so
    `mix nerves.system.lint` passes again.

## v0.5.0-mm.2

* Changes
  * nerves_system_br 1.35.1: Buildroot 2026.08 and Erlang/OTP 29.1.1. OTP
    29.0.6's ssh daemon rejected any `subsystem` request preceded by an `env`
    request on the channel (OTP-20371), which broke `mix upload` and sftp from
    macOS clients that send `LANG`/`LC_*`. Fixed in 29.1.1.
  * `BR2_TOOLCHAIN_EXTERNAL_GCC_15=y` from upstream main.

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
