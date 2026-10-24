mkdir -p ~/cheats && cd ~/cheats

# Simple examples (tldr)
git clone --depth 1 https://github.com/tldr-pages/tldr.git

# Curated topic sheets (cht.sh source)
git clone --depth 1 https://github.com/chubin/cheat.sheets.git

# Framework/language sheets
git clone --depth 1 https://github.com/LeCoupa/awesome-cheatsheets.git
git clone --depth 1 https://github.com/rstacruz/cheatsheets.git

# Grep across all of them
alias cheatgrep='grep -rni --include="*.md" --include="*.txt"'
cheatgrep "reverse a list" ~/cheats | head