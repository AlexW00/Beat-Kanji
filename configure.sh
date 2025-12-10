#!/bin/bash

# Setup script for Beat Kanji
# Configures the Xcode project with your development team and bundle identifier

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROJECT_FILE="Beat Kanji.xcodeproj/project.pbxproj"

if [ ! -f ".env" ]; then
    if [ -f "../../.env" ]; then
        echo -e "${YELLOW}Found .env in grandparent directory. Copying...${NC}"
        cp "../../.env" .env
        echo -e "${GREEN}Copied .env from ../../.env${NC}"
    else
        echo -e "${YELLOW}No .env file found. Creating from .env.example...${NC}"
        cp .env.example .env
        echo -e "${GREEN}Created .env file.${NC}"
        echo -e "${YELLOW}Please edit .env and add your DEVELOPMENT_TEAM and PRODUCT_BUNDLE_IDENTIFIER.${NC}"
        exit 1
    fi
fi

# Load environment variables
source .env

if [ -z "$DEVELOPMENT_TEAM" ]; then
    echo -e "${RED}Error: DEVELOPMENT_TEAM is not set in .env${NC}"
    exit 1
fi

if [ -z "$PRODUCT_BUNDLE_IDENTIFIER" ]; then
    echo -e "${RED}Error: PRODUCT_BUNDLE_IDENTIFIER is not set in .env${NC}"
    exit 1
fi

echo -e "${YELLOW}Configuring Xcode project...${NC}"

# Update DEVELOPMENT_TEAM
# We use a more robust sed pattern to handle existing empty strings or other values
sed -i '' "s/DEVELOPMENT_TEAM = [^;]*;/DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM;/g" "$PROJECT_FILE"

# Update PRODUCT_BUNDLE_IDENTIFIER
sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = [^;]*;/PRODUCT_BUNDLE_IDENTIFIER = \"$PRODUCT_BUNDLE_IDENTIFIER\";/g" "$PROJECT_FILE"

echo -e "${GREEN}✓ Updated DEVELOPMENT_TEAM to $DEVELOPMENT_TEAM${NC}"
echo -e "${GREEN}✓ Updated PRODUCT_BUNDLE_IDENTIFIER to $PRODUCT_BUNDLE_IDENTIFIER${NC}"

# Ensure Kanji dataset is available
KANJI_DB="Beat Kanji/Resources/Data/kanji.sqlite"
EXTERNAL_KANJI_DB=${EXTERNAL_KANJI_DB:-"../../Beat Kanji/Resources/Data/kanji.sqlite"}

if [ -f "$KANJI_DB" ]; then
    echo -e "${GREEN}✓ Kanji dataset present${NC}"
elif [ -f "$EXTERNAL_KANJI_DB" ]; then
    echo -e "${YELLOW}Found external kanji dataset at $EXTERNAL_KANJI_DB; copying...${NC}"
    mkdir -p "$(dirname "$KANJI_DB")"
    cp "$EXTERNAL_KANJI_DB" "$KANJI_DB"
    echo -e "${GREEN}✓ Copied kanji dataset from external location${NC}"
else
    echo -e "${YELLOW}Kanji dataset missing. Generating...${NC}"
    if [ -x "./scripts/generate_kanji.sh" ]; then
        ./scripts/generate_kanji.sh
    else
        bash ./scripts/generate_kanji.sh
    fi
    echo -e "${GREEN}✓ Generated kanji.sqlite${NC}"
fi

echo -e "${GREEN}Setup complete! You can now run ./build.sh or open the project in Xcode.${NC}"
