import argparse
import sys
from pathlib import Path
from typing import List, Optional
try:
    from fontTools.ttLib import TTFont
except ImportError:
    print("Error: 'fonttools' library is not installed. Install it using: pip install fonttools[woff] brotli")
    sys.exit(1)
SUPPORTED_EXTENSIONS = {".ttf", ".otf", ".woff", ".woff2", ".eot"}
def convert_font(
    input_path: Path, target_format: str, output_dir: Optional[Path] = None, remove_original: bool = False
) -> None:
    target_format = target_format.lower().lstrip(".")
    valid_formats = {"ttf", "otf", "woff", "woff2", "eot"}
    if target_format not in valid_formats:
        raise ValueError(f"Unsupported format '{target_format}'. Choose from: {', '.join(valid_formats)}")
    if not input_path.exists() or not input_path.is_file():
        raise FileNotFoundError(f"Source font file not found: {input_path}")
    if target_format == "eot":
        print(
            f"[-] Notice: Native EOT writing requires specialized binary mapping (like ttf2eot). "
            f"Fonttools focuses on sfnt formats. Skipping EOT conversion for: {input_path.name}"
        )
        return
    out_dir = output_dir if output_dir else input_path.parent
    out_dir.mkdir(parents=True, exist_ok=True)
    output_path = out_dir / f"{input_path.stem}.{target_format}"
    print(f"[*] Processing: {input_path.name} -> {target_format.upper()}")
    try:
        font = TTFont(str(input_path))
        if target_format in {"woff", "woff2"}:
            font.flavor = target_format
        else:
            font.flavor = None
        font.save(str(output_path))
    except Exception as e:
        if "woff2" in target_format and "brotli" in str(e).lower():
            print("[-] Error: WOFF2 conversion requires the 'brotli' package. Install it via: pip install brotli")
        else:
            print(f"[-] Error converting {input_path.name}: {e}")
        return
    original_size = input_path.stat().st_size
    new_size = output_path.stat().st_size
    size_diff = new_size - original_size
    percent_change = (size_diff / original_size) * 100 if original_size > 0 else 0
    if size_diff > 0:
        change_str = f"increased by {abs(size_diff):,} bytes ({abs(percent_change):.2f}%) 📈"
    elif size_diff < 0:
        change_str = f"decreased by {abs(size_diff):,} bytes ({abs(percent_change):.2f}%) 📉"
    else:
        change_str = "remained unchanged ⚖️"
    print(f"    [+] Saved successfully to: {output_path}")
    print(f"    [+] Original Size: {original_size / 1024:.2f} KB | New Size: {new_size / 1024:.2f} KB")
    print(f"    [+] Size {change_str}")
    if remove_original and output_path.exists():
        try:
            input_path.unlink()
            print(f"    [+] Removed original source file: {input_path.name} 🗑️")
        except Exception as rm_err:
            print(f"    [!] Warning: Could not remove original file: {rm_err}")
    print()
def find_fonts_in_current_dir() -> List[Path]:
    current_dir = Path.cwd()
    found_fonts = [f for f in current_dir.rglob("*") if f.is_file() and f.suffix.lower() in SUPPORTED_EXTENSIONS]
    return found_fonts
def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert font files between TTF, OTF, WOFF, WOFF2, and EOT using fonttools."
    )
    parser.add_argument("input_files", nargs="*", type=Path, help="Path(s) to font file(s) to convert.")
    parser.add_argument(
        "--to", type=str, default="ttf", help="Target format (ttf, otf, woff, woff2, eot). Defaults to 'ttf'."
    )
    parser.add_argument("--output-dir", type=Path, default=None, help="Optional output directory for converted fonts.")
    parser.add_argument(
        "-r", "--remove", action="store_true", help="Remove the original font file if conversion is successful."
    )
    args = parser.parse_args()
    input_files = args.input_files
    if not input_files:
        print("[*] No input files specified. Scanning current directory recursively...")
        input_files = find_fonts_in_current_dir()
        if not input_files:
            print("[-] No supported font files found in the current directory.")
            sys.exit(0)
    print(f"\n=== Font Converter Initialized ===")
    print(f"Target Format: {args.to.upper()}")
    print(f"Files to process: {len(input_files)}")
    print(f"Remove originals: {args.remove}\n")
    for file_path in input_files:
        try:
            convert_font(file_path, args.to, args.output_dir, args.remove)
        except Exception as err:
            print(f"[-] Failed to process {file_path}: {err}\n")
    print("=== Conversion Complete ===")
if __name__ == "__main__":
    main()
