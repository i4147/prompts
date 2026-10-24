from __future__ import annotations
import argparse
import ast
import contextlib
import difflib
import functools
import io
import multiprocessing as mp
import os
import queue
import re
import signal
import stat
import sys
import tempfile
import threading
import time
import tokenize
import traceback
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import TypeVar
if sys.version_info < (3, 10):
    sys.stderr.write(
        "error: strip_python_comments requires Python 3.10 or newer, found "
        f"{sys.version_info.major}.{sys.version_info.minor}\n"
    )
    raise SystemExit(2)
try:
    import libcst as cst
except ModuleNotFoundError as exc:
    sys.stderr.write("error: libcst is required (pip install libcst loguru)\n")
    raise SystemExit(2) from exc
try:
    from loguru import logger
except ModuleNotFoundError as exc:
    sys.stderr.write("error: loguru is required (pip install loguru)\n")
    raise SystemExit(2) from exc
__all__ = [
    "FileReport",
    "FileStatus",
    "JobOptions",
    "RunStats",
    "main",
    "process_file",
    "run",
]
__version__ = "1.0.0"
TARGET_PYTHON_VERSION = "3.12"
DEFAULT_WORKERS = 8
IN_FLIGHT_PER_WORKER = 16
DEFAULT_MAX_FILE_SIZE = 8 * 1024 * 1024
_PROBE_BYTES = 2048
_PYTHON_SUFFIXES = frozenset({".py", ".pyi", ".pyw", ".pyx"})
_SKIPPED_DIR_NAMES = frozenset({
    "__pycache__",
    ".git",
    ".hg",
    ".svn",
    ".mypy_cache",
    ".pytest_cache",
    ".ruff_cache",
    ".tox",
    ".nox",
    ".eggs",
    ".venv",
    "venv",
    "node_modules",
    "build",
    "dist",
    "site-packages",
})
_NON_PYTHON_FILE_NAMES = frozenset({
    "makefile",
    "dockerfile",
    "license",
    "licence",
    "notice",
    "readme",
    "authors",
    "changelog",
    "contributing",
    "codeowners",
    "manifest",
    "requirements",
})
_PROTECTED_COMMENT_RE = re.compile(
    r"""
    ^\#\s*(?:
        type\b | pyright\b | mypy\b | pyre\b | ruff\b |
        noqa\b | nosec\b | pragma\b |
        fmt\b | yapf\b | isort\b | autopep8\b | black\b |
        pylint\b | flake8\b |
        ! | %%
    )
    | coding[:=]\s*[-_.a-zA-Z0-9]+          # PEP 263 cookie (incl. -*- coding: ... -*-)
    | fileencoding[:=]\s*[-_.a-zA-Z0-9]+    # Vim modeline
    """,
    re.IGNORECASE | re.VERBOSE,
)
_QUOTE_RE = re.compile(r"""['"]""")
_UNEXTENDED_SHEBANG_RE = re.compile(rb"^#![^\n]*\bpython[0-9.]*\b", re.IGNORECASE)
_UNEXTENDED_COOKIE_RE = re.compile(rb"^#.*coding[:=]", re.IGNORECASE)
_UNEXTENDED_CODE_RE = re.compile(
    rb"^(?:"
    rb"from\s+[\w.]+\s+import\b"
    rb"|import\s+[\w.]"
    rb"|def\s+\w+\s*\("
    rb"|class\s+\w+[:(\[]"
    rb"|async\s+def\s+\w+\s*\("
    rb"|if\s+__name__\s*=="
    rb"|@\w"
    rb"|__\w+__\s*[:=]"
    rb")"
)
_TMP_SUFFIX = ".strip-tmp"
_POLL_INTERVAL = 0.05
_LOG_FORMAT = "{time:HH:mm:ss.SSS} <level>{level: <8}</level> {message}"
_INTERRUPTED = threading.Event()
_CSTDefinition = TypeVar("_CSTDefinition", cst.FunctionDef, cst.ClassDef)
class FileStatus(str, Enum):
    STRIPPED = "stripped"
    """Comments/docstrings were (or would be) removed."""
    UNCHANGED = "unchanged"
    """Nothing needed removing."""
    SKIPPED = "skipped"
    """File was ignored (too large, vanished, not parseable as Python)."""
    ERROR = "error"
    """Processing failed; the file was left untouched."""
