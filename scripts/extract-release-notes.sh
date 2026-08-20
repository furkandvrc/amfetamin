#!/usr/bin/env bash
# Extract GitHub release notes for a single tag from .github/release-notes.md
set -euo pipefail

TAG="${1:?Usage: extract-release-notes.sh <tag> [notes-file]}"
NOTES_FILE="${2:-.github/release-notes.md}"

python3 - "$TAG" "$NOTES_FILE" <<'PY'
import re
import sys
from pathlib import Path

tag = sys.argv[1].strip()
version = tag.removeprefix("v")
path = Path(sys.argv[2])
text = path.read_text(encoding="utf-8")

section_patterns = [
    rf"^## v{re.escape(version)}\s*$",
    rf"^## What's new in v{re.escape(version)}\s*$",
]

start = None
for pattern in section_patterns:
    match = re.search(pattern, text, re.MULTILINE)
    if match:
        start = match.start()
        break

if start is None:
    print(f"No release notes section found for {tag} in {path}", file=sys.stderr)
    sys.exit(1)

next_section = re.search(
    r"^## (?:v[\d.]+|What's new in v[\d.]+)\s*$",
    text[start + 3 :],
    re.MULTILINE,
)
if next_section:
    end = start + 3 + next_section.start()
else:
    requirements = re.search(r"^---\s*\n## Requirements\b", text[start:], re.MULTILINE)
    end = start + requirements.start() if requirements else len(text)

section = text[start:end].strip()

# Keep install/download instructions; omit stacked version history.
download_match = re.search(
    r"^## Download\s*$.*?(?=^---\s*$)",
    text,
    re.MULTILINE | re.DOTALL,
)
parts = []
if download_match:
    parts.append(download_match.group(0).strip())
    parts.append("---")
parts.append(section)

print("\n\n".join(parts))
PY
