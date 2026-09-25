ARCHS = arm64
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DuoDashUnifiedFullscreen
DuoDashUnifiedFullscreen_FILES = Tweak.xm
DuoDashUnifiedFullscreen_FRAMEWORKS = UIKit Foundation
DuoDashUnifiedFullscreen_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = DauDatPrefs
DauDatPrefs_FILES = DauDatPrefsRootListController.m
DauDatPrefs_FRAMEWORKS = UIKit
DauDatPrefs_INSTALL_PATH = /Library/PreferenceBundles
DauDatPrefs_CFLAGS = -fobjc-arc
DauDatPrefs_RESOURCE_DIRS = layout/Library/PreferenceBundles/DauDatPrefs.bundle
DauDatPrefs_LDFLAGS = -undefined dynamic_lookup
include $(THEOS_MAKE_PATH)/bundle.mk
