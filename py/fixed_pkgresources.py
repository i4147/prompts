from __future__ import annotations
import argparse
import re
from multiprocessing import Pool
from pathlib import Path
REPLACEMENTS = [
    (r"pkg_resources\.resource_filename\(", "importlib.resources.files("),
    (r"pkg_resources\.resource_string\(", "importlib.resources.files("),
    (r"pkg_resources\.require\(", "packaging.requirements.Requirement("),
    (r"pkg_resources\.get_distribution\(", "importlib.metadata.version("),
    (r"pkg_resources\.iter_entry_points\(", "importlib.metadata.entry_points("),
    (r"pkg_resources\.parse_version\(", "packaging.version.Version("),
]
def detect_pkg_resources(file_path: Path) -> dict:
    try:
        try:
            content = file_path.read_text(encoding="utf-8", errors="ignore")
        except (OSError, UnicodeDecodeError) as e:
            return {
                "file": str(file_path),
                "error": str(e),
                "found": False,
                "usages": [],
                "imports_needed": set(),
                "reason": "read_error",
            }
        has_import = bool(re.search(r"^import\s+pkg_resources|^from\s+pkg_resources", content, re.MULTILINE))
        usages = []
        for pattern, _ in REPLACEMENTS:
            try:
                for match in re.finditer(pattern, content):
                    line_num = content[: match.start()].count("\n") + 1
                    usages.append({"pattern": pattern, "line": line_num})
            except re.error:
                continue
        imports_needed = set()
        if has_import:
            if re.search(r"pkg_resources\.resource_filename", content) or re.search(
                r"pkg_resources\.resource_string", content
            ):
                imports_needed.add("importlib.resources")
            if re.search(r"pkg_resources\.require", content):
                imports_needed.add("packaging.requirements")
            if re.search(r"pkg_resources\.get_distribution", content):
                imports_needed.add("importlib.metadata")
            if re.search(r"pkg_resources\.iter_entry_points", content):
                imports_needed.add("importlib.metadata")
            if re.search(r"pkg_resources\.parse_version", content):
                imports_needed.add("packaging.version")
        found = bool(usages)
        return {
            "file": str(file_path),
            "found": found,
            "usages": usages,
            "imports_needed": imports_needed,
            "reason": "found" if found else "no_pkg_resources",
        }
    except Exception as exc:
        return {
            "file": str(file_path),
            "error": f"Unexpected: {exc}",
            "found": False,
            "usages": [],
            "imports_needed": set(),
            "reason": "exception",
        }
def autofix_pkg_resources(file_path: Path) -> dict:
    try:
        try:
            original = file_path.read_text(encoding="utf-8", errors="ignore")
        except (OSError, UnicodeDecodeError) as e:
            return {"file": str(file_path), "error": str(e), "fixed": False, "reason": "read_error"}
        content = original
        content = re.sub(
            r"^import\s+pkg_resources\n?|^from\s+pkg_resources.*?\n",
            "",
            content,
            flags=re.MULTILINE | re.DOTALL,
        )
        content = re.sub(r"\n\n+", "\n\n", content)
        imports_needed = set()
        changed = False
        for old_pattern, new_pattern in REPLACEMENTS:
            try:
                if re.search(old_pattern, content):
                    content = re.sub(old_pattern, new_pattern, content)
                    changed = True
                    if "importlib.resources" in new_pattern:
                        imports_needed.add("importlib.resources")
                    elif "packaging.requirements" in new_pattern:
                        imports_needed.add("packaging.requirements")
                    elif "importlib.metadata" in new_pattern:
                        imports_needed.add("importlib.metadata")
                    elif "packaging.version" in new_pattern:
                        imports_needed.add("packaging.version")
            except Exception:
                continue
        if imports_needed or changed:
            import_lines = "\n".join(f"import {imp}" for imp in sorted(imports_needed))
            m = re.search(r"^(#!.*\n)?(?:\"\"\"[\\s\\S]*?\"\"\"\n)?", content)
            insert_pos = m.end() if m else 0
            existing = set(re.findall(r"^import\s+(\S+)", content, flags=re.MULTILINE))
            missing = sorted(imports_needed - existing)
            if missing:
                import_block = "\n".join(f"import {imp}" for imp in missing)
                content = content[:insert_pos] + import_block + "\n" + content[insert_pos:]
                changed = True
        if content != original:
            try:
                file_path.write_text(content, encoding="utf-8")
                return {
                    "file": str(file_path),
                    "fixed": True,
                    "imports_added": sorted(imports_needed),
                    "reason": "autofixed",
                }
            except OSError as e:
                return {"file": str(file_path), "error": f"Write failed: {e}", "fixed": False, "reason": "write_error"}
        return {"file": str(file_path), "fixed": False, "reason": "no_changes", "imports_added": sorted(imports_needed)}
    except Exception as exc:
        return {"file": str(file_path), "error": f"Unexpected: {exc}", "fixed": False, "reason": "exception"}
