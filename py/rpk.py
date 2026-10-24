import os
import sys
import shutil
import csv
import logging
import subprocess
from pathlib import Path
from multiprocessing import Pool, cpu_count, Manager
TMP_BASE = Path.home() / "tmp"
REPACK_DIR = TMP_BASE / "repack"
WHL_DIR = TMP_BASE / "whl"
LOG_FILE = TMP_BASE / "repack-errors.log"
def setup_logging():
    if not TMP_BASE.exists():
        TMP_BASE.mkdir(parents=True)
    logging.basicConfig(
        filename=LOG_FILE, level=logging.ERROR, format="%(asctime)s - %(levelname)s - %(message)s", filemode="w"
    )
def get_dist_info_dirs():
    return [d for d in Path(".").iterdir() if d.is_dir() and d.name.endswith(".dist-info")]
def resolve_sys_path(file_path_str, pkg_root_name):
    path = Path(file_path_str)
    parts = path.parts
    if parts[0] == "..":
        data_dir = f"{pkg_root_name}.data"
        clean_parts = [p for p in parts if p != ".."]
        if not clean_parts:
            return None, False
        top_folder = clean_parts[0].lower()
        if top_folder in ["bin", "scripts"]:
            return Path(data_dir) / "scripts" / Path(*clean_parts[1:]), True
        elif top_folder == "include":
            return Path(data_dir) / "headers" / Path(*clean_parts[1:]), True
        elif top_folder == "share":
            return Path(data_dir) / "data" / Path(*clean_parts[1:]), True
        else:
            return Path(data_dir) / "data" / Path(*clean_parts), True
    return path, True
def get_unique_filename(directory, filename):
    target = directory / filename
    if not target.exists():
        return target
    name_stem = target.stem
    suffix = target.suffix
    counter = 1
    while True:
        new_name = f"{name_stem}_{counter}{suffix}"
        new_target = directory / new_name
        if not new_target.exists():
            return new_target
        counter += 1
def process_package(args):
    dist_path_str, progress_queue = args
    dist_path = Path(dist_path_str)
    try:
        pkg_dname = dist_path.name
        pkg_base_name = pkg_dname.replace(".dist-info", "")
        temp_pkg_root = REPACK_DIR / pkg_base_name
        if temp_pkg_root.exists():
            shutil.rmtree(temp_pkg_root)
        temp_pkg_root.mkdir(parents=True)
        record_file = dist_path / "RECORD"
        if not record_file.exists():
            raise FileNotFoundError(f"RECORD file missing for {pkg_dname}")
        with open(record_file, "r", encoding="utf-8", errors="ignore") as rf:
            reader = csv.reader(rf)
            for row in reader:
                if not row:
                    continue
                rel_path_str = row[0]
                source_file = Path(rel_path_str)
                if not source_file.exists():
                    continue
                dest_rel_path, valid = resolve_sys_path(rel_path_str, pkg_base_name)
                if not valid:
                    continue
                dest_file = temp_pkg_root / dest_rel_path
                dest_file.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source_file, dest_file)
        dest_dist_info = temp_pkg_root / pkg_dname
        temp_build_dir = temp_pkg_root / "build_whl"
        temp_build_dir.mkdir()
        cmd = [sys.executable, "-m", "wheel", "pack", str(temp_pkg_root), "--dest-dir", str(temp_build_dir)]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(f"Wheel pack failed: {result.stderr}")
        generated_whl = next(temp_build_dir.glob("*.whl"), None)
        if generated_whl:
            final_target = get_unique_filename(WHL_DIR, generated_whl.name)
            shutil.move(str(generated_whl), str(final_target))
        else:
            raise FileNotFoundError(f"Wheel pack ran but produced no .whl for {pkg_dname}")
        shutil.rmtree(temp_pkg_root)
        progress_queue.put(1)
        return True
    except Exception as e:
        logging.error(f"Failed to repack {dist_path.name}: {str(e)}")
        progress_queue.put(1)
        return False
def main():
    if not Path("site-packages") in Path.cwd().parents and Path.cwd().name != "site-packages":
        print("Warning: Current directory does not look like a site-packages folder.")
        print(f"CWD: {os.getcwd()}")
    setup_logging()
    if not WHL_DIR.exists():
        WHL_DIR.mkdir(parents=True)
    dist_infos = get_dist_info_dirs()
    total_pkgs = len(dist_infos)
    if total_pkgs == 0:
        print("No .dist-info directories found.")
        return
    print(f"Found {total_pkgs} packages. Starting repack...")
    print(f"Logs: {LOG_FILE}")
    print(f"Output: {WHL_DIR}")
    m = Manager()
    q = m.Queue()
    tasks = [(str(p), q) for p in dist_infos]
    with Pool(processes=cpu_count()) as pool:
        result_async = pool.map_async(process_package, tasks)
        processed_count = 0
        while not result_async.ready():
            while not q.empty():
                q.get()
                processed_count += 1
            percent = (processed_count / total_pkgs) * 100
            sys.stdout.write(f"\rCompleted: {percent:.1f}% ({processed_count}/{total_pkgs})")
            sys.stdout.flush()
            time.sleep(0.1)
        while not q.empty():
            q.get()
            processed_count += 1
        sys.stdout.write(f"\rCompleted: 100.0% ({total_pkgs}/{total_pkgs})\n")
if __name__ == "__main__":
    try:
        import wheel
    except ImportError:
        print("Error: 'wheel' package is not installed. Please run: pip install wheel")
        sys.exit(1)
    import time
    main()
