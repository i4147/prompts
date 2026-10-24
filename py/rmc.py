import argparse
import ast
import sys
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path
from tree_sitter import Language, Parser
import tree_sitter_python as tspython
PY_LANGUAGE = Language(tspython.language())
parser = Parser(PY_LANGUAGE)
def walk_files(root):
    try:
        for entry in root.iterdir():
            if entry.is_symlink():
                continue
            if entry.is_dir():
                if entry.name in {".git", "__pycache__", ".venv", "venv", "node_modules"}:
                    continue
                yield from walk_files(entry)
            elif entry.is_file() and entry.suffix == ".py":
                yield entry
    except PermissionError:
        pass
def get_node_text(source, node):
    return source[node.start_byte : node.end_byte].decode("utf-8")
def is_shebang(node, source):
    if node.type != "comment":
        return False
    text = get_node_text(source, node)
    return text.strip().startswith("#!")
def is_special_comment(node, source):
    if node.type != "comment":
        return False
    text = get_node_text(source, node).strip()
    return text.startswith("# fmt") or text.startswith("# type") or text.startswith("# noqa")
def is_module_docstring(node):
    if node.type != "expression_statement":
        return False
    parent = node.parent
    return parent is not None and parent.type == "module"
def is_docstring_node(node):
    if node.type != "expression_statement":
        return False
    if len(node.children) != 1:
        return False
    child = node.children[0]
    return child.type == "string"
def get_body_node(node):
    for child in node.children:
        if child.type == "block":
            return child
    return None
def process_file(filepath, preserve_module_docstring):
    try:
        source_bytes = filepath.read_bytes()
    except Exception as e:
        print(f"Error reading {filepath}: {e}", file=sys.stderr)
        return (filepath, 0)
    tree = parser.parse(source_bytes)
    source_bytes_array = bytearray(source_bytes)
    removals = []
    def traverse(node):
        if node.type == "comment":
            if not is_shebang(node, source_bytes) and not is_special_comment(node, source_bytes):
                end_byte = node.end_byte
                if end_byte < len(source_bytes) and source_bytes[end_byte : end_byte + 1] == b"\n":
                    end_byte += 1
                removals.append((node.start_byte, end_byte))
            return
        if is_docstring_node(node):
            should_remove = True
            if preserve_module_docstring and is_module_docstring(node):
                should_remove = False
            if should_remove:
                parent = node.parent
                body_node = get_body_node(parent) if parent else None
                if body_node:
                    other_children = [
                        c for c in body_node.children if c.type != "expression_statement" or not is_docstring_node(c)
                    ]
                    if not other_children:
                        indent = " " * (node.start_point[1])
                        replacement = f"{indent}pass\n"
                        removals.append((body_node.start_byte, body_node.end_byte, replacement))
                        return
                end_byte = node.end_byte
                while end_byte < len(source_bytes) and source_bytes[end_byte : end_byte + 1] in (b" ", b"\t"):
                    end_byte += 1
                if end_byte < len(source_bytes) and source_bytes[end_byte : end_byte + 1] == b"\n":
                    end_byte += 1
                removals.append((node.start_byte, end_byte))
            return
        for child in node.children:
            traverse(child)
    traverse(tree.root_node)
    if not removals:
        return (filepath, 0)
    removals.sort(key=lambda x: x[0], reverse=True)
    result_bytes = bytearray(source_bytes)
    for removal in removals:
        start, end = removal[0], removal[1]
        if len(removal) == 3:
            replacement = removal[2].encode("utf-8")
            result_bytes[start:end] = replacement
        else:
            result_bytes[start:end] = b""
    try:
        result_text = result_bytes.decode("utf-8")
        ast.parse(result_text)
    except SyntaxError as e:
        print(f"Syntax error after processing {filepath}: {e}", file=sys.stderr)
        print("Skipping this file to avoid corruption.", file=sys.stderr)
        return (filepath, 0)
    if result_bytes == source_bytes:
        return (filepath, 0)
    try:
        filepath.write_bytes(result_bytes)
    except Exception as e:
        print(f"Error writing {filepath}: {e}", file=sys.stderr)
        return (filepath, 0)
    return (filepath, len(removals))
def collect_files(paths):
    files = []
    for path in paths:
        if not path.exists():
            print(f"Warning: {path} does not exist, skipping.", file=sys.stderr)
            continue
        if path.is_symlink():
            continue
        if path.is_file():
            if path.suffix == ".py":
                files.append(path)
        elif path.is_dir():
            files.extend(walk_files(path))
    return files
def main():
    parser_arg = argparse.ArgumentParser(description="Remove comments and docstrings from Python files")
    parser_arg.add_argument("paths", nargs="*", help="Files or directories to process (default: current directory)")
    parser_arg.add_argument(
        "-r", "--preserve-module-docstring", action="store_true", help="Preserve module-level docstrings"
    )
    parser_arg.add_argument("-j", "--jobs", type=int, default=None, help="Number of parallel jobs (default: CPU count)")
    args = parser_arg.parse_args()
    if not args.paths:
        paths = [Path(".")]
    else:
        paths = [Path(p) for p in args.paths]
    files = collect_files(paths)
    if not files:
        print("No Python files found to process.")
        return
    print(f"Processing {len(files)} Python file(s)...")
    total_removals = 0
    files_modified = 0
    with ProcessPoolExecutor(max_workers=args.jobs) as executor:
        futures = {executor.submit(process_file, f, args.preserve_module_docstring): f for f in files}
        for future in as_completed(futures):
            filepath, removals = future.result()
            if removals > 0:
                print(f"{filepath}: {removals} comment(s)/docstring(s) removed")
                total_removals += removals
                files_modified += 1
    print(f"\nDone. Modified {files_modified} file(s), removed {total_removals} comment(s)/docstring(s).")
if __name__ == "__main__":
    main()
