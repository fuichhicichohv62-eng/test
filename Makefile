ARCHS = arm64
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ClashRoyaleMobileMenu

ClashRoyaleMobileMenu_FILES = mobile_menu.m
ClashRoyaleMobileMenu_CFLAGS = -fobjc-arc -I. -DCONFIG_ASSERT=1 -DCONFIG_PRINT=1 -DCONFIG_TIMER=1
ClashRoyaleMobileMenu_FRAMEWORKS = UIKit Foundation
ClashRoyaleMobileMenu_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS)/makefiles/tweak.mk