Write a Python script that generates a project's `README.md` file by building its Sphinx
documentation into Markdown format.
The script should: 1.
Create a temporary directory to use as the output location for the Sphinx build,
ensuring it is automatically cleaned up afterward.
2. Invoke the `sphinx-build` command-line tool as a subprocess,
using the `-M markdown` builder mode,
with `./docs` as the source documentation directory
and the temporary directory as the output destination.
The subprocess call should raise an error if the build fails (non-zero exit code).
3. After the build completes,
locate the generated `index.md` file inside the `markdown` subfolder of the temporary output
directory, and read its full text content using UTF-8 encoding.
4. Write that content out to a `README.md` file in the current working directory,
also using UTF-8 encoding, overwriting any existing file.
Use the `subprocess`, `tempfile`, and `pathlib.Path` modules from the Python standard library.
The script should be straightforward top-level procedural code
(no functions, classes, or command-line argument parsing needed),
suitable for use as a build/documentation automation step
(e.g., run before packaging or publishing a project) to keep the README in sync with the
Sphinx-generated docs. ---
