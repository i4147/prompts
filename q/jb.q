generate a standalone, dependency-optional Python 3 command-line tool for
processing and manipulating JSON files.
The tool should behave as follows: **Purpose**: A versatile CLI utility that can
validate, format/pretty-print, minify, diff, and recursively process JSON (and
JSON-like) files across a filesystem, with support for multiple JSON parsing
backends and large-file optimization. **Key requirements**: 1. **Backend
abstraction**: Implement an abstract `_Backend` base class defining `loads()`
and `dumps()` methods, with at least one concrete implementation using Python's
standard `json` library as a guaranteed fallback.
Design it so additional faster/optional third-party JSON libraries (e.g.,
`orjson`, `ujson`, `rapidjson`) could be plugged in as alternative backends,
with automatic selection of the best available backend at runtime and graceful
fallback to stdlib if none are installed. 2. **File discovery**: Recursively
walk a given root directory (or accept explicit file paths) to find JSON-like
files.
Recognize extensions such as `.json`, `.jsonc`, and `.tsconfig`.
Support glob/fnmatch-based include/exclude patterns.
Exclude common noise directories by default (e.g., `.git`, `.hg`, `.svn`,
`node_modules`, `.venv`, `venv`, `__pycache__`, `build`, `dist`), with an option
to override or extend this list. 3. **Large file handling**: For files exceeding
a defined size threshold (e.g., 1MB), use memory-mapped file reading (`mmap`)
for efficiency instead of loading the whole file into memory at once. 4. **Core
operations** the CLI should support (via subcommands or flags): - **Validate**:
Check whether each file contains syntactically valid JSON, reporting errors with
file path and line/column information where possible. - **Format/Pretty-print**:
Re-serialize JSON with configurable indentation and optional key sorting,
writing back to the file or to stdout. - **Minify/Compact**: Serialize JSON with
no extraneous whitespace. - **Diff**: Compare two JSON files (or a file
before/after formatting) and show a human-readable diff (using Python's
`difflib`), highlighting structural/content differences. - Support an in-place
mode that safely writes results using a temporary file (`tempfile`) and atomic
replace, to avoid data corruption on failure. 5. **Parallelism**: Use
`multiprocessing.Pool` (sized based on `cpu_count()`) to process multiple files
concurrently, improving throughput on large codebases/directories. 6. **CLI
interface**: Build the command-line interface with `argparse`, exposing options
such as: target path(s), include/exclude patterns, output mode (stdout vs
in-place), indentation level, sort-keys flag, diff mode, backend
selection/override, and verbosity/quiet flags.
Provide clear `--help` documentation and sensible defaults. 7.
**Output/reporting**: Print per-file status (OK, invalid, changed, unchanged,
error) to stdout/stderr, and return a meaningful process exit code (e.g., 0 if
all files are valid/unchanged, non-zero if any errors or invalid files are
found) so the tool can be used in CI pipelines/pre-commit hooks. 8. **Code
structure & style**: Use modern Python with `from __future__ import
annotations`, type hints throughout (including `Any`, `Sequence`, `dataclass`
for structured results), dataclasses for representing per-file results/summary,
and clean separation between the backend layer, file-discovery layer, processing
logic, and CLI entry point (`main()` function guarded by `if __name__ ==
"__main__":`). 9. **Robustness**: Handle encoding issues, missing files,
permission errors, and malformed JSON gracefully without crashing the whole run;
collect and report all errors at the end of execution.
Generate the complete, runnable Python script implementing all of the above as a
single cohesive CLI tool. ---
