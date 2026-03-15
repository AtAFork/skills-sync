#!/usr/bin/env python3

from __future__ import annotations

import argparse
import filecmp
import os
import shutil
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Result:
    created: int = 0
    removed: int = 0
    fixed: int = 0
    adopted: int = 0
    ok: int = 0
    conflicts: int = 0


def expand(path_str: str) -> Path:
    return Path(os.path.expanduser(path_str)).resolve()


def relevant_entries(path: Path) -> list[str]:
    return sorted(
        entry.name
        for entry in path.iterdir()
        if entry.name not in {".git", ".DS_Store"}
    )


def relative_link_target(source: Path, target: Path) -> Path:
    return Path(os.path.relpath(source, start=target.parent))


def dir_trees_identical(left: Path, right: Path) -> bool:
    comparison = filecmp.dircmp(left, right, ignore=[".git", ".DS_Store"])
    if comparison.left_only or comparison.right_only or comparison.funny_files:
        return False

    _, mismatches, errors = filecmp.cmpfiles(
        left, right, comparison.common_files, shallow=False
    )
    if mismatches or errors:
        return False

    for common_dir in comparison.common_dirs:
        if not dir_trees_identical(left / common_dir, right / common_dir):
            return False

    if relevant_entries(left) != relevant_entries(right):
        return False

    return True


def is_same_link(target: Path, source: Path) -> bool:
    if not target.is_symlink():
        return False
    try:
        if target.resolve() != source.resolve():
            return False
    except FileNotFoundError:
        return False
    return Path(os.readlink(target)) == relative_link_target(source, target)


def safe_backup_name(backup_root: Path, name: str) -> Path:
    candidate = backup_root / name
    if not candidate.exists():
        return candidate

    index = 1
    while True:
        candidate = backup_root / f"{name}.{index}"
        if not candidate.exists():
            return candidate
        index += 1


def sync_skills(
    source_root: Path, target_root: Path, backup_root: Path, apply: bool, adopt: bool
) -> Result:
    result = Result()
    source_skills = sorted(
        path for path in source_root.iterdir() if path.is_dir() and not path.name.startswith(".")
    )
    source_names = {path.name for path in source_skills}

    print(f"Source: {source_root}")
    print(f"Target: {target_root}")
    print(f"Apply:  {apply}")
    print(f"Adopt:  {adopt}")
    print("")

    for source_skill in source_skills:
        target_skill = target_root / source_skill.name
        link_target = relative_link_target(source_skill, target_skill)

        if not target_skill.exists() and not target_skill.is_symlink():
            print(f"CREATE   {target_skill} -> {link_target}")
            if apply:
                target_skill.symlink_to(link_target)
            result.created += 1
            continue

        if is_same_link(target_skill, source_skill):
            print(f"OK       {target_skill}")
            result.ok += 1
            continue

        if target_skill.is_symlink():
            current_dest = target_skill.resolve(strict=False)
            print(f"FIXLINK  {target_skill} -> {current_dest}")
            if apply:
                target_skill.unlink()
                target_skill.symlink_to(link_target)
            result.fixed += 1
            continue

        if target_skill.is_dir():
            if adopt and dir_trees_identical(source_skill, target_skill):
                backup_root.mkdir(parents=True, exist_ok=True)
                backup_target = safe_backup_name(backup_root, target_skill.name)
                print(f"ADOPT    {target_skill} -> backup {backup_target}")
                if apply:
                    shutil.move(str(target_skill), str(backup_target))
                    target_skill.symlink_to(link_target)
                result.adopted += 1
            else:
                print(f"CONFLICT {target_skill} (real directory)")
                result.conflicts += 1
            continue

        print(f"CONFLICT {target_skill} (non-directory)")
        result.conflicts += 1

    for target_skill in sorted(target_root.iterdir()):
        if not target_skill.is_symlink():
            continue

        try:
            resolved = target_skill.resolve(strict=False)
        except OSError:
            resolved = target_skill

        if resolved.parent != source_root:
            continue

        if target_skill.name in source_names:
            continue

        print(f"REMOVE   {target_skill}")
        if apply:
            target_skill.unlink()
        result.removed += 1

    return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Mirror ~/.agents/skills into ~/.claude/skills as symlinks."
    )
    parser.add_argument(
        "--source",
        default="~/.agents/skills",
        help="Source skill root. Default: ~/.agents/skills",
    )
    parser.add_argument(
        "--target",
        default="~/.claude/skills",
        help="Claude skill root. Default: ~/.claude/skills",
    )
    parser.add_argument(
        "--backup-dir",
        default=str(Path(__file__).resolve().parent / "backups"),
        help="Backup directory for adopted target folders.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Perform filesystem changes. Default is dry-run.",
    )
    parser.add_argument(
        "--adopt-identical",
        action="store_true",
        help="Replace identical real Claude directories with symlinks.",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    source_root = expand(args.source)
    target_root = expand(args.target)
    backup_root = expand(args.backup_dir)

    if not source_root.is_dir():
        parser.error(f"Source skill directory does not exist: {source_root}")
    if not target_root.is_dir():
        parser.error(f"Target skill directory does not exist: {target_root}")

    result = sync_skills(
        source_root=source_root,
        target_root=target_root,
        backup_root=backup_root,
        apply=args.apply,
        adopt=args.adopt_identical,
    )

    print("")
    print("Summary")
    print(f"  created:   {result.created}")
    print(f"  fixed:     {result.fixed}")
    print(f"  adopted:   {result.adopted}")
    print(f"  removed:   {result.removed}")
    print(f"  ok:        {result.ok}")
    print(f"  conflicts: {result.conflicts}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
