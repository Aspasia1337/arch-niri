#!/usr/bin/env bash
# Cava visualizer — microphone input
bars=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")

cava -p /dev/stdin <<'CONF' 2>/dev/null | while IFS=';' read -ra values; do
[general]
bars = 8
framerate = 30
[input]
method = pulse
source = auto
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
[smoothing]
noise_reduction = 77
CONF
    out=""
    for v in "${values[@]}"; do
        v="${v%$'\n'}"
        [ -z "$v" ] && continue
        (( v > 7 )) && v=7
        out+="${bars[$v]}"
    done
    [ -n "$out" ] && echo "$out"
done