@dataclass(frozen=True, slots=True)
class JobOptions:
    strip_comments = True
    strip_docstrings = True
    apply_changes = True
    keep_backup = False
    atomic_write = True
    fsync = False
    preserve_mtime = False
    structural_check = True
    diff = False
    max_file_size = DEFAULT_MAX_FILE_SIZE
    python_version = TARGET_PYTHON_VERSION
@dataclass(slots=True)
class FileReport:
    comments_removed = 0
    docstrings_removed = 0
    size_before = 0
    size_after = 0
    duration_s = 0.0
    message = ""
    traceback_text = ""
    diff = ""
    @property
    def changed(self):
        return self.status is FileStatus.STRIPPED
@dataclass(slots=True)
class RunStats:
    files_seen = 0
    stripped = 0
    unchanged = 0
    skipped = 0
    errors = 0
    comments_removed = 0
    docstrings_removed = 0
    bytes_before = 0
    bytes_after = 0
    elapsed_s = 0.0
    interrupted = False
    def merge(self, report):
        self.files_seen += 1
        if report.status is FileStatus.STRIPPED:
            self.stripped += 1
        elif report.status is FileStatus.UNCHANGED:
            self.unchanged += 1
        elif report.status is FileStatus.SKIPPED:
            self.skipped += 1
        else:
            self.errors += 1
        self.comments_removed += report.comments_removed
        self.docstrings_removed += report.docstrings_removed
        self.bytes_before += report.size_before
        self.bytes_after += report.size_after
@dataclass(slots=True)
class _SourceFile:
    pass
@dataclass(slots=True)
class _CleanResult:
    pass
class OutputValidationError(RuntimeError):
    pass
class _FileTooLargeError(Exception):
    pass
def configure_logging(*, verbose=False, quiet=False):
    level = "DEBUG" if verbose else ("ERROR" if quiet else "INFO")
    is_tty = bool(getattr(sys.stderr, "isatty", lambda: False)())
    logger.remove()
    logger.add(
        sys.stderr,
        level=level,
        format=_LOG_FORMAT,
        colorize=is_tty,
        backtrace=False,
        diagnose=False,
        enqueue=False,
    )
@functools.lru_cache(maxsize=4)
def _parser_config(python_version):
    if python_version is None:
        return cst.PartialParserConfig()
    try:
        return cst.PartialParserConfig(python_version=python_version)
    except Exception as exc:
        logger.warning(
            "libcst cannot parse with python_version={!r} ({}); using the default grammar",
            python_version,
            exc,
        )
        return cst.PartialParserConfig()
def _parse_module(text, python_version, source_name="<string>"):
    try:
        return cst.parse_module(text, config=_parser_config(python_version))
    except cst.ParserSyntaxError:
        if python_version is None:
            raise
        logger.warning(
            "{}: not valid Python {}; retrying with the interpreter grammar",
            source_name,
            python_version,
        )
        return cst.parse_module(text, config=_parser_config(None))
def _is_string_docstring(expression):
    if isinstance(expression, cst.SimpleString):
        return "b" not in expression.prefix.lower()
    if isinstance(expression, cst.ConcatenatedString):
        return all(
            isinstance(part, cst.SimpleString) and "b" not in part.prefix.lower()
            for part in (expression.left, expression.right)
        )
    return False
def _docstring_expression(statement):
    if not isinstance(statement, cst.SimpleStatementLine) or not statement.body:
        return None
    first = statement.body[0]
    if isinstance(first, cst.Expr) and _is_string_docstring(first.value):
        return first.value
    return None
def _docstring_line_to_pass(statement):
    if isinstance(statement, cst.SimpleStatementLine):
        return statement.with_changes(body=[cst.Pass()])
    return cst.SimpleStatementLine(body=[cst.Pass()])
def _merge_leading_lines(statement, extra_lines):
    if not extra_lines:
        return statement
    existing = getattr(statement, "leading_lines", ())
    return statement.with_changes(leading_lines=(*extra_lines, *existing))
