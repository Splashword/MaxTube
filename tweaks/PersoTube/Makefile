TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = YouTube

# Build-time choices (set by the "Build open-source YouTube" workflow).
# TAB_ORDER: bottom-bar tabs to keep, in order (home,shorts,upload,subscriptions,you,explore).
#            Empty = do not touch the bar.
# LANDSCAPE_SIDE: 0 = off, 1 = camera on the right, 2 = camera on the left.
TAB_ORDER ?= home,subscriptions,you
LANDSCAPE_SIDE ?= 0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PersoTube
$(TWEAK_NAME)_FILES = Tabs.x Landscape.x
$(TWEAK_NAME)_FRAMEWORKS = UIKit
$(TWEAK_NAME)_CFLAGS = -fobjc-arc '-DTAB_ORDER="$(TAB_ORDER)"' -DLANDSCAPE_SIDE=$(LANDSCAPE_SIDE)

include $(THEOS_MAKE_PATH)/tweak.mk
