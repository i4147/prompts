Build a production-grade, single-package Python CLI application called `pixctl` 
(image conversion & modification tool). Use Typer (or Click) + Pillow as the 
core stack. The app must be installable via `pip install -e .` and expose a 
`pixctl` entry point.
=====================================================================
PROJECT GOAL
=====================================================================
A fast, scriptable, chainable image conversion and modifier CLI that:
  1. Converts images between formats (JPEG, PNG, WEBP, GIF, BMP, TIFF, ICO, PDF, HEIC if available)
  2. Applies modifications (resize, crop, rotate, filters, watermarks, text, metadata stripping)
  3. Supports batch processing (single file, directory, glob, or recursive)
  4. Works well in pipelines (stdin/stdout, exit codes, quiet/verbose modes)
=====================================================================
CLI STRUCTURE
=====================================================================
Command name: pixctl
Subcommands:
  pixctl convert   <input> -o <output> -f <format>
  pixctl resize    <input> -o <output> --size WxH | --scale 0.5
  pixctl crop      <input> -o <output> --box x,y,w,h
  pixctl rotate    <input> -o <output> --angle 90
  pixctl flip      <input> -o <output> --axis h|v
  pixctl filter    <input> -o <output> --grayscale --blur 2 --sharpen 1.5
  pixctl watermark <input> -o <output> --image logo.png --position br --opacity 0.6
  pixctl text      <input> -o <output> --text "Hello" --position center --font-size 32
  pixctl chain     <input> -o <output> --ops "resize:800x600,grayscale,blur:1.5"
  pixctl batch     <dir-or-glob> -o <outdir> --ops "convert:webp,resize:50%"
  pixctl info      <input>          # show dimensions, format, EXIF, size
=====================================================================
GLOBAL FLAGS (available on every subcommand)
=====================================================================
  -o, --output PATH        Output file or directory
  -f, --format FORMAT      Target format (jpg, png, webp, gif, bmp, tiff, ico, pdf)
  -q, --quality INT        Output quality 1–100 (JPEG/WEBP/HEIC)
      --optimize           Enable Pillow's optimize mode
      --progressive        Progressive JPEG
      --strip-metadata     Remove EXIF/ICC/XMP
      --keep-metadata      Preserve all metadata (default: keep EXIF only)
  -r, --recursive          Recurse into subdirectories (for batch)
      --pattern GLOB       Filter files e.g. "*.jpg"
      --threads INT        Parallel workers (default: cpu_count)
      --overwrite          Overwrite existing output files
      --dry-run            Show what would happen, don't write
      --backup EXT         Copy original as <name>.bak<EXT> before modifying
  -v, --verbose            Verbose logging
      --quiet              Suppress non-error output
      --json               Emit machine-readable JSON summary at end
      --config PATH        Load defaults from TOML/YAML config file
      --no-color           Disable ANSI colors
=====================================================================
MODIFICATION FLAGS (per applicable subcommand)
=====================================================================
Resize:
  --size WxH               Exact dimensions (aspect-ratio ignored)
  --scale FLOAT            Percentage or factor: 0.5 or 50%
  --fit contain|cover|fill Letterbox / crop-to-fill / stretch
  --max WxH                Only downscale if larger
  --resample nearest|bilinear|bicubic|lanczos   (default: lanczos)
Crop:
  --box x,y,w,h            Pixel box
  --aspect 16:9            Center-crop to ratio
  --gravity center|n|s|e|w|ne|nw|se|sw
Rotate/Flip:
  --angle DEG              Any angle (auto-expand canvas)
  --expand                 Grow canvas to fit rotated image
  --axis h|v
Filters:
  --grayscale
  --blur RADIUS
  --sharpen FACTOR
  --brightness FLOAT       -1.0 to 1.0
  --contrast FLOAT
  --saturation FLOAT
  --sepia
  --invert
  --auto-contrast
  --posterize BITS         2–8
Watermark / Text:
  --image PATH             Watermark image (PNG w/ alpha recommended)
  --text STRING
  --position tl|tc|tr|cl|center|cr|bl|bc|br
  --opacity 0.0–1.0
  --font PATH              TTF/OTF font
  --font-size INT
  --color "#RRGGBB"
  --padding INT
=====================================================================
BEHAVIORAL REQUIREMENTS
=====================================================================
1. Format auto-detection:
   - If -f/--format omitted, infer from output extension.
   - If output omitted, default to <input_stem>_modified.<same_ext>.
2. Validation & errors:
   - Non-image inputs → clear error, exit code 2.
   - Unwritable output → exit code 3.
   - Unsupported combination (e.g. transparency → JPEG) → warn and 
     composite on white unless --strict is set (then fail).
   - All errors print to stderr with actionable messages.
3. Batch semantics:
   - Mirrors directory structure into output dir.
   - Skips files already newer than input unless --overwrite.
   - Prints per-file progress (tqdm) unless --quiet/--json.
   - Parallelizes with ThreadPoolExecutor; per-file isolation so one 
     failure doesn't abort the batch.
4. Chain mode (`pixctl chain`):
   - Parses a comma-separated op string: "resize:800x600,grayscale,blur:1.5"
   - Each op maps to a function; unknown ops raise a helpful error 
     listing valid ops.
5. Config file (~/.pixctl.toml):
   - Default quality, threads, color theme, output dir.
   - CLI flags override config values.
6. Exit codes:
   0 success | 1 generic error | 2 bad input | 3 IO error | 4 partial 
   failure (batch with some failures).
7. Output & logging:
   - Default: single summary line per file.
   - --verbose: per-op timing.
   - --json: {"processed": N, "failed": M, "files": [{in, out, ms, status}]}
=====================================================================
CODE STRUCTURE (deliverables)
=====================================================================
pixctl/
  __init__.py
  __main__.py           # python -m pixctl
  cli.py                # Typer app + flags
  core/
    convert.py          # format conversion + quality handling
    transform.py        # resize, crop, rotate, flip
    filters.py          # blur, sharpen, color adjustments
    overlay.py          # watermark & text
    metadata.py         # EXIF read/write/strip
    batch.py            # directory walking + threading
    chain.py            # op-string parser
    io.py               # safe read/write, atomic replace
  config.py             # TOML loader + defaults
  utils.py              # logging, color, human sizes
pyproject.toml          # entry point: pixctl = pixctl.cli:app
README.md               # usage + examples
tests/
  test_convert.py
  test_transform.py
  test_chain.py
  test_batch.py
=====================================================================
TESTING & QUALITY
=====================================================================
- Use pytest with tmp_path fixtures.
- Cover: format conversion roundtrip, resize math, chain parsing, 
  batch parallelism (mock), error paths.
- Target ≥80% coverage on core/.
- Type hints on all public functions.
- Format with `ruff format` and lint with `ruff check`.
=====================================================================
DELIVERABLE
=====================================================================
Produce the full source tree above. Include:
  - All files, fully implemented (no stubs/TODOs).
  - A pyproject.toml with dependencies: typer, pillow, tqdm, tomli, 
    (optional) pillow-heif for HEIC.
  - A README with 6+ runnable examples (single convert, resize+filter, 
    batch webp conversion, watermark, chain mode, JSON output).
  - A short "Design decisions" section explaining tradeoffs 
    (threads vs processes, metadata policy, atomic writes).
Constraints:
  - Pure Python (no external binaries required).
  - Windows/macOS/Linux compatible.
  - No network calls at runtime.
  - Deterministic, testable, side-effect-free core functions.
