#!/bin/bash

# Usage: ./prefetch_crates.sh /path/to/Cargo.lock [DOWNLOAD_DIR]
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/Cargo.lock [DOWNLOAD_DIR]"
    exit 1
fi

CARGO_LOCK="$1"
DOWNLOAD_DIR="${2:-/opt/yocto/shared-scarthgap/downloads}"

mkdir -p "$DOWNLOAD_DIR"

echo "Extracting crates from $CARGO_LOCK..."

urls=$(awk '
  $1 == "name" { name = $3; gsub(/\"/, "", name) }
  $1 == "version" { ver = $3; gsub(/\"/, "", ver) }
  $1 == "source" && $3 ~ /crates\.io/ {
    url = "https://static.crates.io/crates/" name "/" name "-" ver ".crate"
    print url
  }
' "$CARGO_LOCK" | sort -u)

downloaded=()
for url in $urls; do
    filename=$(basename "$url")
    if [ ! -f "$DOWNLOAD_DIR/$filename" ]; then
        echo "Downloading $filename..."
        wget -q --show-progress -P "$DOWNLOAD_DIR" "$url"
        downloaded+=("$filename")
    else
        echo "Skipping $filename (already exists)"
    fi
done

echo
if [ ${#downloaded[@]} -eq 0 ]; then
    echo "No new crates were downloaded."
else
    echo "Summary of downloaded crates:"
    for f in "${downloaded[@]}"; do
        echo "  $f"
    done
fi

echo "Done! All crates downloaded to $DOWNLOAD_DIR."
