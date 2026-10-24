## User
**Attachments:**
- pasted-text-2026-08-06T01-33-04.txt
**Document Content:**
```
Create a high-performance Python command-line utility that strips comments and docstrings from Python source files while preserving code formatting, structure, and functionality. The tool should work on individual files, directories recursively, and .whl (wheel) archive files.
Core Requirements:
1. Comment Removal Engine:
   · Parse Python source code line-by-line to remove comments while preserving:
     · String literals (single, double, and triple-quoted strings)
     · Shebang lines (#!/usr/bin/env python)
     · Encoding declarations (# -*- coding: utf-8 -*-)
     · Type comments (# type: ignore, # type: Optional[str])
   · Track state machine for: in-string, in-triple-quotes, string character type
   · Strip inline comments but preserve the rest of the line
   · Remove standalone comment lines completely (replace with empty line to preserve line numbering)
   · Count the number of comments removed per file
2. Docstring Removal Engine:
   · Use Python's ast module with a custom NodeTransformer to remove docstrings from:
     · Functions (def)
     · Async functions (async def)
     · Classes
     · Modules (optional, controlled by flag)
   · After removing a docstring, ensure the node body isn't empty (insert pass if needed)
   · Use ast.unparse() to convert the modified AST back to source code
   · Count docstrings removed per file
   · Handle the case where ast.unparse() may not perfectly preserve original formatting
3. File Processing Pipeline:
   · For each file, execute in order:
     1. Read file content (UTF-8)
     2. Extract shebang and encoding declaration lines
     3. Remove comments (preserving formatting)
     4. Remove docstrings via AST transformation
     5. Restore shebang and encoding at the top
     6. Validate the resulting code is syntactically valid Python
     7. If valid, atomically write changes using a temporary file + shutil.move()
   · If validation fails, report the error and leave the original file unchanged
   · Clean up temporary files on failure
4. Atomic File Writing:
   · Use tempfile.NamedTemporaryFile in the same directory as the target file
   · Write processed content to the temp file
   · Use shutil.move() for atomic replacement (works across filesystems on same device)
   · On any error, delete the temp file and report failure
5. Wheel (.whl) Archive Processing:
   · Extract wheel files to temporary directories
   · Process all .py files within the extracted contents
   · Track changes with virtual paths formatted as wheelname.whl::internal/path.py
   · If any files changed, rebuild the wheel archive with zipfile.ZIP_DEFLATED
   · Replace the original wheel atomically using a .tmp.whl intermediate file
   · Clean up all temporary directories in a finally block
6. File Discovery:
   · Use Path.walk() (Python 3.12+) with top_down=True for efficient traversal
   · Prune directories in-place by modifying the dirs list to skip:
     · .git, __pycache__, .mypy_cache, .ruff_cache, .pytest_cache
     · .venv, venv, lazy
   · Target files: .py and .whl extensions
   · Accept either a single file or directory as input
7. Parallel Processing:
   · Use ProcessPoolExecutor for concurrent processing of regular Python files
   · Configurable worker count via --workers flag (default: 4)
   · Process wheel files sequentially in the main process (due to filesystem operations)
   · For dry-run mode, submit a picklable placeholder function instead of lambdas (avoid pickle errors)
8. Command-Line Interface:
   · Positional argument: target file or directory (default: current directory)
   · --workers N: number of parallel worker processes
   · --remove-module-docstring: also strip module-level docstrings (preserved by default)
   · --dry-run: show what would be changed without modifying files
   · Display count of found files at start
   · Show per-file results with relative paths and change details
   · Print summary statistics: total files, changed files, comments removed, docstrings removed, errors
9. Error Handling and Robustness:
   · Handle syntax errors gracefully (skip file, report error)
   · Handle encoding issues
   · Handle corrupted wheel files
   · Handle permission errors
   · Never lose original file content (atomic writes)
   · Report all errors with context
10. Performance Optimizations:
    · Use frozenset for skip directories
    · In-place list modification during directory traversal to prune early
    · Stream files with generators rather than collecting all in memory
    · Use string building efficiently (list of strings + join)
    · Minimize memory footprint through incremental processing
Technical Specifications:
· Target Python 3.12+ (use Path.walk() instead of os.walk())
· Use dataclasses for result objects
· Use type hints throughout with modern syntax (str | None, list[FileResult])
· Implement proper state machine for comment detection
· Handle edge cases in string/comment interaction:
  · "string with # hash" — not a comment
  · '''triple quoted # still not a comment'''
  · "nested 'quotes' are tricky"
· The AST docstring removal should handle empty bodies by inserting pass
Expected Behavior:
· Comments like # this is a comment are removed
· Inline comments like x = 1  # increment become x = 1
· Docstrings inside functions/classes are removed
· Module docstrings are preserved unless --remove-module-docstring is specified
· Type comments like x = []  # type: List[int] are preserved
· The tool should never produce invalid Python code
· Original file is safe — changes are atomic
Example Output Format:
```
Found: 42 Python files, 3 wheel files
src/main.py (5 comments, 2 docstrings removed)
src/utils.py (no change)
src/helpers.py (error: Syntax error at line 10)
Processing wheel file: package-1.0.whl
  package-1.0.whl::pkg/module.py (3 comments removed)
==================================================
Summary:
  Total files processed: 45
  Files changed: 12
  Total comments removed: 67
  Total docstrings removed: 23
```
The tool should be production-ready, handling edge cases gracefully and never corrupting source files. It should be fast enough to process large codebases with hundreds of files using parallel execution.
python version = 3.12
- use pathlib and parallel processing
```
