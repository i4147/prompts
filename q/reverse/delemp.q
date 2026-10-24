Create a production-quality Python command-line utility that recursively removes blank lines from text files across multiple directories using parallel processing. The tool should be safe (automatically skip binary files), fast (parallel workers), and provide beautiful, informative terminal output.
Core Requirements:
1. Blank Line Removal Engine:
   · Process text files to remove blank lines (lines containing only newline characters \n or \r)
   · Optional mode (--space flag) to also remove lines containing only whitespace characters (spaces, tabs)
   · Preserve all non-blank lines exactly as they appear (maintain indentation, encoding, line endings)
   · Only write to files that actually changed (if no blank lines found, don't modify the file)
   · Handle UTF-8 encoding with graceful fallback (errors='ignore')
2. Binary File Detection (Critical Safety Feature):
   · Implement multi-layered detection to prevent corruption of binary files:
     · Layer 1: Check file extension against a whitelist of known text extensions (60+ extensions covering programming languages, config files, markup, data formats)
     · Layer 2: Read first 8192 bytes and check for null bytes (\x00) which strongly indicate binary content
     · Layer 3: Check for known binary file signatures (magic bytes) for common formats:
       · Images: JPEG, PNG, GIF, BMP, ICO, WebP, HEIF
       · Archives: ZIP, GZIP, BZ2, XZ, 7z, RAR, RPM, PCAP
       · Executables: ELF, PE (MZ), Mach-O
       · Documents: PDF, OLE2 (DOC/XLS), SQLite, PostScript
       · Media: MP4, AVI, WAV, MP3 (ID3), OGG, FLAC, Flash (FWS/CWS)
     · Layer 4: Heuristic analysis — if >30% of bytes are non-text characters (outside ASCII printable ranges + common control chars), classify as binary
   · Skip all binary files without attempting to modify them
   · Report skipped binary files in the output
3. Parallel Processing Architecture:
   · Use concurrent.futures.ProcessPoolExecutor for true parallel execution
   · Configurable worker count via --workers flag (default: CPU count)
   · Each worker receives a tuple of (base_directory, file_path, remove_spaces_flag) to allow relative path calculation
   · Use as_completed() to process results as they finish with real-time progress display
   · Track completion count, binary skip count, and total lines removed during processing
4. File Discovery and Collection:
   · Accept one or more directories as input (default: current directory)
   · Resolve all paths to absolute paths
   · Skip symlinks to avoid double-processing or infinite loops
   · Recursively find all files using Path.rglob("*")
   · Collect all file paths before processing to show accurate total count
   · Warn about non-existent or invalid directories but continue with valid ones
5. Rich Terminal Output:
   · Beautiful header with box-drawing characters (╔═╗ ║ ╚═╝)
   · Color-coded output using ANSI escape codes:
     · Cyan for headers and separators
     · Green for success, modified files, completion
     · Yellow for warnings, binary skips
     · Red for errors
     · Bold for emphasis, counts, summaries
     · Dim for secondary information
   · Auto-detect terminal color support (via sys.stdout.isatty())
   · Organized results display:
     · Modified files with line counts and removal counts
     · Unchanged files (no blank lines) shown dimmed
     · Skipped binary files (show first 5, then count of remaining)
     · Errors with details
   · Progress indicator that updates in-place using \r carriage return
   · Comprehensive summary with totals for all categories
6. Results Organization and Reporting:
   · Sort results alphabetically by file path for consistent output
   · Categorize results into: processed, skipped binary, errors
   · For each modified file, show:
     · Relative path from base directory
     · Total lines in file
     · Number of blank lines removed
   · Final summary showing:
     · Total files found
     · Text files processed
     · Binary files skipped
     · Files modified (where changes were made)
     · Total lines removed
     · Errors (if any)
7. Command-Line Interface:
   · Positional arguments: one or more directories (default: ["."])
   · -s / --space: also remove whitespace-only lines
   · -w N / --workers N: number of parallel workers
   · --show-binary: show all skipped binary files instead of just first 5
   · Rich help text with examples showing various usage patterns:
     · Process current directory
     · Process single/multiple directories
     · Combine with space removal
     · Custom worker count
   · Use argparse.RawDescriptionHelpFormatter for formatted examples
8. Edge Cases and Safety:
   · Empty files: skip without error (no blank lines to remove)
   · Files with only blank lines: result should be empty file
   · Files with mixed line endings (\r\n, \r, \n): handle correctly
   · Files that become empty after removal: write empty file (don't delete)
   · Read-only files: catch permission errors and report as errors
   · Very large files: process line-by-line to manage memory
   · Unicode files: handle UTF-8 BOM, various encodings gracefully
   · Files with no trailing newline: preserve original ending style
   · Concurrent file access conflicts: handle IOErrors gracefully
9. Performance Optimizations:
   · Pre-collect file list to enable accurate progress reporting
   · Batch file discovery before processing starts
   · Use binary detection before reading full file content
   · Only read/write files that actually need modification
   · Use errors='ignore' for encoding to avoid exceptions on malformed files
   · Minimize inter-process communication overhead
10. Code Quality:
    · Clean separation of concerns: discovery, detection, processing, reporting
    · Pure functions where possible for testability
    · Type hints on all function signatures
    · Comprehensive docstring at module level
    · Constants for magic values (binary signatures, text extensions, ANSI codes)
    · Use frozenset for immutable lookup sets
    · Use Path objects throughout (no string path manipulation)
Technical Specifications:
· Python 3.8+ compatible (use concurrent.futures not newer features)
· Standard library only (no third-party dependencies)
· pathlib.Path for all file operations
· argparse for CLI with rich formatting
· ANSI escape codes for terminal colors
· Process pool for CPU-bound parallel I/O operations
· Proper if __name__ == "__main__" guard for multiprocessing safety
Example Output:
```
╔══════════════════════════════════════════════╗
║         Blank Line Remover                    ║
╚══════════════════════════════════════════════╝
Processing directories:
  • /home/user/project/src
  • /home/user/project/tests
Mode: Remove blank lines only
Scanning for files... Done! Found 1,247 files.
Processing files...
(Using 8 worker processes)
  Progress: Complete! (1,198 text, 49 binary)
──────────────────────────────────────────────────────────────────────
✓ Modified files:
  ● src/main.py
    Lines: 342  →  Removed: 28
  ● src/utils.py
    Lines: 156  →  Removed: 12
  ○ tests/test_main.py (no blank lines found)
⊘ Skipped binary files: 49
  ⊘ assets/logo.png
  ⊘ data/database.sqlite
  ⊘ libs/library.so
  ... and 46 more binary files
──────────────────────────────────────────────────────────────────────
Summary:
  Total files found:     1,247
  Text files processed:  1,198
  Binary files skipped:  49
  Files modified:        87
  Lines removed:         2,341
──────────────────────────────────────────────────────────────────────
```
The tool should be safe enough to run on any directory without fear of corrupting binary files, fast enough to handle large codebases through parallel processing, and provide clear, beautiful output that makes it easy to understand exactly what was changed. It should be a polished, production-ready utility that could be used daily by developers to clean up their codebases.
python version = 3.12
