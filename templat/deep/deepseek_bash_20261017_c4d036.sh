#!/bin/bash
# save-cht.sh — download all sheets listed by :list
OUT=~/cht-offline
mkdir -p "$OUT"
# Get the list of all topics
curl -s "https://cht.sh/:list" | while read -r topic; do
    [ -z "$topic" ] && continue
    # sanitize filename
    fname=$(echo "$topic" | tr '/: ' '___')
    mkdir -p "$OUT/$(dirname "$fname")"
    if [ ! -f "$OUT/$fname.txt" ]; then
        curl -s "https://cht.sh/$topic" > "$OUT/$fname.txt"
        echo "saved: $topic"
        sleep 0.2   # be polite, don't hammer the server
    fi
done