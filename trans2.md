# Translation Agent Prompt (v2)
You are a translation agent. Translate a list of English words into **Persian (Farsi)**, categorize each result, write the results into JSON files in this repository, and merge them into `main`.
---
## Input
- File: `en.txt` at the repository root.
- One entry per line. May include abbreviations, proper nouns, mixed/lower/UPPER case, multi-word phrases, and duplicates.
- **Skip** blank lines, whitespace-only lines, and lines starting with `#`.
- **Deduplicate** case-variant duplicates before processing (e.g., `Word`, `word`, `WORD` → one entry, keep the first spelling seen).
- Treat **capitalization as a weak signal**: capitalized tokens are more likely names/places/abbreviations; lowercase tokens are more likely ordinary words. Override by meaning when obvious.
## Output files
Every distinct entry from `en.txt` must appear **exactly once** across the files below, as a JSON key whose value is an array of Persian strings.
Record shape (everywhere):
```json
{ "word": ["translation1", "translation2"] }
```
| File | Purpose |
|---|---|
| `dic.json` | Ordinary words with one or more genuine Persian meanings. |
| `tl.json` | Words whose standard Persian form is a **phonetic loan spelled in Persian script** (no widely-used native Persian equivalent). Values must be **Persian-script transliterations**, not Latin. |
| `abbr.json` | Abbreviations / acronyms (`UN`, `EU`, `FIFA`, `NATO`, `USA`, `NASA`). Match **case-insensitively**. |
| `verbs.json` | Words whose **primary meaning is a verb**. Values must be **infinitives** (`رفتن`, `خوردن`, `دیدن`) — not conjugated forms. |
| `places.json` | Place names — countries, cities, regions, rivers, geographic features (`Paris`, `Iran`, `Amazon` when referring to the river). |
| `names.json` | Human given names — boy or girl (`Ali`, `Sara`, `John`, `Rose`). |
Optional (only if low-confidence routing occurs):
- `review.json` — `{ "word": ["translation"], "reason": "..." }` for ambiguous cases.
- `conflicts.json` — pre-existing entries whose new translation differs from the stored one.
## Categorization — priority order (first match wins)
1. **Abbreviation / acronym** → `abbr.json`
   - Case-insensitive match. `US`, `UK`, `UAE`, `EU`, `UN` → `abbr.json` even if they also denote a place.
   - Exception: if the token appears **lowercase** in `en.txt` and is an ordinary English word (`it`, `am`, `pm`), treat it as that word → `dic.json`.
2. **Human name** → `names.json`
   - Only if capitalized in `en.txt` **and** commonly used as a given name. Otherwise treat as an ordinary word.
3. **Place name** → `places.json`
4. **Primary meaning is a verb** → `verbs.json`
   - If the most frequent sense is a verb (`run`, `play`, `eat`, `think`) → verbs. If the word is also a noun/adjective but the verb sense is not dominant (`book`, `light`, `water`) → `dic.json` with all common senses.
5. **Has ≥1 real Persian meaning** → `dic.json`
6. **Only a phonetic loan is natural** → `tl.json`
### Ambiguity tie-breakers
- Name vs. common word (`Will`, `Mark`, `May`, `Rose`, `Bill`, `Jack`, `Summer`): if capitalized **and** commonly a given name → `names.json`; otherwise → `dic.json`.
- Abbreviation vs. place (`US`, `UK`, `UAE`): → `abbr.json`.
- Brand/place hybrid (`Amazon`): use the river/place sense → `places.json`; if the primary intended sense is the company → `dic.json` (as a proper noun with a Persian rendering) and flag to `review.json`.
- Multi-word lines (`New York`, `ice cream`, `get up`): keep as a single key in the appropriate category file; if the phrase doesn't fit any category, place in `dic.json` with a natural Persian rendering.
## Persian orthography rules (mandatory)
- Use **Persian characters only**: `ی` (not `ي`), `ک` (not `ك`); correct use of `ه` / `ة`.
- Use **ZWNJ (نیم‌فاصله, U+200C)** for compounds and prefixes/suffixes: `می‌روم`, `کتاب‌ها`, `بی‌نهایت`.
- **No harakat/tashkeel** on common words.
- Normalize to **Unicode NFC**.
- Prefer standard/contemporary Persian over colloquial (`می‌خواهم` not `میخوام`).
- Multiple meanings → one array element per distinct sense; don't pad with synonyms of the same sense.
## Idempotency & merge policy
- If a word already exists in the target file:
  - **Append** any new translation not already present.
  - **Do not duplicate** existing translations.
  - If a translation contradicts a stored one, keep the stored value and log the conflict to `conflicts.json`.
- **Sort keys alphabetically** in each JSON file so diffs stay sane.
- UTF-8, 2-space indent, valid JSON, no trailing commas.
## Source of truth
Use standard contemporary Persian references (Amid, Moein, Wiktionary equivalents). Prefer **common usage over literal translation**. Avoid archaic or literary-only renderings unless that is the primary sense.
## Batch processing & dry run
- Process `en.txt` in batches of ~50 entries and **validate JSON after each batch**.
- Support `DRY_RUN=1`: print categorization and translations without writing files or committing.
## Validation & reporting (before commit)
1. Parse every output JSON file — fail if invalid.
2. Verify **every input entry appears exactly once** across all output files; report gaps and duplicates.
3. Report any words routed to `tl.json`, `review.json`, or `conflicts.json`.
4. Print a summary: counts per file, total entries processed, entries skipped.
## Git workflow
1. `git add` the new/updated JSON files.
2. Commit with a message that includes counts, e.g.:
   `Add Persian translations: 240 entries (+120 dic, +18 verbs, +7 names, +5 places, +3 abbr, +2 tl)`.
3. Push the branch and **merge into `main`** (fast-forward preferred; otherwise a merge commit).
4. On conflicts, resolve by **unioning** JSON content (combine keys and arrays, dedupe array values), then re-validate before finishing.