def _clean_suite(suite):
    if isinstance(suite, cst.IndentedBlock):
        statements = list(suite.body)
        if not statements or _docstring_expression(statements[0]) is None:
            return suite, 0
        first_line = statements[0]
        if not isinstance(first_line, cst.SimpleStatementLine):
            return suite, 0
        small_statements = list(first_line.body)
        if len(small_statements) > 1:
            new_first = first_line.with_changes(body=tuple(small_statements[1:]))
            return suite.with_changes(body=[new_first, *statements[1:]]), 1
        if len(statements) > 1:
            following = _merge_leading_lines(statements[1], first_line.leading_lines)
            return suite.with_changes(body=[following, *statements[2:]]), 1
        return suite.with_changes(body=[_docstring_line_to_pass(first_line)]), 1
    if isinstance(suite, cst.SimpleStatementSuite):
        body = list(suite.body)
        if not body:
            return suite, 0
        head = body[0]
        if not (isinstance(head, cst.Expr) and _is_string_docstring(head.value)):
            return suite, 0
        if len(body) == 1:
            return suite.with_changes(body=[cst.Pass()]), 1
        return suite.with_changes(body=body[1:]), 1
    return suite, 0
class _CleanupTransformer(cst.CSTTransformer):
    __slots__ = (
        "_comments_removed",
        "_docstrings_removed",
        "_strip_comments",
        "_strip_docstrings",
    )
    def __init__(self, *, strip_comments, strip_docstrings):
        super().__init__()
        self._strip_comments = strip_comments
        self._strip_docstrings = strip_docstrings
        self._comments_removed = 0
        self._docstrings_removed = 0
    @property
    def comments_removed(self):
        return self._comments_removed
    @property
    def docstrings_removed(self):
        return self._docstrings_removed
    @property
    def removed_anything(self):
        return bool(self._comments_removed or self._docstrings_removed)
    def leave_Comment(self, _original_node, updated_node):
        if not self._strip_comments:
            return updated_node
        if _PROTECTED_COMMENT_RE.search(updated_node.value):
            return updated_node
        self._comments_removed += 1
        return cst.RemoveFromParent()
    def leave_EmptyLine(self, original_node, updated_node):
        if self._strip_comments and original_node.comment is not None and updated_node.comment is None:
            return cst.RemoveFromParent()
        return updated_node
    def leave_TrailingWhitespace(
        self,
        original_node,
        updated_node,
    ):
        if not (self._strip_comments and original_node.comment is not None and updated_node.comment is None):
            return updated_node
        whitespace = updated_node.whitespace
        if isinstance(whitespace, cst.SimpleWhitespace) and whitespace.value:
            return updated_node.with_changes(whitespace=cst.SimpleWhitespace(""))
        return updated_node
    def leave_FunctionDef(self, _original_node, updated_node):
        return _strip_body_docstring(updated_node, enabled=self._strip_docstrings, counter=self)
    def leave_ClassDef(self, _original_node, updated_node):
        return _strip_body_docstring(updated_node, enabled=self._strip_docstrings, counter=self)
    def count_removed_docstring(self):
        self._docstrings_removed += 1
def _strip_body_docstring(
    node,
    *,
    enabled,
    counter,
):
    if not enabled:
        return node
    body = node.body
    if not isinstance(body, (cst.IndentedBlock, cst.SimpleStatementSuite)):
        return node
    new_body, removed = _clean_suite(body)
    if not removed:
        return node
    counter.count_removed_docstring()
    return node.with_changes(body=new_body)
def _strip_source(text, options, source_name="<string>"):
    unchanged = _CleanResult(text, False, 0, 0)
    if not text:
        return unchanged
    strip_comments = options.strip_comments and "#" in text
    strip_docstrings = options.strip_docstrings and _QUOTE_RE.search(text) is not None
    if not strip_comments and not strip_docstrings:
        return unchanged
    module = _parse_module(text, options.python_version, source_name)
    transformer = _CleanupTransformer(strip_comments=strip_comments, strip_docstrings=strip_docstrings)
    new_module = module.visit(transformer)
    if not transformer.removed_anything:
        return unchanged
    new_text = new_module.code
    newline = new_module.default_newline
    if not module.has_trailing_newline and new_text.endswith(newline):
        new_text = new_text[: -len(newline)]
    elif module.has_trailing_newline and not new_text.endswith(newline):
        new_text += newline
    return _CleanResult(
        text=new_text,
        changed=new_text != text,
        comments_removed=transformer.comments_removed,
        docstrings_removed=transformer.docstrings_removed,
    )
