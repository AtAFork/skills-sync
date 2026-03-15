#!/usr/bin/env python3

from __future__ import annotations

import argparse
import filecmp
import shutil
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Result:
    copied: int = 0
    updated: int = 0
    ok: int = 0


def dir_trees_identical(left: Path, right: Path) -> bool:
    comparison = filecmp.dircmp(left, right)
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

    return True


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


def ignore_copy_patterns(_dir: str, names: list[str]) -> set[str]:
    ignored: set[str] = set()
    if ".git" in names:
        ignored.add(".git")
    return ignored


def copy_tree(src: Path, dest: Path) -> None:
    shutil.copytree(src, dest, symlinks=True, ignore=ignore_copy_patterns)


def reconcile(source_root: Path, target_root: Path, backup_root: Path, apply: bool) -> Result:
    result = Result()
    source_skills = sorted(
        path for path in source_root.iterdir() if path.is_dir() and not path.name.startswith(".")
    )

    print(f"Claude source: {source_root}")
    print(f"Agents target: {target_root}")
    print(f"Apply:         {apply}")
    print("")

    for source_skill in source_skills:
        target_skill = target_root / source_skill.name

        if not target_skill.exists():
            print(f"COPY    {source_skill} -> {target_skill}")
            if apply:
                copy_tree(source_skill, target_skill)
            result.copied += 1
            continue

        if not target_skill.is_dir():
            raise RuntimeError(f"Target exists but is not a directory: {target_skill}")

        if dir_trees_identical(source_skill, target_skill):
            print(f"OK      {target_skill}")
            result.ok += 1
            continue

        backup_root.mkdir(parents=True, exist_ok=True)
        backup_target = safe_backup_name(backup_root, target_skill.name)
        print(f"UPDATE  {target_skill} -> backup {backup_target}")
        if apply:
            shutil.move(str(target_skill), str(backup_target))
            copy_tree(source_skill, target_skill)
        result.updated += 1

    return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Copy ~/.claude/skills into ~/.agents/skills with Claude as source of truth."
    )
    parser.add_argument(
        "--source",
        default="~/.claude/skills",
        help="Claude skill root. Default: ~/.claude/skills",
    )
    parser.add_argument(
        "--target",
        default="~/.agents/skills",
        help="Agents skill root. Default: ~/.agents/skills",
    )
    parser.add_argument(
        "--backup-dir",
        default=str(Path(__file__).resolve().parent / "backups" / "agents-pre-reconcile"),
        help="Backup directory for replaced agents skills.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Perform filesystem changes. Default is dry-run.",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    source_root = Path(args.source).expanduser().resolve()
    target_root = Path(args.target).expanduser().resolve()
    backup_root = Path(args.backup_dir).expanduser().resolve()

    if not source_root.is_dir():
        parser.error(f"Claude skill directory does not exist: {source_root}")
    if not target_root.is_dir():
        parser.error(f"Agents skill directory does not exist: {target_root}")

    result = reconcile(source_root, target_root, backup_root, args.apply)

    print("")
    print("Summary")
    print(f"  copied:  {result.copied}")
    print(f"  updated: {result.updated}")
    print(f"  ok:      {result.ok}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
