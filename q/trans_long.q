**Task:** Write a single, self-contained, well-annotated Python 3.12 script called `translate_words.py` that translates a word-list file (one word per line) into a JSON mapping. **Target environment:** Termux on Android 7, 32-bit ARM (`armv8l`), with strict hardware constraints.
## Hard Constraints & Target Environment
**System Requirements:**
- OS: Termux on Android 7 (bionic libc, not glibc)
- Python: 3.12 (validate at startup)
- Architecture: `armv8l` (32-bit ARM only)
- Memory: Processes are memory-constrained; design accordingly
**Forbidden Dependencies** (no wheels, source builds fail on this platform):
- `torch`, `ctranslate2`, `sentencepiece`, `grpcio`, `pydantic-core`, and any package requiring them
- Machine learning frameworks: `transformers`, `opus_mt`, `nllb`, `m2m100`, `argostranslate`, `libretranslate` self-hosted
- Cloud SDKs with compiled extensions: `google-cloud-translate`, `yandex_cloud`
- LLM SDKs by default: `openai`, `anthropic`, `mistralai` (they pull `pydantic>=2`)
**Hard Rules:**
- Do not import, register, or reference forbidden backends—even lazily—because fallback noise confuses users. Hard-code only viable backends.
- No systemd, no daemons, no Docker. Plain single process.
- Do not name the script `translate.py` (causes import collisions with the `translate` package).
## Core Functionality
**Input/Output:**
- Read a plain-text file: one word per line.
- Translate each word from source language to target language.
- Write results to JSON as `{"source_word": "translated_word"}` mapping (preserve input order).
- Collect failed words (after 3 retry attempts) in a separate `failed.txt` file (one per line).
**Resilience & Recovery:**
- Resume from previous job by default (load existing output JSON, skip already-translated words).
- Survive `Ctrl+C` gracefully (save current state before exit).
- Survive process OOM-kill: atomic writes (temp → rename) every 50 words; no final-save-only strategy.
- Retry failed translations: up to 3 attempts with exponential backoff per word.
- Retry triggers: backend exception OR identity translation (output matches input, case-insensitive, or empty/whitespace).
## Command-Line Interface
| Flag | Default | Description |
|---|---|---|
| `-i`, `--input` | `words.txt` | Input file (one word per line). |
| `-o`, `--output` | `words.json` | Output JSON file. |
| `--failed` | `failed.txt` | Words that failed all retries. |
| `-s`, `--source` | `fr` | Source language code (ISO 639-1 or backend-specific). |
| `-t`, `--target` | `en` | Target language code. |
| `-b`, `--backend` | (fallback order) | Preferred backend (see list below). |
| `-w`, `--workers` | `2` | Concurrent worker threads. **Keep ≤ 2 for Termux memory.** |
| `-d`, `--delay` | `0.5` | Seconds between requests (per worker; Termux IPs often shared, rate-limit-prone). |
| `--save-every` | `50` | Save JSON every N words (not 100; OOM-kill on older Android loses less work). |
| `--no-continue` | (off) | Do not resume; start fresh. |
## Supported Backends
### Tier 1: Recommended (pure Python, reliable)
- **`deep_translator`** (default)  
  `pip install deep_translator`  
  Wraps Google, MyMemory, Libre, Pons, Yandex, Microsoft, Baidu. Uses `requests` + `beautifulsoup4`.
- **`deepl`**  
  `pip install deepl`  
  Requires `DEEPL_API_KEY` env var. Best quality for European languages. Uses `requests`.
### Tier 2: Free Scrapers (pure Python, fragile)
- **`translate`**  
  `pip install translate`  
  Accepts `translate.Translator` (source/target params) or `translate.GoogleTranslator` variants. **Warn if import resolves to the script itself.**
- **`translators_bing`**  
  `pip install translators` + `pkg install nodejs` (needs `pyexecjs` JS runtime).  
  Register as `translators_bing` (same pattern for `translators_yandex`, etc.).
- **`googletrans`**  
  `pip install "googletrans==4.0.0rc1"`  
  Unofficial Google endpoint, fragile; last resort.
- **`pygoogletranslation`**  
  `pip install pygoogletranslation`  
  Maintained fork of `googletrans`.
