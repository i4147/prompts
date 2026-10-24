implement taplo (toml lang server, formatter,linter) in python, i  just need formatter,linter part
pkg name should be taplo too, with a cli with same usage as taplo, 
one difference i expect is, if no cli arg is provided, script should format .toml files in current folder recursively inplace
use pathlib 
yse mp.pool(8) -> imap_unordered for processing multiple files
report : bytes reduced added to every processed file(in format mode not linting)
log ant errors with loguru