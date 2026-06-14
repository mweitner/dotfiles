#!/usr/bin/env python3
"""Auto-fix common markdown issues:
- Add 'text' to unlabeled fenced code blocks (``` -> ```text)
- Convert emphasized headings (*Heading* or **Heading**) into '## Heading'
- Convert closed-atx headings (### Title ###) to '### Title'
- Add alt text 'screenshot' for images missing alt text: ![](path) -> ![screenshot](path)

Run from repo root: python3 scripts/fix_markdown.py
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

md_paths = list(ROOT.glob("**/*.md"))
# exclude .git and doc build dirs
md_paths = [p for p in md_paths if ".git" not in p.parts and "build" not in p.parts]

changed = []
for p in md_paths:
    try:
        s = p.read_text(encoding="utf-8")
    except Exception:
        continue
    orig = s
    # Add language to unlabeled fences: ^```\s*$ -> ```text
    s = re.sub(r"^```\s*$", "```text", s, flags=re.MULTILINE)
    # Emphasis-as-heading: lines that are exactly *text* or **text**
    s = re.sub(r"^[ \t]*\*\*(.+?)\*\*[ \t]*$", "## \1", s, flags=re.MULTILINE)
    s = re.sub(r"^[ \t]*\*(.+?)\*[ \t]*$", "## \1", s, flags=re.MULTILINE)
    # Closed ATX headings: # heading # -> # heading
    s = re.sub(r"^(#{1,6})\s*(.*?)\s*#{1,6}\s*$", r"\1 \2", s, flags=re.MULTILINE)
    # Missing alt text: ![](path) -> ![screenshot](path)
    s = re.sub(r"!\[\s*\]\(([^)]+)\)", r"![screenshot](\1)", s)
    # also handle images with empty quotes: ![](/path "title")
    s = re.sub(r"!\[\s*\]\(([^)]+)\"", r'![screenshot](\1"', s)

    if s != orig:
        p.write_text(s, encoding="utf-8")
        changed.append(str(p))

print(f"Processed {len(md_paths)} markdown files, changed {len(changed)} files")
for c in changed[:200]:
    print(c)
