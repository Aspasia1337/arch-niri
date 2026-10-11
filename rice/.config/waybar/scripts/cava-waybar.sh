#!/usr/bin/env bash
# Pipe cava ASCII output into waybar-friendly Unicode bars
bars=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")

~/.config/waybar/scripts/cava.sh 2>/dev/null | while IFS=';' read -ra values; do
    out=""
    for v in "${values[@]}"; do
        v="${v%$'\n'}"
        [ -z "$v" ] && continue
        (( v > 7 )) && v=7
        out+="${bars[$v]}"
    done
    [ -n "$out" ] && echo "$out"
done
