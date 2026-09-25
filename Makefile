ARCHS = arm64
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DauDat
DauDat_FILES = Tweak.xm
DauDat_FRAMEWORKS = UIKit Foundation CoreFoundation
DauDat_CFLAGS = -fobjc-arc

BUNDLE_NAME = DauDatPrefs
DauDatPrefs_FILES = DauDatPrefsRootListController.m
DauDatPrefs_INSTALL_PATH = /Library/PreferenceBundles
DauDatPrefs_FRAMEWORKS = UIKit
DauDatPrefs_PRIVATE_FRAMEWORKS = Preferences
DauDatPrefs_CFLAGS = -fobjc-arc
DauDatPrefs_RESOURCE_DIRS = layout/Library/PreferenceBundles/DauDatPrefs.bundle
DauDatPrefs_INFOPLIST_FILE = DauDatPrefs-Info.plist

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
