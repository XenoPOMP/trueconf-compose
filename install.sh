#!/bin/bash

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; OFF=$'\033[0m'

step()  { printf '\n%s==>%s %s\n' "$BOLD" "$OFF" "$1"; }
ok()    { printf '    %s✓%s %s\n' "$GREEN" "$OFF" "$1"; }
warn()  { printf '    %s!%s %s\n' "$YELLOW" "$OFF" "$1"; }
info()  { printf '    %s>%s %s\n' "$YELLOW" "$OFF" "$1"; }
fail()  { printf '\n%sОшибка:%s %s\n\n' "$RED" "$OFF" "$1"; }

color() {
  echo "$1$2$OFF"
}

compose() {
  docker-compose $@
}

step "Checking for image existence"
if [[ ! -f images/trueconf.tar || "$(cat .env | grep TC_IMAGE_TAG)" == "" ]]; then
  fail "Missing image metadata (trueconf.tar or .env TC_IMAGE_TAG field). Aborting installation"
  exit 1
fi

TAG=$(cat .env | grep TC_IMAGE_TAG | sed "s/TC_IMAGE_TAG=//g")

ok "Image metadata provided"
info "Using tag $(color "$GREEN$BOLD" "$TAG")"

step "Stopping previous ran containers"
compose down > /dev/null 2>&1
ok "All containers have been stopped"

step "Clearing old image data"
for image in $(docker images --format '{{.Repository}}:{{.Tag}}' | grep trueconf); do
  docker rmi "$image" || true
done
docker image prune -f
ok "Images have been cleared"

step "Finding and loading prepared images"
for image in $(find $(pwd)/images -maxdepth 1 -type f -name "*.tar"); do
  printf '    loading %s … ' "$(basename "$image")"
  docker load -i "$image" >/dev/null
  printf '%sdone%s\n' "$GREEN" "$OFF"
done

step "Starting server"
docker-compose up -d
ok "Server is starting. Inspect with docker logs -f trueconf-server"