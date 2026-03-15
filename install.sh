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

PLIST_LABEL="com.user.claude-skill-sync"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
LOG_DIR="$HOME/Library/Logs"

echo "Installing launchd agent..."
echo "  Script dir:   $DIR"
echo "  Claude skills: $CLAUDE_SKILLS_DIR"
echo "  Agents skills: $AGENTS_SKILLS_DIR"
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
    <string>$AGENTS_SKILLS_DIR</string>
    <string>$CLAUDE_SKILLS_DIR</string>
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
