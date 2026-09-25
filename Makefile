ARCHS = arm64
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DauDat
DauDat_FILES = Tweak.xm
DauDat_FRAMEWORKS = UIKit Foundation CoreFoundation
DauDat_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = DauDatPrefs
DauDatPrefs_FILES = DauDatPrefsRootListController.m
DauDatPrefs_FRAMEWORKS = UIKit
DauDatPrefs_PRIVATE_FRAMEWORKS = Preferences
DauDatPrefs_INSTALL_PATH = /Library/PreferenceBundles
DauDatPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

after-install::
	install.exec "killall -9 Preferences || true"
