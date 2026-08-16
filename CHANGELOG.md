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
