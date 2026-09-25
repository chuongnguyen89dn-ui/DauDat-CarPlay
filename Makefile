ARCHS = arm64
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = DuoDashUnifiedFullscreen
DuoDashUnifiedFullscreen_FILES = Tweak.xm
DuoDashUnifiedFullscreen_FRAMEWORKS = UIKit Foundation
DuoDashUnifiedFullscreen_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tweak.mk
