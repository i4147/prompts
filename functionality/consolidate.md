1. Output correctness & verification
· Round-trip validation: after writing the output, actually importlib.util.spec_from_file_location the merged module in a subprocess to confirm it loads without runtime errors (currently only ast.parse is checked).
· py_compile / mypy smoke test: optionally run mypy --follow-imports=skip or py_compile as a post-step, failing loudly if the merged file has type/syntax issues beyond the initial parse.
· Public API diff: compare __all__ / exported names of the original package (via importlib) against the merged module, and report anything missing.
· Source map: emit a .map (JSON: merged line → original file:line) so tracebacks can be rewritten. You already have all the info in ModuleInfo; you just need to track node.lineno before ast.unparse.

2. Faithfulness to source

· Comment / formatting preservation via libcst (or asttokens) instead of the ast.unparse round-trip. Currently all comments, blank-line grouping, and docstring style are lost.
· Module docstring handling: strip_docstrings drops everything; optionally keep the first module's docstring as the merged module's __doc__.
· __all__ merging: instead of dropping every __all__, union them (with renames applied) and emit a single one.
· TYPE_CHECKING blocks: is_import_block only matches the exact if TYPE_CHECKING: shape; extend to if TYPE_CHECKING or ... and if not TYPE_CHECKING, and reorder typing-only imports after the header.
· __main__.py promotion: if the package has a __main__.py, convert its body into the merged file's if __name__ == "__main__": guard (and warn if multiple main guards exist).
· PEP 562 __getattr__ / __dir__ at module level: detect and either merge or fail explicitly instead of silently producing wrong behavior.
· Multiple if __name__ == "__main__" blocks: currently all are kept (guards list), which is wrong — merge into one, or pick the one from __main__.py.

3. Robustness / diagnostics

· Circular import detection: build the local-import graph and produce a clear cycle message before rewriting names (currently cycles silently degrade to None resolution warnings).
· Dynamic import detection: flag importlib.import_module(...), __import__(...), exec, eval, and module-level getattr(sys.modules[...]) — these cannot be statically resolved and often break after merging.
· Name-collision report: emit a --report file (JSON/CSV) listing every rename, unresolved import, star import, and dropped construct.
· Source attribution comments: optional # from pkg/sub/mod.py:42 marker before each top-level node — invaluable for reviewing the merge.
· Fail-fast option (--strict): turn the existing logger.warning calls into errors so CI can catch them.
· Duplicate-definition detection: currently identical definitions are silently merged by name; report when two different definitions share a name and are being resolved by rename.

4. Usability

· Config file (.pymerge.toml) for WORKERS, header list, log format, transformer toggles, renamer strategy, etc.
· Dry-run mode (--dry-run): print the resolved rename table and module order without writing.
· Interactive rename resolution (--interactive): prompt when a rename is ambiguous instead of silently prefixing with the module name.
· Renamer strategies: prefix (current), suffix, hash8, numbered, interactive. Expose via --rename-strategy.
· Reverse mode (--split): given a single file + a manifest, emit the original package tree. Useful for round-tripping.
· Selective output: --only mod1,mod2 / --exclude tests,benchmarks to control which files participate.
· Progress bar for large packages (tqdm or loguru's logger.info("... {}/{}", i, n)).
· Watch mode (--watch): re-run on file changes, ideal during iterative refactors.

5. Transformer coverage

· pathlib alternative for glob, os.walk, os.listdir, os.sep, os.linesep, os.getcwd — extend OsPathTransformer into a broader OsTransformer.
· typing modernization: Optional[X] → X | None, Dict/List/Tuple → dict/list/tuple, Text → str, from typing import ... cleanup.
· subprocess modernization: check_output → run(..., capture_output=True, check=True), etc.
· importlib.resources migration: pkg_resources.resource_* → importlib.resources.files(...).
· unittest → pytest is probably out of scope, but unittest.TestCase detection could at least warn.
· argparse subcommand extraction — optional, but you already inject a WORKERS global; consider exposing it via --workers N in the merged __main__.
· open() default encoding: open(p, "r") without encoding= could be rewritten to add encoding="utf-8" (matches the utf-8 read/write you already use).

6. Performance / engineering

· Parallel parsing with the WORKERS constant you define — currently load_directory parses serially.
· AST cache keyed by (path, mtime, size) under .pymerge_cache/.
· Incremental mode: only re-run when a source file changed since the last merge (compare hashes).
· Deterministic output: currently unique_nodes uses ast.dump orderings and order_by_dependencies uses a set — sort explicitly to guarantee byte-identical output across runs.
· Plugin API: a Transformer protocol plus --plugin mymod:MyTransformer so users can add their own rewrites without forking.

7. Reporting

· Statistics: number of files, top-level defs, LOC before/after, bytes, elapsed time (some already logged).
· HTML/Markdown report: a small self-contained summary of renames, unresolved names, and warnings.
· JSON schema for the report so CI can assert on it.

