################################################################################
#
# trellis_radio
#
################################################################################

TRELLIS_RADIO_VERSION = f6f3582
TRELLIS_RADIO_SITE = https://pushin.eu/gus/trellis-radio.git
TRELLIS_RADIO_SITE_METHOD = git
TRELLIS_RADIO_LICENSE = GPL-2.0

TRELLIS_RADIO_MODULE_SUBDIRS = driver

define TRELLIS_RADIO_INSTALL_FW_BLOBS
	$(INSTALL) -D -m 0644 $(@D)/firmware/blobs/trellis_flash_stub.bin \
		$(TARGET_DIR)/lib/firmware/trellis_flash_stub.bin
	if [ -f $(@D)/firmware/blobs/trellis_radio_fw.bin ]; then \
		$(INSTALL) -D -m 0644 $(@D)/firmware/blobs/trellis_radio_fw.bin \
			$(TARGET_DIR)/lib/firmware/trellis_radio_fw.bin; \
	else \
		echo "trellis_radio: trellis_radio_fw.bin not synced, skipping (see scripts/sync-fw-blob.sh)"; \
	fi
endef
TRELLIS_RADIO_POST_INSTALL_TARGET_HOOKS += TRELLIS_RADIO_INSTALL_FW_BLOBS

$(eval $(kernel-module))
$(eval $(generic-package))
