# Override esp-hosted download settings and build flags.
#
# Pin the host driver to ng-1.0.4.0.0. Buildroot 2026.05 (nerves_system_br
# 1.34.x) bumped its esp-hosted package to 1.0.6, but the esp-hosted NG host
# driver must match the firmware flashed on the ESP32-C6 module, and our
# patches in patches/esp-hosted/ target 1.0.4.0.0. Buildroot evaluates
# ESP_HOSTED_VERSION immediately when it defines the package, so overriding it
# here does not change the build directory name (esp-hosted-1.0.6) or the
# legal-info version; the SOURCE/SITE overrides below are what actually select
# the tarball, and patches/esp-hosted/esp-hosted.hash carries its checksum.
#
# The upstream Buildroot package uses tag "release/ng-v<version>" but the
# actual GitHub tag is "release/ng-<version>" (no "v" prefix).
ESP_HOSTED_PINNED_VERSION = 1.0.4.0.0
ESP_HOSTED_SITE = https://github.com/espressif/esp-hosted/archive/release
ESP_HOSTED_SOURCE = ng-$(ESP_HOSTED_PINNED_VERSION).tar.gz

# Compile esp32_sdio with AP-mode support so wlan0 advertises
# NL80211_IFTYPE_AP to cfg80211. See esp_cfg80211.c ~line 1207-1209
# and host/Makefile lines 23-25 in the ng-1.0.4.0.0 source.
ESP_HOSTED_MODULE_MAKE_OPTS += CONFIG_AP_SUPPORT=y

# The ng-1.0.4.0.0 host Makefile selects the slave-specific include/source
# directories via ESP_SLAVE. Buildroot's 1.0.4-era package passed this; the
# 1.0.6 package no longer does (1.0.6 dropped the variable), so pass it here or
# the build fails with "utils.h: No such file or directory".
ESP_HOSTED_MODULE_MAKE_OPTS += ESP_SLAVE=CONFIG_TARGET_ESP32C6=y
