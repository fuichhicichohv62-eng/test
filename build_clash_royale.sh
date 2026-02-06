#!/bin/bash

# 🏰 Clash Royale Mobile Menu Build Script
# Author: fre1zik

echo "🏰 Building Clash Royale Mobile Menu..."
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Theos is installed
if [ -z "$THEOS" ]; then
    echo -e "${RED}❌ Error: THEOS environment variable not set!${NC}"
    echo -e "${YELLOW}Please install Theos and set the THEOS environment variable.${NC}"
    exit 1
fi

echo -e "${BLUE}📦 Theos path: $THEOS${NC}"

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
make clean

# Build the project
echo -e "${BLUE}🔨 Building project...${NC}"
if make package; then
    echo -e "${GREEN}✅ Build successful!${NC}"
    
    # Find the generated .deb file
    DEB_FILE=$(find . -name "*.deb" -type f -newer Makefile | head -1)
    
    if [ -n "$DEB_FILE" ]; then
        echo -e "${GREEN}📦 Package created: $DEB_FILE${NC}"
        
        # Show package info
        echo -e "${BLUE}📋 Package information:${NC}"
        dpkg-deb -I "$DEB_FILE"
        
        echo ""
        echo -e "${GREEN}🎉 Build completed successfully!${NC}"
        echo -e "${YELLOW}📱 To install on jailbroken device:${NC}"
        echo -e "   scp $DEB_FILE root@<device-ip>:/tmp/"
        echo -e "   ssh root@<device-ip> 'dpkg -i /tmp/$(basename "$DEB_FILE") && killall SpringBoard'"
        echo ""
        echo -e "${YELLOW}🔧 To install via package manager:${NC}"
        echo -e "   Add the .deb file to your repository or install via Filza"
        
    else
        echo -e "${RED}❌ Error: .deb file not found!${NC}"
        exit 1
    fi
    
else
    echo -e "${RED}❌ Build failed!${NC}"
    echo -e "${YELLOW}💡 Common solutions:${NC}"
    echo -e "   • Check if all dependencies are installed"
    echo -e "   • Verify Theos installation"
    echo -e "   • Check code syntax"
    exit 1
fi

echo ""
echo -e "${BLUE}🏰 Clash Royale Mobile Menu build script completed!${NC}"