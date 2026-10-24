Act as a principal systems software engineer. I want you to rewrite the classic Linux utilities "[locate]" (and its companion helper "[updatedb]") completely from scratch in Rust.

Your design constraints are strict: prioritize execution speed, minimal memory overhead, and minimal crate dependencies.

Please follow these exact structural guidelines:

### 1. Reference & Standard Specification
* Base your implementation strictly on the behavior and core flags of the standard Linux [locate] utility. 
* At the very beginning of your response, explicitly state the exact version or release specification of the tool you are using as your reference design (e.g., "Based on GNU findutils version 4.10.0" or "Based on mlocate 0.26").

### 2. Dependency Philosophy (Least Crates Possible)
* Avoid large framework crates or deep dependency trees. 
* Do NOT pin exact versions in the Cargo.toml dependencies (use loose versioning like `*` or general minor boundaries like `^0.x` to let cargo resolve the latest compatible versions).
* Only use external crates if they are absolutely essential for low-level systems operations (such as `walkdir` for fast filesystem traversal or a minimal byte-serialization crate if raw performance demands it). Prefer the Rust standard library (`std`) wherever possible.

### 3. Required Project Structure
Provide the complete codebase broken down into the following explicit code blocks:

* Cargo.toml: Define the project metadata and the minimal dependency list without rigid version pins.
* Main Engine / Shared Library: If the tools rely on a shared logic backend (such as a shared database file layout), isolate this core logic into a modular design.
* Binary 1 ([locate]): The primary user-facing lookup CLI tool. It must handle argument parsing natively (or via a minimal token matcher) to avoid heavy dependencies.
* Binary 2 ([updatedb]): The system background indexer/builder daemon or script. Focus heavily on efficient multi-threading (using std::thread or std::sync) and raw I/O performance.

### 4. Implementation Details
* Ensure proper POSIX exit codes are implemented.
* Use idiomatic, safe Rust with zero unhandled panics (`expect` or `unwrap` should be properly replaced with safe `Result`/`Option` match patterns).
* Optimize for modern SSD/NVMe data structures if a binary storage file is being maintained.

Provide the full, production-ready Rust source code files wrapped in clean markdown blocks. No placeholders, no pseudocode.
