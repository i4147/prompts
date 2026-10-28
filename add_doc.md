# Adding Docstrings to a Python Project with a Git-Aware AI Agent

There are two realistic paths: **use an existing agent** that already knows how to clone, branch, and open PRs, or **build a small custom agent** for full control. Below is the full playbook for both, plus the guardrails you need so the agent doesn't hallucinate docstrings or touch logic.

---

## 1. Pick your vehicle

| Option | Best for | Notes |
|---|---|---|
| **Claude Code / OpenAI Codex / Cursor agent** | Fastest to try | Point it at a repo, give a `CLAUDE.md`/`AGENTS.md` with rules, ask for docstrings |
| **Aider** (open source) | Scriptable, git-native | `aider --message "add Google-style docstrings" $(files)` auto-commits |
| **OpenHands / SWE-agent** | Fully autonomous runs | Can run tests, open PRs |
| **GitHub Copilot coding agent** | PR-based workflow | Assign an issue, it opens a PR |
| **Custom script** | Batch, reproducible, cheap | Best when the rules are strict (see §3) |

For a one-off cleanup, an existing agent is fine. For "run this on 200 files and enforce a style," build the small pipeline in §3.

---

## 2. Prepare the repo before any agent runs

This is the part people skip and then regret.

1. **Clean baseline**: `git status` is clean, on a fresh branch `docs/add-docstrings`.
2. **Add enforcement linters** so the agent (and CI) has a target:
   ```bash
   pip install ruff interrogate pydocstyle
   # ruff.toml
   # [lint.pydocstyle]
   # convention = "google"   # or numpy / pep257
   ```
   ```bash
   ruff check --select D .
   interrogate -vv .
   ```
3. **Make tests runnable** — the agent should be able to prove it didn't break anything.
4. **Add an `AGENTS.md` / `CLAUDE.md`** at repo root:
   ```md
   # Rules for AI agents
   - Only add or edit docstrings. Never change function bodies, signatures, or imports.
   - Use Google-style docstrings.
   - Preserve any existing docstring content; extend rather than replace.
   - Run `ruff check --select D .` and `pytest -q` before committing.
   - One commit per module.
   ```

---

## 3. Build a small custom agent (recommended for batch work)

The loop is: **find → contextualize → generate → apply → validate → commit**.

### 3a. Find the gaps with `ast`

Don't let the LLM decide which functions need docstrings — deterministically enumerate them:

```python
import ast, pathlib

def missing_docstrings(root="."):
    for path in pathlib.Path(root).rglob("*.py"):
        if any(p in path.parts for p in ("venv", ".venv", "build", "dist")):
            continue
        tree = ast.parse(path.read_text())
        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                if ast.get_docstring(node) is None:
                    yield path, node.lineno, node.name, type(node).__name__
```

This gives you a list of `(file, line, name, kind)` — the agent's work queue.

### 3b. Build minimal context per item

Fetch just enough for a good docstring — the signature, the body, and the module's existing style:

```python
def build_context(path, node):
    src = path.read_text()
    segment = ast.get_source_segment(src, node)          # the whole def
    module_doc = ast.get_docstring(ast.parse(src)) or "" # style hints
    return {
        "file": str(path),
        "source": segment,
        "module_docstring": module_doc,
        "existing_docstrings": _sample_docstrings(src, n=3),
    }
```

Sample a few existing docstrings so the model matches your house style (Google vs NumPy vs Sphinx).

### 3c. Generate as a *diff*, not a rewrite

Never let the agent return the whole file — it will drift. Ask for a minimal replacement of the function definition, then apply with a patch:

```python
PROMPT = """You are adding docstrings to Python code.

Rules:
- Only add a docstring. Do not change the signature, body, imports, or decorators.
- Google-style docstrings.
- Include Args, Returns, Raises, Yields only when applicable.
- If a docstring exists, leave it alone and return NO_CHANGE.
- Return ONLY the replacement function/class source, with no code fences.

Context:
{context}
"""
```

```python
def apply_patch(path, old_segment, new_segment):
    src = path.read_text()
    assert src.count(old_segment) == 1, "ambiguous match"
    path.write_text(src.replace(old_segment, new_segment))
```

