# Prompt
Write a single-file Python script called `requirements_generator.py` that scans a Python project for imports and generates a `requirements.txt`. Return only the full annotated code with no comments and no docstrings.
## Environment and constraints
- Target Python 3.8+.
- Must import from a local module `dh` the following two symbols:
  - `STDLIB` — a collection of stdlib module names to strip.
  - `PKG_MAPPING` — a `dict` mapping package names to their primary import name (e.g. `{"aadb": "auto_adjust_display_brightness", "abakaffe": "abakaffe_cli", ...}`). Many-to-one entries are possible; keep the first mapping when building the reverse lookup.
- A JSON file at `/sdcard/data/pip.json` contains all packages that exist on PyPI. Its top-level is either a dict whose keys are package names, or a list of names. Use this as the local PyPI existence index.
- Use `yarg` (`json2package`) and `requests` to fetch latest release info from `https://pypi.python.org/pypi/`.
- Use `pip._internal.operations.freeze` as a fallback import where historically the script imported it — but the actual installed-package listing must be obtained by running `[python, "-m", "pip", "freeze"]` as a subprocess so it works on Windows and any interpreter passed by the user.
## Required functionality
### 1. Import extraction (AST-based, not string splitting)
- Walk the target directory recursively.
- Parse `.py` files with `ast`.
- For `.ipynb` files, load JSON, join each cell's `source` list, and `ast.parse` the joined string.
- Collect top-level names from `ast.Import` and `ast.ImportFrom` (only when `level == 0` and `module` is set).
- If a node is inside a `try:` block whose handlers catch `ImportError` or `ModuleNotFoundError` (or a bare `except`, or a tuple containing either), mark the imports there as "optional". Optional imports are skipped unless `--include-optional` is passed.
- `SyntaxError` in a file must not crash the scan; return an empty list for that file.
### 2. Stdlib strip
- Drop any imported name that appears in `STDLIB` (from `dh`). Normalize the STDLIB value whether it's a set or another collection.
### 3. Local-module filtering
- An imported top-level name is "local" if:
  - `<dir_of_source_file>/<name>.py` exists, or
  - `<dir_of_source_file>/<name>/__init__.py` exists, or
  - any ancestor directory up to the filesystem root contains `<name>/__init__.py`.
- Local modules must be dropped before dependency resolution.
### 4. Import-name → package-name mapping
- Build a reverse dict from `PKG_MAPPING` once at module import: `IMPORT_TO_PKG[import_name] = package_name`, keeping the first occurrence for a given import name.
- For each surviving import name, look it up in `IMPORT_TO_PKG`; fall back to the name itself.
### 5. PyPI existence check
- Load `/sdcard/data/pip.json`. Normalize every key with PEP 503 (`re.sub(r"[-_.]+", "-", name).lower()`).
- If the index loads successfully and a package's normalized name is not in it, skip that package (with a warning). If the index cannot be loaded, fall back to online lookups without the local filter.
### 6. Installed packages and version resolution
- Get installed packages by running `sys.executable -m pip freeze` (or `args["python"] -m pip freeze` when `--python` is supplied). Build a dict keyed by normalized name → `(original_name, version_or_None)`.
- For each candidate package:
  - If it is installed locally, use its installed version.
  - Otherwise, fetch from PyPI (`{pypi_server}{pkg}/json`). Parse with `json2package`, take `latest_release_id`. On `HTTPError`, `requests.RequestException`, or missing data, log a warning and either skip (if the local index confirms absence) or emit the name with no version.
### 7. Caching
- Cache PyPI lookups under `~/.cache/piplist/` as `<sha256(module)[:16]>.json` with `{"ts": epoch, "value": ...}`. TTL = 86400 seconds. Reads must tolerate corrupt/missing files silently.
### 8. Concurrency
- Online lookups must run in a `concurrent.futures.ThreadPoolExecutor(max_workers=8)`.
### 9. Version pinning styles
- `--pin {exact,compatible,minimal,none}` with default `exact`.
  - exact → `name==version`
  - compatible → `name~=version`
  - minimal → `name>=version`
  - none → bare name
- If version is unknown, emit the bare name regardless of style.
### 10. Filtering and exclusions
- `--exclude pkg1 pkg2 ...` — drop these packages (normalized).
- `--include pkg1 pkg2 ...` — keep only these (normalized), if non-empty.
- `--ignore-dir d1 d2 ...` — additional directory names to skip during the walk. Always skip (by default) these directory names: `.git`, `.hg`, `.svn`, `.tox`, `.venv`, `venv`, `env`, `build`, `dist`, `__pycache__`, `node_modules`, `.mypy_cache`, `.pytest_cache`, `site-packages`, `.eggs`, `.idea`, `.vscode`. Also skip any subdirectory whose name starts with `.`.
- `--ignore-file path` — read one package name per line, ignore blank lines and lines starting with `#`.
### 11. Strip already-installed packages
- By default, after resolving versions, remove any package whose normalized name is in the installed set. Provide `--keep-installed` to disable this.
### 12. Output
- `--dry-run` or `--stdout`: print results to stdout, one per line, do not write a file.
- Otherwise write `requirements.txt`:
  - If `--path` is given, write `<path>/requirements.txt`; otherwise write `requirements.txt` in the CWD.
  - If the target file already exists and `--overwrite` is not passed, merge with the existing non-empty, non-comment lines (union of sets).
- Sort case-insensitively (`key=str.lower`) and deduplicate.
- Ensure a trailing newline when the file is non-empty.
### 13. CLI flags (exact names)
`-p/--path`, `--python`, `--proxy`, `--pin`, `--exclude` (nargs="*"), `--include` (nargs="*"), `--ignore-dir` (nargs="*"), `--ignore-file`, `--include-optional` (store_true), `--keep-installed` (store_true), `--overwrite` (store_true), `--dry-run` (store_true), `--stdout` (store_true), `--verbose` (store_true), `--quiet` (store_true).
### 14. Logging
- Use the `logging` module with a logger named `piplist`.
- Level: `WARNING` if `--quiet`, `DEBUG` if `--verbose`, else `INFO`.
- Format: `"%(message)s"`.
- Replace all `print()` calls with `log.info` / `log.warning` / `log.debug` as appropriate.
### 15. Exit codes
- `0` success.
- `2` if `--path` was given but does not exist.
- `KeyboardInterrupt` → exit `0`.
### 16. Misc
- `main()` parses args, sets `args["strip_installed"] = not args["keep_installed"]`, and calls `init(args)`, wrapping it in a `try/except KeyboardInterrupt` that exits `0`.
- Use `sys.exit(init(args))` so the exit code from `init` propagates.
- No `#` comments anywhere in the file.
- No docstrings anywhere in the file.
Return the complete script in one code block.