def _ast_parse(text, *, target_version, type_comments):
    feature_version = None
    if target_version:
        major, _, minor = TARGET_PYTHON_VERSION.partition(".")
        feature_version = (int(major), int(minor))
    return ast.parse(text, type_comments=type_comments, feature_version=feature_version)
def _normalise_ast(tree):
    docstring_owners = (ast.Module, ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)
    for node in ast.walk(tree):
        body = getattr(node, "body", None)
        if not isinstance(body, list):
            continue
        if isinstance(node, docstring_owners) and body:
            first = body[0]
            if (
                isinstance(first, ast.Expr)
                and isinstance(first.value, ast.Constant)
                and isinstance(first.value.value, str)
            ):
                del body[0]
        body[:] = [statement for statement in body if not isinstance(statement, ast.Pass)]
    return ast.dump(tree, include_attributes=False, annotate_fields=True)
def _validate_output(new_text, original_text, *, structural_check):
    warnings = []
    try:
        _ast_parse(new_text, target_version=True, type_comments=True)
    except SyntaxError as exc:
        try:
            _ast_parse(original_text, target_version=True, type_comments=True)
        except SyntaxError:
            try:
                _ast_parse(new_text, target_version=False, type_comments=False)
            except SyntaxError as lenient_exc:
                raise OutputValidationError(f"transformed code is not valid Python: {lenient_exc}") from lenient_exc
            warnings.append(
                f"input already failed stricter validation; output checked leniently ({type(exc).__name__}: {exc})"
            )
        else:
            raise OutputValidationError(f"transformed code is not valid Python {TARGET_PYTHON_VERSION}: {exc}") from exc
    if structural_check:
        try:
            original_tree = _ast_parse(original_text, target_version=False, type_comments=False)
            new_tree = _ast_parse(new_text, target_version=False, type_comments=False)
        except SyntaxError:
            warnings.append("structural check skipped: source could not be parsed")
        else:
            if _normalise_ast(original_tree) != _normalise_ast(new_tree):
                raise OutputValidationError(
                    "structural check failed: the rewrite changed the program AST beyond comment/docstring removal"
                )
    return warnings
def _decode_source(raw):
    encoding, _lines = tokenize.detect_encoding(io.BytesIO(raw).readline)
    return raw.decode(encoding), encoding
def _read_source(path, max_size):
    file_stat = path.stat()
    if file_stat.st_size > max_size:
        raise _FileTooLargeError(f"{file_stat.st_size} bytes exceeds the {max_size} bytes limit")
    raw = path.read_bytes()
    text, encoding = _decode_source(raw)
    return _SourceFile(
        text=text,
        encoding=encoding,
        had_trailing_newline=text.endswith(("\n", "\r")),
        size_bytes=file_stat.st_size,
        mode=stat.S_IMODE(file_stat.st_mode),
        atime_ns=file_stat.st_atime_ns,
        mtime_ns=file_stat.st_mtime_ns,
    )
def _atomic_write(path, data, *, mode, fsync):
    directory = path.parent
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=_TMP_SUFFIX, dir=str(directory))
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
            if fsync:
                handle.flush()
                os.fsync(handle.fileno())
        tmp_path = Path(tmp_name)
        with contextlib.suppress(OSError):
            tmp_path.chmod(mode)
        tmp_path.replace(path)
    except BaseException:
        with contextlib.suppress(OSError):
            Path(tmp_name).unlink(missing_ok=True)
        raise
def _direct_write(path, data, *, fsync):
    with path.open("wb") as handle:
        handle.write(data)
        if fsync:
            handle.flush()
            os.fsync(handle.fileno())
def _write_source(
    path,
    text,
    source,
    options,
    original_bytes,
):
    data = text.encode(source.encoding)
    if options.keep_backup and original_bytes is not None:
        backup_path = path.with_name(path.name + ".bak")
        _direct_write(backup_path, original_bytes, fsync=False)
    if options.atomic_write:
        _atomic_write(path, data, mode=source.mode, fsync=options.fsync)
    else:
        _direct_write(path, data, fsync=options.fsync)
    if options.preserve_mtime:
        with contextlib.suppress(OSError):
            os.utime(path, ns=(source.atime_ns, source.mtime_ns), follow_symlinks=False)
