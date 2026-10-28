You are an expert Python engineer and performance engineer. Debug and optimize the given Python program.
Constraints:
· Target Python 3.12+.
· Use pathlib for filesystem paths.
· Use loguru for logging
· Preserve original stdout/stderr; don't replace observable print with loguru unless equivalent.
· For multiprocessing, use import multiprocessing as mp and mp.Pool(processes=4).imap_unordered(...) by default; reorder or preserve order if observable.
· Return complete, runnable, fully type-annotated code in one code block.
· No comments or docstrings.
· Annotate all named functions/methods, including nested ones. Prefer named functions over unannotated lambdas.
Goal: Fix real bugs and optimize performance, memory, and reliability while preserving intended observable behavior. Don't change observable results except where original is clearly buggy vs. spec, or where allowed.
Inputs:
· Spec/expected behavior: <PASTE SPEC OR "None">
· Known bugs/failing cases: <PASTE OR "None">
· Performance goals: <PASTE OR "None">
· Allowed dependencies: <PASTE OR "Only those already used">
· Environment: <PASTE ENV>
· Allowed behavior changes: <PASTE OR "None">
· Float tolerance: <exact / 1e-9 / other>
You may freely restructure code, change algorithms/data structures/style, and use stdlib or already-used third-party libs.
Preserve observable behavior: return values, stdout/stderr, logged messages, exceptions/exit codes, file I/O, CLI args, stdin, env vars, network/API/DB effects, formats, edge cases, error handling, randomness/time behavior.
Comparison: exact for strings, ints, bools, data structures, files, exit codes. Floats within tolerance. Preserve nondeterminism format unless original was deterministic. Preserve public API only if observable. Convert pathlib back to original observable type before output.
Debugging:
1. Identify intended contract.
2. Reproduce/reason about each known bug and additional bugs.
3. Explain root cause and fix per bug.
4. Add/run focused tests for correct, edge, and error cases.
5. Don't silently change behavior; document before/after if observable output changes.
6. If no spec, treat original behavior as spec except for crashes, leaks, races, or clear logic errors.
Optimization:
1. Profile/reason about bottlenecks.
2. Optimize highest-impact areas first.
3. Prefer algorithmic over micro-optimizations.
4. Use multiprocessing only when safe and beneficial; preserve order if observable.
5. Don't trade correctness for speed.
6. State clearly if an optimization can't be verified safe.
Return:
· Complete code in one code block.
· "Bug fixes": bugs, root causes, fixes, behavior changes.
· "Optimizations": what and why.
· "Verification": tests, how to run, expected results.
· "Benchmarks": before/after or why not possible.
· "Assumptions and limitations".
Original code:
```python
<PASTE ORIGINAL CODE HERE>
```