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
AGENTS_ROOT_DIR="${AGENTS_ROOT_DIR:-~/.agents}"
AGENTS_CLAUDE_DIR="${AGENTS_CLAUDE_DIR:-~/.agents/claude}"
AGENTS_CODEX_DIR="${AGENTS_CODEX_DIR:-~/.agents/codex}"
AGENTS_OPENCODE_DIR="${AGENTS_OPENCODE_DIR:-~/.agents/opencode}"
AGENTS_CURSOR_DIR="${AGENTS_CURSOR_DIR:-~/.agents/cursor}"
CLAUDE_HOME_DIR="${CLAUDE_HOME_DIR:-~/.claude}"
CODEX_HOME_DIR="${CODEX_HOME_DIR:-~/.codex}"
CURSOR_HOME_DIR="${CURSOR_HOME_DIR:-~/.cursor}"
OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-~/.config/opencode}"
SYNC_OPTIONAL_HOOKS="${SYNC_OPTIONAL_HOOKS:-1}"

# Expand ~ to absolute path
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR/#\~/$HOME}"
AGENTS_SKILLS_DIR="${AGENTS_SKILLS_DIR/#\~/$HOME}"
AGENTS_ROOT_DIR="${AGENTS_ROOT_DIR/#\~/$HOME}"
AGENTS_CLAUDE_DIR="${AGENTS_CLAUDE_DIR/#\~/$HOME}"
AGENTS_CODEX_DIR="${AGENTS_CODEX_DIR/#\~/$HOME}"
AGENTS_OPENCODE_DIR="${AGENTS_OPENCODE_DIR/#\~/$HOME}"
AGENTS_CURSOR_DIR="${AGENTS_CURSOR_DIR/#\~/$HOME}"
CLAUDE_HOME_DIR="${CLAUDE_HOME_DIR/#\~/$HOME}"
CODEX_HOME_DIR="${CODEX_HOME_DIR/#\~/$HOME}"
CURSOR_HOME_DIR="${CURSOR_HOME_DIR/#\~/$HOME}"
OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR/#\~/$HOME}"
CLAUDE_HOOKS_SOURCE="$AGENTS_CLAUDE_DIR/hooks"
CLAUDE_HOOKS_TARGET="$CLAUDE_HOME_DIR/hooks"
CLAUDE_KNOWN_MISTAKES_SOURCE="$AGENTS_CLAUDE_DIR/known-mistakes.json"
CLAUDE_KNOWN_MISTAKES_TARGET="$CLAUDE_HOME_DIR/known-mistakes.json"
OPENCODE_HOOKS_SOURCE="$AGENTS_OPENCODE_DIR/hooks"
OPENCODE_HOOKS_TARGET="$OPENCODE_CONFIG_DIR/hooks"
CODEX_HOOKS_SOURCE="$AGENTS_CODEX_DIR/hooks.json"
CODEX_HOOKS_TARGET="$CODEX_HOME_DIR/hooks.json"
CODEX_AGENTS_SOURCE_DIR="$AGENTS_CODEX_DIR/agents"
CODEX_AGENTS_TARGET_DIR="$CODEX_HOME_DIR/agents"
AGENTS_MD_SOURCE="$AGENTS_ROOT_DIR/AGENTS.md"
CLAUDE_MD_SOURCE="$AGENTS_ROOT_DIR/CLAUDE.md"
CODEX_AGENTS_TARGET="$CODEX_HOME_DIR/AGENTS.md"
CLAUDE_MD_TARGET="$CLAUDE_HOME_DIR/CLAUDE.md"
CURSOR_AGENTS_TARGET="$CURSOR_HOME_DIR/AGENTS.md"
CURSOR_CLAUDE_TARGET="$CURSOR_HOME_DIR/CLAUDE.md"
CURSOR_RULE_SOURCE="$AGENTS_CURSOR_DIR/rules/global-agents.mdc"
CURSOR_RULE_TARGET="$CURSOR_HOME_DIR/rules/global-agents.mdc"
OPENCODE_AGENTS_TARGET="$OPENCODE_CONFIG_DIR/AGENTS.md"
OPENCODE_HOOKS_SOURCE="$AGENTS_OPENCODE_DIR/hooks"
OPENCODE_HOOKS_TARGET="$OPENCODE_CONFIG_DIR/hooks"

relative_link_target() {
  python3 -c 'import os, sys; print(os.path.relpath(sys.argv[1], start=sys.argv[2]))' "$1" "$2"
}

sync_shared_file() {
  local source="$1"
  local target="$2"
  local backup_dir="$3"

  if [ ! -f "$source" ]; then
    echo "SKIP     missing source $source"
    return 0
  fi

  mkdir -p "$(dirname "$target")"
  local link_target
  link_target="$(relative_link_target "$source" "$(dirname "$target")")"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$link_target" ]; then
    echo "OK       $target -> $link_target"
    return 0
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    mkdir -p "$backup_dir"
    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    local backup_target="$backup_dir/$(basename "$target").$ts"
    echo "BACKUP   $target -> $backup_target"
    mv "$target" "$backup_target"
  fi

  echo "LINK     $target -> $link_target"
  ln -s "$link_target" "$target"
}

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

