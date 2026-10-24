//! Command-line parsing for `locate`.
//!
//! Supports short options, grouped short options (`-ic`), attached values
//! (`-l10`), long options (`--limit 10`, `--limit=10`), repeated options, and
//! the `--` terminator. Patterns are kept as raw bytes so non-UTF-8 names
//! survive end to end.

use crate::error::LocateError;
use std::ffi::OsString;
use std::os::unix::ffi::OsStrExt;
use std::path::PathBuf;

/// Parsed `locate` invocation.
#[derive(Debug, Clone)]
pub struct Options {
    /// Patterns, byte-preserved.
    pub patterns: Vec<Vec<u8>>,
    /// `-b`: match the basename only.
    pub basename: bool,
    /// `-c`: print only a count.
    pub count: bool,
    /// Databases to search, in order.
    pub databases: Vec<PathBuf>,
    /// `-e`: only report existing paths.
    pub existing: bool,
    /// `-i`: ASCII case-insensitive matching.
    pub ignore_case: bool,
    /// `-l`: maximum number of entries (0 == unlimited).
    pub limit: Option<usize>,
    /// `-m`: read the whole DB into memory instead of streaming.
    pub whole_file: bool,
    /// `-L`: follow symlinks when testing existence. Default false (`-P`).
    pub follow: bool,
    /// `-0`: NUL-separated output.
    pub null: bool,
    /// `-S`: print database statistics.
    pub statistics: bool,
    /// `-r`: treat patterns as regular expressions.
    pub regex: bool,
    /// `--help`.
    pub help: bool,
    /// `--version`.
    pub version: bool,
}

impl Default for Options {
    fn default() -> Self {
        Self {
            patterns: Vec::new(),
            basename: false,
            count: false,
            databases: Vec::new(),
            existing: false,
            ignore_case: false,
            limit: None,
            whole_file: false,
            follow: false,
            null: false,
            statistics: false,
            regex: false,
            help: false,
            version: false,
        }
    }
}

fn push_databases(dst: &mut Vec<PathBuf>, spec: &str) {
    for part in spec.split(':') {
        if !part.is_empty() {
            dst.push(PathBuf::from(part));
        }
    }
}

fn take_value(raw: &[OsString], i: usize, opt: &str) -> Result<String, LocateError> {
    raw.get(i)
        .map(|s| s.to_string_lossy().into_owned())
        .ok_or_else(|| LocateError::Usage(format!("option '{opt}' requires an argument")))
}

fn parse_limit(s: &str) -> Result<usize, LocateError> {
    s.parse::<usize>()
        .map_err(|_| LocateError::Usage(format!("invalid limit '{s}'")))
}

