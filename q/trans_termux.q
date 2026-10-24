**Task:** Write a single, self-contained, well-annotated Python 3 script called `translate_words.py` that translates a word-list file line by line into a JSON mapping, targeted specifically at a **Termux environment on Android 7 running 32-bit ARM (`armv8l`)**. Deliver the complete script in one code block with docstrings, inline comments, and a short usage section at the end.
## Target environment (hard constraints)
- **OS:** Termux on Android 7 (bionic libc, not glibc).
- python version 3.12
- **Architecture:** `armv8l` — 32-bit ARM only. No `aarch64` wheels, no `manylinux` wheels usable, everything either has a pure-Python wheel or must build from source.
- **No `torch`, no `ctranslate2`, no `sentencepiece`, no `grpcio`, no `pydantic-core`** — none of these publish 32-bit ARM wheels, and source builds fail on Termux Android 7.
- **No systemd, no daemons, no Docker.** Plain process, plain files.
Everything in the script must run inside these constraints. Do **not** import, register, or reference any backend that requires the forbidden native dependencies above — even behind a lazy import — because the fallback chain would just log noise and confuse the user. Hard-code the Termux-viable fallback chain.
## Purpose
Read a plain-text file containing one word per line, translate each word from a source language to a target language using a configurable translation backend, and write the results to a JSON file as a simple `{"source_word": "translated_word"}` mapping. The script must be resilient to API rate limits, safe to interrupt, memory-frugal (32-bit Android processes are memory-constrained), and able to resume a previous job.
## Command-line interface
The script must expose the following options via `argparse`:
| Flag | Default | Description |
|---|---|---|
| `-i`, `--input` | `words.txt` | Input file with one word per line. |
| `-o`, `--output` | `words.json` | Output JSON file containing the `{word: translation}` map. |
| `--failed` | `failed.txt` | File collecting words that failed all retries, one per line. |
| `-s`, `--source` | `fr` | Source language code. |
| `-t`, `--target` | `en` | Target language code. |
| `-b`, `--backend` | `deep_translator` | Preferred backend (see list below). |
| `-w`, `--workers` | `2` | Number of concurrent worker threads. **Default to 2** — 32-bit Termux is memory-tight, and 4+ threads with `requests` sessions can OOM. |
| `-d`, `--delay` | `0.5` | Delay in seconds between requests, per worker. **Default 0.5** — free scrapers on Termux are more likely to trigger rate limits because the phone IP is often shared. |
| `--save-every` | `50` | Save the output file every N words. **Default 50** instead of 100, so an Android OOM-kill loses less work. |
| `--no-continue` | off | Do not resume from a previous job; start fresh. |
## Backend handling
Support only the backends that are known to install and run on **Termux `armv8l` / Android 7**. All backend imports must be lazy, so the script runs if the user has only installed a subset.
### Supported backends (Termux-viable only)
**Tier 1 — recommended, pure Python, reliable:**
- `deep_translator` — `pip install deep_translator`. **Default backend.** Wraps Google, MyMemory, Libre, Pons, Yandex, Microsoft, Baidu. Pure Python (`requests` + `beautifulsoup4`).
- `deepl` — `pip install deepl`. Requires `DEEPL_API_KEY` env var. Best quality for European languages. Pure Python (`requests`).
**Tier 2 — free scrapers, pure Python, fragile:**
- `translate` — `pip install translate`. Accepts either `translate.Translator` (upstream, `from_lang` / `to_lang`) or `translate.GoogleTranslator` (forks, `source` / `target`). Detect when `import translate` resolves to the running script itself (common footgun when the script is named `translate.py`) and skip with a clear warning.
- `googletrans` — `pip install "googletrans==4.0.0rc1"`. Unofficial Google endpoint, fragile; keep as last resort.
- `pygoogletranslation` — `pip install pygoogletranslation`. Maintained fork of `googletrans`. Same caveats.
- `translators_bing` — `pip install translators` plus `pkg install nodejs` (because `translators` uses `pyexecjs`, which needs a JS runtime). Register Bing specifically as `translators_bing`. Same pattern can be extended to `translators_yandex`, etc.
**Tier 3 — API-key cloud providers that install cleanly on 32-bit ARM:**
- `boto3` — `pip install boto3`. AWS Translate. Pure Python.
- `baidu` — `pip install baidu-aip`. Strong for Chinese. Pure Python.
- `alibaba` — `pip install aliyun-python-sdk-alimt`. Strong for Chinese. Pure Python.
- `watson` — `pip install ibm-watson`. IBM Watson. Usually installs.
- `azure` — `pip install azure-ai-translation-text`. Azure Translator. Usually installs; key-based auth works without MSAL.
### Explicitly NOT supported (do not include, do not try to import)
The following must be **absent** from the script. They have no usable 32-bit ARM path on Termux Android 7 and attempting them wastes the user's time:
- `argostranslate` (depends on `ctranslate2`)
- `libretranslate` self-hosted (depends on `ctranslate2` + `sentencepiece`)
- `opus_mt`, `nllb`, `m2m100`, `transformers` (all depend on `torch`)
- `google-cloud-translate`, `yandex_cloud` (depend on `grpcio` / `protobuf` compiled extensions)
- `torch`, `sentencepiece`, `ctranslate2`, `pydantic-core` (no `linux_armv8l` wheels)
- LLM SDKs `openai`, `anthropic`, `mistralai` **by default**, because they pull `pydantic>=2` → `pydantic-core` (Rust). If you want to include them, gate them behind a `--experimental-llm` flag and document that the user must `pip install "pydantic<2"` first.
If the user passes `-b` with a forbidden name, exit with a clear message explaining why that backend is not available on their platform and pointing to the offline alternative below.
### Offline alternative for Termux
Since no local offline MT engine works on this platform, document in the header docstring and in the post-run "next steps" that the recommended offline setup is to run a **LibreTranslate server on another machine on the LAN** (PC / VPS / Raspberry Pi) and call it via `deep_translator`'s `LibreTranslateTranslator`:
```python
from deep_translator import LibreTranslateTranslator
t = LibreTranslateTranslator(source="fr", target="en",
                             api_url="http://192.168.1.50:5000")
```
Provide a small `_make_libretranslate_remote` factory that reads `LIBRETRANSLATE_URL` from the environment and registers it as backend `libretranslate_remote`. This is pure Python (`requests`) and works fine on Termux — the heavy lifting happens on the LAN machine.
### Default fallback order on Termux
Use this order unless the user overrides it with `-b`:
1. `deepl` (only if `DEEPL_API_KEY` is set)
2. `deep_translator`
3. `libretranslate_remote` (only if `LIBRETRANSLATE_URL` is set)
4. `translate`
5. `translators_bing`
6. `googletrans`
7. `pygoogletranslation`
### Backend implementation rules
- Each backend lives behind a single factory function `_make_<name>(source, target, script_path)` that returns a callable `(text: str) -> str` or raises `BackendError`.
- Register each factory in `_BACKEND_FACTORIES`; the wrapper iterates over the fallback chain and picks the first that initializes successfully.
- On any failed initialization, log at `WARNING` with loguru and continue to the next backend. On success after fallback, print `⚠️  Backend 'X' unavailable — falling back to 'Y'.`
- **Thread safety:**
  - `deep_translator`, `translate`, `deepl`, `boto3`, `baidu`, `alibaba`, `watson`, `azure`, `libretranslate_remote`: fresh client per call — these libraries are not documented as thread-safe, and creating per-call clients is cheap compared to the network round trip.
  - `googletrans`, `pygoogletranslation`: reuse a single instance serialized by a `threading.Lock` (they hold HTTP session state and are not thread-safe).
  - `translators_bing`: `translators` spins up a subprocess per call for the JS runtime, which is heavyweight on Termux — serialize calls with a lock and log a warning that throughput is low.
