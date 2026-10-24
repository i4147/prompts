Create a Python command-line utility that benchmarks multiple compression algorithms on a given file or directory, automatically selects the best compression result, and cleans up inferior compressed files. The tool should help users determine which compression algorithm works best for their specific data.
Core Requirements:
1. Multi-Algorithm Compression Engine:
   · Implement compression functions for 8 different algorithms:
     · Brotli (quality=11, maximum compression)
     · Zstandard (level=21, maximum compression)
     · LZMA/XZ (preset=9, maximum compression)
     · Bzip2 (compresslevel=9)
     · Gzip (compresslevel=9)
     · LZ4 (maximum compression level via frame API)
     · Blosc (ZSTD codec, clevel=9)
     · 7z (via py7zr library, as a separate archive format)
   · Each compression function should:
     · Accept raw bytes as input
     · Return compressed bytes
     · Be wrapped in error handling to catch and report failures
     · Measure and report compression time
2. Input Preparation:
   · Accept either a single file or a directory as input
   · If input is a file: read it directly as raw bytes
   · If input is a directory: create a temporary tar archive, read it as bytes, then delete the temporary tar
   · Track the original uncompressed size for ratio calculations
   · Validate that the target path exists before processing
3. Benchmarking and Metrics:
   · For each compression algorithm, measure and report:
     · Compressed size (in bytes, with thousands separators)
     · Compression ratio (compressed_size / original_size, to 4 decimal places)
     · Compression time (in seconds, to 3 decimal places)
   · Display real-time progress with aligned columns:
     · Success indicator (✓ or ✗)
     · Algorithm name (10-character width)
     · Compressed size (12-character width, right-aligned)
     · Ratio (4 decimal places)
     · Time (3 decimal places)
4. Output File Management:
   · Save each compressed result to a file named {base_name}.{extension} in the current directory
   · Use appropriate extensions: .br, .zst, .xz, .bz2, .gz, .lz4, .blosc, .7z
   · Handle the 7z compression separately (writes to temp file first, then compresses via py7zr)
   · Clean up temporary files after 7z compression
5. Automatic Best Result Selection:
   · After all compression attempts complete, sort results by compression ratio (ascending)
   · Display a formatted summary showing the top 3 results with:
     · Rank
     · Algorithm name
     · Compressed size
     · Compression ratio
     · Bytes saved compared to original
   · Keep only the best result file on disk
   · Delete all other compressed files to save space
   · Handle file deletion errors gracefully
6. Error Handling and Robustness:
   · Individual compression failures should not stop the entire benchmark
   · Report errors for failed algorithms but continue with others
   · Clean up partial output files on failure (delete incomplete compressed files)
   · Handle missing dependencies gracefully (though they're required imports)
   · Validate command-line arguments
   · Provide clear error messages for missing files or invalid inputs
7. User Interface:
   · Command-line usage: python script.py <file_or_directory>
   · Show an introductory header with the target being compressed
   · Display original size before showing results
   · Clean, aligned table formatting for compression results
   · Separator lines for visual clarity
   · Final summary with clear indication of which file is kept and which are deleted
   · Use emoji indicators for visual feedback (📦, ✓, ✗, ⚠)
8. Performance Considerations:
   · Use maximum compression settings for fair comparison of best-case scenarios
   · Time each compression operation individually
   · Handle large files efficiently by reading once and reusing the data buffer
   · Clean up temporary files immediately after use
   · Use context managers for all file operations
Technical Specifications:
· Python 3.8+ compatible
· Required third-party libraries:
  · brotli (Google's Brotli compression)
  · zstandard (Facebook's Zstandard compression)
  · lz4 (LZ4 compression with frame API)
  · blosc (high-performance compressor)
  · py7zr (7-Zip archive format)
  · Standard library: bz2, lzma, gzip, tarfile
· Use collections.namedtuple for structured compression results
· Use pathlib.Path for all file path operations
· Type hints where practical
· Shebang line for Termux/Unix environment: #!/data/data/com.termux/files/usr/bin/env python
Example Output Format:
```
📦 Compressing: my_project/
Original size: 14,532,110 bytes
COMPRESSION PROGRESS:
----------------------------------------------------------------------
✓ brotli     | Size:    3,210,456 | Ratio: 0.2209 | Time: 2.341s
✓ zstd       | Size:    3,456,789 | Ratio: 0.2379 | Time: 1.892s
✓ xz         | Size:    2,987,654 | Ratio: 0.2056 | Time: 4.123s
✓ bz2        | Size:    3,876,543 | Ratio: 0.2668 | Time: 3.456s
✓ gzip       | Size:    4,234,567 | Ratio: 0.2914 | Time: 1.234s
✓ lz4        | Size:    5,678,901 | Ratio: 0.3908 | Time: 0.567s
✓ blosc      | Size:    3,123,456 | Ratio: 0.2149 | Time: 0.892s
✓ 7z         | Size:    2,876,543 | Ratio: 0.1979 | Time: 5.678s
======================================================================
TOP 3 COMPRESSION RESULTS
======================================================================
1. 7z         | Size:    2,876,543 | Ratio: 0.1979 | Saved:   11,655,567 bytes
2. xz         | Size:    2,987,654 | Ratio: 0.2056 | Saved:   11,544,456 bytes
3. blosc      | Size:    3,123,456 | Ratio: 0.2149 | Saved:   11,408,654 bytes
✓ Keeping best: 7z (my_project.7z)
✗ Deleted: brotli
✗ Deleted: zstd
✗ Deleted: xz
✗ Deleted: bz2
✗ Deleted: gzip
✗ Deleted: lz4
✗ Deleted: blosc
```
Edge Cases to Handle:
· Directory with no read permissions
· Very small files (where compression might increase size)
· Files that are already compressed (won't compress further)
· Missing optional dependencies (though all are imported at top)
· Interrupted compression (partial file cleanup)
· Existing output files with same names (overwrite behavior)
· Large files that might exceed memory (process as single buffer)
The tool should serve as a practical utility for determining the optimal compression algorithm for specific data types, automatically applying the best one and cleaning up the rest. It's designed for use cases like compressing project directories, datasets, or any scenario where storage efficiency matters and the best algorithm may vary by content type.
