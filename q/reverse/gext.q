Create a comprehensive Python utility for extracting and collecting Python code entities (classes, functions, methods, constants) from a directory of Python files and archives. The tool should work as a command-line utility that processes all Python files and archive files (whl, zip, tar.gz, etc.) in the current working directory.
Core Requirements:
1. Entity Extraction Engine:
   · Parse Python source code using the ast module to identify and extract:
     · Top-level functions (including async functions)
     · Classes (with their methods being classified as methods, not standalone functions)
     · Module-level constants (variables matching ^[A-Z_][A-Z0-9_]*$ pattern when defined at module scope)
   · For each extracted entity, capture:
     · The full source code slice (including proper line/column offsets)
     · The entity's name and a scoped full name (e.g., ClassName_method_name)
     · The entity type classification
     · Metadata about whether it's a constant, class, or function
2. Import Collection and Analysis:
   · Collect all import statements from processed files using both tree-sitter (if available) and AST fallback
   · For each extracted entity, analyze its code to determine required imports based on common patterns like:
     · Type hints (List, Dict, Optional, etc.) → from typing import ...
     · Decorators (@dataclass, @property, etc.)
     · Common library usage (pathlib, datetime, re, json, etc.)
   · Merge existing imports with newly detected needed imports, prioritizing standard library imports first
3. File Discovery and Processing:
   · Walk through directory trees recursively, skipping .git and __pycache__ directories and symlinks
   · Process files with .py extension and also detect Python files without extensions by checking for shebangs or Python keywords
   · Handle archive formats: .zip, .whl, .tar.gz, .tgz, .tar.zst, .tar.xz, .tar
   · For archives, extract Python files from within and process them with virtual paths indicating their archive origin
4. Parallel Processing:
   · Use ProcessPoolExecutor for concurrent file processing with configurable worker count (default: min(cpu_count, 8))
   · Each worker should handle individual file or archive processing independently
   · Show progress indicators for each processed file
5. Output Organization:
   · Save extracted entities to an output directory (./output/ or ~/tmp/output/ if -t flag is passed)
   · Organize entities in subdirectories by type: function/, class/, const/
   · Generate enhanced entity files with:
     · Header comments indicating source path
     · Consolidated import statements
     · The original entity code
   · Handle filename collisions by appending incremental numbers
   · Save a global imports file aggregating all unique imports discovered
6. Error Handling and Robustness:
   · Gracefully handle permission errors, syntax errors, and malformed archives
   · Provide fallback parsing mechanisms (tree-sitter → AST)
   · Display clear error messages and continue processing remaining files
   · Handle edge cases like empty files, binary content, and encoding issues
7. Reporting and Statistics:
   · Display a summary of extracted entities by type
   · Show most common import modules with usage counts
   · Report total count of successfully saved entities
   · Provide progress updates during processing
Technical Specifications:
· Use Python 3.10+ features including type hints with union syntax (str | Path)
· Leverage pathlib.Path for all file operations
· Implement custom AST visitor classes using ast.NodeVisitor
· Use concurrent.futures for parallel processing
· Support optional dependencies: tree-sitter, tree-sitter-python, and zstd
· Follow PEP 8 style guidelines
· Include proper docstrings and comments for complex logic
· Handle both synchronous and asynchronous function definitions
Command-Line Interface:
· Support a -t flag to change output directory to ~/tmp/output/
· Exit with appropriate status codes (0 for success, 1 for failure)
· Print clear status messages throughout execution
The script should be designed to analyze Python codebases, extract reusable code entities with their dependencies, and organize them for easy discovery and reuse. It should be robust enough to handle large codebases efficiently through parallel processing and comprehensive error handling.
python version = 3.12
-use pathlib and parallel processing