def collect_python_files(paths: list[str]) -> list[Path]:
    py_files: list[Path] = []
    for path_str in paths:
        path = Path(path_str)
        if path.is_file() and path.suffix == ".py":
            py_files.append(path.resolve())
        elif path.is_dir():
            py_files.extend(path.rglob("*.py"))
    unique = sorted({str(p.resolve()): p.resolve() for p in py_files}.values(), key=lambda p: str(p))
    return unique
def main() -> int:
    parser = argparse.ArgumentParser(
        description="Detect and autofix deprecated pkg_resources usage.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Examples:\n  python script.py\n  python script.py -a\n  python script.py src/ -a -j 4",
    )
    parser.add_argument("paths", nargs="*", help="Python files or dirs (default: .)")
    parser.add_argument("-a", "--autofix", action="store_true", help="Autofix usage")
    parser.add_argument(
        "-j", "--jobs", type=int, default=min(4, max(1, __import__("os").cpu_count() - 1)), help="Workers"
    )
    args = parser.parse_args()
    paths = args.paths if args.paths else ["."]
    py_files = collect_python_files(paths)
    if not py_files:
        print("No .py files found.")
        return 0
    mode = "AUTOFIX" if args.autofix else "REPORT"
    print(f"Found {len(py_files)} file(s) | Mode: {mode}")
    print()
    try:
        if args.autofix:
            with Pool(processes=max(1, args.jobs)) as pool:
                results = pool.map(autofix_pkg_resources, py_files)
            fixed = 0
            for res in results:
                if res is None or not isinstance(res, dict):
                    continue
                if res.get("error"):
                    print(f"❌ {res.get('file', '?')}: {res['error']}")
                elif res.get("fixed"):
                    fixed += 1
                    imports = ", ".join(res.get("imports_added") or [])
                    print(f"✓ {res.get('file', '?')} | Added: {imports or 'none'}")
                else:
                    reason = res.get("reason", "no_changes")
                    if reason not in ("no_changes", "no_pkg_resources"):
                        print(f"- {res.get('file', '?')}: {reason}")
            print()
            print(f"Fixed {fixed}/{len(py_files)} file(s)")
        else:
            with Pool(processes=max(1, args.jobs)) as pool:
                results = pool.map(detect_pkg_resources, py_files)
            found = 0
            for res in results:
                if res is None or not isinstance(res, dict):
                    continue
                if res.get("error"):
                    print(f"❌ {res.get('file', '?')}: {res['error']}")
                elif res.get("found"):
                    found += 1
                    usages = res.get("usages") or []
                    imports = res.get("imports_needed") or set()
                    print(f"⚠ {res.get('file', '?')}")
                    for usage in usages:
                        if isinstance(usage, dict) and "line" in usage:
                            print(f"   Line {usage['line']}: {usage.get('pattern', '?')}")
                    if imports:
                        print(f"   Imports needed: {', '.join(sorted(imports))}")
                    print()
            print()
            print(f"Found pkg_resources in {found}/{len(py_files)} file(s)")
            if found > 0:
                print("Run with -a to autofix.")
    except KeyboardInterrupt:
        print("\nInterrupted by user.")
        return 130
    except Exception as e:
        print(f"Fatal error: {e}")
        import traceback
        traceback.print_exc()
        return 1
    return 0
if __name__ == "__main__":
    raise SystemExit(main())