def _unified_diff(path, before, after):
    diff_lines = difflib.unified_diff(
        before.splitlines(keepends=True),
        after.splitlines(keepends=True),
        fromfile=f"a/{path.name}",
        tofile=f"b/{path.name}",
        n=3,
    )
    return "".join(diff_lines)
def _is_extensionless_python(raw):
    head = raw[:_PROBE_BYTES]
    first_line = head.split(b"\n", 1)[0].strip()
    if _UNEXTENDED_SHEBANG_RE.match(first_line):
        return True
    if _UNEXTENDED_COOKIE_RE.match(first_line):
        return True
    for line in head.splitlines()[:10]:
        stripped = line.strip()
        if not stripped or stripped.startswith(b"#"):
            continue
        return bool(_UNEXTENDED_CODE_RE.match(stripped))
    return False
def _sniff_extensionless(path):
    try:
        with path.open("rb") as handle:
            head = handle.read(_PROBE_BYTES)
    except OSError as exc:
        logger.debug("cannot sniff {}: {}", path, exc)
        return False
    return _is_extensionless_python(head)
def iter_candidate_files(
    roots,
    *,
    include_extensionless=True,
    follow_symlinks=False,
    max_size=DEFAULT_MAX_FILE_SIZE,
):
    candidates = []
    oversized = []
    seen = set()
    def _register(path, *, explicit):
        key = os.path.normcase(os.path.abspath(path))
        if key in seen:
            return
        seen.add(key)
        if not explicit and path.suffix not in _PYTHON_SUFFIXES:
            if path.suffix or not include_extensionless:
                return
            if path.name.lower() in _NON_PYTHON_FILE_NAMES:
                return
            if not _sniff_extensionless(path):
                logger.debug("skipping extension-less non-Python file: {}", path)
                return
        try:
            size = path.stat().st_size
        except OSError as exc:
            logger.warning("cannot stat {}: {}", path, exc)
            return
        if size > max_size:
            oversized.append(path)
            return
        candidates.append(path)
    search_roots = list(roots) if roots else [Path.cwd()]
    for root in search_roots:
        if root.is_dir():
            for dirpath, dirnames, filenames in os.walk(root, topdown=True, followlinks=follow_symlinks):
                dirnames[:] = [
                    name
                    for name in dirnames
                    if not name.startswith(".") and name not in _SKIPPED_DIR_NAMES and not name.endswith(".egg-info")
                ]
                for filename in filenames:
                    _register(Path(dirpath, filename), explicit=False)
        elif root.is_file() or root.is_symlink():
            _register(root, explicit=True)
        else:
            logger.error("no such file or directory: {}", root)
    candidates.sort()
    oversized.sort()
    return candidates, oversized
def _worker_init():
    signal.signal(signal.SIGINT, signal.SIG_IGN)
def process_file(task):
    path_str, options = task
    path = Path(path_str)
    started = time.perf_counter()
    size_before = 0
    def _elapsed():
        return time.perf_counter() - started
    try:
        source = _read_source(path, options.max_file_size)
        size_before = source.size_bytes
        original_bytes = None
        if options.keep_backup:
            original_bytes = path.read_bytes()
        result = _strip_source(source.text, options, path_str)
        if not result.changed:
            logger.debug("unchanged: {}", path)
            return FileReport(
                path=path_str,
                status=FileStatus.UNCHANGED,
                size_before=size_before,
                size_after=size_before,
                duration_s=_elapsed(),
            )
        warnings = _validate_output(result.text, source.text, structural_check=options.structural_check)
        diff = ""
        if options.diff:
            diff = _unified_diff(path, source.text, result.text)
        if options.apply_changes:
            _write_source(path, result.text, source, options, original_bytes)
        size_after = len(result.text.encode(source.encoding))
        return FileReport(
            path=path_str,
            status=FileStatus.STRIPPED,
            comments_removed=result.comments_removed,
            docstrings_removed=result.docstrings_removed,
            size_before=size_before,
            size_after=size_after,
            duration_s=_elapsed(),
            message="; ".join(warnings),
            diff=diff,
        )
    except _FileTooLargeError as exc:
        return FileReport(
            path=path_str,
            status=FileStatus.SKIPPED,
            size_before=size_before,
            duration_s=_elapsed(),
            message=f"skipped: {exc} (see --max-file-size)",
        )
    except FileNotFoundError as exc:
        return FileReport(
            path=path_str,
            status=FileStatus.SKIPPED,
            size_before=size_before,
            duration_s=_elapsed(),
            message=f"skipped: vanished before processing ({exc})",
        )
    except SyntaxError as exc:
        return FileReport(
            path=path_str,
            status=FileStatus.ERROR,
            size_before=size_before,
            duration_s=_elapsed(),
            message=f"not a valid Python module: {type(exc).__name__}: {exc}",
            traceback_text=traceback.format_exc(),
        )
    except Exception as exc:
        return FileReport(
            path=path_str,
            status=FileStatus.ERROR,
            size_before=size_before,
            duration_s=_elapsed(),
            message=f"{type(exc).__name__}: {exc}",
            traceback_text=traceback.format_exc(),
        )
    except BaseException as exc:
        return FileReport(
            path=path_str,
            status=FileStatus.ERROR,
            size_before=size_before,
            duration_s=_elapsed(),
            message=f"{type(exc).__name__}: {exc}",
            traceback_text=traceback.format_exc(),
        )
