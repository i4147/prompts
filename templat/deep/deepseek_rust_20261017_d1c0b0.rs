//! Database reading and writing.
//!
//! ## Native format (documented deviation)
//!
//! ```text
//! magic   : 8 bytes  b"RSLOCATE"
//! version : 1 byte   0x01
//! records : repeated [u32 little-endian length][length bytes]
//! ```
//!
//! Records are length-prefixed, so arbitrary bytes (newlines, `0xff`, control
//! characters) round-trip exactly. Reading is streaming and uses O(1) memory.
//!
//! ## Plain-text fallback
//!
//! If the file does not start with the magic, it is read as newline-separated
//! paths. This makes hand-built fixtures and `find`-style lists usable, but it
//! cannot represent paths containing `\n`.

use std::fs::File;
use std::io::{self, BufRead, BufReader, Cursor, ErrorKind, Read, Write};
use std::path::Path;

/// Magic prefix of the native format.
pub const MAGIC: &[u8; 8] = b"RSLOCATE";
/// Native format version.
pub const VERSION: u8 = 1;

fn read_full<R: Read>(r: &mut R, buf: &mut [u8]) -> io::Result<usize> {
    let mut n = 0;
    while n < buf.len() {
        match r.read(&mut buf[n..]) {
            Ok(0) => break,
            Ok(k) => n += k,
            Err(e) if e.kind() == ErrorKind::Interrupted => continue,
            Err(e) => return Err(e),
        }
    }
    Ok(n)
}

fn read_exact_or_eof<R: Read>(r: &mut R, buf: &mut [u8]) -> io::Result<bool> {
    let n = read_full(r, buf)?;
    if n == 0 {
        Ok(false)
    } else if n == buf.len() {
        Ok(true)
    } else {
        Err(io::Error::new(ErrorKind::UnexpectedEof, "truncated record"))
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Format {
    Native,
    Plain,
}

/// Streaming reader over a locate database.
pub struct DbReader {
    inner: BufReader<Box<dyn Read>>,
    format: Format,
}

impl DbReader {
    /// Open `path`. `whole_file` reads the entire database into memory first
    /// (the `-m` strategy); the default streams.
    pub fn open(path: &Path, whole_file: bool) -> io::Result<Self> {
        let mut f = File::open(path)?;
        let mut magic = [0u8; 8];
        let n = read_full(&mut f, &mut magic)?;
        let format = if n == 8 && &magic == MAGIC {
            Format::Native
        } else {
            Format::Plain
        };
        let prefix = magic[..n].to_vec();

        let source: Box<dyn Read> = if whole_file {
            let mut all = prefix;
            f.read_to_end(&mut all)?;
            Box::new(Cursor::new(all))
        } else {
            Box::new(Cursor::new(prefix).chain(f))
        };

        let mut inner = BufReader::new(source);
        if format == Format::Native {
            let mut v = [0u8; 1];
            inner.read_exact(&mut v)?;
            if v[0] != VERSION {
                return Err(io::Error::new(
                    ErrorKind::InvalidData,
                    "unsupported database version",
                ));
            }
        }
        Ok(Self { inner, format })
    }

    /// Read the next path into `out`. Returns `false` at end of database.
    pub fn next_entry(&mut self, out: &mut Vec<u8>) -> io::Result<bool> {
        out.clear();
        match self.format {
            Format::Native => {
                let mut len = [0u8; 4];
                if !read_exact_or_eof(&mut self.inner, &mut len)? {
                    return Ok(false);
                }
                let n = u32::from_le_bytes(len) as usize;
                out.resize(n, 0);
                self.inner.read_exact(out)?;
                Ok(true)
            }
            Format::Plain => {
                let n = self.inner.read_until(b'\n', out)?;
                if n == 0 {
                    return Ok(false);
                }
                if out.last() == Some(&b'\n') {
                    out.pop();
                }
                Ok(true)
            }
        }
    }
}

/// Buffered writer for the native format.
pub struct DbWriter