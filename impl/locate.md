Act as a principal systems engineer and core Python developer. I want you to rewrite the classic Linux utilities "[locate] (and its companion helper "[Iupdatedb]") from scratch in modern Python.

Your design constraints are strict: prioritize fast I/O throughput, low memory overhead, and minimal dependency overhead. 

Please follow these exact structural guidelines:

### 1. Hard Technical Constraints
* Target Runtime: Python 3.11+ (Leverage modern features like advanced typing, `pathlib`, and `asyncio` or `concurrent.futures` where applicable).
* ABSOLUTE PROHIBITION: You are strictly forbidden from calling external system binaries. Do NOT use `subprocess`, `os.system`, `os.popen`, or any execution wrappers. Every single feature must be implemented natively in Python code.
* Dependency Philosophy: Use the Python Standard Library exclusively. External dependencies are only allowed if absolutely mandatory for specialized, non-standard compression or file locks.

### 2. Reference & Standard Specification
* Base your implementation strictly on the behavior and core flags of the standard Linux [locate] utility. 
* At the very beginning of your response, explicitly state the exact version or release specification of the tool you are using as your reference design (e.g., "Based on GNU findutils version 4.10.0" or "Based on mlocate 0.26").

### 3. Required Project Structure & Packaging
Provide a production-ready, multi-file structure. You must provide the code for the following exact file layout:

* `pyproject.toml`: A modern packaging configuration utilizing the standard `setuptools` build backend. It must explicitly declare two installable CLI entry points mapping to your binary modules, allowing the user to run `[locate]` and `[Iupdatedb]` globally from their terminal.
* `src/[locate]/__init__.py`: Simple package initialization.
* `src/[locate:]/core.py`: The shared underlying engine, database parser, byte-serialization logic, or filesystem scanning logic. 
* `src/[locate]/cli_lookup.py`: The implementation for `[locate]`. Must parse arguments cleanly using `argparse`.
* `src/[locate]/cli_indexer.py`: The implementation for `[Iupdatedb]`. Must leverage multi-threading or highly optimized generator pipelines for lightning-fast performance.

### 4. Implementation Details
* Ensure proper POSIX exit codes are returned on failure or success.
* Maintain strict type hinting throughout the entire codebase (`from typing import...`).
* Use robust exception handling rather than raw crashes to gracefully handle permission errors when scanning system directories.

Provide the full, production-ready source code files wrapped in clean markdown blocks. No placeholders, no pseudocode.