class _Progress:
    def __init__(self, total, *, enabled):
        self._total = total
        self._enabled = bool(enabled) and total >= 16
        self._last_update = 0.0
    def update(self, done, stats, *, force=False):
        if not self._enabled:
            return
        now = time.monotonic()
        if not force and (now - self._last_update) < 0.2:
            return
        self._last_update = now
        line = (
            f"  {done}/{self._total} files | {stats.stripped} stripped"
            f" | {stats.unchanged} unchanged | {stats.errors} errors"
        )
        sys.stderr.write(f"\r\x1b[2K{line}")
        sys.stderr.flush()
    def close(self):
        if self._enabled:
            sys.stderr.write("\r\x1b[2K")
            sys.stderr.flush()
            self._enabled = False
def _render_summary(stats):
    saved = max(0, stats.bytes_before - stats.bytes_after)
    ratio = (saved / stats.bytes_before * 100.0) if stats.bytes_before else 0.0
    throughput = (stats.files_seen / stats.elapsed_s) if stats.elapsed_s > 0 else 0.0
    lines = [
        f"files    : {stats.files_seen} processed | {stats.stripped} stripped"
        f" | {stats.unchanged} unchanged | {stats.skipped} skipped | {stats.errors} errors",
        f"removed  : {stats.comments_removed} comments, {stats.docstrings_removed} docstrings",
        f"bytes    : {stats.bytes_before} -> {stats.bytes_after} (-{saved}, -{ratio:.1f}%)",
        f"duration : {stats.elapsed_s:.2f}s ({throughput:.0f} files/s)",
    ]
    if stats.interrupted:
        lines.append("run was interrupted: results above are partial")
    return "\n".join(lines)