Because you're replacing an exact AST segment, the diff is minimal and reviewable.

### 3d. Validate every change before committing

```python
import subprocess
def validate(path):
    subprocess.run(["python", "-m", "compileall", "-q", str(path)], check=True)
    subprocess.run(["ruff", "check", "--select", "D", str(path)], check=True)
    subprocess.run(["pytest", "-q"], check=True)
```

If validation fails, revert that file (`git checkout -- file`) and skip — don't let the agent "fix" its own bad output by rewriting logic.

### 3e. Git flow

```python
def commit(path, symbol):
    subprocess.run(["git", "add", str(path)], check=True)
    subprocess.run(
        ["git", "commit", "-m", f"docs: add docstrings to {symbol} ({path.name})"],
        check=True,
    )
```

Commit per file or per symbol. Push the branch and open a PR:

```bash
gh pr create --title "docs: add docstrings" --body "Generated docstrings, tests green, ruff D passes."
```

---

## 4. If you use an off-the-shelf agent instead

The workflow is the same but the agent drives git. Give it:

```
Goal: add Google-style docstrings to every public function and class in src/.
Constraints:
- Do not modify code outside docstrings.
- Run `ruff check --select D .` and `pytest -q` after each file.
- Commit per module and open a PR against main.
Start by running `interrogate -vv .` to find the gaps.
```

Aider example (batch, git-native):

```bash
aider --model claude-sonnet-4-5 \
      --message "Add Google-style docstrings to all public functions/classes in these files. Only touch docstrings. Run pytest before committing." \
      $(git ls-files 'src/**/*.py')
```

---

## 5. Guardrails that actually matter

- **Deterministic scoping.** Use `ast` / `interrogate` to pick targets — not the LLM. It will skip or invent functions otherwise.
- **Diff-only edits.** Reject any output that changes more than the docstring region. Compare the AST of the original and new file with the docstrings stripped — they must be structurally identical:
  ```python
  def same_logic(old_src, new_src):
      a, b = ast.parse(old_src), ast.parse(new_src)
      for t in (a, b): _strip_docstrings(t)
      return ast.dump(a) == ast.dump(b)
  ```
- **No network from the agent** when applying patches (if using a sandboxed runner) — prevents "helpful" package installs.
- **Rate/cost control.** Batch small items, cache contexts, skip trivial ones (`__init__` with no args, one-liners).
- **Human review.** Docstrings are documentation — a wrong `Raises:` section is worse than none. Require PR review.
- **Enforce in CI after the fact** so drift doesn't return:
  ```yaml
  - run: ruff check --select D .
  - run: interrogate --fail-under=95 .
  ```

---

## 6. A realistic end-to-end script skeleton

```python
import ast, pathlib, subprocess
from llm_client import generate  # your Claude/OpenAI wrapper

for path, lineno, name, kind in missing_docstrings("src"):
    node = _node_at(path, lineno)
    ctx  = build_context(path, node)
    new  = generate(PROMPT.format(context=ctx))
    if new.strip() == "NO_CHANGE":
        continue

    old_segment = ast.get_source_segment(path.read_text(), node)
    if not new.strip().startswith(("def ", "async def ", "class ")):
        continue  # reject anything that isn't a clean function/class replacement

    backup = path.read_text()
    apply_patch(path, old_segment, new)

    if not same_logic(backup, path.read_text()) or not validate(path):
        path.write_text(backup)   # revert
        continue

    commit(path, name)
```

Run it on a branch, eyeball the PR, then merge and flip on `interrogate --fail-under`.

---

## TL;DR

- **Scope with `ast`/`interrogate`, not the LLM.**
- **Generate minimal diffs** that only touch the docstring region.
- **Validate with `compileall` + `ruff --select D` + tests**; auto-revert on failure.
- **Commit per file, open a PR, require human review.**
- **Enforce afterward** in CI so the repo stays clean.

Off-the-shelf agents (Claude Code, Aider, OpenHands, Copilot coding agent) can do this today if you give them a tight `AGENTS.md` and a lint/test target; a ~150-line custom script gives you reproducible, cheap, and auditable runs for large codebases.