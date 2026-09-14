#!/usr/bin/env python3
"""Merge ~/.agents/claude/.mcp.json mcpServers into ~/.claude.json top-level mcpServers.

Claude Code reads MCP user-scope config from ~/.claude.json top-level "mcpServers",
NOT from ~/.claude/.mcp.json. This script keeps the authoritative
~/.agents/claude/.mcp.json synced into the location Claude Code actually reads.

Semantics:
- Source keys overwrite target keys (source is authoritative for its namespace).
- Target keys not in source are preserved (so `claude mcp add --scope user` survives).
- A manifest at ~/.agents/claude/.mcp.managed-keys.json tracks which keys this script
  owns; on next run, any previously-managed key that no longer exists in source is
  removed from target (so deleting from source actually deletes).
"""

import argparse
import json
import os
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default=str(Path.home() / ".agents/claude/.mcp.json"))
    parser.add_argument("--target", default=str(Path.home() / ".claude.json"))
    parser.add_argument(
        "--manifest",
        default=str(Path.home() / ".agents/claude/.mcp.managed-keys.json"),
    )
    args = parser.parse_args()

    source_path = Path(args.source)
    target_path = Path(args.target)
    manifest_path = Path(args.manifest)

    if not source_path.is_file():
        print(f"SKIP     missing MCP source {source_path}")
        return 0
    if not target_path.is_file():
        print(f"SKIP     missing MCP target {target_path}")
        return 0

    source = json.loads(source_path.read_text())
    target = json.loads(target_path.read_text())

    source_servers = (source.get("mcpServers") or {}) if isinstance(source, dict) else {}
    if "mcpServers" not in target or not isinstance(target["mcpServers"], dict):
        target["mcpServers"] = {}

    previously_managed = []
    if manifest_path.is_file():
        try:
            previously_managed = json.loads(manifest_path.read_text()).get("keys", [])
        except (json.JSONDecodeError, OSError):
            previously_managed = []

    # Drop previously-managed keys that no longer exist in source (true deletions).
    current_source_keys = set(source_servers.keys())
    removed = []
    for key in previously_managed:
        if key not in current_source_keys and key in target["mcpServers"]:
            del target["mcpServers"][key]
            removed.append(key)

    # Merge source into target (source wins on conflicts).
    added = []
    overwritten = []
    for key, value in source_servers.items():
        if key in target["mcpServers"]:
            if target["mcpServers"][key] != value:
                overwritten.append(key)
        else:
            added.append(key)
        target["mcpServers"][key] = value

    # Atomic write of target.
    tmp_path = target_path.with_suffix(target_path.suffix + ".tmp-mcp-merge")
    tmp_path.write_text(json.dumps(target, indent=2))
    os.replace(tmp_path, target_path)

    # Update manifest.
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_tmp = manifest_path.with_suffix(manifest_path.suffix + ".tmp")
    manifest_tmp.write_text(json.dumps({"keys": sorted(current_source_keys)}, indent=2))
    os.replace(manifest_tmp, manifest_path)

    summary = f"MERGED   {len(source_servers)} mcpServer(s) {source_path.name} -> {target_path.name}"
    print(summary)
    if added:
        print(f"         + added:       {', '.join(added)}")
    if overwritten:
        print(f"         ~ overwritten: {', '.join(overwritten)}")
    if removed:
        print(f"         - removed:     {', '.join(removed)}")
    if not (added or overwritten or removed):
        print("         (no change)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
