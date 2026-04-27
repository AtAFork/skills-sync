#!/usr/bin/env bash
# sync-claude-hooks.sh — Sync Claude hooks from ~/.agents/claude/hooks/ to ~/.claude/hooks/
#
# This script ensures ~/.claude/hooks points at ~/.agents/claude/hooks/ so the
# shared agents directory is the single source of truth for Claude hooks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

SOURCE_DIR="${SOURCE_DIR:-$HOME/.agents/claude/hooks}"
TARGET_DIR="${TARGET_DIR:-$HOME/.claude/hooks}"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backups/claude-hooks}"

SOURCE_DIR="${SOURCE_DIR/#\~/$HOME}"
TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
BACKUP_DIR="${BACKUP_DIR/#\~/$HOME}"

echo "=== Claude Hooks Sync ==="
echo "Source: $SOURCE_DIR"
echo "Target: $TARGET_DIR"
echo ""

if [ ! -d "$SOURCE_DIR" ]; then
  echo "ERROR: Source directory does not exist: $SOURCE_DIR"
  exit 1
fi

mkdir -p "$(dirname "$TARGET_DIR")"

relative_path() {
  python3 -c 'import os, sys; print(os.path.relpath(sys.argv[1], start=sys.argv[2]))' "$1" "$2"
}

link_target="$(relative_path "$SOURCE_DIR" "$(dirname "$TARGET_DIR")")"

if [ -L "$TARGET_DIR" ] && [ "$(readlink "$TARGET_DIR")" = "$link_target" ]; then
  echo "OK       $TARGET_DIR -> $link_target"
  exit 0
fi

if [ -e "$TARGET_DIR" ] || [ -L "$TARGET_DIR" ]; then
  mkdir -p "$BACKUP_DIR"
  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup_target="$BACKUP_DIR/$(basename "$TARGET_DIR").$timestamp"
  echo "BACKUP   $TARGET_DIR -> $backup_target"
  mv "$TARGET_DIR" "$backup_target"
fi

echo "LINK     $TARGET_DIR -> $link_target"
ln -s "$link_target" "$TARGET_DIR"

echo ""
echo "Claude hooks sync complete."
