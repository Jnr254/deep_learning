#!/bin/bash

# Dataset Downloader - Handles data repository pages
# Usage: ./download_dataset.sh <URL> [directory]

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get arguments
URL="${1}"
DOWNLOAD_DIR="${2:-./datasets}"
TARGET_FILE="${3}"  # Optional: specify which .zip file to download

if [ -z "$URL" ]; then
    echo "Usage: $0 <URL> [directory] [target-file]"
    echo "Example: $0 https://data.caltech.edu/records/mzrjq-6wc02"
    echo "Example: $0 https://data.caltech.edu/records/mzrjq-6wc02 ./datasets caltech-101.zip"
    exit 1
fi

# Create directory
mkdir -p "$DOWNLOAD_DIR"

echo -e "${YELLOW}Dataset Downloader${NC}"
echo -e "URL: $URL"
echo -e "Directory: $DOWNLOAD_DIR"

# Handle Kaggle
if [[ "$URL" == *"kaggle.com"* ]]; then
    echo -e "${YELLOW}Kaggle detected! Use:${NC}"
    echo "kaggle datasets download -d [dataset] -p $DOWNLOAD_DIR --unzip"
    exit 0
fi

# Direct .zip file
if [[ "$URL" == *.zip ]]; then
    FILENAME=$(basename "$URL")
    echo -e "${GREEN}Direct .zip URL detected${NC}"
    wget -L --show-progress -O "$DOWNLOAD_DIR/$FILENAME" "$URL"
    
    if [ $? -eq 0 ]; then
        unzip -q -o "$DOWNLOAD_DIR/$FILENAME" -d "$DOWNLOAD_DIR"
        echo -e "${GREEN}✓ Downloaded and extracted${NC}"
    fi
    exit $?
fi

# Handle CaltechDATA specifically
if [[ "$URL" == *"data.caltech.edu"* ]]; then
    echo -e "${YELLOW}CaltechDATA repository detected${NC}"
    
    # Extract record ID from URL
    RECORD_ID=$(echo "$URL" | grep -oE 'records/[^/]+' | cut -d'/' -f2)
    
    if [ -z "$RECORD_ID" ]; then
        echo -e "${RED}Cannot extract record ID from URL${NC}"
        exit 1
    fi
    
    # Default to caltech-101.zip if no target specified
    if [ -z "$TARGET_FILE" ]; then
        TARGET_FILE="caltech-101.zip"
        echo -e "${YELLOW}No target file specified, looking for: $TARGET_FILE${NC}"
    fi
    
    # Construct the direct download URL for CaltechDATA
    # Pattern: https://data.caltech.edu/records/{id}/files/{filename}?download=1
    DOWNLOAD_URL="https://data.caltech.edu/records/${RECORD_ID}/files/${TARGET_FILE}?download=1"
    
    echo -e "${GREEN}Download URL: $DOWNLOAD_URL${NC}"
    
    # Download with redirect following
    echo -e "${YELLOW}Downloading $TARGET_FILE...${NC}"
    wget -L --show-progress -O "$DOWNLOAD_DIR/$TARGET_FILE" "$DOWNLOAD_URL"
    
    if [ $? -eq 0 ]; then
        # Verify it's a zip file
        if file "$DOWNLOAD_DIR/$TARGET_FILE" | grep -q -i "zip\|archive"; then
            echo -e "${YELLOW}Extracting...${NC}"
            unzip -q -o "$DOWNLOAD_DIR/$TARGET_FILE" -d "$DOWNLOAD_DIR"
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Extraction complete${NC}"
                echo -n "Delete zip? (y/n): "
                read -r answer
                [[ "$answer" == "y" ]] && rm "$DOWNLOAD_DIR/$TARGET_FILE"
            else
                echo -e "${YELLOW}Note: Extraction had issues, file might be corrupted${NC}"
            fi
            
            echo -e "${GREEN}✓ Dataset ready in: $DOWNLOAD_DIR${NC}"
        else
            echo -e "${RED}Downloaded file is not a valid zip archive${NC}"
            echo "The download might have failed or returned an error page"
            exit 1
        fi
    else
        echo -e "${RED}✗ Download failed${NC}"
        exit 1
    fi
    exit 0
fi

# Generic repository page handling
echo -e "${YELLOW}Searching page for .zip files...${NC}"
TEMP="/tmp/page_$$.html"
wget -q -O "$TEMP" "$URL" 2>/dev/null

if [ ! -f "$TEMP" ]; then
    echo -e "${RED}Cannot access page${NC}"
    exit 1
fi

# Find .zip URLs (excluding preview links)
ZIP_URL=$(grep -oE 'href="[^"]*\.zip(\?[^"]*)?"|https?://[^"<>[:space:]]*\.zip' "$TEMP" | \
          grep -v '/preview/' | \
          grep -oE '[^"]+\.zip(\?[^"]*)?$' | \
          head -1)

rm -f "$TEMP"

if [ -z "$ZIP_URL" ]; then
    echo -e "${RED}No .zip download link found${NC}"
    echo ""
    echo "Tips:"
    echo "1. Open $URL in a browser"
    echo "2. Look for 'Download' or 'Files' section"
    echo "3. Right-click the .zip file → 'Copy Link Address'"
    echo "4. Run: $0 <direct-link>"
    echo ""
    echo "For CaltechDATA, you can also specify the filename:"
    echo "$0 $URL ./datasets filename.zip"
    exit 1
fi

# Make absolute URL if relative
if [[ "$ZIP_URL" != http* ]]; then
    BASE=$(echo "$URL" | grep -oE 'https?://[^/]+')
    ZIP_URL="${BASE}${ZIP_URL}"
fi

FILENAME=$(basename "$ZIP_URL" | cut -d'?' -f1)
echo -e "${GREEN}Found: $FILENAME${NC}"

# Download and extract
wget -L --show-progress -O "$DOWNLOAD_DIR/$FILENAME" "$ZIP_URL"

if [ $? -eq 0 ]; then
    echo -e "${YELLOW}Extracting...${NC}"
    unzip -q -o "$DOWNLOAD_DIR/$FILENAME" -d "$DOWNLOAD_DIR"
    echo -e "${GREEN}✓ Complete! Files in: $DOWNLOAD_DIR${NC}"
    
    echo -n "Delete zip? (y/n): "
    read -r answer
    [[ "$answer" == "y" ]] && rm "$DOWNLOAD_DIR/$FILENAME"
else
    echo -e "${RED}✗ Download failed${NC}"
    exit 1
fi