### Tier 3: Cloud Providers (pure Python, API-key required)
- **`boto3`**: AWS Translate. `pip install boto3`.
- **`baidu`**: Chinese-focused. `pip install baidu-aip`.
- **`alibaba`**: Chinese-focused. `pip install aliyun-python-sdk-alimt`.
- **`watson`**: IBM Watson. `pip install ibm-watson`.
- **`azure`**: Azure Translator. `pip install azure-ai-translation-text`. Works with key-based auth (no MSAL).
### Offline Alternative: Remote LibreTranslate
For true offline use on Termux, run a **LibreTranslate server on another machine (PC/VPS/Raspberry Pi)** and call it from Termux via `deep_translator`:
```python
from deep_translator import LibreTranslateTranslator
t = LibreTranslateTranslator(source="fr", target="en", api_url="http://192.168.1.50:5000")
```
Implement a `_make_libretranslate_remote()` factory that reads `LIBRETRANSLATE_URL` from env and registers backend `libretranslate_remote` (pure Python `requests`).
### Default Fallback Order (if user doesn't specify `-b`)
1. `deepl` (only if `DEEPL_API_KEY` is set)
2. `deep_translator`
3. `libretranslate_remote` (only if `LIBRETRANSLATE_URL` is set)
4. `translate`
5. `translators_bing`
6. `googletrans`
7. `pygoogletranslation`
## Backend Implementation
**Factory Pattern:**
- Each backend lives behind a factory function `_make_<name>(source, target, script_path) → callable`.
- Factory returns `(text: str) → str` or raises `BackendError`.
- Register all factories in `_BACKEND_FACTORIES` dict.
- Wrapper iterates the fallback chain; first successful init is used.
- On failed init: log `WARNING` with loguru, continue to next.
- On success after fallback: print `⚠️  Backend 'X' unavailable — falling back to 'Y'.`
**Thread Safety:**
- **Fresh client per call** (safe defaults): `deep_translator`, `translate`, `deepl`, `boto3`, `baidu`, `alibaba`, `watson`, `azure`, `libretranslate_remote`. Creating per-call clients is cheap vs. network latency.
- **Single serialized instance** (not thread-safe): `googletrans`, `pygoogletranslation`. Use `threading.Lock` to serialize calls.
- **Heavyweight subprocess per call**: `translators_bing` (JS runtime overhead on Termux). Serialize with `threading.Lock` and log throughput warning.
**Language-Code Mapping:**
- Maintain per-backend `_LANG_MAP` dict (don't pass raw user input to API).
- Examples: DeepL → `FR`, `EN-US`; `deep_translator` → `fr`, `en`; `boto3` → `fr`, `en`; `baidu` → `fra`, `en`.
- Unknown codes: fall back to raw user value; log `WARNING`.
**Error Handling:**
- Define custom exception: `class BackendError(Exception): ...`
- If user passes `-b` with a forbidden backend name, exit immediately with clear message: "Backend 'X' is not available on Termux 32-bit ARM because [reason]. Use '-b deep_translator' or one of [alternatives]."
## Translation Logic
**Retry Strategy:**
- Attempt each word up to **3 times**.
- Trigger retry on:
  1. Backend raises exception.
  2. Backend returns identity translation (case-insensitive match via `casefold()`, or empty/whitespace-only response).
- On all 3 attempts failing: do NOT write to output JSON; append word to `failed.txt` (thread-safe); log `ERROR` with word quoted (for easy grepping).
- Failed words are retryable in future runs with a different backend.
## Output & State Management
**Console Output:**
- As each translation arrives, print: `[n/total] ✓ word -> translation` or `[n/total] ✗ word (failed → failed.txt)`.
- All console output to stdout (guarded by lock); do not interleave with loguru messages.
**Atomic Saves:**
- Write output JSON every `--save-every` words (default **50**) using write-to-temp-then-rename pattern.
- Never corrupt file on interrupted write.
**Resume Support:**
- At startup, if output JSON exists and `--no-continue` is not set: load it, skip already-translated words, print count loaded.
- Pending list = words from input minus words already in output.
**Graceful Interrupt:**
- Catch `KeyboardInterrupt` (`Ctrl+C`), save state, print save location, exit cleanly.
## Logging
Use **loguru**. Remove default stderr sink; install two sinks:
1. **Rotating file sink** at `translate_words.log`:
   - Level: DEBUG
   - Rotation: 5 MB (not 100 MB; Termux storage is tight on older devices)
   - Retention: 3 files max
   - Format: timestamped, include level and thread name, UTF-8
2. **Compact stderr sink**:
   - Level: ERROR (immediate visibility of failures)
**Logging Levels:**
- `WARNING`: every backend fallback, every per-attempt failure
- `ERROR`: final give-up on a word (include word quoted for grepping)
## Concurrency, Memory & Rate Limiting
- Use `ThreadPoolExecutor(max_workers=N)` where N defaults to **2** (Termux-friendly).
- User can raise with `-w`, but default must be safe.
- Sleep **`--delay` seconds** before every individual request (default **0.5**; free scrapers on shared IPs are rate-limit-prone).
- **Memory design:**
  - Stream input file when building pending list; avoid loading entire input twice.
  - Keep only `results` dict (unavoidable) and `pending` list (bounded by input size).
  - Do NOT print entire `results` dict anywhere (can be very large).
- **Lock per concern:** file writes, shared counter, console output, `failed.txt` appends (avoid global lock contention).
## Code Quality & Documentation
**Code:**
- Return **full annotated code** in one block.
- Docstring on every function.
- Inline comments on non-obvious lines.
- No placeholder or omitted sections.
- Header docstring: explain Termux target, list supported backends, clearly state excluded backends and why.
- Fail fast on user error: missing input file, unknown backend, unavailable backend on platform, missing env var. Provide actionable messages.
- Be Python 3.8+ compatible, depend only on stdlib + `loguru` + user-selected backends.
- Never import a native-dependency package at module scope.
**Companion Documentation Section** (after code):
1. **Termux Prerequisites:**
   - Exact `pkg` commands: `pkg update && pkg upgrade`, `pkg install python`, `pkg install nodejs` (if using translators), `pkg install libxml2 libxslt libjpeg-turbo` (if transitive deps need `lxml`/Pillow).
2. **Backend Installation Commands:**
   - Exact `pip install` lines for each Tier, plus remote LibreTranslate setup.
3. **Concrete Bash Snippet:**
   - Fresh Termux install from scratch (copy-paste ready).
4. **Six Example Invocations:**
   - Default run
   - DeepL with API key
   - Free backend (e.g., `deep_translator` + Google)
   - `translators_bing` with Node installed
   - Remote LibreTranslate
   - `--no-continue` fresh run
5. **Limitations & Workarounds:**
   - Exactly which backends cannot work on Termux 32-bit ARM and why.
   - LAN LibreTranslate workaround for offline use.
strip comments and docstrings from final code (except module docstring)
return fully annotated code 
