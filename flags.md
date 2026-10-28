## Features / flags to add

- `--dry-run` / `--print` — emit to stdout, write nothing
- `--check` — exit non-zero if generated file wouldn't import (currently only `compile()`, no import smoke test)
- `--report json|md` — emit rename map (module.name → final name) + skipped/warnings; helps auditing large refactors
- `--format {black,ruff,none}` — optional post-format of generated files (the writer's spacing is hand-tuned; let a formatter win)
- `--module-name NAME` — override the hardcoded `_consolidated` module name
- `--config pyproject.toml` — read defaults (exclude, entry, mode) from `[tool.pyrefactor]`
- `--no-dedupe` / `--dedupe-names-only` — control the aggressive "identical block" dedupe
- `--keep-guards` / `--drop-guards` — decide whether `try/except ImportError` guards survive
- `--keep-all-mains` — inverse of `--entry` (currently every non-entry `__main__` is dropped silently)
- `--include GLOB` — symmetric to `--exclude` (work on a subtree only)
- `--target-version 3.9` — stdlib detection uses the *running* interpreter's `stdlib_module_names`; wrong for cross-version consolidation
- `--line-length N` — currently hardcoded `_LINE = 88`
- `--no-verify` — skip the compile check for huge codebases
- `--fail-on-warnings` — `--strict` only counts skipped files, not warnings
- `--emit-map FILE` — CSV/JSON of `(module, name) -> final_name` for manual `import` fixups
- `--follow-symlinks` and `--respect-gitignore` (current exclusion is a fixed dir list)

## Edge cases missing

**Scope/shadowing (likely real bugs):**
- Loop vars, `with … as x`, `except E as e`, comprehension targets, walrus, `match` captures are **not** added to the `shadow` set → identifiers inside those bodies can be wrongly renamed
- `global x` / `nonlocal x` statements: the identifier node gets rewritten, producing invalid code
- PEP 695 `def f[T]()` type params not shadowed
- Class-body `__slots__`, `Enum` member strings, `typing.Literal["name"]` strings — renames don't touch string contents (usually right, occasionally wrong)
- `__all__.append(...)` / `__all__ += [...]` only partially handled; `__all__` set via helper function is lost
- Module-level `__getattr__` (PEP 562), `sys.modules[...]`, `importlib.import_module("x")` — invisible to the analyzer

**Import semantics:**
- Lazy/function-local imports of *internal* modules are silently dropped; the whole point was to break a cycle → generated file may now raise `ImportError` at import time
- `try: import a\nexcept ImportError: import b` fallbacks are emitted as verbatim guard text but their names aren't in `env`, so usages later stay unresolved (only a warning)
- `if TYPE_CHECKING:` imports get merged unconditionally; without `from __future__ import annotations` this can introduce runtime imports/costs, and there's no warning
- Star-import from an internal module whose names later collide is not deduped/renamed properly (star locals aren't in `group`)

**Discovery / paths:**
- Two `foo.py` under different dirs → same dotted name → dict collision, silent loss
- `src/` layout with multiple top-level packages → `detect_base` returns `src`, losing the package prefix (relative imports then resolve wrong)
- Namespace packages (no `__init__.py`) → `detect_base` guesses wrong
- Same module name as a real third-party module → `_is_internal` decides via `self.tops`, which can misroute
- `--exclude GLOB` matches `entry.as_posix()` with `fnmatch` (so `*` spans `/`) — surprising for `*.py` style patterns
- Windows backslashes in module path derivation
- Output dir == source dir, or output inside a package that's also discovered

**Parsing / input:**
- Non-UTF-8 (latin-1) source: `read_bytes()` + `decode(..., "replace")` corrupts; no PEP 263 `# -*- coding: -*-` handling
- CRLF sources: `_extent`/indent logic assumes `\n`
- Syntax error in one file → its importers silently lose symbols (warns but keeps going); `--strict` doesn't catch it since the importer parsed fine
- Empty file, docstring-only file, `# comment` only
- Top-level `del`, `assert`, `raise`, `yield` (illegal), `pass` — `pass_statement` is dropped but bare `...` in a suite becomes MISC

**Output / determinism:**
- `ext_final` naming depends on set iteration for aliases in some paths; `--keep-unused-imports` unions sets → verify determinism across runs
- Generated `__init__.py` overwrites any existing one in `output/` without backup
- Re-running on the already-consolidated `output/` — idempotency isn't guaranteed (source discovery excludes it, but `--output` elsewhere isn't)
- `mains` merged only if multiple; a *non-entry* module's `if __name__ == "__main__"` is silently dropped when `--entry` is set — no warning
- `_wrap` ignores `_LINE` when items contain `*` or when a single long item exceeds the limit
- `__file__` warning is emitted, but `__path__`, `os.path.dirname(__file__)`, `pkgutil` — not
- Output on compile failure: code logs the error but still writes the broken file (write happens unconditionally after the compile loop)