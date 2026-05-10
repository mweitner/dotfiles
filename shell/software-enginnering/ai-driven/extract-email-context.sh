import email
from email import policy
from pathlib import Path

EML_PATH = "input/email.eml"
OUT_MD = "output/context.md"

def extract_email_context(eml_path):
    with open(eml_path, "rb") as f:
        msg = email.message_from_binary_file(f, policy=policy.default)

    subject = msg["subject"]
    sender = msg["from"]
    to = msg["to"]
    date = msg["date"]

    # extract body
    if msg.is_multipart():
        parts = [p.get_content() for p in msg.walk() if p.get_content_type() == "text/plain"]
        body = "\n".join(parts)
    else:
        body = msg.get_content()

    return {
        "subject": subject,
        "from": sender,
        "to": to,
        "date": date,
        "body": body
    }

def generate_markdown(ctx):
    return f"""# Email Context

## Metadata
- Subject: {ctx['subject']}
- From: {ctx['from']}
- To: {ctx['to']}
- Date: {ctx['date']}

## Raw Content
ctx['body']}
"""

ctx = extract_email_context(EML_PATH)

Path(OUT_MD).write_text(generate_markdown(ctx))
