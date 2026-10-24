Create a Python command-line utility that detects and fixes file extension mismatches in a directory by analyzing file content using MIME type detection. The tool should recursively scan directories, identify files whose extensions don't match their actual content type, and optionally rename them with the correct extension.
Core Requirements:
1. Comprehensive MIME-to-Extension Mapping Database:
   · Build an exhaustive dictionary mapping MIME types to their standard file extensions
   · Cover all major categories:
     · Applications: documents (PDF, DOC, XLS, PPT, ODF), archives (ZIP, RAR, 7z, tar variants), executables (EXE, DLL, APK, AppImage), fonts (TTF, OTF, WOFF, WOFF2), packages (DEB, RPM, Flatpak), disk images (ISO, DMG, VDI, VMDK)
     · Audio: MP3, FLAC, AAC, OGG, WAV, MIDI, MOD tracker formats, game console audio formats
     · Video: MP4, AVI, MKV, WebM, MOV, WMV, FLV, game console ROM formats (NES, SNES, GameBoy, N64, etc.)
     · Images: JPEG, PNG, GIF, SVG, TIFF, WebP, AVIF, HEIC, raw camera formats (CR2, NEF, ARW, etc.), GIMP formats (XCF)
     · Text: plain text, source code for 30+ languages (Python, Rust, Go, Java, C/C++, etc.), markup (HTML, XML, Markdown), configuration formats (JSON, YAML, TOML, INI)
     · Fonts: TTF, OTF, WOFF, WOFF2, EOT
     · Models: 3D formats (STL, OBJ, glTF, Collada, VRML)
   · Include legacy and obscure formats (Amiga, Atari, Commodore, Lotus, WordPerfect, etc.)
   · Support compound extensions like .tar.gz, .tar.bz2, .tar.xz, .tar.zst
   · Handle format variants (e.g., .jpeg/.jpg, .html/.htm, .yaml/.yml)
2. Shebang-Based Extension Detection:
   · Before MIME detection, check if the file has a shebang line (#!)
   · If the shebang indicates a shell script (bash, /bin/sh), rename to .sh
   · If the shebang indicates Python, rename to .py
   · Skip MIME detection for files already fixed by shebang analysis
   · Handle cases where the target filename already exists (use unique naming)
3. MIME Type Detection System:
   · Use the system's file command with --brief --mime-type flags for accurate detection
   · Execute via a robust subprocess runner that handles:
     · Command not found errors
     · Permission denied errors
     · Timeout errors
     · Unexpected exceptions
   · Return structured results with exit code, stdout, and stderr
   · Support silent mode (suppress output) and capture mode
4. Extension Mismatch Detection Algorithm:
   · For each file in the directory tree:
     1. Skip .git and __pycache__ directories
     2. Skip files with .css and .js extensions (commonly misidentified)
     3. Try shebang-based fixing first
     4. If not fixed by shebang, detect MIME type via file command
     5. Look up expected extensions for the detected MIME type
     6. Skip if MIME type maps to .txt (too generic, many false positives)
     7. Compare current extension against expected extensions
     8. If mismatch found, determine the correct new filename
   · Handle files with multiple expected extensions (pick the first one)
   · Handle files with no extension (add the correct one)
5. Safe Renaming System:
   · Before renaming, check if the target filename already exists
   · Use a unique path generator that appends incremental counters:
     · Parse the filename into stem and suffix(es)
     · If target exists, try stem_1.suffix, stem_2.suffix, etc.
     · Support files with no extension and files with compound extensions
   · Optional confirmation mode (-y flag):
     · Show the proposed rename
     · Prompt user for y confirmation before renaming
   · Without confirmation mode: rename automatically
6. Binary File Detection:
   · Implement heuristic binary detection before processing:
     · Read first 8KB of file
     · Check for null bytes (strong binary indicator)
     · Calculate ratio of non-text characters
     · If >30% non-text, classify as binary
   · Skip binary files for shebang detection
   · Allow MIME detection on binary files (the file command handles them)
7. Terminal Output and Colors:
   · Implement a comprehensive color library supporting:
     · 16 standard colors (black, red, green, yellow, blue, magenta, cyan, white)
     · Light/dark variants of each color
     · 8 background highlight colors
     · Text attributes: bold, dark, italic, underline, blink, reverse, concealed, strikethrough
     · RGB color support for foreground and background
   · Respect terminal color capability:
     · Check NO_COLOR and ANSI_COLORS_DISABLED environment variables
     · Honor FORCE_COLOR environment variable
     · Check if stdout is a TTY
     · Allow programmatic override with no_color and force_color parameters
   · Display mismatched files with colored output:
     · Original filename in one color
     · New filename in another color
     · MIME type information
   · Print "no mismatch" message in color if all files are correct
8. Directory Scanning:
   · Accept a directory path (defaults to current working directory)
   · Recursively walk the directory tree using os.walk()
   · Skip .git and __pycache__ directories automatically
   · Process all files regardless of current extension
9. Utility Functions:
   · is_binary(path): Heuristic binary file detection
   · unique_path(path): Generate non-conflicting file paths with counters
   · fix_by_shebang(path): Analyze and fix file extension based on shebang
   · get_file_mime(path): Get MIME type using system file command
   · safe_rename(old, new): Rename with conflict resolution
   · runcmd(cmd, silent, show_output, timeout): Robust subprocess execution
   · colored(text, color, on_color, attrs): ANSI color formatting
   · cprint(text, ...): Print with color
   · can_colorize(): Determine if terminal supports colors
10. Reporting:
    · Collect all mismatched files during scanning
    · After processing, display a summary:
      · List files with mismatched extensions
      · Show original name, detected MIME type, and new name (if renamed)
      · Use bold/blink formatting to highlight changes
      · Format cleanly with aligned columns
Technical Specifications:
· Python 3.10+ (use modern type hints: str | None, list[str])
· Standard library only (no external dependencies for core functionality)
· Use pathlib.Path for file path operations
· Use os.walk() for recursive directory traversal
· Use subprocess.run() for MIME detection via system file command
· Comprehensive MIME database as a module-level constant dictionary
· Skip directory set as a frozenset for immutability
Command-Line Interface:
· -y flag: enable confirmation mode (prompt before each rename)
· No required arguments (defaults to current directory)
· Exit with appropriate status codes
Example Usage:
```bash
# Automatic rename without confirmation
python fix_extensions.py
# Interactive mode with confirmation
python fix_extensions.py -y
# Output example:
# document.pdf --> application/zip
# mime=application/zip
# expected exts =['.zip', '.zipx']
# new name = document.zip
# document.pdf -> document.zip ?
```
Edge Cases to Handle:
· Files with no extension at all (add correct extension)
· Files with compound extensions like .tar.gz (treat as single extension)
· Files where multiple MIME types map to the same extension (use first match)
· Binary files that the file command can't identify
· Empty files (skip processing)
· Symlinks (handle or skip appropriately)
· Read-only files or permission errors during rename
· Target filename already exists (increment counter)
· Very large directories with thousands of files
· Files with Unicode characters in names
· System without file command installed
Safety Considerations:
· Never overwrite existing files (always use unique path)
· Optional confirmation before renaming
· Skip known problematic extensions (.css, .js often misidentified)
· Skip .txt MIME type matches (too many false positives)
· Validate file readability before attempting MIME detection
The tool should be comprehensive enough to handle virtually any file format encountered in a typical filesystem, smart enough to avoid common false positives, and safe enough to run without accidentally losing data. The MIME database should be exhaustive, covering hundreds of file formats across all major categories.
python version 3.12
- use pathlib and parallel processing
