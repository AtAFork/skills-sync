#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

# Load config
if [ -f "$DIR/.env" ]; then
  # shellcheck source=/dev/null
  source "$DIR/.env"
fi

CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-~/.claude/skills}"
AGENTS_SKILLS_DIR="${AGENTS_SKILLS_DIR:-~/.agents/skills}"

# Expand ~ to absolute path
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR/#\~/$HOME}"
AGENTS_SKILLS_DIR="${AGENTS_SKILLS_DIR/#\~/$HOME}"

# Step 1: Move any hardcoded skills from Claude into the shared agents dir
python3 "$DIR/reconcile_agents_from_claude.py" \
  --source "$CLAUDE_SKILLS_DIR" \
  --target "$AGENTS_SKILLS_DIR" \
  --apply

# Step 2: Ensure Claude skills dir has symlinks pointing to agents dir
python3 "$DIR/sync_claude_skills.py" \
  --source "$AGENTS_SKILLS_DIR" \
  --target "$CLAUDE_SKILLS_DIR" \
  --apply --adopt-identical
