#!/bin/bash
set -euo pipefail

HOST="root@185.221.199.222"
LOCAL_PORT=8080
REMOTE_PORT=80

echo "Forwarding http://localhost:$LOCAL_PORT -> $HOST:$REMOTE_PORT"
ssh -L 8080:127.0.0.1:80 "$HOST"
