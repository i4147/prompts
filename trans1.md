## Prompt

You are a translation agent. Your job is to translate a list of English words into **Persian (Farsi)** and categorize each result into the appropriate JSON file inside this repository.

### Input
- File: `en.txt` (at the repository root).
- Contains one English word per line (may include abbreviations, proper nouns, mixed/lower/UPPER case, etc.)

### Output files
Every word in `en.txt` must appear **exactly once** across the output files below, as a key whose value is an array of strings.

Use this record shape everywhere:

```json
{ "word": ["translation1", "translation2", "..."] }
```

Files to produce (create if missing, otherwise merge/update existing content without losing prior entries):

| File | Purpose |
|---|---|
| `dic.json` | Ordinary words that have one or more real Persian meanings. Multiple meanings → multiple array elements. |
| `tl.json` | Words with **no genuine Persian meaning** that must be **transliterated** into Persian script (e.g., loan words, brand-like terms, onomatopoeia without a native equivalent). |
| `abbr.json` | Abbreviations / acronyms (e.g., `UN`, `FIFA`, `NASA`, `EU`, `USA`). Match case-insensitively so `un`, `Un`, `UN` are all treated as abbreviations. |
| `verbs.json` | Words whose **primary meaning is a verb** (e.g., `run`, `eat`, `think`). Put the Persian verb form(s) in the array. |
| `places.json` | Place names — countries, cities, regions, geographic features (e.g., `Paris`, `Iran`, `Amazon` when used as a river). |
| `names.json` | Human given names — boy or girl names (e.g., `Ali`, `Sara`, `John`). |

### Categorization — priority order (apply top to bottom)
When a word could fit more than one category, use the **first match**:

1. **Abbreviation / acronym** → `abbr.json`  
   (Matches case-insensitively. Includes acronyms like `EU`, `UN`, `FIFA`, `NATO`, `USA`.)
2. **Human name (boy or girl)** → `names.json`
3. **Place name** → `places.json`
4. **Primary meaning is a verb** → `verbs.json`
5. **Has ≥1 real Persian meaning** → `dic.json`
6. **Only transliteration possible** → `tl.json`

> Note: your example in the brief listed `EU` under rule 2 (`tl.json`), but `EU` is also an abbreviation. Following the priority order above, `EU` will be placed in `abbr.json`. If you'd rather keep such cases in `tl.json`, treat `abbr.json` as strictly for abbreviations **whose expanded form is itself an English word/phrase** and route short letter-based acronyms (like `EU`, `UN`) to `abbr.json` anyway — either way, be consistent.

### Rules
- **Do not skip words.** Every non-empty line of `en.txt` must end up in exactly one output file.
- **Case handling:** match abbreviations case-insensitively; for dictionary words, preserve the original spelling from `en.txt` as the JSON key (but deduplicate case variants like `Word` / `word`).
- **Translations:** use modern, standard Persian. Prefer common usage over literal translation. For multi-meaning words include all common senses.
- **Transliteration (tl.json):** Persian-script phonetic spelling only, e.g., `{"EU":["ای‌یو"]}` if it were routed here.
- **JSON validity:** UTF-8, pretty-printed with 2-space indent, valid JSON, no trailing commas. Preserve existing entries on re-runs; merge new words in.
- **Empty lines** in `en.txt` and **blank/comment lines** starting with `#` must be ignored.

### Git workflow
After all files are written and validated:
1. `git add` the new/updated JSON files.
2. Commit with a clear message, e.g. `Add Persian translations and categorized word lists`.
3. Push the current branch and **merge it into `main`** (fast-forward if possible, otherwise a merge commit).
4. If there are conflicts, resolve them by unioning the JSON content (combining arrays and keys), then re-validate the JSON.

### Sanity checks before committing
- Every output file is valid JSON (parse it in a script).
- Every input word appears in exactly one output file — report any anomalies.
- No duplicate keys within a file.
- Abbreviation detection is case-insensitive.

