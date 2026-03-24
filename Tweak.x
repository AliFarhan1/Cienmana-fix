TARGET := iphone:clang:17.5:14.0
ARCHS = arm64

INSTALL_TARGET_PROCESSES = Cinemana

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CinemanaFix

CinemanaFix_FILES = Tweak.x
CinemanaFix_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
