#!/usr/bin/env bash
#
# install_backends_termux.sh
# ==========================
#
# Install the subset of translate_words.py backends that actually works on
# Termux / Android 7 / 32-bit ARM (armv8l).
#
# What it does NOT install (because it cannot work on this platform):
#   - torch, sentencepiece, ctranslate2  → no 32-bit ARM wheels
#   - argostranslate, libretranslate     → depend on ctranslate2
#   - transformers, nllb, m2m100, opus_mt → depend on torch
#   - google-cloud-translate, yandexcloud → depend on grpcio (no armv8l wheel)
#
# What it DOES install:
#   - core:        loguru
#   - free:        deep_translator, translate, translators,
#                  googletrans==4.0.0rc1, pygoogletranslation
#   - api-key:     deepl, boto3, baidu-aip, ibm-watson,
#                  azure-ai-translation-text, aliyun-python-sdk-alimt
#   - llm (opt-in): openai, anthropic, mistralai  (with pydantic<2 fallback)
#
# Usage:
#   bash install_backends_termux.sh              # core + free
#   bash install_backends_termux.sh --api-keys   # add API-key backends
#   bash install_backends_termux.sh --llm        # add LLM SDKs
#   bash install_backends_termux.sh --all        # everything safe here
set -u
PYTHON="${PYTHON:-python}"
# Colors (Termux supports them)
if [ -t 1 ]; then
    BOLD="$(printf '\033[1m')"; DIM="$(printf '\033[2m')"
    RED="$(printf '\033[31m')";  GREEN="$(printf '\033[32m')"
    YELLOW="$(printf '\033[33m')"; BLUE="$(printf '\033[34m')"
    RESET="$(printf '\033[0m')"
else
    BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi
log()  { printf '%s\n' "${BLUE}▶${RESET} $*"; }
ok()   { printf '%s\n' "${GREEN}✓${RESET} $*"; }
warn() { printf '%s\n' "${YELLOW}⚠${RESET} $*" >&2; }
err()  { printf '%s\n' "${RED}✗${RESET} $*" >&2; }
SUCCEEDED=(); FAILED=()
install_pkg() {
    local spec="$1"
    log "pip install ${BOLD}${spec}${RESET}"
    if "$PYTHON" -m pip install --verbose --no-deps "$spec"; then
        ok "installed ${spec}"
        SUCCEEDED+=("$spec")
    else
        err "failed: ${spec}"
        FAILED+=("$spec")
    fi
}
install_group() {
    local name="$1"; shift
    [ "$#" -eq 0 ] && return
    printf '\n%s\n' "${BOLD}=== ${name} ===${RESET}"
    for spec in "$@"; do install_pkg "$spec"; done
}
# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
WANT_API=0
WANT_LLM=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --api-keys) WANT_API=1;;
        --llm)      WANT_LLM=1;;
        --all)      WANT_API=1; WANT_LLM=1;;
        -h|--help)  sed -n '2,30p' "$0"; exit 0;;
        *) err "Unknown option: $1"; exit 2;;
    esac
    shift
done
# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------
ARCH="$(uname -m)"
log "Python: $("$PYTHON" --version 2>&1)"
log "Arch:   ${ARCH}"
log "Pip:    $("$PYTHON" -m pip --version 2>&1)"
if ! "$PYTHON" -m pip --version >/dev/null 2>&1; then
    err "pip not available. Run: pkg install python"
    exit 1
fi
# Termux system deps that some pure-Python packages need at runtime
# (nodejs for translators' pyexecjs, libxml2/libxslt for lxml fallbacks)
#if command -v pkg >/dev/null 2>&1; then
#    log "Installing Termux system deps (nodejs, libxml2, libxslt, libjpeg-turbo)"
#    pkg install -y nodejs libxml2 libxslt libjpeg-turbo >/dev/null 2>&1 \
#        || warn "some system packages failed; continuing"
#fi
# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
#install_group "Core"          loguru
#install_group "Tier 1 (free, reliable)" deep_translator translate
install_group "Tier 2 (free scrapers)"  \
     pygoogletranslation translators
if [ "$WANT_API" -eq 1 ]; then
    install_group "Tier 3a (API-key, pure Python — best on Termux)" \
        deepl boto3 "baidu-aip" ibm-watson \
        azure-ai-translation-text aliyun-python-sdk-alimt
    install_group "Tier 3b (API-key, may fail on 32-bit)" \
        yandexcloud google-cloud-translate
fi
#if [ "$WANT_LLM" -eq 1 ]; then
    # Pin pydantic<2 first so the Rust-based pydantic-core is not required.
#    install_group "LLM pre-req (pydantic<2 to avoid Rust build)" "pydantic<2"
#    install_group "Tier 5 (LLM SDKs)" openai anthropic mistralai
#fi
# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n%s\n' "${BOLD}=== Summary ===${RESET}"
printf '  installed: %d\n' "${#SUCCEEDED[@]}"
printf '  failed:    %d\n' "${#FAILED[@]}"
if [ "${#FAILED[@]}" -gt 0 ]; then
    printf '\n%s\n' "${RED}Failed:${RESET}"
    for p in "${FAILED[@]}"; do printf '  - %s\n' "$p"; done
    printf '\n%s\n' "${DIM}translate_words.py will fall back automatically — missing backends are OK.${RESET}"
fi
cat <<'EOF'
Recommended fallback order on Termux armv8l / Android 7
-------------------------------------------------------
  1. deepl              (if DEEPL_API_KEY is set — best quality)
  2. deep_translator    (no key needed; wraps Google/MyMemory/Libre/Pons)
  3. translate          (no key needed; multi-engine)
  4. translators        (needs nodejs — Bing/Yandex/etc.)
  5. googletrans        (fragile; keep as last-ditch)
Run with:
  python translate_words.py -i words.txt -t en -b deepl
  python translate_words.py -i words.txt -t en -b deep_translator
EOF
