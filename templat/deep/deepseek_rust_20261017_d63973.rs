#![forbid(unsafe_code)]
//! Core logic for the `locate` and `updatedb` reimplementation.
//!
//! Everything that can be unit tested without spawning a process lives here.
//! The two `src/bin/*.rs` files are thin argument-parsing wrappers.
pub mod db;
pub mod error;
pub mod glob;
pub mod matcher;
pub mod options;
pub mod regex;
pub mod walk;
/// Help text for `locate`. Kept byte-identical to `tests/golden/locate-help.txt`.
pub const LOCATE_HELP: &str = "\
Usage: locate [OPTION]... [PATTERN]...
Search for entries in a locate database.
  -b, --basename         match only the base name of path names
  -c, --count            only print number of found entries
  -d, --database DBPATH  use DBPATH instead of default database
  -e, --existing         only print entries for currently existing files
  -i, --ignore-case      ignore case distinctions when matching patterns
  -l, --limit LIMIT      limit output to LIMIT entries (0 means no limit)
  -m, --mmap             read the whole database into memory
  -P, --nofollow         do not follow symbolic links when testing existence (default)
  -L, --follow           follow symbolic links when testing existence
  -0, --null             separate entries with NUL on output
  -S, --statistics       print statistics about the database
  -w, --wholename        match the whole path name (default)
  -r, --regex            interpret patterns as extended regular expressions
  -s, --stdio            stream the database with buffered I/O (default)
      --help             display this help and exit
      --version          output version information and exit
";
/// Version string for `locate`. Kept byte-identical to the golden file.
pub const LOCATE_VERSION: &str = "locate (locate-rs) 0.1.0";
/// Help text for `updatedb`.
pub const UPDATEDB_HELP: &str = "\
Usage: updatedb [OPTION]...
Build or update a locate database.
  -o, --output FILE      write the database to FILE
  -l, --localpaths DIRS  colon-separated list of directories to index
  -U, --netpaths DIRS    alias for --localpaths
  -v, --verbose          report progress on stderr
      --help             display this help and exit
      --version          output version information and exit
";
/// Version string for `updatedb`.
pub const UPDATEDB_VERSION: &str = "updatedb (locate-rs) 0.1.0";