implement a python pkg that can consolidate a small to medium size python module(lib,pkg,project).
output modes

1. mode 1. ?single file): output/ (__init__.py,_consolidated.py -> (soryed : imports->const,classes,funcs))

constraints:

* use pathlib
* use tree-sitter for parsing code
* use parallel processing wherever possible
* log any errors with loguru
* skip adding any test file, __main__.py (even in subdirs), add main functions to end of s8ngle file created
* pay attension to claszes order, sone of them need to be defined before others
* resolve similar name of objects cross project dirs & optimize import section
* project name=refactor_utils, expose a cli entry point named pyrefactor
* export final clasdes,consts,functs to __init__.py and generate __all__