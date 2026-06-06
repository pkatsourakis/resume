#!/usr/bin/env bash
# build.sh: regenerate the resume + cover-letter PDFs/docx from their markdown sources.
# Sources of truth are README.md and cover-letter.md; everything else is generated. Run after edits, then commit.
set -euo pipefail

# Work from the script's own directory so relative paths (resume.css, README.md) resolve.
cd "$(dirname "$0")"

# Locate pandoc.
if ! command -v pandoc >/dev/null 2>&1; then
  echo "pandoc not found. Install it (Windows: 'winget install --id JohnMacFarlane.Pandoc -e'; Linux: 'sudo apt-get install -y pandoc'; macOS: 'brew install pandoc')." >&2
  exit 1
fi

# Locate a Chromium browser for PDF printing (Chrome preferred, Edge/Chromium fallback).
# Covers Linux package names, macOS app bundles, and Git Bash on Windows.
browser=""
for candidate in \
  google-chrome google-chrome-stable chromium chromium-browser microsoft-edge microsoft-edge-stable \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
  "/Applications/Chromium.app/Contents/MacOS/Chromium" \
  "/c/Program Files/Google/Chrome/Application/chrome.exe" \
  "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
  "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" \
  "/c/Program Files/Microsoft/Edge/Application/msedge.exe"
do
  if command -v "$candidate" >/dev/null 2>&1; then browser="$candidate"; break; fi
  if [ -x "$candidate" ]; then browser="$candidate"; break; fi
done
if [ -z "$browser" ]; then
  echo "No Chrome/Edge/Chromium found for PDF printing." >&2
  exit 1
fi

# Chrome on Windows needs native paths/URLs, not MSYS ones (e.g. file:///c/dev/...
# resolves to C:\c\dev and silently prints an error page). cygpath does the
# conversion under Git Bash; on Linux/macOS the path passes through unchanged.
to_url() {   # filesystem path -> file:// URL the browser accepts
  if command -v cygpath >/dev/null 2>&1; then echo "file:///$(cygpath -m "$1")"; else echo "file://$1"; fi
}
to_path() {  # filesystem path -> native path for browser arguments
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else echo "$1"; fi
}

# Each row: markdown source | html | pdf | docx | title
docs=(
  "README.md|resume.html|PanoKatsourakis_EngineerResume.pdf|PanoKatsourakis_EngineerResume.docx|Pano Katsourakis Resume"
  "cover-letter.md|cover-letter.html|PanoKatsourakis_CoverLetter.pdf|PanoKatsourakis_CoverLetter.docx|Pano Katsourakis Cover Letter"
)

for doc in "${docs[@]}"; do
  IFS='|' read -r md html pdf docx title <<< "$doc"

  # 1. Markdown -> standalone styled HTML
  pandoc "$md" -o "$html" --standalone --css=resume.css --metadata pagetitle="$title"

  # 2. HTML -> PDF via headless browser. Use a throwaway --user-data-dir so we get a
  #    fresh isolated instance even if the browser is already running (otherwise the
  #    headless call is silently ignored).
  "$browser" \
    --headless=new --disable-gpu --no-pdf-header-footer \
    --user-data-dir="$(to_path "$(mktemp -d)")" \
    --print-to-pdf="$(to_path "$PWD/$pdf")" \
    "$(to_url "$PWD/$html")"
  if [ ! -f "$pdf" ]; then
    echo "PDF was not produced for $md." >&2
    exit 1
  fi

  # 3. Markdown -> docx (same source, for applications that want Word)
  pandoc "$md" -o "$docx"

  echo "Built $pdf and $docx from $md"
done
