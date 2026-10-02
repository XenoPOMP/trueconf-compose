#!/bin/bash
# Download docker.io + docker-compose, and their full dependency closure, as
# .deb files so they can be installed on a Debian 12 server with no internet
# access. Needs `docker` and internet on the machine running this script.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEPS_DIR="$ROOT_DIR/docker-deps"
DEBIAN_IMAGE="debian:12"
PACKAGES=(docker.io docker-compose)

echo "Clearing docker-deps folder"
mkdir -p "$DEPS_DIR"
find "$DEPS_DIR" -maxdepth 1 -type f ! -name ".gitkeep" -delete

echo "Downloading ${PACKAGES[*]} (+ dependencies) for $DEBIAN_IMAGE, linux/amd64..."
docker run --rm --platform linux/amd64 \
  -v "$DEPS_DIR:/debs" \
  "$DEBIAN_IMAGE" \
  bash -c "apt-get update && apt-get install -y --download-only -o Dir::Cache::Archives=/debs ${PACKAGES[*]}"

COUNT=$(find "$DEPS_DIR" -maxdepth 1 -type f -name '*.deb' | wc -l | tr -d ' ')
echo "Saved $COUNT .deb packages to $DEPS_DIR"
