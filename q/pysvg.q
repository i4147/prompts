# Consolidated Prompt
Write a production-quality Python 3.12 script that optimizes `.svg` files in place by invoking **svgo** through `subprocess`, with the following full specification.
## Core Behaviour
- Run `svgo` on every `.svg` file discovered under the given paths.
- Update files **in place**, but only after validating svgo's result (exit code `0`, output exists, non-empty, well-formed XML).
- Write atomically using a temp file in the same directory as the input followed by `os.replace`, so a crash can never leave a half-written file.
- Preserve the original file mode bits.
- Always show the output of the svgo command (stdout and stderr), captured by the workers and printed by the parent process so lines never interleave.
- Report the number of processed / changed / unchanged / skipped / errored files, plus the byte savings per file and in aggregate.
## Discovery
- Accept **multiple files and directories** as positional arguments. When no arguments are given, process files in the current directory recursively.
- Use `pathlib` throughout.
- Use the **`fastwalk`** Rust extension's `walk_files(root)` function to discover `.svg` files. It accepts only a path and returns a `list[Path]`; no pruning options are exposed, so all filtering happens in Python on the returned list.
- Since `fastwalk` cannot prune on the Rust side, enforce a `SKIP_DIRS` set in Python (`.git`, `.hg`, `.svn`, `.tox`, `.nox`, `.venv`, `venv`, `env`, `__pycache__`, `node_modules`, `.cache`, `.idea`, `.vscode`, `build`, `dist`, `target`, `.mypy_cache`, `.pytest_cache`, `.ruff_cache`). A path is skipped if any of its directory components (relative to the walk root) match a name in `SKIP_DIRS`.
- **Skip symlinks** during discovery, so svgo is never invoked on a symlinked SVG and the symlink itself is never replaced.
- Match `.svg` extensions **case-insensitively**: `.svg`, `.SVG`, `.Svg`, and any other casing must all be accepted. Drive this from a single named constant (`SVG_SUFFIXES`) so other extensions can be added later.
- De-duplicate paths (e.g. a file passed explicitly that is also inside a directory argument) via `Path.resolve()` keys.
- Surface per-root errors (missing paths, `walk_files` failures) as warnings rather than aborting the whole run.
## Parallelism
- Use `multiprocessing.Pool` with **8 workers**, driven by `imap_unordered` (no `--workers` or `--jobs` CLI flag; the worker count is fixed).
- Feed the pool a lazy stream so the parent's working memory stays bounded even when walking very large trees: chunk the discovery output (`WALK_CHUNK = 512`) and use `chunksize=4` for `imap_unordered`.
- Bind the worker options with `functools.partial` so `process_file` remains a top-level, picklable function.
## Validation Before Writing
Only overwrite the original if **all** of the following hold:
1. svgo exited with status `0`.
2. The output file exists and is non-empty.
3. The output parses as well-formed XML via `xml.etree.ElementTree`.
4. The output is **not byte-identical** to the input. Detect this by comparing sizes first, then streaming both files in fixed-size chunks for a direct byte comparison. When identical, skip the write entirely — no inode churn, no mtime bump — and report the file as `NOCHG`.
5. The output is **strictly smaller** than the input. If it is larger, skip the write, preserve the original, and report the file as `SKIP`.
6. If `--dry-run` is set, run and validate everything but do not modify any files, reporting the file as `DRY-RUN`.
## CLI
- Positional arguments: one or more files or directories. Default: current directory, recursive.
- `-q` / `--quiet` — do not print svgo's own stdout/stderr, only summary lines.
- `--dry-run` — run and validate, but do not modify any files.
- `--multipass` — pass `--multipass` to svgo.
- `--pretty` — pass `--pretty` to svgo.
- `--svgo PATH` — path to the svgo executable (default: search `PATH`).
- `--svgo-arg ARG` — extra argument to pass to svgo; may be repeated.
- `--timeout SECONDS` — per-file svgo timeout (default: 300 s).
## Robustness and Quality
- Resolve symlinks in the worker so `os.replace` targets the real file when symlink filtering is bypassed by unusual setups (hardlinks, bind mounts).
- Per-file subprocess timeout so a hung svgo can never stall the pool.
- Capture svgo output as UTF-8 with `errors="replace"`.
- Per-file `try`/`finally` cleanup of the temp file; a failure in cleanup must never mask the real result.
- Never let a worker raise — turn every failure into an entry on the `ProcessResult` record with a short human-readable error message.
- Return a non-zero exit code from `main` if any file errored.
- Report with clear tags: `OK`, `DRY-RUN`, `SAME` (same size but different bytes), `NOCHG` (byte-identical), `SKIP` (output larger), `ERROR`.
- Human-readable byte formatting (B / KiB / MiB / GiB / TiB).
- Derive the temp-file suffix from the target's original extension so a `logo.SVG` gets a `.SVG.tmp` scratch file — cosmetic but makes in-progress directory listings self-explanatory.
## Style
- Fully type-annotated (`from __future__ import annotations`, PEP 604 unions, `Final` for constants).
- Comprehensive docstrings on the module and every function.
- A `ProcessResult` `NamedTuple` to carry `(path, original_size, new_size, stdout, stderr, skipped, no_change, error)` back from each worker.
- Clear section banners and inline comments explaining every non-obvious decision.
- Small, single-responsibility helpers.
- Ordered so that cheap checks (suffix, skip-dir) run before expensive ones (lstat, realpath), and the byte-identical short-circuit runs before the size-comparison short-circuit.
- Return the fully annotated source code.