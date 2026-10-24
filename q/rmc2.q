▎Prompt: Production-Grade Python Source Cleaner (LibCST)
Role: Expert Python Developer specializing in AST manipulation, high-performance concurrency, and toolchain development.
Objective: Develop a robust, production-ready Python utility using libcst that cleans Python source files by removing comments, docstrings, and type annotations based on user-defined configurations.
▎1. Core Logic & Transformations
The tool must process files via libcst.Transformer to perform the following operations:
• Default Behavior (Minimal): Strip only inline comments.
• Flag: -c / --strip-comments: Remove block and inline comments (excluding #! shebangs, # type:, and # fmt:).
• Flag: -d / --strip-docstrings: Remove docstrings. If a docstring is the only statement in a function/class body, replace it with pass to maintain syntax.
• Flag: -t / --strip-type-hints: Remove all type annotations from variables, function signatures, and imports (e.g., typing module imports).
• Flag: -a / --all: Force-strip everything, including shebangs, preserved comments (type/fmt), and all type annotations.
• Heuristic: Comment Preservation: Implement logic to identify "commented-out code." If consecutive lines start with #, attempt to parse the content (with # removed) as Python code. If the resulting code is syntactically valid, preserve the comment block.
▎2. CLI Interface & Execution
• Arguments:
    – Input paths (positional, defaults to cwd).
    – --pool-method: Options: map, imap, imap_unordered, apply, apply_async (Default: apply_async).
    – --backup: Create a .bak copy of files before modification.
    – --dry-run: Output changes to console without writing to disk.
    – --diff: Print a colorized diff of proposed changes.
    – --stats (-n): Output a report of total comments/docstrings removed per file and total bytes saved.
• Performance:
    – Use multiprocessing.Pool with strictly 8 workers.
    – Optimize for large codebases (chunking, memory-efficient streaming).
▎3. Robustness & Safety
• Validation: Before overwriting, use ast.parse to ensure the generated code is valid Python 3.12 syntax. If invalid, log an error and skip the file.
• Encoding: Enforce utf-8 read/write. If decoding fails, attempt to detect or handle alternative encodings (e.g., cp1252) gracefully via try-except blocks.
• Error Handling: Use loguru for all logging. Handle file permission errors and non-Python files (filter based on extensions or shebangs).
• File Handling: Use pathlib for all filesystem operations. Support files without extensions (if they contain a valid shebang).
▎4. Quality Requirements
• Strict Typing: Full PEP 484 type annotations for the utility itself.
• Documentation: Comprehensive docstrings and type hints explaining each libcst transformer.
• Maintainability: Follow clean architecture; separate the CLI parsing, the libcst visitor/transformer logic, and the multiprocessing executor.
▎5. Suggested Enhancements (Implement these)
• Import Optimization: If -t is used, automatically remove now-unused imports from the typing module.
• File Filtering: Add an .ignore configuration support (e.g., ignore __pycache__, .venv, or specific user-defined patterns).
• Progress Bar: Use tqdm for visual feedback during the multiprocessing task.
Output Requirement: Provide the complete, single-file Python script. The script must be ready for immediate production usage.
