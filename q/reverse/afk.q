Create a comprehensive Python command-line tool that detects and optionally removes unused imports from Python source files. The tool should work on individual files, directories recursively, and Python package archives (.whl, .tar.zst).
Core Requirements:
1. Unused Import Detection Engine:
   · Parse Python source code using the ast module to analyze import usage
   · For each import statement (import X and from X import Y), track which imported names are actually used in the code
   · Collect all name references from:
     · AST Name nodes (direct variable references)
     · AST Attribute nodes (to catch module.function() style usage)
     · String constants (for dynamic imports, type hints in strings, etc.)
   · Handle edge cases:
     · import X as Y — check if alias Y is used
     · from X import Y as Z — check if alias Z is used
     · from __future__ import — never flag as unused
     · from . import X — relative imports
     · from module import * — skip checking (assume all used)
2. Smart False Positive Avoidance:
   · Detect re-exports: if a name appears in __all__, treat it as used
   · Detect imports under if TYPE_CHECKING: blocks and skip them (type-checking-only imports)
   · Check if module name appears in module docstring (documentation reference)
   · For __init__.py files, treat relative imports (.module) as potentially used for re-export
   · Skip flagging imports in __init__.py that match __all__ entries
3. Archive Processing:
   · Extract and analyze Python files from .whl (wheel) archives using zipfile
   · Extract and analyze Python files from .tar.zst archives using zstandard library (with fallback to standard tarfile if zstd support available)
   · Virtual paths for archive members: format as archive_name::internal/path.py
   · Handle corrupted archives gracefully with error reporting
4. Auto-Fix Functionality:
   · When --autofix is specified, remove unused import names from source files in-place
   · Handle different import formats:
     · import X, Y, Z → remove unused names, delete entire line if none remain
     · from module import X, Y, Z → remove unused names, handle parenthesized multi-line imports
     · from module import (X, Y, Z) → preserve parenthesized format
   · After modification, validate the resulting code parses correctly with ast.parse()
   · Skip auto-fix if validation fails, report error, leave file unchanged
   · --dry-run mode: show what would be changed without writing files
5. File Discovery and Filtering:
   · Accept multiple paths (files and directories mixed) as input
   · Recursively scan directories using Path.rglob()
   · Support --exclude regex patterns (can be specified multiple times) to skip matching files/directories
   · Target files: .py, .whl, and .tar.zst extensions
   · Warn about non-existent paths but continue processing valid ones
6. Parallel Processing:
   · Use multiprocessing.Pool for concurrent file analysis
   · Configurable worker count via --workers flag (default: 8)
   · For file tasks, pass file paths to workers (workers read files)
   · For archive-sourced content, pass source strings directly (avoid re-extracting)
   · Show progress during processing when --verbose is enabled
7. Reporting and Output:
   · Per-file reports showing:
     · File path (relative when possible)
     · Line number of unused import
     · The original import statement
   · Color-coded terminal output (auto-detected, disable with --no-color):
     · Bold for file paths
     · Cyan for line numbers
     · Yellow for import statements
     · Red for errors
     · Green for success messages
   · Verbose mode (--verbose): show which specific names within an import are unused
   · Summary: total unused imports found, number of files affected
   · Exit code 1 if unused imports found, 0 if clean
8. Command-Line Interface:
   · Positional arguments: one or more file/directory paths (default: current directory)
   · -a / --autofix: remove unused imports in-place
   · --dry-run: preview changes without writing (automatically enables autofix mode)
   · -v / --verbose: detailed output with per-name breakdown and progress
   · --workers N: number of parallel workers (default: 8)
   · --exclude PATTERN: regex pattern to exclude files (repeatable)
   · --ignore-init: treat all imports in __init__.py as used
   · --no-color: disable ANSI color codes
   · Rich help text with usage examples
   · Graceful handling of no valid paths found
9. Code Architecture:
   · Use @dataclass for structured data:
     · UnusedImport: lineno, col_offset, original statement, list of unused names
     · FileReport: path, list of UnusedImport, optional error message
   · Pure function design where possible for testability
   · Separate analysis, fixing, and reporting concerns
   · Top-level functions for multiprocessing (picklable)
10. Edge Cases and Robustness:
    · Handle syntax errors in source files (report error, skip analysis)
    · Handle encoding issues (use errors='replace')
    · Handle permission errors when reading/writing files
    · Handle empty files and files with only comments
    · Handle imports split across multiple lines with parentheses
    · Handle imports with complex aliasing chains
    · Handle try/except ImportError patterns (don't flag imports that are conditionally used)
    · Preserve original file permissions and metadata when fixing
Technical Specifications:
· Python 3.10+ compatible
· Standard library only for core functionality; zstandard as optional dependency for .tar.zst support
· Type hints throughout using modern syntax (str | None, list[UnusedImport])
· Use ast.unparse() not required (preserving original formatting better than regenerating)
· Efficient: avoid re-parsing files unnecessarily
· Memory-conscious: stream results where possible, don't hold all file contents in memory
· Thread-safe: multiprocessing-compatible functions at module level
Example Output:
```
Scanning 3 path(s) with 8 worker(s) …
  42 .py file(s), 0 archive member(s) queued.
src/main.py  -->  line    5  import os, sys, json
                                         [unused: json]
src/utils.py  -->  line    3  from typing import List, Dict, Optional
                                                     [unused: Optional]
✓ No unused imports found in src/clean.py
Found 2 unused import(s) across 2 file(s).
```
Auto-fix Behavior:
```
src/main.py  -->  line    5  import os, sys, json
                                         [unused: json]
  fixed src/main.py
src/utils.py  -->  line    3  from typing import List, Dict, Optional
                                                     [unused: Optional]
  SKIP autofix on src/utils.py — result failed to parse: ...
Fixed 1 file(s).
```
The tool should be production-quality, handling real-world Python codebases with complex import patterns, type-checking blocks, re-exports, and various edge cases. It should prioritize correctness over completeness — it's better to leave a potentially-used import than to break working code.
