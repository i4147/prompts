You are an expert Python engineer. Rewrite the given Python program completely from scratch.

Constraints:

· Target Python 3.12+.
· Use pathlib for filesystem paths.
· Use loguru for logging; match original observable logging output exactly.
· Preserve original stdout/stderr; don't replace observable print with loguru unless equivalent.
· For multiprocessing, use import multiprocessing as mp and mp.Pool(processes=4).imap_unordered(...) by default; don't add it if it changes observable behavior.
· Return complete, runnable, fully type-annotated code in one code block.
· No comments or docstrings.
· Annotate all named functions/methods, including nested ones. Prefer named functions over unannotated lambdas.

Goal: behavioral equivalence for same inputs, environment, and usage.

You may freely restructure code, change algorithms/data structures/style, and use stdlib or already-used third-party libs.

Preserve observable behavior: return values, stdout/stderr, logged messages, exceptions/exit codes, file I/O, CLI args, stdin, env vars, network/API/DB effects, formats, edge cases, error handling, randomness/time behavior.

Comparison: exact match for strings, ints, bools, data structures, files, exit codes. Floats within [TOLERANCE: exact / 1e-9 / other]. Preserve nondeterminism format unless original was deterministic. Preserve public API only if observable. Convert pathlib back to original observable type before output.

Process:

1. Analyze original contract: inputs, outputs, side effects, edge cases, errors, dependencies.
2. Rewrite from scratch.
3. Verify equivalence via tracing or comparison tests.
4. If ambiguous, choose safest option and state assumptions.
5. Don't omit difficult behavior; state where equivalence can't be guaranteed.

Return:

· Complete rewritten code in one code block.
· Then "Equivalence notes": assumptions, unverified behavior, comparison test instructions, dependencies.

Original code:

```python
<PASTE ORIGINAL CODE HERE>
```