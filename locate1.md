You are an expert systems programmer. Your task is to completely rewrite the existing Linux `locate` command utility as a modern, clean, and installable Python CLI package targeting Python 3.11+.

The implementation must strictly adhere to the following rules:

### 1. Project Structure & Metadata
- The package name and CLI executable names must match the original utility. Because `locate` relies on database generation, your package must expose **two** distinct installable CLI entry points in `pyproject.toml`:
  1. `locate` (for searching the index)
  2. `updatedb` (for building/updating the index)
- All standard command-line flags/arguments for `locate` (such as `-i`/`--ignore-case`, `-e`/`--existing`, `-l`/`--limit`) must be mapped exactly.
- Provide a robust, production-grade multi-file layout. Show the repository layout explicitly, which must strictly contain:
  ```text
  ├── pyproject.toml
  ├── src/
  │   └── locate/
  │       ├── __init__.py
  │       ├── database.py
  │       ├── locate_cli.py
  │       └── updatedb_cli.py
  ├── tests/
  │   ├── conftest.py
  │   ├── test_locate.py
  │   └── test_updatedb.py
  └── benchmarks/
      └── benchmark_indexing.py
  ```
- Include a valid `pyproject.toml` file configuration targeting a `setuptools` backend. Ensure `pytest` and any required testing/benchmark extensions are declared under development dependencies.

### 2. Architectural & Technical Constraints
- **Database Backend:** You must use the standard library `sqlite3` module to implement the search index storage. Design an efficient schema to store absolute paths, directory indices, or mtimes to enable fast pattern matching.
- **Native Implementation Only:** No `subprocess`, `os.system`, `os.popen`, or similar shell-execution functions are allowed. You must implement the underlying file indexing logic natively in pure Python.
- **File System Traversal:** `updatedb` must exclusively use `pathlib.Path` for all file system traversal, metadata manipulation, and path checks during indexing. Do not use legacy `os.path` or `os.walk` modules.
- **Logging:** Use the `loguru` library for all internal logging, progress metrics, and unexpected runtime captures.
- **Concurrency & Multiprocessing:** For the `updatedb` traversal and indexing paths, you must explicitly use `concurrent.futures.ProcessPoolExecutor` configured with a fixed pool of exactly 4 workers (`max_workers=4`) to ingest paths efficiently into the SQLite database.

### 3. Testing & Benchmarking Rules
- **Pytest Suite:** Provide complete, type-annotated `pytest` unit/integration test code under the `tests/` directory. Ensure it covers mocking file system hierarchies using pytest fixtures (e.g., `tmp_path`), index state validation, and flag combinations.
- **Performance Benchmarks:** Provide a functional benchmarking script under `benchmarks/` to measure execution times for database reads (`locate`) and writes (`updatedb`). Use native timing mechanisms or appropriate testing fixtures to capture metrics.

### 4. Code Quality, Annotations, & Robustness
- **Type Safety:** The entire codebase (including main code, tests, and benchmarks) must be fully type-annotated using standard Python typing syntax.
- **Documentation:** Provide clean, professional docstrings for all modules, classes, and public functions detailing parameters, return types, and raised exceptions.
- **Error & Edge Case Handling:** Implement defensive programming. Gracefully handle edge cases specific to file systems and database persistence (e.g., database locks, permission errors, broken symlinks, circular directory links, missing paths) using explicit `try/except` blocks and structural logging.

### 5. Command-Specific Custom Rules
- **Database Storage Path:** By default, look for or initialize the SQLite file in a standard location compliant with user-space execution if root permissions are missing (e.g., `~/.cache/locate/locate.db`).
- **Query Optimization:** Since `locate` performs glob/substring lookups, utilize efficient SQL querying (such as `LIKE` operators, indexes, or custom SQLite functions if necessary) to ensure near-instantaneous responses even with millions of indexed rows.
