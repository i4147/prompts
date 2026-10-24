write a python script to safely fix , invalid escape sequence issue in python files in current dir recursively, inplace, using pathlib
-use a generator style fs walker
-report relpath of changed files
-validate result code before writing to file
-preferably convert escaped regexes to raw
return full annotated code