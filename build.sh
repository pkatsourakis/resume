#!/usr/bin/env bash
# build.sh: regenerate the resume + cover-letter PDFs/docx from their markdown sources.
#
# Two modes:
#   ./build.sh              Build the canonical base from this repo (README.md, cover-letter.md)
#                           into the repo root, exactly as before.
#   ./build.sh --app <slug> Build a tailored application living in the private vault
#                           (created by ./apply.sh) into that folder's own out/.
#
# Add --combined to also emit one stitched document (cover letter, page break, resume)
# for portals that only allow a single upload. Works with or without --app.
#
# Sources of truth are the markdown files; everything else is generated.
set -euo pipefail

# Work from the script's own directory so relative paths (resume.css) resolve.
cd "$(dirname "$0")"
ROOT="$PWD"

# Where ./apply.sh stashes tailored applications. Override with RESUME_APPLICATIONS_DIR.
APPLICATIONS_DIR="${RESUME_APPLICATIONS_DIR:-/c/Users/pano/OneDrive/Documents/Vault/Job Hunting/Applications}"

# Parse args.
app=""
combined=""
while [ $# -gt 0 ]; do
  case "$1" in
    --app|-a) app="${2:-}"; shift 2 || true ;;
    --combined|-c) combined="1"; shift ;;
    -h|--help)
      echo "Usage: ./build.sh [--app <slug>] [--combined]" >&2
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

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

# Resolve where the source markdown lives (srcdir) and where artifacts go (workdir).
# The browser loads the generated HTML and pulls in resume.css relative to it, so the
# stylesheet must sit next to the HTML in workdir.
if [ -z "$app" ]; then
  srcdir="$ROOT"
  workdir="$ROOT"   # resume.css already lives here
else
  # Resolve the slug to a single application folder (exact name or "<date>-<slug>").
  if [ -d "$APPLICATIONS_DIR/$app" ]; then
    appdir="$APPLICATIONS_DIR/$app"
  else
    shopt -s nullglob
    cands=( "$APPLICATIONS_DIR"/*-"$app" )
    shopt -u nullglob
    if [ "${#cands[@]}" -eq 1 ]; then
      appdir="${cands[0]}"
    elif [ "${#cands[@]}" -eq 0 ]; then
      echo "No application matching '$app' in $APPLICATIONS_DIR (run ./apply.sh first)." >&2
      exit 1
    else
      echo "Ambiguous slug '$app'; matches:" >&2
      printf '  %s\n' "${cands[@]}" >&2
      exit 1
    fi
  fi
  srcdir="$appdir"
  workdir="$appdir/out"
  mkdir -p "$workdir"
  cp "$ROOT/resume.css" "$workdir/resume.css"
fi

# render: one markdown source -> styled HTML -> PDF, plus a DOCX, all into workdir.
#   render <src-md-path> <html> <pdf> <docx> <title>
render() {
  local md="$1" html="$2" pdf="$3" docx="$4" title="$5"

  # 1. Markdown -> standalone styled HTML (href to resume.css, which we keep beside it).
  pandoc "$md" -o "$workdir/$html" --standalone --css=resume.css --metadata pagetitle="$title"

  # 2. HTML -> PDF via headless browser. Use a throwaway --user-data-dir so we get a
  #    fresh isolated instance even if the browser is already running (otherwise the
  #    headless call is silently ignored).
  "$browser" \
    --headless=new --disable-gpu --no-pdf-header-footer \
    --user-data-dir="$(to_path "$(mktemp -d)")" \
    --print-to-pdf="$(to_path "$workdir/$pdf")" \
    "$(to_url "$workdir/$html")"
  if [ ! -f "$workdir/$pdf" ]; then
    echo "PDF was not produced for $title." >&2
    exit 1
  fi

  # 3. Markdown -> docx (same source, for applications that want Word)
  pandoc "$md" -o "$workdir/$docx"

  echo "Built $pdf and $docx -> $workdir"
}

# Each row: markdown source | html | pdf | docx | title
docs=(
  "README.md|resume.html|PanoKatsourakis_EngineerResume.pdf|PanoKatsourakis_EngineerResume.docx|Pano Katsourakis Resume"
  "cover-letter.md|cover-letter.html|PanoKatsourakis_CoverLetter.pdf|PanoKatsourakis_CoverLetter.docx|Pano Katsourakis Cover Letter"
)

for doc in "${docs[@]}"; do
  IFS='|' read -r md html pdf docx title <<< "$doc"
  if [ ! -f "$srcdir/$md" ]; then
    echo "Skipping $md (not present in $srcdir)." >&2
    continue
  fi
  render "$srcdir/$md" "$html" "$pdf" "$docx" "$title"
done

# Optional: one stitched document (cover letter, hard page break, resume) for portals
# that only take a single upload.
if [ -n "$combined" ]; then
  if [ ! -f "$srcdir/cover-letter.md" ] || [ ! -f "$srcdir/README.md" ]; then
    echo "--combined needs both cover-letter.md and README.md in $srcdir." >&2
    exit 1
  fi

  # Build the merged source in a temp .md. The page break is emitted as two raw blocks,
  # one per target writer; pandoc passes through only the block matching the format it's
  # currently producing (html for the PDF path, openxml for the DOCX), so each output
  # gets a real page break and the other block is dropped.
  tmpdir="$(mktemp -d)"
  merged="$tmpdir/combined.md"
  {
    # Cover letter unchanged: it keeps its normal letterhead on page 1.
    cat "$srcdir/cover-letter.md"
    printf '\n\n```{=html}\n<div style="page-break-after: always;"></div>\n```\n\n'
    printf '```{=openxml}\n<w:p><w:r><w:br w:type="page"/></w:r></w:p>\n```\n\n'
    # Resume: relabel the H1 to "... - Resume" and drop the contact + links lines, which
    # already appear in the letterhead one page up. Filter only the header region (before
    # the first --- rule) so any links or "@" in the body are left untouched.
    awk '
      NR==1                  { print $0 " - Resume"; next }
      !hr && /^---/          { hr=1 }
      !hr && /@/             { next }            # contact line (carries the email)
      !hr && /^\[.*\]\(http/ { next }            # links line
      { print }
    ' "$srcdir/README.md"
  } > "$merged"

  render "$merged" "combined.html" \
    "PanoKatsourakis_CoverLetterAndResume.pdf" \
    "PanoKatsourakis_CoverLetterAndResume.docx" \
    "Pano Katsourakis Cover Letter and Resume"

  rm -rf "$tmpdir"
fi