- **Language-code mapping:** keep a per-backend `_LANG_MAP` dict rather than passing user input through. Examples: DeepL wants uppercase (`FR`, `EN-US` for some targets); `deep_translator` accepts lowercase; `boto3` wants `fr` / `en`; `baidu` wants `fra` / `en`. Unknown codes should fall back to the raw value.
## Translation rules
For each pending word, attempt translation up to **3 times** with gentle exponential backoff between attempts.
A retry is triggered by **either** of the following:
1. The backend raises an exception.
2. The backend returns the **identity translation** — the returned text matches the input (compare case-insensitively with `casefold()`), or the response is empty / whitespace-only. This catches services that silently return the source text when a term is unknown.
If all 3 attempts fail, do **not** write the word to the output JSON. Instead, append the word to `failed.txt` (one word per line, thread-safe), and log the failure with loguru at `ERROR` level. Failed words remain retryable in a future run with a different `-b`.
## Output behavior
- **Live console output:** as each translation arrives, print a line showing the word and the raw result exactly as returned, then a compact progress line: `[n/total] ✓ word -> translation` or `[n/total] ✗ word (failed -> failed.txt)`.
- **Atomic saves:** write the output JSON every `--save-every` words (default **50** for Termux) using a write-to-temp-then-rename strategy so an interrupted write can never corrupt the file. Termux on Android 7 can be OOM-killed at any moment; never rely on a final save.
- **Resume support:** at startup, if the output JSON exists and `--no-continue` is not set, load it and skip any words already present. Print how many were loaded.
- **Graceful interrupt:** catch `KeyboardInterrupt` (`Ctrl+C` in Termux), save the current state, print where progress was saved, and exit cleanly.
## Logging
Use **loguru** for all error and diagnostic logging. Remove the default stderr sink and install two sinks:
1. A rotating file sink at `translate_words.log` (DEBUG level, `5 MB` rotation, retain 3 files, UTF-8, timestamped format including level and thread name). **Keep rotation small (5 MB / 3 files)** because Termux storage on older devices is tight.
2. A compact stderr sink at ERROR level for immediate visibility.
Console progress and translation prints go to stdout (guarded by a lock) and must not interleave with loguru messages. Log every backend fallback at `WARNING`, every per-attempt failure at `WARNING`, and every final give-up at `ERROR` with the word quoted for easy grepping.
## Concurrency, memory, and rate limiting
- Use a `ThreadPoolExecutor` with `--workers` threads. **Default 2.** The user can raise it with `-w`, but the default must be Termux-friendly.
- Sleep `--delay` seconds before every individual request (**default 0.5**).
- Avoid loading the entire input into memory twice. Stream the input file when building the pending list; only keep the `results` dict (which is unavoidable) and the `pending` list (which is bounded by input size). For a word list of tens of thousands of words this is fine, but do not build a second full copy of the word list.
- Avoid printing the entire `results` dict anywhere — it can be large.
- Use separate locks for file writes, the shared counter, console output, and `failed.txt` appends.
- Preserve the input order of successfully translated words in the final JSON.
## Code quality requirements
- Return the **full annotated code** in a single block — docstrings on every function, inline comments on non-obvious lines, and no placeholder or omitted sections.
- Include a header docstring at the top explaining the Termux target, listing the supported backends, and stating clearly which backends are excluded and why.
- After the code, add a companion section covering:
  1. **Termux prerequisites:** `pkg update && pkg upgrade`, `pkg install python`, `pkg install nodejs` (only if using `translators`), `pkg install libxml2 libxslt libjpeg-turbo` (for `lxml`/Pillow transitive deps).
  2. **Install commands for the supported backends** — the exact `pip install` lines for Tier 1, Tier 2, Tier 3, and the remote LibreTranslate option.
  3. **A concrete example `bash` snippet** for a fresh install on Termux.
  4. **At least six example invocations** of `translate_words.py`: default run, DeepL with an API key, a free backend, `translators_bing` with Node installed, remote LibreTranslate, and a `--no-continue` fresh run.
  5. **A "limitations" note** listing exactly which backends cannot work on Termux 32-bit ARM and why, plus the LAN LibreTranslate workaround for offline use.
- Fail fast and clearly on user error (missing input file, unknown backend, unavailable backend on this platform, missing env var), with actionable messages.
- Be Python 3.8+ compatible, depend only on the standard library plus `loguru` and the user-selected backends, and never import a native-dependency package at module scope.
- Treat the fallback chain as best-effort: a missing backend should log one warning and move on; it must never crash the script.
