plz add following options to code

## 1. Safety & correctness (highest priority)

- **Interactive confirmation before deletion.** Currently `-r` unlinks files silently. Add `-y/--yes` and otherwise prompt per group (`keep this, delete N others? [y/N/a/q]`), with `a` = all, `q` = quit.
- **Dry-run as default, or explicit `--dry-run`.** Print the plan and require `-r` (already) but also `--dry-run` so users can preview the exact `rm` set.
- **Quarantine instead of delete.** Move duplicates to a temp dir (`--to-trash` / `--quarantine DIR`) or use `send2trash`, instead of `Path.unlink()`. Adds a safety net and reversibility.
- **Configurable "keeper" policy.** Today it's `group.paths[0]` (lexicographic). Add `--keep oldest|newest|shortest|longest|path-pattern GLOB|prefer PREFIX`. Useful when one copy is the canonical source.
- **Ignore directories and files.** Skip `.venv`, `.git`, `__pycache__`, `node_modules`, `.tox`, `.mypy_cache`, `.pytest_cache`, plus `--exclude GLOB` (repeatable) and an ignore-file (`.pydupignore` or `[tool.pydup] ignore = [...]` in `pyproject.toml`).
- **Respect `.gitignore`.** Via `pathspec`; almost always what users actually want.
- **Symlink handling.** Add `--follow-symlinks`/`--no-follow-symlinks` and detect broken symlinks (today `Path.resolve()` will throw). Also de-duplicate paths that resolve to the same inode.
- **CI-friendly exit codes.** Return `1` when duplicates are found and `--fail-on-dupes`/`--exit-code` is set; currently always `0`. Add `--fail-on-error` for parse failures too.
- **Guard against changing files during the run.** `identify_duplicates` re-normalizes each candidate for exactness, but a file could be modified mid-run. Capture `st_mtime_ns` + `st_size` at scan time and verify before deletion.

## 2. CLI & UX

- **Positional arguments.** Accept explicit file/dir paths, or `-` for stdin list, in addition to `--root`.
- **Multiple roots** (`--root A --root B`) for cross-project comparison.
- **`--min-lines` / `--min-bytes`.** Skip trivially-small files that normalize to the same AST (e.g. `pass`, empty modules). Optionally `--skip-empty`.
- **`--verbose`/`--quiet` and a `--log-format`.** Currently `cprint` and raw `print` are mixed; standardize on `logging`.
- **`--version`** (and a proper `pyproject.toml` with a `console_scripts` entry point).
- **`--format {text,json,ndjson,csv}` output** (see §5).
- **Progress bug.** In the non-`rich` branch, `\r` updates don't clear trailing text; use `\r` + padding or write to a TTY-safe line.
- **Interrupted-run handling.** Wrap the `ProcessPoolExecutor` loop with `try/finally` and `KeyboardInterrupt` so no worker output is lost and the pool is cleaned up.

## 3. Detection capabilities

- **Normalization levels.** Today everything (docstrings, annotations, type comments, type ignores, `TypeAlias`) is stripped. Add `--mode strict|default|loose|structural`:
  - `strict`: source hash — identical bytes.
  - `default`: AST with docstrings removed (current behavior minus annotations).
  - `loose`: current behavior.
  - `structural`: normalized AST + a token-stream hash to catch cases where AST differs but token order matches (rarely needed).
  This is the single biggest correctness/utility upgrade, because "identical normalized AST" is currently quite aggressive.
- **Near-duplicate detection.** For each group of similar ASTs, compute a similarity score (token n-gram Jaccard, or AST node histogram) and report pairs above `--similarity 0.9`. Catches refactor-worthy copies the exact hash misses.
- **Duplicate functions/classes within and across files** (not just whole-file). Walk `ast.FunctionDef`/`ast.AsyncFunctionDef`/`ast.ClassDef` nodes, normalize each independently, and group by hash. Report `module:lineno`. This is often what people actually want (it's the "find copy-pasted functions" use case).
- **Import-level duplicates.** Detect files that differ only by import ordering or by unused imports (`ruff --select F401` style) — small extension of the normalizer.
- **`--changed-since REF`.** Only compare files modified since a git ref, useful in pre-commit.
- **Support `.pyi`** and (optionally) `.ipynb` by extracting code cells.

## 4. Performance

- **Persistent hash cache.** Store `{path: {mtime_ns, size, hash}}` in `.pydup-cache.json`; skip re-parsing unchanged files. Huge win on large repos (a second run is near-instant).
- **Fingerprint pass first, AST pass second.** Roughly what `identify_duplicates` does, but currently the AST re-parse is done regardless. Keep the current "verify exact ASTs on collision" behavior, but also verify size/mtime match before trusting the cached hash.
- **Read `path` via `os.scandir`** for `get_pyfiles` to avoid a second `stat`.
- **Use `--workers` = 0 as "auto"** or accept `--workers 0`; today `_positive_int` rejects 0.
- **Streamed reporting** so results appear as groups are found, instead of waiting for all files.

## 5. Output & reporting

- **`--format json`** with schema like `{"version":1,"groups":[{"digest":…,"paths":[…],"bytes_wasted":N}], "failures":[…]}`. Essential for CI/editor integration.
- **Rich tables** in text mode: group id, hash, count, total size, individual paths — instead of the current plain lines.
- **Byte accounting.** Report per-group and total wasted bytes, plus a summary table (`N groups, M files, X MB recoverable`).
- **Diff mode.** `--diff A B` prints a unified diff of two normalized ASTs (`ast.unparse`) so users can see *why* they were considered duplicates (or not).
- **`--stats`** summary at the end (files scanned, parsed, skipped, elapsed).

## 6. Integration & workflow

- **Pre-commit hook & GitHub Action** wrapping the JSON output + non-zero exit.
- **`--watch`** mode using `watchdog` for continuous monitoring.
- **Baseline mode.** `--baseline existing.json` to report only *new* duplicates — standard pattern for incremental rollout in large repos.
- **`--print-keep`** to output only the keeper paths (useful for scripts that want to delete the rest themselves).
- **Machine-readable deletion manifest.** `--manifest out.json` before deletion, so you can restore via `git checkout`.

## 7. Small correctness fixes worth doing alongside

- `visit_TypeAlias(self, node) -> None: return None` is correct behavior (deletes the node) but the return annotation is misleading; use `-> ast.AST | None`.
- `_run_jobs` swallows `ProcessPoolExecutor` exceptions only at `future.result()` — wrap `_run_jobs` in `main` so a worker crash produces a clean error message.
- `Path.cwd()` in `--root` default is fine, but `resolve()` on a symlinked cwd changes behavior — prefer `Path.cwd()` unresolved for the default.
- `sorted({Path(path) for path in get_pyfiles(root)}, key=str)` — if `get_pyfiles` already returns strings, the extra `Path()` conversion is wasted; also `set()`+`sorted()` only matters if there are duplicates (unlikely).
- show a progress using rich library while processing
return full type-annotated code (no comments or docstrings needed)
