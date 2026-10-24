i will share some python scripts with you
your job is to
1. add main guard if missing
  if code does not contain a main guard, add it
2. migrate to pathlib
  any os.path usage should be replaced with equivalent pathlib code that use pathlib
3. migrate to mp.pool from concurrent.futures
   if code uses concuttent.futures functions replace it with mp.pool.imap_unordered
4. apply ruff rules UP006 & UP007
  target python version is 3.12+
and eturn full type annotated code,no comments, no docstrings
first code is:
