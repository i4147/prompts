Write a Python script that searches the current directory for a README file
(checking common names like README.md, README.rst, README.txt,
or README in a case-insensitive manner) and displays its contents using a pager,
similar to the `pydoc` command's paging behavior.
If no README file is found, it should print an error message to stderr and exit with status code 1.
The script should read the file as UTF-8 text,
falling back to replacing invalid characters if a decoding error occurs.
