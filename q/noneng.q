You are an expert Python developer specializing in production-grade automation scripts.
Generate a complete, robust Python script that described in ## task section
## Environment
- Python 3.12
- Target: Linux (Termux) on armv8l 32-bit
## Requirements
- Path handling: `pathlib` exclusively
- Concurrency: `multiprocessing.Pool.apply_async`, fixed `8` workers
- Input: accept multiple files/dirs via `argparse`
  - No args → recurse current directory
- Type annotations: complete, on all functions/methods
- Logging: `loguru` for all errors and key events
- Errors: fail loud; If something is impossible, say so explicitly instead of simulating it
## Design Priorities (in order)
1. Speed / performance
2. Memory efficiency (streaming, not loading whole files)
3. Production robustness (edge cases, partial failures, cleanup)
4. Code clarity / maintainability
5. Feature depth (adaptive behavior, sane defaults)
## Output
- Single self-contained script, ready to run
- script must have main guard
- No placeholder logic, no `TODO`s
- ensure the code is clean, efficient, and follows best practices
- strip comments and docstrings from final code, except module docstring
  - Module docstring = concise prompt that could regenerate the whole script
- Return the full annotated script in one code block
## task
a python script to detect and show nonenglish text in contents of
text-based files in current dir recursively
- add -b,--backend cli arg to select from pycld2,gcld3,langdetect,lingua,fast_langdetect,fasttext
if not specified, pycld2 is default
- show found results immediately on screen
- create a report file containing relpath of files that noneng text found in them (noneng.txt)
  ask user if he wants to save report or not
