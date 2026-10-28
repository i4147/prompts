## 1. Better matching / filtering
- **Regex support**  
  `--regex` / `-E`  
  Treat `--remove` and `--replace` patterns as regex, with capture groups:
  ```bash
  pnr.py -s --regex "IMG_(\d+)" "photo_\1"
  ```
- **Case-insensitive matching**  
  `-i` / `--ignore-case`
- **Include / exclude glob patterns**  
  `--include "*.jpg"`  
  `--exclude "*backup*"`  
  `--exclude-dir ".git"`
- **File type filters**  
  `--ext jpg,png,pdf`  
  `--files-only`  
  `--dirs-only`
- **Hidden files control**  
  `--hidden` / `--no-hidden`
- **Depth limit**  
  `--max-depth 2`
- **Skip symlinks / follow symlinks**  
  `--follow-symlinks` or keep skipping them.
## 2. Safety and conflict handling
- **Overwrite policy**  
  Currently you auto-use `unique_path`. Add:
  ```bash
  --overwrite
  --backup
  --unique
  --force
  --interactive
  ```
- **Undo support**  
  Log every rename to a JSON/CSV file:
  ```bash
  --log renames.json
  --undo renames.json
  ```
- **Transaction-style rollback**  
  If one rename fails, optionally undo previous renames.
- **Verbose / quiet output**  
  `-v` / `--verbose`  
  `-q` / `--quiet`
- **Log file**  
  `--log-file pnr.log`
## 3. More rename operations
- **Prefix / suffix**  
  `--prefix "new_"`  
  `--suffix "_final"`
- **Case conversion**  
  `--lower`  
  `--upper`  
  `--title`  
  `--snake`  
  `--kebab`  
  `--camel`
- **Whitespace cleanup**  
  `--trim`  
  `--collapse-spaces`  
  `--spaces-to-underscores`
- **Unicode normalization / transliteration**  
  `--normalize-unicode`  
  `--ascii`  
  `--remove-diacritics`
- **Sanitize filenames**  
  Remove or replace characters illegal on Windows/Linux/macOS:
  ```bash
  --sanitize
  ```
- **Truncate long names**  
  `--max-length 120`
- **Random names**  
  `--random`  
  `--uuid`
- **Date/time based names**  
  `--date-format "%Y-%m-%d"`  
  Use file mtime/ctime:
  ```bash
  --rename-by-mtime
  ```
## 4. Better template / numbering
Your `--template` is a good start. Add:
- **Start number**  
  `--start 1`
- **Step**  
  `--step 2`
- **Explicit padding**  
  `--padding 4`
- **Custom format string**  
  ```bash
  --format "{template}{number:03}{ext}"
  ```
- **Preserve original name**  
  ```bash
  --format "{template}_{original}{ext}"
  ```
- **Extension filtering for templates**  
  Only renumber `*.jpg`.
- **Natural sort**  
  `--sort natural`  
  Instead of plain `sorted(files)`.
- **Sort by mtime / size / name / random**  
  ```bash
  --sort mtime
  --sort size
  --reverse
  ```
- **Template directories too**  
  Currently `rename_by_template` only handles files.
## 5. Traversal and scope
- **Current directory only vs recursive**  
  You already have `--recursive`, but add:
  ```bash
  --depth N
  --include-dir PATTERN
  --exclude-dir PATTERN
  ```
- **Root path argument**  
  ```bash
  pnr.py -r "old" /path/to/dir
  ```
- **Multiple paths**  
  ```bash
  pnr.py -r "old" dir1 dir2 dir3
  ```
- **Dry-run summary**  
  Show counts by file type, conflicts, skipped items.
## 6. Metadata / automation
- **Rename by EXIF date**  
  `--exif-date`
- **Rename by music tags**  
  `--id3`
- **Rename by PDF title**  
  `--pdf-title`
- **Rename using CSV mapping**  
  ```bash
  --map mapping.csv
  ```
- **Config file**  
  `.pnr.toml` with default include/exclude/sort rules.
- **Shell completion**  
  Generate completions for bash/zsh/fish.
## 7. UX improvements
- **Preview table**  
  Show old name, new name, status.
- **Colorized output**  
  `--color auto|always|never`
- **Progress bar**  
  For large directories.
- **JSON output**  
  `--json` for scripting.
- **Exit codes**  
  Distinguish no-op, partial failure, complete failure.
## 8. Fun / extra features
- `--leet` → `file.txt` to `f1l3.txt`
- `--spongebob` → `DoNt_Do_ThIs.txt`
- `--random-emoji-prefix`
- `--pirate` → replace words with pirate slang
- `--slugify` → web-safe names
- `--obfuscate` → random but reversible with mapping log
## 9. Bugs / limitations worth fixing first
Before adding lots of features, fix these:
1. **Recursive rename bug**  
   In `remove_string_from_names` and `replace_string_in_names`, you rename `item`, then check `item.is_dir()`. After rename, `item` no longer exists, so recursion into renamed directories may be skipped.
2. **`should_skip` is too broad**  
   It checks `path.parts`, so if any parent directory name matches `SKIP_DIRS`, everything below may be skipped. Better to check only the current relative path parts.
3. **No overwrite control**  
   You always call `unique_path`, which is safe but may surprise users who want `--overwrite` or `--backup`.
4. **Template mode ignores directories**  
   Decide whether `--template` should rename directories too.
5. **No case-insensitive or regex support**  
   These are probably the highest-value additions.
## Recommended highest-value flags to add first
```bash
--regex
--ignore-case
--include
--exclude
--files-only
--dirs-only
--hidden
--max-depth
--overwrite
--backup
--interactive
--yes
--log
--undo
--sort
--start
--step
--padding
--format
--verbose
--quiet
```
- transliterate flag, that convert non-english fnames like persian arabic  chinese,japanese,korean to equivalent english (just transliterate)
return full type-annotated code in one markdown block, no docstrings & no comments
