# Task: 
implement a python port of nodjs based package named svgo (https://github.com/svgo/svgo)
pkg name should be svgo too, with same cli flags and usage
-the  requested diffrences in python implementation are
1. use pathlib for file system traverse
2.use multoprocessing wherever possible(cf.ProcessPoolExecutor with fixed 4 workers)
3. cli  script must accept one or more files or dirs as input,if no input is provided, cli script must process .svg files found under current dir recursively inplace

## Objective
Implement a faithful, working reimplementation of the svgo in Python 3.11+, on Linux

## Naming and CLI contract (HARD)
- The user-facing command name MUST be exactly `svgo` — same string as the
  original. No `-py`, `-python`, `-impl`, or any other suffix in:
    - `pyproject.toml` `[project.scripts]` entry (key MUST be `svgo`),
    - the `python -m svgo` module path (must behave like the command, but the
      console script is the canonical entry point),
    - usage/help text (`Usage: svgo [OPTION]...`),
    - error messages.
- If the original ships multiple binaries (e.g. `mlocate` → `updatedb` + `locate`),
  register one `[project.scripts]` entry per original binary, each with the exact
  original name.
- The CLI surface MUST match the original: subcommand/argument grammar, option names
  (short and long), option-argument forms (`-e PATTERN`, `--regexp=PATTERN`,
  `-ePATTERN` where the original accepts the attached form), and `--help` / `--version`.
- Grouped short flags (`-abc`), repeated flags (`-e a -e b`), `--` terminator,
  `--opt=value` and `--opt value` must all be accepted wherever the reference accepts
  them.
- `argparse` defaults to different usage/error formatting — either configure it to
  match the reference or hand-roll parsing so stderr text and exit codes match.
- `--help` and `--version` output MUST match the reference byte-for-byte (modulo
  formatting of the program name, which is the same string).

## Flags — ALL of them (HARD)
- Enumerate every flag the reference version accepts for the target binaries
  (from `--help`, the man page, and the info manual).
- Implement **every** flag whose behavior is achievable under the hard constraints
  below. Do not silently drop flags; do not stub them to no-ops; do not "implement
  the popular ones."
- If a specific flag is genuinely unimplementable under the constraints (e.g. needs
  root, needs a kernel interface not exposed by the stdlib), then in your initial
  reply you MUST list each such flag with a one-line justification, and reproduce
  that list in `README.md` under "Unsupported flags". Any flag not on that list is
  expected to work correctly.
- Every supported flag must appear in `tests/matrix.py` (see below) and be
  exercised by at least one unit test and one integration-test invocation.

## Hard constraints (apply always)
- Language: Python 3.11+.
- **Standard library only.** No `pip install`, no `requirements.txt`, no third-party
  packages. `[project] dependencies = []`.
- **No subprocess / no shelling out in the implementation.** The following are forbidden in `svgo/`:
    - `subprocess` (any API),
    - `os.system`, `os.popen`, `os.spawn*`, `os.exec*`, `os.fork`, `os.forkpty`,
    - `pty`, `asyncio.create_subprocess_*`, `multiprocessing` (for invoking external
      programs),
    - `ctypes` calls that reach `fork`/`exec*`/`posix_spawn`.
  You may use `subprocess` inside `tests/` ONLY, and ONLY for differential testing
  against the real reference binary — never in `svgo/`.
- A mechanical check must pass:
  `grep -rn 'subprocess\\|os\\.system\\|os\\.popen\\|os\\.exec\\|os\\.spawn\\|os\\.fork\\|pty\\.' svgo/`
  must return nothing. Add this as a test.
- No shelling out to the real command, to `find`/`grep`/`sed`/`awk`/`sort`/`xargs`,
  or to any external helper that would trivially solve the task.
- If you believe a third-party package is unavoidable, STOP and justify it in your
  initial reply before adding it.

## Functional requirements
error handling must be done & edge cases MUST be handled correctly.

### Byte-exact compatibility
- `svgo --help` and `svgo --version` must match the reference output
  byte-for-byte (modulo the program name, which is identical). Check in the expected
  text as a golden file under `tests/fixtures/help/` and diff in a test.
- Error text on stderr must match the reference format exactly, e.g.
  `svgo: <fname>: No such file or directory`. Check in one golden file
  per error class under `tests/fixtures/errors/`.
- Produce an explicit exit-code table in `README.md` (0, 1, 2, others). Every
  documented exit code must be exercised by at least one integration test.
- Exit codes must match the reference byte-for-byte for every documented error class.

### Robustness
- **SIGPIPE:** `svgo ... | head -1` must exit with the reference's code, no
  traceback, no stderr noise. Python raises `BrokenPipeError` — catch it and exit
  with the right code. Add an integration test using a shell pipeline.
- **Pathological filenames:** correct behavior with filenames containing newlines,
  spaces, tabs, quotes, backslashes, control bytes, and non-UTF-8 bytes (`\xff\xfe`).
  Byte-preserve on output via `os.fsencode`/`bytes` paths. Document `-z`/`\0` support
  if the reference has it. Handle names near 255 bytes and total paths near
  `PATH_MAX` (4096).
- **Memory bounds:** must run under `ulimit -v 262144` (256 MB) on a 1,000,000-file
  input without OOM. Peak RSS must be O(1) in input size. Add a `make bench-mem`
  target that reports peak RSS via `/usr/bin/time -v`.
- **FD leaks:** FD count in `/proc/<pid>/fd` must be stable across 10,000 iterations
  of the command. Add a test that loops and compares.

### Differential testing
- Ship `scripts/difftest.sh` that, when the reference binary is on `$PATH`, runs
  both on the same fixture and diffs stdout, stderr, and exit code byte-for-byte.
  Include 20+ cases covering every flag and every error class. Skips cleanly if the
  reference is absent.
- Ship `scripts/grade.sh` that runs the differential harness end-to-end and prints
  a pass/fail table. It must be runnable by a reviewer with one command.

### Test matrix
- Ship `tests/matrix.py` listing every supported flag and the name of the test that
  exercises it. A test asserting "every flag in the matrix has at least one passing
  test" must exist. No supported flag may be tested zero times.

### Hidden sanity fixture
- Ship `tests/fixtures/sanity/` containing:
    - one empty directory,
    - one regular file whose name contains a byte ≥ 0x80 (e.g. `\xff`),
    - one regular file whose name contains a newline,
    - one symlink loop (`a -> b -> a`),
    - one directory containing 10,000 small files.
  Integration tests must exercise all five cases against the installed `svgo`
  entry point. Do NOT modify this fixture from the implementation side — treat it
  as read-only.

## Quality bar (apply always)
- Package layout: `svgo/__init__.py`, `svgo/core.py` (logic),
  `svgo/cli.py` (entry point). Core logic importable and unit-testable.
- Type hints throughout; `mypy --strict` clean is a bonus.
- Docstrings on every public function/class.
- Unit tests with `unittest` (stdlib only — no pytest).
- Integration test that invokes the installed `svgo` entry point via
  `subprocess` from test code against `tests/fixtures/sanity/` and any additional
  fixtures.
- Non-zero exit + stderr on error; no bare `except:`; no `sys.exit()` inside
  library code (only in `svgo/cli.py`).
- Every integration test creates a fresh `tempfile.mkdtemp`, `chdir`s into it, and
  cleans up. No test depends on order or on the host `$HOME`.

## Deliverables (apply always)
1. Full source tree + `pyproject.toml` with
   `[project.scripts] svgo = "svgo.cli:main"` and `dependencies = []`.
2. `README.md` containing:
   - design overview,
   - complete supported-flags table,
   - **Unsupported flags** section (may be empty; must exist),
   - exit-code table,
   - **deviations from reference behavior**,
   - how to run.
3. `scripts/demo.sh` (or a `Makefile` target) that builds a synthetic fixture,
   invokes the built entry point by its exact name `svgo`, and shows 5+
   representative invocations covering multiple flags with expected output.
4. `scripts/difftest.sh` and `scripts/grade.sh` as specified above.
5. Final message: what you implemented, every omitted flag with reason, any
   third-party packages used and why, known limitations.

## Reporting back (before you write any code)
Reply with:
  1. The reference version you are targeting and where you got its flag list.
  2. The complete list of flags you will implement.
  3. The list of flags you will NOT implement, with one-line reasons.
  4. How you will guarantee no process spawning in `svgo/`.
  5. How you will handle non-UTF-8 paths and bytes.
  6. Confirmation that the `[project.scripts]` key will be exactly `svgo`.
Then proceed.
