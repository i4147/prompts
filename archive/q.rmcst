You are an expert python developer.
generate a complete robust python
script to strip comments and docstring from python files using libcst
- make libcst optional by adding -b,--backend cli arg, other options are tree-sitter and ast
- add support for python files without extension
- preserve shebang, module docstring and # type and # fmt
- if docstring is the only node in a function/class body
  replace it with pass -> to avoid syntax error
- validate result code before writing to file
  result code should be a valid python code
- python version=3.14
- Path handling: with pathlib
- for concurrency use mp.pool.apply_async with fixed 8 workers
- the script should accept multiple files/dirs as input
  (if no input is provided, the script should process files in current dir recursively)
- consider following factors in implementation:
    Speed / performance
    Code clarity / maintainability
    Memory efficiency
    Production-ready robustness
    Feature set (streaming, adaptive, edge cases)
- Loggin: log any errors with loguru
- script default behavior: in normal run it only removes inline comments, 
  with -c,--comments it removes all comments except shebangs and #type, # fmt
  with -d,--docstring it removes all docstrings except module docstring
  wirh -a,all it removes all comments and docstrings,even preserved shebang and module docstring and #type,# fmt
  with -t,--type it removes type annotations
Return the full annotated code
