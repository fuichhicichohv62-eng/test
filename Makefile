ARCHS = arm64
TARGET = iphone:clang:16.5:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ClashRoyaleMobileMenu

ClashRoyaleMobileMenu_FILES = mobile_menu.m
ClashRoyaleMobileMenu_CFLAGS = -fobjc-arc
ClashRoyaleMobileMenu_FRAMEWORKS = UIKit Foundation
ClashRoyaleMobileMenu_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS)/makefiles/tweak.mk