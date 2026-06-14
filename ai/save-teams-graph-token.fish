#!/usr/bin/env fish

set target /home/ldcwem0/dotfiles/.secrets/microsoft/teams/teams-graph.token

if not type -q wl-paste
    echo "Error: wl-paste is required but not installed."
    exit 1
end

set token (wl-paste --no-newline | string trim)

if test -z "$token"
    echo "Error: clipboard is empty. Copy the access token first."
    exit 1
end

set token_len (string length -- "$token")
if test $token_len -lt 100
    echo "Error: clipboard content looks too short to be an access token."
    exit 1
end

umask 077
mkdir -p (dirname $target)
printf '%s\n' "$token" > $target
chmod 600 $target

echo "Saved token to $target"
echo "Token length: $token_len"
