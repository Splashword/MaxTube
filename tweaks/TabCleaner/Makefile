TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = YouTube

# Build-time choices (1 = remove the tab, 0 = keep it).
HIDE_SHORTS_TAB ?= 1
HIDE_UPLOAD_TAB ?= 0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TabCleaner
$(TWEAK_NAME)_FILES = Tweak.x
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -DHIDE_SHORTS_TAB=$(HIDE_SHORTS_TAB) -DHIDE_UPLOAD_TAB=$(HIDE_UPLOAD_TAB)

include $(THEOS_MAKE_PATH)/tweak.mk
