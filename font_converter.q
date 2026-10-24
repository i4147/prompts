write a python font converter script
example usages:
python script.py a.otf --to ttf
python script.py a.woff --to woff2
python script.py a.woff2 --to ttf
script uses fonttools lib to convert supported formats to each other
-use pathlib
-report size change
when we convert a font to other format (size increases or decreasez?)
-add any other functionality you recomment
return full type annotated code