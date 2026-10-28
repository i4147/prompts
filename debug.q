You are an expert Python engineer and performance engineer. I will give you an original Python program. Your job is to debug it and optimize it.
Constant constraints:
- Target Python 3.12+.
- Use pathlib for all filesystem path handling.
- Use loguru for logging. If the original program’s logging output is observable, configure loguru so the observable output matches the original exactly.
- Preserve original observable stdout/stderr. Do not replace observable print output with loguru unless the output remains equivalent.
- When multiprocessing is used, use `import multiprocessing as mp` and `mp.Pool(processes=4).imap_unordered(...)` by default. If order is observable, reorder results to match the original or use a method that preserves order.
- Return complete, runnable, fully type-annotated Python code in one code block.
- The code block must contain no comments and no docstrings.
- Every named function and method, including nested functions, must have full parameter and return type annotations. Prefer named functions over unannotated lambdas.
Primary goal:
Fix all real bugs and optimize the program’s performance, memory usage, and reliability while preserving the intended observable behavior. The original behavior is the reference for correct inputs unless I provide a spec that says otherwise. Do not change observable results except where the original is clearly buggy relative to the spec or where I explicitly allow behavior changes.
Inputs:
- Original code: see below (end of prompt)
- Spec / expected behavior: <PASTE SPEC OR "None">
- Known bugs / failing cases: <PASTE OR "None">
- Performance goals: <PASTE GOALS OR "None">
- Allowed dependencies: <PASTE ALLOWED LIBS OR "Only those already used">
- Environment: <PASTE ENV DETAILS>
- Allowed behavior changes: <PASTE OR "None">
- Floating-point tolerance: <exact / 1e-9 / other>
You may freely:
- add, remove, rename, merge, or split functions/classes/modules
- change algorithms, data structures, control flow, style, and organization
- use the Python standard library
- use third-party libraries only if the original already uses them, or if I explicitly allow it above
You must preserve observable behavior, including:
- return values
- stdout/stderr output
- printed/logged messages
- exceptions raised and exit codes
- files read/written/modified and their contents
- CLI arguments, stdin behavior, environment variables
- network/API/database side effects
- input/output formats
- edge cases and error handling
- randomness/time behavior if the original depends on it
Comparison rule for “same enough”:
- Exact match is required for strings, integers, booleans, data structures, files, and exit codes.
- Floating-point output must match within the tolerance above.
- If the original is nondeterministic, preserve the same format and behavior, or make determinism explicit only if the original did.
- If the code is meant to be imported as a library, preserve the public API only if that is part of the observable behavior. Otherwise, internal APIs may change freely.
- If pathlib changes an observable type, convert back to the original observable type before returning, printing, or writing.
Debugging process:
1. Read the code and identify the intended contract: inputs, outputs, side effects, edge cases, errors, dependencies.
2. Reproduce or reason about each known bug and any additional bugs you find.
3. For each bug, explain the root cause and the fix.
4. Add or run focused tests for correct inputs, edge cases, and error cases.
5. Do not silently change behavior. If a fix changes observable output, document the before/after and why the new behavior is correct.
6. If no spec is provided, treat original observable behavior as the spec except for crashes, exceptions, resource leaks, race conditions, or clear logic errors that prevent intended operation.
Optimization process:
1. Profile or reason about time, memory, I/O, and concurrency bottlenecks.
2. Optimize the highest-impact areas first.
3. Prefer algorithmic improvements over micro-optimizations.
4. Use multiprocessing only when it is safe and beneficial. Preserve output order if order is observable.
5. Do not trade correctness for speed.
6. If you cannot verify an optimization is safe, state that clearly.
Return format:
- First, provide the complete debugged and optimized Python code in one code block.
- Then provide a section called “Bug fixes” with a list of bugs, root causes, fixes, and any behavior changes.
- Then provide a section called “Optimizations” with what changed and why.
- Then provide a section called “Verification” with tests, how to run them, and expected results.
- Then provide a section called “Benchmarks” with before/after measurements if possible, or why not possible.
- Then provide a section called “Assumptions and limitations” with anything ambiguous or unverified.
Original code:
```python
