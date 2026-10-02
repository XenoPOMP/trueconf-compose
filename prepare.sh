#!/usr/bin/env bash
# Interactively pick a tag for trueconf/trueconf-server from Docker Hub.
# Prints the chosen tag to stdout; everything else goes to stderr.
set -euo pipefail

IMAGE="trueconf/trueconf-server"
API_BASE="https://hub.docker.com/v2/repositories/${IMAGE}/tags"
PAGE_SIZE=100

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: '$1' is required but not installed. Install it with: $2" >&2
    exit 1
  }
}

need curl "brew install curl"
need jq "brew install jq"
need fzf "brew install fzf"

check_internet() {
  if ! curl -fsS --max-time 5 -o /dev/null "https://hub.docker.com"; then
    echo "Error: no internet connection (could not reach hub.docker.com)" >&2
    exit 1
  fi
}

check_internet

fetch_tags() {
  local url="${API_BASE}?page_size=${PAGE_SIZE}&ordering=last_updated"
  local response
  while [[ -n "$url" && "$url" != "null" ]]; do
    response=$(curl -fsSL "$url") || {
      echo "Error: failed to reach Docker Hub API" >&2
      exit 1
    }
    jq -r '.results[].name' <<<"$response"
    url=$(jq -r '.next // empty' <<<"$response")
  done
}

echo "Fetching tags for ${IMAGE} from Docker Hub..." >&2
TAGS=()
while IFS= read -r line; do
  TAGS+=("$line")
done < <(fetch_tags)

if [[ ${#TAGS[@]} -eq 0 ]]; then
  echo "No tags found for ${IMAGE}" >&2
  exit 1
fi

TAG=$(printf '%s\n' "${TAGS[@]}" |
  fzf --prompt="${IMAGE}:> " --height=90% --border --reverse \
      --header="Select a tag (newest first) and press Enter")

if [[ -z "${TAG:-}" ]]; then
  echo "No tag selected." >&2
  exit 1
fi

PULL_IMAGE="$IMAGE:$TAG"
echo "Selected image tag: $PULL_IMAGE"

echo "Clearing images folder"
rm -f images/*.tar

echo "Pulling down image..."
docker pull $PULL_IMAGE --platform linux/amd64
docker save -o images/trueconf.tar $PULL_IMAGE
echo "Image saved to images/trueconf.tar"

echo "TC_IMAGE_TAG=$PULL_IMAGE" | tee .env
echo "Updated .env file"

echo "All tasks completed successfully."
