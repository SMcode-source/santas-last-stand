#!/bin/sh
# Renders one still of a level: tools/level_shot.sh <out.png> <frames> [level args...]
# e.g. tools/level_shot.sh top.png 40 --cam=0,120,40 --look=0,0,-10 --l1=workshop
G=/c/Users/sapta/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe
out="$1"; frames="$2"; shift 2
rm -f "$out".tmp*.png
timeout 300 "$G" --write-movie "$out.tmp.png" --fixed-fps 30 --quit-after "$frames" --resolution 1280x720 res://tools/level_preview.tscn -- "$@" 2>&1 | grep -iE "script error|parse error" | head -8
last=$(ls "$out".tmp*.png | sort | tail -1)
mv "$last" "$out"
rm -f "$out".tmp*.png
