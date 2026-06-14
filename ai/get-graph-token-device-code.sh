#!/usr/bin/env bash
set -euo pipefail

TENANT_ID=${TENANT_ID:-}
CLIENT_ID=${CLIENT_ID:-}
SCOPE=${SCOPE:-"https://graph.microsoft.com/Chat.Read https://graph.microsoft.com/User.Read offline_access openid profile"}
OUT_FILE=${OUT_FILE:-/home/ldcwem0/dotfiles/.secrets/microsoft/teams/teams-graph.token}

if [ -z "$TENANT_ID" ] || [ -z "$CLIENT_ID" ]; then
  echo "Usage: TENANT_ID=<tenant-guid> CLIENT_ID=<app-client-id> $0" >&2
  echo "Optional: SCOPE and OUT_FILE environment variables" >&2
  exit 1
fi

base="https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0"

device_json=$(curl -sS -X POST "$base/devicecode" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "client_id=$CLIENT_ID" \
  --data-urlencode "scope=$SCOPE")

device_code=$(python3 - <<'PY' "$device_json"
import json, sys
d = json.loads(sys.argv[1])
print(d.get("device_code", ""))
PY
)

interval=$(python3 - <<'PY' "$device_json"
import json, sys
d = json.loads(sys.argv[1])
print(d.get("interval", 5))
PY
)

message=$(python3 - <<'PY' "$device_json"
import json, sys
d = json.loads(sys.argv[1])
print(d.get("message", ""))
PY
)

if [ -z "$device_code" ]; then
  echo "Error: failed to start device code flow" >&2
  echo "$device_json" >&2
  exit 1
fi

echo "$message"

mkdir -p "$(dirname "$OUT_FILE")"
chmod 700 "$(dirname "$OUT_FILE")"

while true; do
  token_json=$(curl -sS -X POST "$base/token" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
    --data-urlencode "client_id=$CLIENT_ID" \
    --data-urlencode "device_code=$device_code")

  access_token=$(python3 - <<'PY' "$token_json"
import json, sys
d = json.loads(sys.argv[1])
print(d.get("access_token", ""))
PY
)

  if [ -n "$access_token" ]; then
    umask 077
    printf '%s\n' "$access_token" > "$OUT_FILE"
    chmod 600 "$OUT_FILE"

    expires_in=$(python3 - <<'PY' "$token_json"
import json, sys
d = json.loads(sys.argv[1])
print(d.get("expires_in", ""))
PY
)

    echo "Token saved to $OUT_FILE"
    echo "Expires in: ${expires_in}s"
    exit 0
  fi

  err=$(python3 - <<'PY' "$token_json"
import json, sys
d = json.loads(sys.argv[1])
print(d.get("error", ""))
PY
)

  case "$err" in
    authorization_pending)
      sleep "$interval"
      ;;
    slow_down)
      interval=$((interval + 5))
      sleep "$interval"
      ;;
    *)
      echo "Error: token request failed: $token_json" >&2
      exit 1
      ;;
  esac
done