impl Options {
    /// Parse arguments (including `argv[0]`).
    pub fn parse<I: IntoIterator<Item = OsString>>(args: I) -> Result<Self, LocateError> {
        let mut raw: Vec<OsString> = args.into_iter().collect();
        if !raw.is_empty() {
            raw.remove(0);
        }
        let mut o = Options::default();
        let mut i = 0usize;
        let mut after_dd = false;

        while i < raw.len() {
            let arg = &raw[i];
            let bytes = arg.as_os_str().as_bytes();

            if after_dd || bytes.first() != Some(&b'-') || bytes.len() == 1 {
                o.patterns.push(bytes.to_vec());
                i += 1;
                continue;
            }
            if bytes == b"--" {
                after_dd = true;
                i += 1;
                continue;
            }

            if bytes.starts_with(b"--") {
                let s = std::str::from_utf8(&bytes[2..])
                    .map_err(|_| LocateError::Usage("invalid option".into()))?;
                let (name, val) = match s.split_once('=') {
                    Some((n, v)) => (n, Some(v.to_string())),
                    None => (s, None),
                };
                let takes_arg = matches!(name, "database" | "limit");
                if val.is_some() && !takes_arg {
                    return Err(LocateError::Usage(format!(
                        "option '--{name}' doesn't allow an argument"
                    )));
                }
                match name {
                    "help" => o.help = true,
                    "version" => o.version = true,
                    "basename" => o.basename = true,
                    "wholename" => o.basename = false,
                    "count" => o.count = true,
                    "existing" => o.existing = true,
                    "ignore-case" => o.ignore_case = true,
                    "mmap" => o.whole_file = true,
                    "stdio" => o.whole_file = false,
                    "follow" => o.follow = true,
                    "nofollow" => o.follow = false,
                    "null" => o.null = true,
                    "statistics" => o.statistics = true,
                    "regex" | "regexp" => o.regex = true,
                    "database" => {
                        let v = match val {
                            Some(v) => v,
                            None => {
                                i += 1;
                                take_value(&raw, i, "--database")?
                            }
                        };
                        push_databases(&mut o.databases, &v);
                    }
                    "limit" => {
                        let v = match val {
                            Some(v) => v,
                            None => {
                                i += 1;
                                take_value(&raw, i, "--limit")?
                            }
                        };
                        o.limit = Some(parse_limit(&v)?);
                    }
                    _ => {
                        return Err(LocateError::Usage(format!(
                            "unrecognized option '--{name}'"
                        )))
                    }
                }
                i += 1;
                continue;
            }

            // Short option cluster.
            let cluster = &bytes[1..];
            let mut j = 0usize;
            while j < cluster.len() {
                let c = cluster[j];
                match c {
                    b'b' => o.basename = true,
                    b'w' => o.basename = false,
                    b'c' => o.count = true,
                    b'e' => o.existing = true,
                    b'i' => o.ignore_case = true,
                    b'm' => o.whole_file = true,
                    b's' => o.whole_file = false,
                    b'L' => o.follow = true,
                    b'P' => o.follow = false,
                    b'0' => o.null = true,
                    b'S' => o.statistics = true,
                    b'r' => o.regex = true,
                    b'd' | b'l' => {
                        let rest = &cluster[j + 1..];
                        let v = if !rest.is_empty() {
                            String::from_utf8_lossy(rest).into_owned()
                        } else {
                            i += 1;
                            take_value(&raw, i, if c == b'd' { "-d" } else { "-l" })?
                        };
                        if c == b'd' {
                            push_databases(&mut o.databases, &v);
                        } else {
                            o.limit = Some(parse_limit(&v)?);
                        }
                        j = cluster.len();
                        continue;
                    }
                    _ => {
                        return Err(LocateError::Usage(format!(
                            "invalid option -- '{}'",
                            c as char
                        )))
                    }
                }
                j += 1;
            }
            i += 1;
        }

        if o.databases.is_empty() {
            if let Ok(p) = std::env::var("LOCATE_PATH") {
                push_databases(&mut o.databases, &p);
            }
            if o.databases.is_empty() {
                let d = std::env::var("LOCATE_DB")
                    .unwrap_or_else(|_| "/var/lib/locatedb".to_string());
                push_databases(&mut o.databases, &d);
            }
        }
        Ok(o)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse(args: &[&str]) -> Options {
        let mut v = vec![OsString::from("locate")];
        v.extend(args.iter().map(OsString::from));
        Options::parse(v).unwrap()
    }

    #[test]
    fn grouped_short_options() {
        let o = parse(&["-ic", "foo"]);
        assert!(o.ignore_case && o.count);
        assert_eq!(o.patterns, vec![b"foo".to_vec()]);
    }

    #[test]
    fn attached_limit() {
        assert_eq!(parse(&["-l10", "x"]).limit, Some(10));
    }

    #[test]
    fn long_with_equals() {
        assert_eq!(parse(&["--limit=3", "x"]).limit, Some(3));
    }

    #[test]
    fn dd_terminator() {
        let o = parse(&["--", "-foo"]);
        assert_eq!(o.patterns, vec![b"-foo".to_vec()]);
    }

    #[test]
    fn unknown_is_usage_error() {
        let mut v = vec![OsString::from("locate"), OsString::from("--nope")];
        assert!(Options::parse(std::mem::take(&mut v)).is_err());
    }
}