def run(
    roots,
    *,
    options,
    workers=DEFAULT_WORKERS,
    include_extensionless=True,
    follow_symlinks=False,
    quiet=False,
    verbose=False,
):
    started = time.perf_counter()
    stats = RunStats()
    reports = []
    candidates, oversized = iter_candidate_files(
        roots,
        include_extensionless=include_extensionless,
        follow_symlinks=follow_symlinks,
        max_size=options.max_file_size,
    )
    for path in oversized:
        report = FileReport(
            path=str(path),
            status=FileStatus.SKIPPED,
            message="skipped: exceeds --max-file-size",
        )
        stats.merge(report)
        reports.append(report)
        logger.warning("skipping oversized file: {}", path)
    if not candidates:
        stats.elapsed_s = time.perf_counter() - started
        logger.info("no Python files found")
        return stats, reports
    workers = max(1, workers)
    logger.info(
        "processing {} file(s) with {} worker process(es) [comment={}, docstring={}, mode={}]",
        len(candidates),
        workers,
        "strip" if options.strip_comments else "keep",
        "strip" if options.strip_docstrings else "keep",
        "write" if options.apply_changes else ("diff" if options.diff else "check"),
    )
    results = queue.SimpleQueue()
    ready = threading.Event()
    def _collect(report):
        results.put(report)
        ready.set()
    total = len(candidates)
    budget = max(workers, workers * IN_FLIGHT_PER_WORKER)
    pending = iter(candidates)
    in_flight = 0
    completed = 0
    progress = _Progress(total, enabled=(not quiet) and sys.stderr.isatty())
    pool = None
    try:
        try:
            pool = mp.Pool(processes=workers, initializer=_worker_init)
        except TypeError:
            pool = mp.Pool(processes=workers)
        while completed < total:
            while in_flight < budget:
                try:
                    path = next(pending)
                except StopIteration:
                    break
                pool.apply_async(process_file, ((str(path), options),), callback=_collect)
                in_flight += 1
            ready.wait(_POLL_INTERVAL)
            ready.clear()
            while True:
                try:
                    report = results.get(block=False)
                except queue.Empty:
                    break
                in_flight -= 1
                completed += 1
                stats.merge(report)
                _handle_report(report, reports, verbose=verbose)
            progress.update(completed, stats)
            if _INTERRUPTED.is_set():
                logger.warning("interrupt received; stopping workers")
                raise KeyboardInterrupt
        pool.close()
        pool.join()
    except KeyboardInterrupt:
        stats.interrupted = True
        if pool is not None:
            pool.terminate()
            pool.join()
        while True:
            try:
                report = results.get(block=False)
            except queue.Empty:
                break
            completed += 1
            stats.merge(report)
            _handle_report(report, reports, verbose=verbose)
    except BaseException:
        if pool is not None:
            pool.terminate()
            pool.join()
        progress.close()
        raise
    finally:
        progress.close()
    stats.elapsed_s = time.perf_counter() - started
    logger.info("run summary:\n{}", _render_summary(stats))
    return stats, reports
def _handle_report(report, reports, *, verbose):
    if report.status is FileStatus.UNCHANGED:
        if verbose:
            logger.debug("unchanged: {}", report.path)
        return
    reports.append(report)
    if report.status is FileStatus.ERROR:
        logger.error("{}: {}", report.path, report.message)
        if verbose and report.traceback_text:
            logger.debug("traceback for {}:\n{}", report.path, report.traceback_text)
    elif report.status is FileStatus.SKIPPED:
        logger.warning("{}: {}", report.path, report.message)
    else:
        if report.message:
            logger.warning("{}: {}", report.path, report.message)
        logger.debug(
            "{}: -{} comment(s), -{} docstring(s) in {:.1f} ms",
            report.path,
            report.comments_removed,
            report.docstrings_removed,
            report.duration_s * 1000.0,
        )
        if verbose:
            logger.info(
                "stripped: {} (-{} comments, -{} docstrings)",
                report.path,
                report.comments_removed,
                report.docstrings_removed,
            )
