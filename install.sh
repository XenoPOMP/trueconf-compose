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

DUMP_DIR="data/dump"
DUMP_FILE="$DUMP_DIR/tcs_db.dump"
APPLY_DUMP=false
mkdir -p "$DUMP_DIR"

step "Checking for dump to import"
CANDIDATES=$(find "$DUMP_DIR" -maxdepth 1 -type f ! -name ".gitkeep" 2>/dev/null)
if [[ -z "$CANDIDATES" ]]; then
  info "No dump file found in $DUMP_DIR, skipping import"
elif [[ -d data/database ]]; then
  warn "Dump file found in $DUMP_DIR, but data/database already exists — this is not a fresh install"
  warn "The dump will NOT be applied. Run .idea/sh/clear-data.sh first if you want to reinitialize from it"
elif [[ $(wc -l <<<"$CANDIDATES") -gt 1 ]]; then
  fail "Multiple files found in $DUMP_DIR. Leave only the single dump file (a pg_dumpall export) there"
  exit 1
else
  mv -f "$CANDIDATES" "$DUMP_FILE"
  APPLY_DUMP=true
  ok "Found dump to import: $(basename "$CANDIDATES")"
fi

step "Starting server"
docker-compose up -d
ok "Server is starting. Inspect with docker logs -f trueconf-server"

if [[ "$APPLY_DUMP" == true ]]; then
  step "Importing dump"
  info "Waiting for first-boot setup (dump import + schema patches) to finish..."
  WAITED=0
  until docker exec trueconf-server pgrep supervisord >/dev/null 2>&1; do
    sleep 2
    WAITED=$((WAITED + 2))
    if [[ $WAITED -ge 300 ]]; then
      fail "Timed out waiting for setup to finish. Check: docker logs trueconf-server"
      exit 1
    fi
  done
  docker exec trueconf-server sh -c 'tail -n 40 /opt/trueconf/server/var/log/database/tcs_db_dump-*.log' 2>/dev/null || \
    warn "No dump import log found — check docker logs trueconf-server"
  rm -f "$DUMP_FILE"
  ok "Dump imported and cleared from $DUMP_DIR"
fi