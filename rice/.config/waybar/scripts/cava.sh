#!/usr/bin/env bash
# Cava output for waybar — 8 bars, raw mode, Pipewire source
cava -p /dev/stdin <<'CONF'
[general]
bars = 8
framerate = 30
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
[smoothing]
noise_reduction = 77
CONF
