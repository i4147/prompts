You are an expert systems programmer. Your task is to completely rewrite the existing Linux command `{{command}}` as a modern, clean, and installable Python CLI package targeting Python 3.11+.

The implementation must strictly adhere to the following rules:

### 1. Project Structure & Metadata
- The package name, CLI executable name, and all command-line flags/arguments must match the original `{{command}}` exactly.
- Provide a modular, multi-file layout. Show the repository structure explicitly (e.g., `pyproject.toml`, `src/{{command}}/__init__.py`, `src/{{command}}/main.py`, etc.).
- Include a valid `pyproject.toml` file configuration targeting a `setuptools` backend. The package must expose an installable CLI entry point mapping `{{command}}` to your execution function.

### 2. Architectural & Technical Constraints
- **Native Implementation Only:** No `subprocess`, `os.system`, `os.popen`, or similar shell-execution functions are allowed. You must implement the underlying logic natively in pure Python.
- **File System Traversal:** You must exclusively use `pathlib.Path` for all file system traversal, metadata manipulation, and path checks. Do not use legacy `os.path` or `os.walk` modules.
- **Logging:** Use the `loguru` library for all internal logging, diagnostic outputs, and unexpected runtime captures.
- **Concurrency & Multiprocessing:** For execution paths involving heavy traversal or I/O processing, you must explicitly use `concurrent.futures.ProcessPoolExecutor` configured with a fixed pool of exactly 4 workers (`max_workers=4`).
- the code must avoid 3rdparty libraries, as much as possinle, but using 3rdparty libs is not forbidden
- the implemented pkg, must contain pytest based tests & proper benchmark codes to test it
### 3. Code Quality, Annotations, & Robustness
- **Type Safety:** The entire codebase must be fully type-annotated using standard Python typing syntax (including `collections.abc` types where appropriate).
- **Documentation:** Provide clean, professional docstrings for all modules, classes, and public functions detailing parameters, return types, and raised exceptions.
- **Error & Edge Case Handling:** Implement defensive programming. Gracefully handle edge cases specific to file systems (e.g., permission errors, broken symlinks, missing paths, concurrent mutations) using explicit `try/except` blocks and structural logging.


### 4. Output Requirements
- Provide the complete, functional, type-safe implementation across the defined file layout. Do not use generic `pass` statements or placeholder comments inside the source code files.
- Ensure the output code accurately replicates the native behavior, defaults, and flag combinations of `{{command}}`.
