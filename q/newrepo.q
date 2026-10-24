
Task: Write a Python 3.12 command-line script that automates creating a new GitHub repository and initializing/pushing a local project to it. The script is designed to run under Termux on Android.

Shebang: #!/data/data/com.termux/files/usr/bin/python3.14

Standard library only. Allowed modules: argparse, json, os, shutil, subprocess, sys, urllib.request, urllib.error, datetime, pathlib, and typing. Do not use requests or any third-party packages.

---

Purpose

A CLI tool that:

1. Creates a GitHub repository via the GitHub REST API.
2. Sets up a local project directory (if it doesn't exist).
3. Initializes git, creates a default branch, adds/commits initial content.
4. Pushes the initial commit to the new GitHub repo.

CLI (via argparse)

· name (positional): repository name.
· --path (optional, default None): local project path. If omitted, use ./<name>.
· --description (default ""): repository description.
· --private (flag): create a private repository.
· --branch (default "main"): default branch name.
· --token (default None): GitHub personal access token.
· --env-file (default "~/.env"): path to a .env-style file that may contain GITHUB_TOKEN.

Token Resolution Logic

Resolve the GitHub token in this priority order:

1. --token argument.
2. GITHUB_TOKEN environment variable.
3. GITHUB_TOKEN parsed from the .env file (simple KEY=VALUE parsing; strip surrounding quotes).

If no token is found, print an error to stderr and exit with a non-zero status.

API Interaction

· Implement a helper using urllib.request (stdlib only) that sends JSON payloads, decodes JSON responses, and sets headers:
  · Authorization: token <TOKEN>
  · Accept: application/vnd.github+json
  · User-Agent: repo-init-script
  · Content-Type: application/json (only when a payload is present)
· Handle HTTP errors gracefully using urllib.error.HTTPError; return (status_code, parsed_body_or_raw_text) — always attempt json.loads, fall back to decoded text.
· On any other API error, print the error and exit with a non-zero status.

Repository Creation

· POST https://api.github.com/user/repos with {"name": ..., "private": ..., "description": ..., "auto_init": False}.
· On 201: return the response body.
· On 422 with an "already exists" style error: treat as success and fetch the existing repo (GET https://api.github.com/repos/{owner}/{name}) instead of failing.
· On any other API error, print the error and exit with a non-zero status.

Authenticated User Lookup

· Provide a helper that calls GET /user to retrieve the authenticated username. Used as a fallback when determining the repo owner for constructing URLs.
· Exit with an error if this call fails.

Local Git Setup

· Create the project directory (including parents) if it doesn't exist.
· Initialize a git repository if .git doesn't exist.
· Create/checkout the specified branch (git checkout -B <branch>).
· Create or update the origin remote to the repo's HTTPS clone URL.
· Create/update .gitignore (default entries like __pycache__/, *.env, .DS_Store, .vscode/).
· Write a default README.md with project name, description (or placeholder), and creation date.
· Only if there are staged changes, commit with message "Initial commit"; otherwise print that there's nothing to commit.
· Push to origin on the specified branch with upstream tracking (git push -u origin <branch>). If the push fails, print a warning to stderr instead of crashing.

Utilities

· A small subprocess wrapper (run(...)) for running shell commands with consistent options: cwd, output capture, check.
· A helper to check whether the gh CLI is available on the system (even if not strictly required by the main flow).

Output / Flow

· Print progress messages at each major step (creating repo, setting up local project, etc.).
· Print a final confirmation message showing the repository's URL on GitHub.
· The script's main() function should orchestrate argument parsing, token resolution, repo creation, local setup, and commit/push in sequence.
· Guard with if __name__ == "__main__": main().

Deliverable

A single self-contained .py file using only the standard library, cleanly organized into functions (get_token, api_request, create_github_repo, get_authenticated_user, init_git_repo, ensure_gitignore, ensure_readme, commit_and_push, run, is_gh_available, main), with type hints and concise docstrings.
