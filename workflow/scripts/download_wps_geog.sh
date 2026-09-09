#!/usr/bin/bash
set -euo pipefail

# Author: Valvanuz Fernandez

DOWNLOAD_URL="$1"
TARGET_DIR="$2"
REQUIRED_FILE="$3"
TARGET_PARENT=$(dirname "$TARGET_DIR")

mkdir -p "$TARGET_PARENT"
DOWNLOAD_TMP=$(mktemp -d "$TARGET_PARENT/.wps-geog-download.XXXXXX")
trap 'rm -rf -- "$DOWNLOAD_TMP"' EXIT

ARCHIVE="$DOWNLOAD_TMP/geog_low_res_mandatory.tar.gz"
EXTRACTED="$DOWNLOAD_TMP/extracted"
mkdir -p "$EXTRACTED"

echo "[WPS geog] Downloading $DOWNLOAD_URL"
curl --fail --location --retry 3 --retry-delay 5 \
    --output "$ARCHIVE" "$DOWNLOAD_URL"

echo "[WPS geog] Checking and extracting the archive"
tar -tzf "$ARCHIVE" >/dev/null
tar -xzf "$ARCHIVE" -C "$EXTRACTED"

EXTRACTED_REQUIRED=$(find "$EXTRACTED" -type f -path "*/$REQUIRED_FILE" -print -quit)
if [[ -z "$EXTRACTED_REQUIRED" ]]; then
    echo "ERROR: the archive does not contain $REQUIRED_FILE" >&2
    exit 1
fi

SOURCE_ROOT="${EXTRACTED_REQUIRED%/$REQUIRED_FILE}"
mkdir -p "$TARGET_DIR"
cp -a "$SOURCE_ROOT"/. "$TARGET_DIR"/

test -s "$TARGET_DIR/$REQUIRED_FILE"
echo "[WPS geog] Data installed in $TARGET_DIR"
