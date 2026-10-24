**Task:** Write a single Python 3.12 script `translate_chunks.py` for Termux (Android 7, 32-bit ARM `armv8l`) that reads a text file, splits it into 2500-char chunks, translates each chunk, and writes results to a JSON file.
## Hard Constraints
- **Platform:** Termux Android 7, `armv8l` (32-bit), Python 3.12
- **Forbidden:** `torch`, `ctranslate2`, `sentencepiece`, `grpcio`, `pydantic-core`, LLM SDKs (without `pydantic<2`)
- **Memory:** Limit to 4 workers, 0.5s delay between requests
- **No daemons, Docker, systemd**
## Core Behavior
1. **Chunking:** Split input file into **2500-char chunks** (preserve word boundaries where possible; don't split mid-word).
2. **Translation:** Translate each chunk as a unit (not line-by-line).
3. **Retry:** Up to 3 attempts per chunk; exponential backoff.
4. **Output:** JSON file with chunk index and translated text: `{"0": "translated chunk 0", "1": "translated chunk 1", ...}`
5. **Resume:** Load existing output JSON; skip already-translated chunks.
6. **Atomic saves:** Write every 10 chunks (temp → rename).
7. **Failed chunks:** Append to `failed.txt` with chunk index.
8. **Graceful exit:** `Ctrl+C` saves and exits cleanly.
## CLI Options
| Flag | Default | Description |
|---|---|---|
| `-i`, `--input` | `input.txt` | Input text file. |
| `-o`, `--output` | `chunks.json` | Output JSON file. |
| `--failed` | `failed.txt` | Failed chunk indices. |
| `-s`, `--source` | `en` | Source language code. |
| `-t`, `--target` | `fr` | Target language code. |
| `-b`, `--backend` | (fallback order) | Translator backend. |
| `-w`, `--workers` | `2` | Concurrent threads (keep ≤ 2). |
| `-d`, `--delay` | `0.5` | Seconds between requests. |
| `--chunk-size` | `2500` | Chars per chunk. |
| `--save-every` | `10` | Save JSON every N chunks. |
| `--no-continue` | (off) | Start fresh, ignore existing output. |
## Supported Backends
**Tier 1 (recommended):**
- `deep_translator` (default)
- `deepl` — `pip install deepl` (requires `DEEPL_API_KEY`)
**Tier 2 (free, fragile):**
- `translate` — `pip install translate`
- `translators_bing` — `pip install translators` + `pkg install nodejs`
- `googletrans` — `pip install "googletrans==4.0.0rc1"`
- `pygoogletranslation` — `pip install pygoogletranslation`
**Tier 3 (cloud, pure Python):**
- `boto3`, `baidu`, `alibaba`, `watson`, `azure`
**Fallback order:** `deepl` (if `DEEPL_API_KEY` set) → `deep_translator` → `translate` → `translators_bing` → `googletrans` → `pygoogletranslation`
## Implementation
- Use `loguru` for logging (DEBUG to file, ERROR to stderr).
- `ThreadPoolExecutor` with `--workers` (default 2).
- Per-backend factory functions `_make_<name>(source, target)` → callable.
- Thread-safe clients: fresh per call for most; serialized with lock for `googletrans`/`pygoogletranslation`.
- Language-code mapping per backend (not raw user input).
- Identity translation (output ≈ input, case-insensitive) triggers retry.
- Atomic writes: temp file → rename.
- Full docstrings, inline comments, no omitted code.
## Chunking Details
- **Split on word boundaries:** don't break mid-word. Scan backwards from 2500 chars to find last space.
- **Whitespace handling:** strip leading/trailing whitespace from each chunk before translating.
- **Output format:** preserve chunk order in JSON (use integer keys: `"0"`, `"1"`, ...).
- **Empty chunks:** skip (don't translate or output).
add any convension or suggestion( like tenacity) you have,
you can use any 3rdparty lib needed
return fully annotated code
