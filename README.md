# Claude Skill Sync

This folder contains tools for syncing skills and hooks across multiple AI agents:

- `reconcile_agents_from_claude.py`: one-way reconciliation that copies skills
  from `~/.claude/skills` into `~/.agents/skills`, with Claude treated as the
  source of truth.
- `sync_claude_skills.py`: mirroring tool that treats `~/.agents/skills` as the
  source of truth for shared custom skills and mirrors them into
  `~/.claude/skills` as symlinks.
- `sync-claude-hooks.sh`: syncs `~/.agents/claude/hooks/` to `~/.claude/hooks/`.
- `sync_opencode_skills.py`: mirroring tool that treats `~/.agents/skills` as the
  source of truth and mirrors them into `~/.config/opencode/skills` as symlinks.
- `sync-opencode-hooks.sh`: syncs `~/.agents/opencode/hooks/` to `~/.config/opencode/hooks/`.
- `sync-all.sh`: orchestration wrapper that syncs skills for Claude and OpenCode,
  plus shared hook configs and top-level instruction files for Codex, Claude,
  Cursor, and OpenCode.

This is aimed at the Claude + Codex + OpenCode split:

- Claude reads `~/.claude/skills`.
- Codex reads `~/.agents/skills` directly.
- OpenCode reads `~/.config/opencode/skills`.
- Codex hooks can live in `~/.agents/codex/hooks.json` and are symlinked into
  `~/.codex/hooks.json`.
- Codex hook helper scripts can live beside that file in `~/.agents/codex/`
  and are symlinked into `~/.codex/`.
- Claude hooks can live in `~/.agents/claude/hooks/` and are symlinked into
  `~/.claude/hooks/`.
- Shared known-mistake patterns can live in `~/.agents/claude/known-mistakes.json`
  and are symlinked into `~/.claude/known-mistakes.json`.
- Shared Codex instructions can live in `~/.agents/AGENTS.md` and are symlinked
  into `~/.codex/AGENTS.md`.
- Shared Claude instructions can live in `~/.agents/CLAUDE.md` and are symlinked
  into `~/.claude/CLAUDE.md`.
- Cursor can also receive symlinked shared instruction entrypoints at
  `~/.cursor/AGENTS.md` and `~/.cursor/CLAUDE.md`, plus an optional Cursor rule
  bridge at `~/.cursor/rules/global-agents.mdc`.
- OpenCode global rules can live in `~/.agents/AGENTS.md` and are symlinked into
  `~/.config/opencode/AGENTS.md`. Additional instruction files can be referenced
  from `~/.config/opencode/opencode.json`.
- OpenCode hooks can live in `~/.agents/opencode/hooks/` and are symlinked into
  `~/.config/opencode/hooks/`.

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
- `sync_claude_skills.py`: sync tool for Claude skills
- `sync-claude-hooks.sh`: sync tool for Claude hooks
- `sync_opencode_skills.py`: sync tool for OpenCode skills
- `sync-opencode-hooks.sh`: sync tool for OpenCode hooks
- `sync-all.sh`: orchestration wrapper that syncs all skills and hooks
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

### OpenCode Skills

Dry run:

```bash
python3 sync_opencode_skills.py
```

Apply safe changes:

```bash
python3 sync_opencode_skills.py --apply
```

### Claude Hooks

```bash
./sync-claude-hooks.sh
```

### OpenCode Hooks

```bash
./sync-opencode-hooks.sh
```

### Sync All (Claude + OpenCode + Hooks)

Run the orchestration wrapper to sync everything:

```bash
./sync-all.sh
```

Apply all changes (dry-run by default for safety):

```bash
./sync-all.sh --apply
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
- watch skill directories and hook directories for changes (`WatchPaths`)
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

### `sync_opencode_skills.py`

Behavior is identical to `sync_claude_skills.py`, but for OpenCode's skill directory
(`~/.config/opencode/skills`).

### `sync-opencode-hooks.sh`

Syncs hook files from `~/.agents/opencode/hooks/` to `~/.config/opencode/hooks/`:

- Creates symlinks for any hooks that exist in the source directory.
- Backs up any existing real files in the target directory.
- Removes stale symlinks that point to deleted source hooks.

## How It Works

After installation:

- `~/.agents/skills` is the shared source of truth for all skills
- `~/.claude/skills` contains symlinks pointing to the shared skills
- `~/.config/opencode/skills` contains symlinks pointing to the shared skills
- `~/.agents/claude/hooks/` is the shared source of truth for Claude hooks
- `~/.claude/hooks` is a symlink pointing at that shared directory
- `~/.agents/claude/known-mistakes.json` is the shared source of truth for
  known-mistake patterns and is symlinked into `~/.claude/known-mistakes.json`
- `~/.agents/codex/hooks.json` is the shared source of truth for Codex hooks
- `~/.codex/hooks.json` is a symlink pointing at that shared file
- top-level helper scripts in `~/.agents/codex/` are symlinked into
  `~/.codex/` so hook-adjacent scripts are carried by the same sync path
- `~/.agents/AGENTS.md` is the shared source of truth for Codex/global
  AGENTS-style instructions and is symlinked into `~/.codex/AGENTS.md`
- `~/.agents/CLAUDE.md` is the shared source of truth for Claude/global
  CLAUDE-style instructions and is symlinked into `~/.claude/CLAUDE.md`
- `~/.cursor/AGENTS.md` and `~/.cursor/CLAUDE.md` can be symlinked from those
  same shared files, with `~/.cursor/rules/global-agents.mdc` as a Cursor rule
  bridge sourced from `~/.agents/cursor/rules/global-agents.mdc`
- `~/.config/opencode/AGENTS.md` can be symlinked from `~/.agents/AGENTS.md`
  so OpenCode picks up the same global rules, while `opencode.json` can include
  additional shared instruction files such as `~/.agents/CLAUDE.md`
- `~/.agents/opencode/hooks/` is the shared source of truth for OpenCode hooks
- `~/.config/opencode/hooks/` contains symlinks pointing to shared hooks
- the launch agent keeps future additions/removals mirrored automatically
- skills created directly in `~/.claude/skills` are automatically adopted into
  `~/.agents/skills` and replaced with symlinks
