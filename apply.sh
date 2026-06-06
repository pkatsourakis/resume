#!/usr/bin/env bash
# apply.sh: start a tailored job application in the private Obsidian vault.
#
# Copies the canonical resume + cover letter out of this (public) repo into a dated
# folder in the vault, auto-fills the placeholders we can fill safely, and drops a
# notes.md. Nothing application-specific ever lands in the repo.
#
#   ./apply.sh <slug> ["Company Name"] ["Role Title"]
#   ./apply.sh acme-backend "Acme Corp" "Senior Backend Engineer"
#
# Then tailor the copies in Obsidian and run:  ./build.sh --app <slug>
set -euo pipefail
cd "$(dirname "$0")"

# Where applications are stored. Override with RESUME_APPLICATIONS_DIR.
APPLICATIONS_DIR="${RESUME_APPLICATIONS_DIR:-/c/Users/pano/OneDrive/Documents/Vault/Job Hunting/Applications}"

slug="${1:-}"
company="${2:-}"
role="${3:-}"
if [ -z "$slug" ]; then
  echo "Usage: ./apply.sh <slug> [\"Company Name\"] [\"Role Title\"]" >&2
  echo "Example: ./apply.sh acme-backend \"Acme Corp\" \"Senior Backend Engineer\"" >&2
  exit 1
fi

date_slug="$(date +%F)"            # e.g. 2026-06-06, for sortable folder names
date_long="$(date '+%B %-d, %Y')"  # e.g. June 6, 2026, for the letter dateline
dir="$APPLICATIONS_DIR/$date_slug-$slug"

if [ -e "$dir" ]; then
  echo "Already exists: $dir" >&2
  exit 1
fi
mkdir -p "$dir"

cp README.md "$dir/README.md"
cp cover-letter.md "$dir/cover-letter.md"

# Escape a string for safe use as a sed replacement (handles \ & and the # delimiter).
esc() { printf '%s' "$1" | sed -e 's/[\\#&]/\\&/g'; }

cl="$dir/cover-letter.md"
# Always fill the dateline. Fill Company/Role only when supplied; otherwise leave the
# [placeholder] so it's obvious what still needs a human. The judgement-call placeholders
# ([Hiring Manager Name], [City, State], the "specific reason" and the skills clause) are
# intentionally left for you to write.
sed -i "s#\[Month Day, Year\]#$(esc "$date_long")#g" "$cl"
[ -n "$company" ] && sed -i "s#\[Company\]#$(esc "$company")#g" "$cl"
[ -n "$role" ]    && sed -i "s#\[Role\]#$(esc "$role")#g" "$cl"

# notes.md: the lightweight CRM row for this application.
heading="${company:-$slug}${role:+ - $role}"
cat > "$dir/notes.md" <<EOF
# $heading

- **Status:** drafting
- **Date opened:** $date_long
- **Date applied:**
- **Job posting:**
- **Contact / referral:**
- **Salary range:**
- **Location / remote:**

## Why this role / company

## Tailoring checklist
- [ ] Cover letter: [Hiring Manager Name]
- [ ] Cover letter: [City, State]
- [ ] Cover letter: the "specific reason: product, mission, or technical challenge"
- [ ] Cover letter: pick the "building scalable platforms / ... " clause
- [ ] Resume: light keyword tweaks for this JD (don't over-rewrite)
- [ ] Proofread the diff vs the base before sending

## Follow-ups
EOF

echo "Created $dir"
echo
echo "Next:"
echo "  1. Tailor $dir/README.md and $dir/cover-letter.md in Obsidian"
echo "  2. ./build.sh --app $slug      # builds PDFs + DOCX into $dir/out/"
