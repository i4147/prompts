//! Error type shared by both binaries.
use std::fmt;
/// An error that maps to a process exit code.
#[derive(Debug)]
pub enum LocateError {
    /// Bad command line: maps to exit code 2.
    Usage(String),
    /// Runtime failure: maps to exit code 1.
    Other(String),
}
impl fmt::Display for LocateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            LocateError::Usage(m) | LocateError::Other(m) => write!(f, "{m}"),
        }
    }
}
impl std::error::Error for LocateError {}
impl LocateError {
    /// Process exit code for this error class.
    pub fn exit_code(&self) -> i32 {
        match self {
            LocateError::Usage(_) => 2,
            LocateError::Other(_) => 1,
        }
    }
}