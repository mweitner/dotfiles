#!/usr/bin/env python3
"""Fetch Microsoft Teams chat/channel messages from a Teams URL via Graph API.

Usage:
  fetch-teams-json.py --url <teams-link> --output <raw.json> [--token <bearer>] [--include-replies]
"""

import argparse
import json
import os
import sys
from dataclasses import dataclass
from typing import Dict, List, Optional
from urllib.parse import parse_qs, quote, unquote, urlparse
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

GRAPH_BASE = "https://graph.microsoft.com/v1.0"


@dataclass
class LinkInfo:
    kind: str
    chat_id: Optional[str] = None
    team_id: Optional[str] = None
    channel_id: Optional[str] = None


def parse_teams_link(teams_url: str) -> LinkInfo:
    parsed = urlparse(teams_url)
    host = (parsed.netloc or "").lower()
    path_parts = [p for p in parsed.path.split("/") if p]
    query = parse_qs(parsed.query)

    if "teams.microsoft.com" not in host:
        raise ValueError("URL must be a teams.microsoft.com link")

    if len(path_parts) >= 3 and path_parts[0] == "l" and path_parts[1] == "chat":
        return LinkInfo(kind="chat", chat_id=unquote(path_parts[2]))

    if len(path_parts) >= 3 and path_parts[0] == "l" and path_parts[1] in ("channel", "message"):
        team_id = query.get("groupId", [None])[0]
        if not team_id:
            raise ValueError("Channel/message link is missing groupId query parameter")
        return LinkInfo(kind="channel", team_id=team_id, channel_id=unquote(path_parts[2]))

    raise ValueError("Unsupported Teams URL format")


def graph_get(url: str, token: str) -> Dict:
    req = Request(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
        },
        method="GET",
    )
    try:
        with urlopen(req) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Graph API HTTP {exc.code}: {body}") from exc
    except URLError as exc:
        raise RuntimeError(f"Network error while calling Graph API: {exc}") from exc


def graph_get_all(first_url: str, token: str) -> List[Dict]:
    out: List[Dict] = []
    next_url = first_url
    while next_url:
        payload = graph_get(next_url, token)
        batch = payload.get("value", [])
        if isinstance(batch, list):
            out.extend(batch)
        next_url = payload.get("@odata.nextLink")
    return out


def build_messages_url(info: LinkInfo, top: int) -> str:
    if info.kind == "chat":
        return f"{GRAPH_BASE}/chats/{quote(info.chat_id or '', safe='')}/messages?$top={top}"
    return (
        f"{GRAPH_BASE}/teams/{quote(info.team_id or '', safe='')}/channels/"
        f"{quote(info.channel_id or '', safe='')}/messages?$top={top}"
    )


def build_replies_url(info: LinkInfo, message_id: str, top: int) -> str:
    msg = quote(message_id, safe="")
    if info.kind == "chat":
        return f"{GRAPH_BASE}/chats/{quote(info.chat_id or '', safe='')}/messages/{msg}/replies?$top={top}"
    return (
        f"{GRAPH_BASE}/teams/{quote(info.team_id or '', safe='')}/channels/"
        f"{quote(info.channel_id or '', safe='')}/messages/{msg}/replies?$top={top}"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fetch Teams messages from URL")
    parser.add_argument("--url", required=True, help="Teams URL")
    parser.add_argument("--output", required=True, help="Output JSON file")
    parser.add_argument("--token", default="", help="Graph bearer token")
    parser.add_argument("--top", type=int, default=50, help="Page size")
    parser.add_argument("--include-replies", action="store_true", help="Include replies")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    token = (args.token or os.getenv("MS_GRAPH_TOKEN", "")).strip()
    if not token:
        print("Error: Missing Graph token (--token or MS_GRAPH_TOKEN)", file=sys.stderr)
        return 1

    try:
        info = parse_teams_link(args.url)
        messages = graph_get_all(build_messages_url(info, args.top), token)

        if args.include_replies:
            with_replies = list(messages)
            for msg in messages:
                msg_id = msg.get("id")
                if not msg_id:
                    continue
                replies = graph_get_all(build_replies_url(info, str(msg_id), args.top), token)
                for reply in replies:
                    reply["_parentMessageId"] = msg_id
                with_replies.extend(replies)
            messages = with_replies

        messages = sorted(messages, key=lambda m: m.get("createdDateTime", ""))
        payload = {
            "source": {
                "url": args.url,
                "kind": info.kind,
                "chatId": info.chat_id,
                "teamId": info.team_id,
                "channelId": info.channel_id,
            },
            "messages": messages,
        }

        with open(args.output, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, indent=2, ensure_ascii=False)

        print(f"Fetched {len(messages)} messages -> {args.output}")
        return 0
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
