#!/bin/bash
set -euo pipefail

HOST="$1"
LOCAL_PORT=8080
REMOTE_PORT=80

if [[ "$HOST" == "" ]]; then
  echo "Host connection string not provided."
  exit 1
fi

echo "Forwarding http://localhost:$LOCAL_PORT -> $HOST:$REMOTE_PORT"
ssh -L 8080:127.0.0.1:80 "$HOST"
