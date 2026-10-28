implemend a python library to Tokenize Persian text with these features:
- Convert whitespaces to zero width nonjoiner (نیم‌فاصله) whenever it is necessary. for example,می رود to می‌رود.
- Convert Persian punctuations to their English equivalent. for example,۳/۱۴ to ۳.۱۴
- Tokenize Persian text by whitespaces and punctuations.
- Normalize Persian tokens into a single canonical form

- Transform all forms of Yeh, Kaf, Heh, and Hamza to a unique form. for example,براي to برای.
- Convert all Persian and Arabic numbers to their English equivalent. for example,۱۴۳ to 143.
- Remove diacritic (اِعراب) from words. for example, اَرّه to اره.
- Remove Kashida form words. for example, بادبــــــادک to بادبادک.
- Remove common Persian stop words

- Persian stop words like از, به and etc will be removed.
- Stem Persian words

- Remove common Persian suffixes. for example, ها or ان.
provide tests and usage examples too
add type-annotations to final code
