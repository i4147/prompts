from __future__ import annotations
import argparse
import os
import sys
import tempfile
from pathlib import Path
def convert(data: bytes) -> bytes:
    """Normalize CRLF and lone CR to LF without changing other bytes."""
    return data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
def convert_file(path: Path, *, keep_date: bool = False) -> bool:
    """Convert a file in place. Return True if its contents changed."""
    original_stat = path.stat()
    data = path.read_bytes()
    converted = convert(data)
    if converted == data:
        return False
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir="/data/data/com.termux/files/usr/tmp")
    try:
        with os.fdopen(fd, "wb") as temp:
            temp.write(converted)
            temp.flush()
            os.fchmod(temp.fileno(), original_stat.st_mode)
        os.replace(temp_name, path)
        if keep_date:
            os.utime(path, ns=(original_stat.st_atime_ns, original_stat.st_mtime_ns))
    except BaseException:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass
        raise
    return True
def main() -> int:
    parser = argparse.ArgumentParser(description="Convert DOS/Windows and classic Mac line endings to Unix LF.")
    parser.add_argument(
        "-k",
        "--keepdate",
        action="store_true",
        help="preserve the file's access and modification times",
    )
    parser.add_argument("files", nargs="+", metavar="FILE")
    args = parser.parse_args()
    status = 0
    for name in args.files:
        try:
            if name == "-":
                sys.stdout.buffer.write(convert(sys.stdin.buffer.read()))
                continue
            path = Path(name)
            changed = convert_file(path, keep_date=args.keepdate)
            print(f"{name}: {'converted' if changed else 'no change'}")
        except (OSError, ValueError) as exc:
            print(f"dos2unix: {name}: {exc}", file=sys.stderr)
            status = 1
    return status
if __name__ == "__main__":
    raise SystemExit(main())
