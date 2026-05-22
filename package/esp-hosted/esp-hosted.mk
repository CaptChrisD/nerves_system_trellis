# Override esp-hosted download settings and build flags.
#
# The upstream Buildroot package uses tag "release/ng-v<version>" but the
# actual GitHub tag is "release/ng-<version>" (no "v" prefix).
# Fix the SITE and SOURCE to match the real tag.
ESP_HOSTED_SITE = https://github.com/espressif/esp-hosted/archive/release
ESP_HOSTED_SOURCE = ng-$(ESP_HOSTED_VERSION).tar.gz

# Compile esp32_sdio with AP-mode support so wlan0 advertises
# NL80211_IFTYPE_AP to cfg80211. See esp_cfg80211.c ~line 1207-1209
# and host/Makefile lines 23-25 in the ng-1.0.4.0.0 source.
ESP_HOSTED_MODULE_MAKE_OPTS += CONFIG_AP_SUPPORT=y
