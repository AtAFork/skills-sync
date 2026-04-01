#!/usr/bin/env bash
# sync-opencode-hooks.sh — Sync OpenCode hooks from ~/.agents/opencode/hooks/ to ~/.config/opencode/hooks/
# 
# This script ensures ~/.config/opencode/hooks/ contains symlinks pointing to
# ~/.agents/opencode/hooks/ (source of truth), similar to how skills are synced.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Default paths (override via environment)
SOURCE_DIR="${SOURCE_DIR:-$HOME/.agents/opencode/hooks}"
TARGET_DIR="${TARGET_DIR:-$HOME/.config/opencode/hooks}"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backups/opencode-hooks}"

# Expand paths
SOURCE_DIR="${SOURCE_DIR/#\~/$HOME}"
TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
BACKUP_DIR="${BACKUP_DIR/#\~/$HOME}"

echo "=== OpenCode Hooks Sync ==="
echo "Source: $SOURCE_DIR"
echo "Target: $TARGET_DIR"
echo ""

# Ensure source exists
if [ ! -d "$SOURCE_DIR" ]; then
  echo "ERROR: Source directory does not exist: $SOURCE_DIR"
  exit 1
fi

# Create target directory if needed
mkdir -p "$TARGET_DIR"

# Calculate relative path from target to source
relative_path() {
  python3 -c 'import os, sys; print(os.path.relpath(sys.argv[1], start=sys.argv[2]))' "$1" "$2"
}

# Sync each hook file
for source_file in "$SOURCE_DIR"/*.js; do
  [ -e "$source_file" ] || continue  # Skip if no .js files
  
  filename=$(basename "$source_file")
  target_file="$TARGET_DIR/$filename"
  
  # Calculate relative link target
  link_target=$(relative_path "$source_file" "$TARGET_DIR")
  
  # Check if already correctly symlinked
  if [ -L "$target_file" ] && [ "$(readlink "$target_file")" = "$link_target" ]; then
    echo "OK       $target_file -> $link_target"
    continue
  fi
  
  # Backup existing file if present
  if [ -e "$target_file" ] || [ -L "$target_file" ]; then
    mkdir -p "$BACKUP_DIR"
    timestamp=$(date +%Y%m%d-%H%M%S)
    backup_file="$BACKUP_DIR/${filename}.$timestamp"
    echo "BACKUP   $target_file -> $backup_file"
    mv "$target_file" "$backup_file"
  fi
  
  # Create symlink
  echo "LINK     $target_file -> $link_target"
  ln -s "$link_target" "$target_file"
done

# Remove stale symlinks (pointing to source_dir but source no longer exists)
for target_file in "$TARGET_DIR"/*.js; do
  [ -e "$target_file" ] || continue
  
  if [ -L "$target_file" ]; then
    resolved=$(readlink "$target_file" 2>/dev/null || true)
    if [[ "$resolved" == *".agents/opencode/hooks"* ]]; then
      # Check if source still exists
      source_expected="$SOURCE_DIR/$(basename "$target_file")"
      if [ ! -e "$source_expected" ]; then
        echo "REMOVE   $target_file (stale symlink)"
        rm "$target_file"
      fi
    fi
  fi
done

echo ""
echo "OpenCode hooks sync complete."