def build_parser():
    parser = argparse.ArgumentParser(
        prog="strip_python_comments",
        description=(
            "Strip comments and docstrings from Python files with libcst "
            "(shebang, module docstring and tooling directives are preserved)."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        allow_abbrev=False,
        epilog=(
            "examples:\n"
            "  %(prog)s                          # current dir, recursively\n"
            "  %(prog)s src/ app.py ./bin/worker # mixed files and directories\n"
            "  %(prog)s --check --diff src/      # show what would change\n"
            "  %(prog)s --no-comments -n 16 pkg/ # docstrings only, more workers\n"
        ),
    )
    parser.add_argument(
        "paths",
        nargs="*",
        metavar="PATH",
        help=("files and/or directories to process; defaults to the current directory (recursively) when omitted"),
    )
    parser.add_argument(
        "--comments",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="remove comments (default: %(default)s); tooling directives are kept",
    )
    parser.add_argument(
        "--docstrings",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="remove docstrings (default: %(default)s); the module docstring is kept",
    )
    parser.add_argument(
        "--extensionless",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="include Python files without an extension (default: %(default)s)",
    )
    parser.add_argument(
        "--structural-check",
        action=argparse.BooleanOptionalAction,
        default=True,
        help=("verify that the rewrite leaves the AST unchanged apart from docstrings (default: %(default)s)"),
    )
    parser.add_argument(
        "-n",
        "--workers",
        type=int,
        default=DEFAULT_WORKERS,
        metavar="N",
        help="worker processes (default: %(default)s)",
    )
    parser.add_argument(
        "--max-file-size",
        type=float,
        default=DEFAULT_MAX_FILE_SIZE / (1024 * 1024),
        metavar="MB",
        help="skip files larger than this many megabytes (default: %(default)s)",
    )
    parser.add_argument(
        "--python-version",
        default=TARGET_PYTHON_VERSION,
        metavar="X.Y",
        help="target grammar version (default: %(default)s)",
    )
    parser.add_argument(
        "-c",
        "--check",
        "--dry-run",
        dest="check",
        action="store_true",
        help="report what would change without writing anything",
    )
    parser.add_argument(
        "--diff",
        action="store_true",
        help="print unified diffs to stdout and write nothing",
    )
    parser.add_argument(
        "-b",
        "--backup",
        action="store_true",
        help="keep a copy of every rewritten file next to it (<name>.bak)",
    )
    parser.add_argument(
        "--atomic",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="replace files atomically via a temporary sibling (default: %(default)s)",
    )
    parser.add_argument(
        "--fsync",
        action=argparse.BooleanOptionalAction,
        default=False,
        help="flush rewritten files to stable storage (default: %(default)s)",
    )
    parser.add_argument(
        "--preserve-mtime",
        action="store_true",
        help="keep the original modification time (useful with build caches)",
    )
    parser.add_argument(
        "--follow-symlinks",
        action="store_true",
        help="recurse into symlinked directories",
    )
    parser.add_argument("-q", "--quiet", action="store_true", help="log errors only")
    parser.add_argument("-v", "--verbose", action="store_true", help="log per-file details")
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    return parser
def main(argv=None):
    args = build_parser().parse_args(argv)
    configure_logging(verbose=args.verbose, quiet=args.quiet)
    if not args.comments and not args.docstrings:
        logger.error("nothing to do: both --no-comments and --no-docstrings given")
        return 2
    apply_changes = not (args.check or args.diff)
    options = JobOptions(
        strip_comments=args.comments,
        strip_docstrings=args.docstrings,
        apply_changes=apply_changes,
        keep_backup=args.backup,
        atomic_write=args.atomic,
        fsync=args.fsync,
        preserve_mtime=args.preserve_mtime,
        structural_check=args.structural_check,
        diff=args.diff,
        max_file_size=max(1, int(args.max_file_size * 1024 * 1024)),
        python_version=str(args.python_version) if args.python_version else None,
    )
    roots = [Path(path) for path in args.paths]
    if not roots:
        logger.debug("no path given; using the current directory recursively")
    def _handler(signum, _frame):
        logger.warning("received signal {}", signum)
        _INTERRUPTED.set()
    for sig in (signal.SIGINT, signal.SIGTERM):
        with contextlib.suppress(ValueError, OSError, AttributeError):
            signal.signal(sig, _handler)
    interrupted = False
    try:
        stats, reports = run(
            roots,
            options=options,
            workers=args.workers,
            include_extensionless=args.extensionless,
            follow_symlinks=args.follow_symlinks,
            quiet=args.quiet,
            verbose=args.verbose,
        )
    except KeyboardInterrupt:
        interrupted = True
        stats = RunStats(interrupted=True)
        reports = []
    if args.diff:
        _print_diffs(reports)
    if not args.quiet:
        _print_file_lists(reports, verbose=args.verbose)
    if interrupted or stats.interrupted:
        if not args.quiet:
            logger.warning("interrupted before all files were processed")
        return 130
    return 1 if stats.errors else 0
def _print_diffs(reports):
    for report in sorted(reports, key=lambda item: item.path):
        if report.diff:
            sys.stdout.write(report.diff)
    sys.stdout.flush()
def _print_file_lists(reports, *, verbose):
    changed = sorted(report.path for report in reports if report.changed)
    if changed:
        logger.info(
            "files {}:\n  {}",
            "changed" if verbose else "rewritten",
            "\n  ".join(changed),
        )
    if verbose:
        for report in sorted(reports, key=lambda item: item.path):
            if report.status in (FileStatus.ERROR, FileStatus.SKIPPED):
                logger.info("{} [{}]: {}", report.path, report.status.value, report.message)
if __name__ == "__main__":
    mp.freeze_support()
    sys.exit(main())
