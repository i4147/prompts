mkdir -p ~/cht-offline && cd ~/cht-offline

git clone --depth 1 https://github.com/chubin/cheat.sheets.git
git clone --depth 1 https://github.com/tldr-pages/tldr.git
git clone --depth 1 https://github.com/cheat/cheat.git

# Combine sheets
mkdir -p sheets
cp -r cheat.sheets/sheets/* sheets/ 2>/dev/null
cp -r tldr/pages/common/* sheets/ 2>/dev/null