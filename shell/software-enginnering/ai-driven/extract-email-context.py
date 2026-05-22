#!/usr/bin/env python3
"""Extract email metadata and body from .eml to markdown.

Usage:
  extract-email-context.py --input input/email.eml --output output/context.md
"""

import argparse
import email
from email import policy
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract email context from .eml and render markdown"
    )
    parser.add_argument("--input", required=True, help="Path to input .eml file")
    parser.add_argument("--output", required=True, help="Path to output .md file")
    return parser.parse_args()


def get_text_content(msg: email.message.EmailMessage) -> str:
    if msg.is_multipart():
        text_parts = []
        for part in msg.walk():
            if part.get_content_type() == "text/plain":
                text_parts.append(part.get_content())
        if text_parts:
            return "\n".join(text_parts).strip()

        html_parts = []
        for part in msg.walk():
            if part.get_content_type() == "text/html":
                html_parts.append(part.get_content())
        if html_parts:
            # Keep it simple: preserve HTML as-is when plain text is unavailable.
            return "\n".join(html_parts).strip()

        return ""

    return (msg.get_content() or "").strip()


def extract_email_context(eml_path: Path) -> dict:
    with eml_path.open("rb") as fh:
        msg = email.message_from_binary_file(fh, policy=policy.default)

    return {
        "subject": str(msg.get("subject", "")),
        "from": str(msg.get("from", "")),
        "to": str(msg.get("to", "")),
        "date": str(msg.get("date", "")),
        "body": get_text_content(msg),
    }


def generate_markdown(ctx: dict) -> str:
    return (
        "# Email Context\n\n"
        "## Metadata\n"
        f"- Subject: {ctx['subject']}\n"
        f"- From: {ctx['from']}\n"
        f"- To: {ctx['to']}\n"
        f"- Date: {ctx['date']}\n\n"
        "## Raw Content\n\n"
        f"{ctx['body']}\n"
    )


def main() -> int:
    args = parse_args()
    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.is_file():
        raise FileNotFoundError(f"Input .eml file not found: {input_path}")

    context = extract_email_context(input_path)
    markdown = generate_markdown(context)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(markdown, encoding="utf-8")

    print(f"Email context extracted: {input_path} -> {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