# Step 3: Ensure Claude and Codex read shared hook sources from ~/.agents
echo ""
echo "=== Step 3: Sync Claude And Codex Hooks ==="
if [ "$SYNC_OPTIONAL_HOOKS" != "0" ] && [ -d "$CLAUDE_HOOKS_SOURCE" ]; then
  SOURCE_DIR="$CLAUDE_HOOKS_SOURCE" \
    TARGET_DIR="$CLAUDE_HOOKS_TARGET" \
    bash "$DIR/sync-claude-hooks.sh"
else
  if [ -d "$CLAUDE_HOOKS_SOURCE" ]; then
    echo "SKIP     Claude hooks source exists but sync disabled: $CLAUDE_HOOKS_SOURCE"
  else
    echo "SKIP     Missing Claude hooks source: $CLAUDE_HOOKS_SOURCE"
  fi
fi

sync_shared_file \
  "$CODEX_HOOKS_SOURCE" \
  "$CODEX_HOOKS_TARGET" \
  "$DIR/backups/codex-config"

if [ -d "$AGENTS_CODEX_DIR" ]; then
  echo "SYNC     Codex helper scripts from $AGENTS_CODEX_DIR"
  find "$AGENTS_CODEX_DIR" -maxdepth 1 -type f ! -name 'hooks.json' | sort | while read -r helper_file; do
    sync_shared_file \
      "$helper_file" \
      "$CODEX_HOME_DIR/$(basename "$helper_file")" \
      "$DIR/backups/codex-config/helpers"
  done
else
  echo "SKIP     Missing Codex config source: $AGENTS_CODEX_DIR"
fi

if [ -d "$CODEX_AGENTS_SOURCE_DIR" ]; then
  echo "SYNC     Codex custom agents from $CODEX_AGENTS_SOURCE_DIR"
  mkdir -p "$CODEX_AGENTS_TARGET_DIR"
  find "$CODEX_AGENTS_SOURCE_DIR" -maxdepth 1 -type f -name '*.toml' | sort | while read -r agent_file; do
    sync_shared_file \
      "$agent_file" \
      "$CODEX_AGENTS_TARGET_DIR/$(basename "$agent_file")" \
      "$DIR/backups/codex-config/agents"
  done
else
  echo "SKIP     Missing Codex custom agents source: $CODEX_AGENTS_SOURCE_DIR"
fi

sync_shared_file \
  "$CLAUDE_KNOWN_MISTAKES_SOURCE" \
  "$CLAUDE_KNOWN_MISTAKES_TARGET" \
  "$DIR/backups/claude-config"

# Step 3b: Ensure shared top-level instruction files are linked into tool homes
echo ""
echo "=== Step 3b: Sync Shared Instruction Files ==="
sync_shared_file \
  "$AGENTS_MD_SOURCE" \
  "$CODEX_AGENTS_TARGET" \
  "$DIR/backups/codex-config"
sync_shared_file \
  "$CLAUDE_MD_SOURCE" \
  "$CLAUDE_MD_TARGET" \
  "$DIR/backups/claude-config"
sync_shared_file \
  "$AGENTS_MD_SOURCE" \
  "$CURSOR_AGENTS_TARGET" \
  "$DIR/backups/cursor-config"
sync_shared_file \
  "$CLAUDE_MD_SOURCE" \
  "$CURSOR_CLAUDE_TARGET" \
  "$DIR/backups/cursor-config"
sync_shared_file \
  "$CURSOR_RULE_SOURCE" \
  "$CURSOR_RULE_TARGET" \
  "$DIR/backups/cursor-config"
sync_shared_file \
  "$AGENTS_MD_SOURCE" \
  "$OPENCODE_AGENTS_TARGET" \
  "$DIR/backups/opencode-config"

# Step 4: Sync OpenCode hooks from ~/.agents/opencode/hooks/ to ~/.config/opencode/hooks/
echo ""
echo "=== Step 4: Sync OpenCode Hooks ==="
if [ "$SYNC_OPTIONAL_HOOKS" != "0" ] && [ -d "$OPENCODE_HOOKS_SOURCE" ]; then
  SOURCE_DIR="$OPENCODE_HOOKS_SOURCE" \
    TARGET_DIR="$OPENCODE_HOOKS_TARGET" \
    bash "$DIR/sync-opencode-hooks.sh"
else
  if [ -d "$OPENCODE_HOOKS_SOURCE" ]; then
    echo "SKIP     OpenCode hooks source exists but sync disabled: $OPENCODE_HOOKS_SOURCE"
  else
    echo "SKIP     Missing OpenCode hooks source: $OPENCODE_HOOKS_SOURCE"
  fi
fi

# Step 5: Ensure OpenCode skills dir has symlinks pointing to agents dir
echo ""
echo "=== Step 5: Sync OpenCode Skills ==="
python3 "$DIR/sync_opencode_skills.py" \
  --source "$AGENTS_SKILLS_DIR" \
  --target "$OPENCODE_CONFIG_DIR/skills" \
  --apply --adopt-identical
