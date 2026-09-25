ARCHS = arm64
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DauDat
DauDat_FILES = Tweak.xm
DauDat_FRAMEWORKS = UIKit Foundation CoreFoundation
DauDat_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

