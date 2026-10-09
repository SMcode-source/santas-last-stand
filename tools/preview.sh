#!/bin/sh
# Renders one still of a prop: tools/preview.sh <prop> <out.png>
G=/c/Users/sapta/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe
rm -f "$2".tmp*.png
timeout 120 "$G" --write-movie "$2.tmp.png" --fixed-fps 30 --quit-after 12 --resolution 960x720 res://tools/prop_preview.tscn -- --prop="$1" 2>&1 | grep -iE "error" | head -5
last=$(ls "$2".tmp*.png | sort | tail -1)
mv "$last" "$2"
rm -f "$2".tmp*.png
