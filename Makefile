include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CinemanaFix

CinemanaFix_FILES = Tweak.x
CinemanaFix_CFLAGS = -fobjc-arc
CinemanaFix_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
