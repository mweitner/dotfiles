#!/usr/bin/env bash
set -euo pipefail

TOKEN_FILE=${TOKEN_FILE:-/home/ldcwem0/dotfiles/.secrets/microsoft/teams/teams-graph.token}
EXPORT_DIR=${EXPORT_DIR:-/home/ldcwem0/dotfiles/.secrets/microsoft/teams/exports}
PAGE_SIZE=${PAGE_SIZE:-50}

usage() {
  echo "Usage: $0 <teams-chat-url-or-chat-id> [output-json-file]"
  echo "Example URL: https://teams.microsoft.com/l/chat/19:meeting_xxx@thread.v2/conversations?..."
}

if [ "${1:-}" = "" ]; then
  usage
  exit 1
fi

input_value="$1"
output_file="${2:-}"

if [ ! -s "$TOKEN_FILE" ]; then
  echo "Error: token file missing or empty at $TOKEN_FILE" >&2
  exit 1
fi

if [[ "$input_value" == http* ]]; then
  chat_id_raw=$(python3 - "$input_value" <<'PY'
import sys
from urllib.parse import urlparse
url = sys.argv[1]
path = urlparse(url).path
parts = [p for p in path.split('/') if p]
chat_id = ""
if len(parts) >= 3 and parts[0] == "l" and parts[1] == "chat":
    chat_id = parts[2]
print(chat_id)
PY
)
  if [ -z "$chat_id_raw" ]; then
    echo "Error: could not extract chat id from Teams URL" >&2
    exit 1
  fi
  chat_id=$(python3 - "$chat_id_raw" <<'PY'
import sys
from urllib.parse import unquote
print(unquote(sys.argv[1]))
PY
)
else
  chat_id="$input_value"
fi

token=$(tr -d '\r\n' < "$TOKEN_FILE")

mkdir -p "$EXPORT_DIR"
chmod 700 "$EXPORT_DIR"

timestamp=$(date +%Y%m%d-%H%M%S)
safe_chat_id=$(printf '%s' "$chat_id" | tr '/:@' '___')

if [ -z "$output_file" ]; then
  output_file="$EXPORT_DIR/chat-${safe_chat_id}-${timestamp}.json"
fi

tmp_file=$(mktemp)
status_file=$(mktemp)
body_file=$(mktemp)
next_url="https://graph.microsoft.com/v1.0/chats/$chat_id/messages?\$top=$PAGE_SIZE"

printf '{\n  "chatId": "%s",\n  "exportedAt": "%s",\n  "messages": [\n' "$chat_id" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$tmp_file"

first=1
page_count=0
msg_count=0

while [ -n "$next_url" ]; do
  page_count=$((page_count + 1))

  http_status=$(curl -sS -o "$body_file" -w '%{http_code}' \
    -H "Authorization: Bearer $token" \
    -H 'Accept: application/json' \
    "$next_url")

  if [ "$http_status" != "200" ]; then
    echo "Error: Graph request failed with HTTP $http_status" >&2
    head -c 800 "$body_file" >&2 || true
    echo >&2
    if grep -q "Missing scope permissions" "$body_file"; then
      echo "Hint: this token needs delegated Graph scope Chat.Read (or Chat.ReadWrite)." >&2
      echo "Hint: Azure CLI built-in app often cannot request this scope in enterprise tenants." >&2
      echo "Hint: use your own Entra app registration + device code auth to get a compliant token." >&2
    fi
    rm -f "$tmp_file" "$status_file" "$body_file"
    exit 1
  fi

  python3 - "$body_file" "$tmp_file" "$status_file" "$first" <<'PY'
import json
import sys

body_path, out_path, status_path, first_flag = sys.argv[1:5]
first = (first_flag == "1")

with open(body_path, "r", encoding="utf-8") as f:
    data = json.load(f)

messages = data.get("value", [])
next_link = data.get("@odata.nextLink", "")

with open(out_path, "a", encoding="utf-8") as out:
    for msg in messages:
        if not first:
            out.write(",\n")
        out.write(json.dumps(msg, ensure_ascii=False))
        first = False

with open(status_path, "w", encoding="utf-8") as s:
    s.write(f"first={1 if first else 0}\n")
    s.write(f"count={len(messages)}\n")
    s.write(next_link)
PY

  first=$(grep '^first=' "$status_file" | cut -d= -f2)
  page_msg_count=$(grep '^count=' "$status_file" | cut -d= -f2)
  msg_count=$((msg_count + page_msg_count))
  next_url=$(tail -n 1 "$status_file")

  if [ "$next_url" = "" ]; then
    break
  fi
done

printf '\n  ]\n}\n' >> "$tmp_file"
mv "$tmp_file" "$output_file"
chmod 600 "$output_file"

rm -f "$status_file" "$body_file"

echo "Export completed"
echo "Chat id: $chat_id"
echo "Pages: $page_count"
echo "Messages: $msg_count"
echo "Output: $output_file"
