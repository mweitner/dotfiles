#!/usr/bin/env sh

target=/home/ldcwem0/dotfiles/.secrets/microsoft/teams/teams-graph.token

if ! command -v wl-paste >/dev/null 2>&1; then
    echo "Error: wl-paste is required but not installed." >&2
    exit 1
fi

token=$(wl-paste --no-newline | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [ -z "$token" ]; then
    echo "Error: clipboard is empty. Copy the access token first." >&2
    exit 1
fi

token_len=$(printf '%s' "$token" | wc -c | tr -d ' ')
if [ "$token_len" -lt 100 ]; then
    echo "Error: clipboard content looks too short to be an access token." >&2
    exit 1
fi

umask 077
mkdir -p "$(dirname "$target")"
printf '%s\n' "$token" > "$target"
chmod 600 "$target"

echo "Saved token to $target"
echo "Token length: $token_len"