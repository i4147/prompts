import re
CM_PATTERN = re.compile(
    r"\bwith\s+(?:ThreadPoolExecutor|ProcessPoolExecutor)\s*"
    r"\([^()]* (?: \( [^()]* \) [^()]* )* \)\s*"
    r"as\s+(\w+)\s*:",
    re.DOTALL | re.VERBOSE,
)
def transform_code(code):
    original_code = code
    pool_vars = CM_PATTERN.findall(code)
    if not pool_vars:
        return code, False
    code = CM_PATTERN.sub(r"with multiprocessing.Pool(processes=8) as \1:", code)
    for var in pool_vars:
        code = re.sub(rf"\b{var}\.map\(", f"{var}.imap_unordered(", code)
        code = re.sub(rf"\b{var}\.submit\(", f"{var}.apply_async(", code)
        code = re.sub(
            rf"\bas_completed\(\s*{var}\b",
            f"# TODO: multiprocessing has no as_completed. Use {var}.imap_unordered or loop with .get()\n# as_completed({var}",
            code,
        )
    code = re.sub(r"^[ \t]*from\s+concurrent\.futures\s+import\s+.*?\n", "", code, flags=re.MULTILINE)
    if "import multiprocessing" not in code and "from multiprocessing" not in code:
        code = "import multiprocessing\n" + code
    if "apply_async" in code and "MIGRATION NOTE" not in code:
        note = "# MIGRATION NOTE: apply_async requires args as a tuple: pool.apply_async(func, (arg1, arg2))\n"
        code = note + code
    return code, code != original_code
def process_file(args):
    pass
