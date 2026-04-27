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

PLIST_LABEL="com.user.claude-skill-sync"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
LOG_DIR="$HOME/Library/Logs"

echo "Installing launchd agent..."
echo "  Script dir:   $DIR"
echo "  Claude skills: $CLAUDE_SKILLS_DIR"
echo "  Agents skills: $AGENTS_SKILLS_DIR"
echo "  Agents root:   $AGENTS_ROOT_DIR"
echo "  Agents Claude: $AGENTS_CLAUDE_DIR"
echo "  Agents codex:  $AGENTS_CODEX_DIR"
echo "  Agents open:   $AGENTS_OPENCODE_DIR"
echo "  Agents cursor: $AGENTS_CURSOR_DIR"
echo "  Claude home:   $CLAUDE_HOME_DIR"
echo "  Codex home:    $CODEX_HOME_DIR"
echo "  Cursor home:   $CURSOR_HOME_DIR"
echo "  OpenCode cfg:  $OPENCODE_CONFIG_DIR"
echo "  Plist:         $PLIST_PATH"
echo ""

# Unload existing agent if present
launchctl bootout "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || true

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$PLIST_LABEL</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$DIR/sync-all.sh</string>
  </array>

  <key>WorkingDirectory</key>
  <string>$DIR</string>

  <key>RunAtLoad</key>
  <true/>

  <key>StartInterval</key>
  <integer>300</integer>

  <key>WatchPaths</key>
  <array>
    <string>$AGENTS_ROOT_DIR</string>
    <string>$AGENTS_CLAUDE_DIR</string>
    <string>$AGENTS_SKILLS_DIR</string>
    <string>$CLAUDE_SKILLS_DIR</string>
    <string>$AGENTS_CODEX_DIR</string>
    <string>$AGENTS_OPENCODE_DIR</string>
    <string>$AGENTS_CURSOR_DIR</string>
    <string>$CLAUDE_HOME_DIR</string>
    <string>$CODEX_HOME_DIR</string>
    <string>$CURSOR_HOME_DIR</string>
    <string>$OPENCODE_CONFIG_DIR</string>
  </array>

  <key>StandardOutPath</key>
  <string>$LOG_DIR/claude-skill-sync.log</string>

  <key>StandardErrorPath</key>
  <string>$LOG_DIR/claude-skill-sync.err.log</string>
</dict>
</plist>
PLIST

# Load the agent
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"

echo "Installed and loaded $PLIST_LABEL"
echo ""
echo "Verify with:"
echo "  launchctl list | grep claude-skill-sync"
echo "  tail -f ~/Library/Logs/claude-skill-sync.log"
