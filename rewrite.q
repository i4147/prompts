You are an expert Python engineer. I will give you an original Python program. Rewrite it completely from scratch.

Primary goal:
The rewritten program must be behaviorally equivalent to the original: for the same inputs, environment, and usage, it must produce the same observable results. Internal structure does not matter.

You may freely:
- add, remove, rename, merge, or split functions/classes/modules
- change algorithms, data structures, control flow, style, and organization
- use the Python standard library
- use third-party libraries only if the original already uses them, or if I explicitly allow it below

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
- Floating-point output must match within: [TOLERANCE: exact / 1e-9 / other]
- If the original is nondeterministic, preserve the same format and behavior, or make determinism explicit only if the original did.
- If the code is meant to be imported as a library, preserve the public API only if that is part of the observable behavior. Otherwise, internal APIs may change freely.

Process:
1. Analyze the original code’s contract: inputs, outputs, side effects, edge cases, errors, and dependencies.
2. Rewrite it from scratch. Do not just lightly refactor it.
3. Verify equivalence by tracing or writing small comparison tests for representative inputs, edge cases, and error cases.
4. If anything is ambiguous, choose the safest option that preserves original behavior, and state the assumption.
5. Do not silently omit difficult behavior. If you cannot guarantee equivalence in some area, say exactly where and why.

Return format:
- First, provide the complete rewritten Python code in one code block.
- Then provide a short section called “Equivalence notes” with:
  - assumptions made
  - any behavior that could not be fully verified
  - how to run a comparison test against the original
  - any required dependencies

The only observable output I care
 about is stdout/stderr and the 
 process exit code. Internal
  functions, classes, and imports
   may change completely.

Original code:
