from __future__ import annotations
import argparse
import difflib
import os
import re
import sys
from pathlib import Path
SKIP_DIRS = {
    ".git",
    ".hg",
    ".svn",
    "__pycache__",
    ".venv",
    "venv",
    "env",
    "build",
    "dist",
    ".tox",
    ".nox",
    ".mypy_cache",
    ".pytest_cache",
    "node_modules",
    ".eggs",
    ".idea",
    ".vscode",
}
TEXT_EXTS = {
    ".py",
    ".pyi",
    ".pyx",
    ".pxd",
    ".c",
    ".h",
    ".txt",
    ".md",
    ".rst",
    ".toml",
    ".cfg",
    ".ini",
    ".json",
    ".yaml",
    ".yml",
    ".in",
    ".jinja",
    ".jinja2",
    ".tmpl",
    ".tpl",
    ".sh",
    ".bash",
    ".zsh",
    ".bat",
    ".ps1",
    ".html",
    ".css",
    ".js",
    ".ts",
}
TEXT_PREFIXES = (
    "readme",
    "license",
    "copying",
    "changelog",
    "authors",
    "notice",
    "requirements",
    "makefile",
    "dockerfile",
)
DOTFILES = {
    ".gitignore",
    ".gitattributes",
    ".editorconfig",
    ".flake8",
    ".pylintrc",
    ".coveragerc",
}
def looks_textual(path: Path) -> bool:
    name = path.name.lower()
    if name in DOTFILES:
        return True
    if path.suffix.lower() in TEXT_EXTS:
        return True
    if name.startswith(TEXT_PREFIXES):
        return True
    return False
def build_replacer(old: str, new: str):
    """Return (compiled_pattern, replacement_callable)."""
    pattern = re.compile(r"\b" + re.escape(old) + r"\b", re.IGNORECASE)
    def _repl(match: re.Match) -> str:
        token = match.group(0)
        if token.isupper():
            return new.upper()
        if token.islower():
            return new.lower()
        if token.istitle():
            return new.title()
        return new
    return pattern, _repl
def process_file(path: Path, pattern, repl, *, dry_run: bool, show_diff: bool) -> bool:
    """Rewrite ``path`` in place. Return True if content changed."""
    try:
        original = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError) as e:
        print(f"  skipped {path}: {e}", file=sys.stderr)
        return False
    new = pattern.sub(repl, original)
    if new == original:
        return False
    if show_diff:
        sys.stdout.writelines(
            difflib.unified_diff(
                original.splitlines(keepends=True),
                new.splitlines(keepends=True),
                fromfile=str(path),
                tofile=str(path) + " (new)",
            )
        )
        print()
    if not dry_run:
        path.write_text(new, encoding="utf-8")
    return True
def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Rename a Python project and update all references.")
    parser.add_argument("project_dir", type=Path, help="Path to the top-level project folder")
    parser.add_argument("new_name", help="New project/module name (must be a valid identifier)")
    parser.add_argument("--dry-run", action="store_true", help="Do not write or rename anything, just report")
    parser.add_argument("--diff", action="store_true", help="Show a unified diff of every file change")
    args = parser.parse_args(argv)
    project_dir = args.project_dir.resolve()
    new_name = args.new_name
    if not project_dir.is_dir():
        print(f"error: {project_dir} is not a directory", file=sys.stderr)
        return 1
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", new_name):
        print(f"error: '{new_name}' is not a valid Python identifier", file=sys.stderr)
        return 1
    old_name = project_dir.name
    if old_name == new_name:
        print("error: old and new names are identical", file=sys.stderr)
        return 1
    target_dir = project_dir.with_name(new_name)
    if target_dir.exists() and not args.dry_run:
        print(f"error: {target_dir} already exists", file=sys.stderr)
        return 1
    pattern, repl = build_replacer(old_name, new_name)
    files_updated = 0
    for dirpath, dirnames, filenames in os.walk(project_dir):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
        for fname in sorted(filenames):
            p = Path(dirpath) / fname
            if not looks_textual(p):
                continue
            if process_file(p, pattern, repl, dry_run=args.dry_run, show_diff=args.diff):
                files_updated += 1
                if not args.diff:
                    action = "would update" if args.dry_run else "updated"
                    print(f"{action}: {p}")
    to_rename: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(project_dir, topdown=False):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames + dirnames:
            if pattern.search(name):
                to_rename.append(Path(dirpath) / name)
    renamed: list[tuple[str, str]] = []
    for src in to_rename:
        new_filename = pattern.sub(repl, src.name)
        dst = src.with_name(new_filename)
        if dst.exists() and not args.dry_run:
            print(f"  skip rename (target exists): {src} -> {dst}", file=sys.stderr)
            continue
        if not args.dry_run:
            src.rename(dst)
        renamed.append((src.name, new_filename))
    if not args.dry_run:
        project_dir.rename(target_dir)
    verb = "Would rename" if args.dry_run else "Renamed"
    print(f"{verb} project '{old_name}' -> '{new_name}'" + ("  (dry-run)" if args.dry_run else ""))
    print(f"  {'would be ' if args.dry_run else ''}new path: {target_dir}")
    print(f"  files updated:         {files_updated}")
    print(f"  files/folders renamed: {len(renamed)}")
    for old, new in renamed:
        print(f"    {old}  ->  {new}")
    return 0
if __name__ == "__main__":
    sys.exit(main())
