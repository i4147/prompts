Write a self-contained Python 3.12 script for
Linux/Termux armv8l: pathlib; skip symlinks/.git;
Pool 8; argparse files/dirs (default cwd);
full type hints; no module/function docstrings (just module docstring: ->regenerates script);
loguru; fail loud, no simulation.
Prioritize speed, streaming memory, robustness, clarity, features.
Main guard, no TODOs/placeholders.
Output full annotated code block.
task:
show text of input pdf file (sys.argv[1])
page by page on screen, scrollable with pg up/down
if extracted text of a page dont fit in sceen, split it to required parts to fit, this addes more pg up/down for user
-add -b,--backend to select from pdfminer.six(default),pypdf,pymupdf,other python libs that can extract text from input pdf
if no usable lib found, try system tools via subprocess(like gs,qpdf,mupdf,...) first try gs+tesseract
