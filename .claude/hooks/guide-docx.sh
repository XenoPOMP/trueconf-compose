#!/bin/bash
# Rebuilds guides/MIGRATIION_GUIDE_WINDOWS.docx from the Markdown guide whenever the .md is newer.
# The .docx is a local build artifact (gitignored). Idempotent and cheap: it does nothing when the
# .docx is already up to date, so it is safe to run after every edit, shell command, or turn.
# Hook JSON on stdin is ignored.
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
SRC="$ROOT/guides/MIGRATIION_GUIDE_WINDOWS.md"
OUT="${SRC%.md}.docx"

cat >/dev/null

[[ -f "$SRC" ]] || exit 0
[[ "$SRC" -nt "$OUT" ]] || exit 0

warn() { jq -n --arg m "$1" '{systemMessage: $m}'; exit 0; }

command -v pandoc >/dev/null 2>&1 || warn "guide-docx: pandoc not found; install it (brew install pandoc) to build $(basename "$OUT")"

tmp="$(mktemp "${OUT%.docx}.tmp.XXXXXX")" || exit 0
trap 'rm -f "$tmp"' EXIT

if err="$(pandoc --from gfm --to docx --resource-path "$ROOT/guides" --output "$tmp" "$SRC" 2>&1)"; then
  chmod 644 "$tmp"
  mv -f "$tmp" "$OUT"
else
  warn "guide-docx: pandoc failed: ${err:0:300}"
fi
exit 0
