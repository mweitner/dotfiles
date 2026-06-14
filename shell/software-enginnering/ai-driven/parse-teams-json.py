#!/usr/bin/env python3
"""Parse Teams JSON export to markdown."""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List

try:
    from bs4 import BeautifulSoup
except ImportError:
    print(
        "Error: BeautifulSoup4 not found. Install with: pip install beautifulsoup4",
        file=sys.stderr,
    )
    raise SystemExit(1)


def clean_html_body(html_content: str) -> str:
    if not html_content:
        return ""

    soup = BeautifulSoup(html_content, "html.parser")

    for div in soup.find_all("div"):
        div.insert(0, "\n")
        div.append("\n")

    for pre in soup.find_all("pre"):
        code_block = pre.get_text()
        pre.replace_with(f"\n```\n{code_block}\n```\n")

    for b in soup.find_all("b"):
        b.replace_with(f"**{b.get_text()}**")
    for strong in soup.find_all("strong"):
        strong.replace_with(f"**{strong.get_text()}**")
    for i in soup.find_all("i"):
        i.replace_with(f"*{i.get_text()}*")
    for em in soup.find_all("em"):
        em.replace_with(f"*{em.get_text()}*")

    for link in soup.find_all("a"):
        href = link.get("href", "#")
        text = link.get_text() or href
        link.replace_with(f"[{text}]({href})")

    text = soup.get_text()
    lines = text.split("\n")
    cleaned_lines = []
    prev_blank = False
    for line in lines:
        is_blank = not line.strip()
        if is_blank and prev_blank:
            continue
        cleaned_lines.append(line)
        prev_blank = is_blank

    return "\n".join(cleaned_lines).strip()


def format_timestamp(iso_timestamp: str) -> str:
    try:
        dt = datetime.fromisoformat(iso_timestamp.replace("Z", "+00:00"))
        return dt.strftime("%Y-%m-%d %H:%M %p")
    except Exception:
        return "Unknown Time"


def parse_teams_export(input_path: str) -> List[Dict[str, Any]]:
    with open(input_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    if isinstance(data, dict):
        if "messages" in data and isinstance(data["messages"], list):
            return data["messages"]
        return [data]
    if isinstance(data, list):
        return data
    return []


def generate_markdown(messages: List[Dict[str, Any]]) -> str:
    lines: List[str] = []
    for msg in messages:
        sender_obj = msg.get("from", {})
        if isinstance(sender_obj, dict):
            author = sender_obj.get("user", {}).get("displayName", "Unknown User")
        else:
            author = str(sender_obj)

        formatted_time = format_timestamp(msg.get("createdDateTime", ""))

        body_obj = msg.get("body", {})
        body_raw = (
            body_obj.get("content", "") if isinstance(body_obj, dict) else str(body_obj)
        )
        clean_text = clean_html_body(body_raw)

        if clean_text.strip():
            lines.append(f"### **{author}** *({formatted_time})*\n")
            lines.append(f"{clean_text}\n")
            lines.append("---\n")

    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Transform Teams JSON to markdown")
    parser.add_argument("--input", required=True, help="Input Teams JSON")
    parser.add_argument("--output", required=True, help="Output markdown file")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    messages = parse_teams_export(args.input)
    markdown_content = generate_markdown(messages)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(markdown_content, encoding="utf-8")

    print(f"Generated: {output_path} ({len(messages)} messages)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
