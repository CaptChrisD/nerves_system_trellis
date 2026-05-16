#!/bin/sh

# Seed the kernel entropy pool
/usr/sbin/rngd

# Load the ESP32 SDIO WiFi driver
# Options (resetpin, etc.) are picked up from /etc/modprobe.d/esp-hosted.conf
# /sbin/modprobe esp32_sdio

# Configure eth0 activity LED (PD9)
echo eth0 > /sys/class/leds/:lan/device_name
echo 1 > /sys/class/leds/:lan/link
echo 1 > /sys/class/leds/:lan/tx
echo 1 > /sys/class/leds/:lan/rx
