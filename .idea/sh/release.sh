#!/bin/bash
set -euo pipefail

RED=$'\033[31m'; GREEN=$'\033[32m'; BOLD=$'\033[1m'; OFF=$'\033[0m'

step() { printf '\n%s==>%s %s\n' "$BOLD" "$OFF" "$1"; }
ok()   { printf '    %s✓%s %s\n' "$GREEN" "$OFF" "$1"; }
fail() { printf '\n%sОшибка:%s %s\n\n' "$RED" "$OFF" "$1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RELEASE_DIR="$ROOT_DIR/.idea/release"

cd "$ROOT_DIR"

step "Preparing image and .env"
"$SCRIPT_DIR/prepare.sh"
ok "Prepare step finished"

step "Preparing Docker .deb packages"
"$SCRIPT_DIR/prepare-docker-deps.sh"
ok "Docker .deb packages ready"

ITEMS=(images docker-deps .env docker-compose.yml install.sh)
for item in "${ITEMS[@]}"; do
  if [[ ! -e "$item" ]]; then
    fail "Missing '$item', cannot build release archive"
    exit 1
  fi
done

mkdir -p "$RELEASE_DIR"
ARCHIVE_NAME="trueconf-release-$(date +%Y%m%d-%H%M%S).tar.gz"
ARCHIVE_PATH="$RELEASE_DIR/$ARCHIVE_NAME"

step "Building release archive"
tar -czf "$ARCHIVE_PATH" "${ITEMS[@]}"
ok "Archive created at $ARCHIVE_PATH"
