#!/bin/bash

# Script to clean/reset the Xcode project configuration
# This removes any configured values and restores the project to its open-source state
# Used by pre-commit hook to prevent accidental commit of sensitive data

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Cleaning Beat Kanji project configuration...${NC}"

# Clean Swift files first - remove author information
echo "Cleaning Swift files..."
find . -name "*.swift" -type f | while read -r file; do
    if grep -q "Created by Alexander Weichart" "$file"; then
        # Replace the "Created by" line with a generic comment
        sed -i '' 's/\/\/  Created by Alexander Weichart on [0-9][0-9]\.[0-9][0-9]\.[0-9][0-9]\./\/\/  Created for Beat Kanji project/' "$file"
        echo "Cleaned: $file"
    fi
done

# Clean Xcode project file
echo "Cleaning Xcode project file..."

# Reset development team and bundle identifier to empty strings
sed -i '' 's/DEVELOPMENT_TEAM = [^;]*;/DEVELOPMENT_TEAM = "";/g' "Beat Kanji.xcodeproj/project.pbxproj"
sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = [^;]*;/PRODUCT_BUNDLE_IDENTIFIER = "";/g' "Beat Kanji.xcodeproj/project.pbxproj"
echo -e "${GREEN}✓ Reset DEVELOPMENT_TEAM and PRODUCT_BUNDLE_IDENTIFIER to empty values${NC}"

# Ensure .env is not being committed (it should be in .gitignore)
if git diff --cached --name-only | grep -q "^\.env$"; then
    echo -e "${RED}Error: .env file is staged for commit. This file contains secrets and should not be committed.${NC}"
    echo -e "${RED}Run: git reset HEAD .env${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Preserved project settings (version numbers, build configuration, etc.)${NC}"
echo -e "${GREEN}✓ Cleaned Swift files${NC}"
echo -e "${GREEN}✓ Project cleaned and ready for open source distribution${NC}"
