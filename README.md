# Claude Skill Sync

This folder contains two related tools:

- `reconcile_agents_from_claude.py`: one-way reconciliation that copies skills
  from `~/.claude/skills` into `~/.agents/skills`, with Claude treated as the
  source of truth.
- `sync_claude_skills.py`: mirroring tool that treats `~/.agents/skills` as the
  source of truth for shared custom skills and mirrors them into
  `~/.claude/skills` as symlinks.
- `sync-all.sh`: orchestration wrapper that also projects shared Codex config
  files such as `~/.agents/codex/hooks.json` into `~/.codex/hooks.json`.

This is aimed at the Codex + Claude split:

- Codex reads `~/.agents/skills` directly.
- Claude reads `~/.claude/skills`.
- Codex hooks can live in `~/.agents/codex/hooks.json` and are symlinked into
  `~/.codex/hooks.json`.

The script is intentionally conservative:

- It creates missing Claude-side symlinks for shared skills.
- It writes relative symlinks so the `~/.claude` repo stays portable across
  machines.
- It removes stale Claude-side symlinks only when they already point back to the
  source skill directory.
- It does not overwrite real Claude directories by default.
- It can optionally replace an identical Claude directory with a symlink if you
  explicitly opt in.

## Files

- `reconcile_agents_from_claude.py`: populate or update `~/.agents/skills` from
  Claude's skill directory
- `sync_claude_skills.py`: sync tool
- `sync-all.sh`: sync shared skills and shared Codex hook config
- `backups/`: created on demand if you use `--adopt-identical`

## Usage

Reconcile `~/.agents/skills` from Claude first:

```bash
python3 reconcile_agents_from_claude.py
python3 reconcile_agents_from_claude.py --apply
```

Dry run:

```bash
python3 sync_claude_skills.py
```

Apply safe changes:

```bash
python3 sync_claude_skills.py --apply
```

Apply safe changes and replace identical Claude directories with symlinks:

```bash
python3 sync_claude_skills.py --apply --adopt-identical
```

Use custom paths:

```bash
python3 sync_claude_skills.py \
  --source /path/to/source/skills \
  --target /path/to/claude/skills \
  --apply
```

## Installation

1. Clone this repo
2. Copy `.env.example` to `.env` and adjust paths if needed
3. Run `./install.sh` to install the launchd agent

The agent is configured to:

- run at login (`RunAtLoad`)
- watch both skill directories plus `~/.agents/codex` for changes (`WatchPaths`)
- re-run every 5 minutes as a safety backstop (`StartInterval = 300`)

This means:

- existing symlinks continue to work across reboots even if the agent never runs
- new or removed skill directories are mirrored automatically after login
- if a filesystem watch event is missed, the periodic run repairs drift

Useful checks:

```bash
launchctl list | grep claude-skill-sync
tail -n 50 ~/Library/Logs/claude-skill-sync.log
tail -n 50 ~/Library/Logs/claude-skill-sync.err.log
```

## Behavior

### `reconcile_agents_from_claude.py`

For each skill in the Claude source directory:

- If the agents target does not exist, the script copies it across.
- If the agents target already exists and is identical, it leaves it alone.
- If the agents target differs, the script moves the old agents version into
  `backups/agents-pre-reconcile/` and replaces it with Claude's version.
- It does not delete Claude skills.

### `sync_claude_skills.py`

For each skill in the source directory:

- If the Claude target does not exist, the script creates a symlink.
- If the Claude target is already the correct symlink, it leaves it alone.
- If the Claude target is a different symlink, the script fixes it.
- If the Claude target is a real directory, the script reports a conflict.
- If `--adopt-identical` is set and the real directory is byte-for-byte
  identical to the source skill, the script moves it into `backups/` and
  replaces it with a symlink.

For stale Claude-side symlinks that point back into the source directory:

- If the source skill no longer exists, the script removes the stale symlink.

## How It Works

After installation:

- `~/.agents/skills` is the shared source of truth
- `~/.claude/skills` contains symlinks pointing to the shared skills
- `~/.agents/codex/hooks.json` is the shared source of truth for Codex hooks
- `~/.codex/hooks.json` is a symlink pointing at that shared file
- the launch agent keeps future additions/removals mirrored automatically
- skills created directly in `~/.claude/skills` are automatically adopted into
  `~/.agents/skills` and replaced with symlinks
