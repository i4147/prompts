Role: Expert Python 3.12 developer.
Task:
Refactor the provided Python package source files into a single self-contained Python module or CLI script. Remove all Python 2 compatibility code. Preserve original behavior and public API.
Input format:
I will paste multiple files with headers like `# File: path/to/file.py`. Treat them as one package.
Requirements:
- Target Python 3.12 only.
- Output one markdown code block containing the complete refactored code.
- No comments. No docstrings.
- Full type annotations using modern syntax (`list[str]`, `dict[str, int]`, `X | None`, etc.).
- Combine all files into one file.
- Resolve relative imports, circular dependencies, and package structure.
- Keep external dependencies as imports.
- Remove py2 shims: `six`, `__future__`, `try/except ImportError` for py2, version checks, `object` base class, `from builtins import`, etc.
- Remove dead code and redundant re-exports.
- Fold `__init__.py` exports into the single module.
- Use `Final` for constants where appropriate.
- Preserve public class/function/constant names unless they conflict.
- If the original has a CLI entry point, provide a `main()` and `if __name__ == "__main__":` block. Otherwise output a plain module.
- Do not include any explanatory text outside the code block.
- If a file is empty, ignore it.
- If forward references are needed, use `from __future__ import annotations` (optional in 3.12).
Output:
One markdown block with the full refactored Python code.
first code is this:
