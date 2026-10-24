write a python script that can do the following
Task. Refactor the small multi-file Python package provided at the end of this prompt into a single-file Python module, applying all of the following changes.
Perform the steps in the order listed.
Target environment: Python 3.12 on Linux(termux). Python 2.7 support will never be needed again.
Applicability. This prompt is written for small-to-medium Python packages consisting of a handful of modules, an optional __main__.py CLI, and a few subpackages 
  — i.e. the typical "one package, several files, some nested folders" layout. Adapt names and paths as needed for the specific package you are given.
---
1. Consolidate into a single file
     Merge every module of the package — the top-level __init__.py, __main__.py, and all sibling modules and subpackages (e.g. base.py, utils.py, decorators.py, mixins.py, load.py, downloader.py, and directories like subpkg/, each containing their own __init__.py and implementation modules) — into one Python module, preserving all public names and behavior. Remove relative imports (from .x import y, from ..x import y). Keep the public API surface unchanged and expose it via __all__. Fix any clear runtime bugs you encounter along the way.
   1.1 resolve functions/classes/constants with same name in contents of source files
   1.2 optimize imports (gather imports from all inputs, and optimize them)
   1.3 resolve imports (drop local imports,sort std lib,3rdparty and dedup them)
   1.4 respect dependency hirarchy,
      if a fuctions needs a class, that claas should be declared before functions, same for constants
   1.5 final structure of single file output should be in this order:
        1. import section (as mentioned above)
        2. constant section (gather all constant defs from all inputs,dedup,desolve names,sort by name)
        3. classes: all classes gatheres from source files( deduped, names resolved, sorted)
        4. functions: all funcs gathered from input sources(deduped(use hash_contents), names resolved, sorted), skip functions with name 'main'
2. Drop Python 2 compatibility
Remove six and everything that exists only to bridge Py2/Py3:
· from __future__ import ... statements.
· unicode → str, basestring → (str, bytes), string_types → str, binary_type → bytes.
· xrange → range; iteritems(d) → d.items(); iterkeys(d) → d.keys(); itervalues(d) → d.values(); unicode(x, "utf-8") → x.decode("utf-8").
· six.moves.* shims (six.moves.copyreg, six.moves.urllib, six.moves.http_client, six.moves.cPickle, six.moves.input, six.moves.zip, six.moves.map, six.moves.range) → native stdlib equivalents (copyreg, urllib, http.client, pickle, input, zip, map, range).
· Any copyreg.pickle(types.MethodType, ...) registration plus its _pickle_method / _unpickle_method helpers (Py3 pickles bound methods natively).
· implements_to_string, __unicode__ methods (fold into __str__), __getslice__ implementations (Py3 uses __getitem__ with slices).
· object base classes are fine to keep, but do not add Py2-style super(Cls, self) calls — use bare super().
3. Migrate os.path to pathlib
Use pathlib.Path everywhere it is reasonable: Path.suffix, Path.stem, Path.name, Path.parent, Path.expanduser(), Path.resolve(), the / operator for joins, Path.exists(), Path.is_dir(), Path.is_file(), Path.mkdir(), Path.mkdir(parents=True), Path.unlink(), Path.stat(), Path.rglob(), Path.iterdir(). Use Path.open(...) where it reads more naturally than open(str(p), ...). Keep string-based URLs (e.g. "http://..." + "/index.json" or f"{base}/{name}") as plain strings so they are not mangled by Path's filesystem semantics.
4. Parallelism via mp.Pool.imap_unordered
Replace concurrent.futures.ProcessPoolExecutor (or any other parallel executor) mp.Pool.imap_unordered, using a fixed module-level constant WORKERS: int = 6. Remove any --workers / -w CLI argument and any corresponding workers=... keyword parameters from public functions. Wherever parallelism is applicable in the codebase, always use 6 workers. Wrap pool usage in try/finally (or a with block) so the pool is closed and joined deterministically. Ensure any function passed to imap_unordered is a picklable top-level function.
5. Replace standard logging with loguru
Swap the logging module for loguru. Import with from loguru import logger. Convert CLI/entry-point setup to logger.remove() followed by logger.add(sys.stderr, level=..., format=...). Rewrite the old LOGFORMAT string in loguru style, e.g. "{time:YYYY-MM-DD HH:mm:ss.SSS} {level} {file.name}:{line} {message}". Existing logger.info(...), logger.warning(...), logger.debug(...), logger.error(...) call sites work unchanged with loguru (both %s-style .format()-applied strings and {} placeholders are accepted).
6. Output format
Return the full annotated code 
7. commnts and docstrings: should be stripped.
just module docstring needed: module docstring should be a prompt provided for an ai chatbot or agent that leads to creating the entire code
input: source code of project files with exact location of each .py file in pkg tree 
add -f cli arg to read project source files from a merged file with following structure
# File: relpath of file1.py
  <multiline source code of file1.py>
# File: relpath of file2.py
  <multiline source code of file2.py>
example : python script.py -f sffrfgrdgyrew.py
if no input is provided, asume current dir is project dir (recursive)
ezample python script.py    --> should process '.'
output: single file .py file(use out.py, if not exists, else rename properly and inform)  with requested properties
   add -o to specify output file
   example python script.py -o mypkg.py
