# part 1
Role: Expert Python Developer
Objective: Create a high-performance, production-ready Python utility using libcst to strip comments and docstrings from Python source files in-place.
Core Functionality:
• Targeting: Recursively process files/directories passed as CLI arguments. If no input is provided, default to the current working directory.
• File Handling:
    – Support files without extensions.
    – Use pathlib for all path manipulations.
    – Update files in-place only after validation.
• Logic Constraints (libcst):
    – Remove all comments and docstrings except:
        ▪ Shebang lines (#!).
        ▪ Module-level docstrings (keep these).
        ▪ Special comments: # type: and # fmt:.
    – Edge Case: If a docstring is the only statement in a function or class body, replace it with pass to maintain syntactic correctness.
• Validation: Use ast.parse to verify the generated code is valid Python 3.12 syntax before overwriting the file.
Concurrency & Performance:
• Use multiprocessing.Pool with default 4 workers
• Support a --pool-method CLI argument to toggle between: map, imap, imap_unordered, apply, apply_async, starmap.
• Default to apply_async.
CLI Interface & Reporting:
• Implement standard argument parsing (e.g., argparse).
• Reporting:
    – Default mode: Report bytes reduced per file and total space saved at the end of execution.
    – -n / --stats flag: Report the total count of comments and docstrings removed per file.
• Logging: Use loguru for all error handling and operational logging.
Quality Requirements:
• Strict Typing: Full type annotations (PEP 484) required.
• Performance: Optimize for memory efficiency and speed; assume large codebases.
• Maintainability: Use clean architecture, modular functions, and idiomatic Python 3.12+.
• Documentation: The generated code must include thorough docstrings and type hints, explaining the logic of the libcst transformers.
Output Constraints:
• Return the complete, single-file Python script.
• The script must be production-ready, robust, and handle edge cases (e.g., file permissions, encoding errors, non-Python files).
. Safety/Backup Mechanism: Add a --backup flag that copies files to a .bak extension before modifying them, or creates a temporary directory for rollback.
. Encoding Handling: Explicitly enforce utf-8 and handle files with different encodings (e.g., cp1252) gracefully by catching exceptions.
. Dry Run Mode: Add a --dry-run flag that prints what would be changed without actually writing to disk and --diff mode
------------------
# part 2
-add -a(--all) to strip all (even shebang & preserved) and remove type annotations too
-change scriot default run behaviour -> just remove inline comments, and add -c to  removes  comments and -d to remove docstrings
-i wanna preserve commented codes that developers comment out in their source code, in case you encounter multiple commented out lines try parsing them as python code(after removing #) if matches, preserve them
-add any recommended functionality you suggest
