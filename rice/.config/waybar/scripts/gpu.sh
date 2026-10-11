#!/bin/bash
CARD=""
for c in /sys/class/drm/card*/device; do
    if grep -q "0x1002" "$c/vendor" 2>/dev/null && [ -f "$c/gpu_busy_percent" ]; then
        CARD="$c"; break
    fi
done
if [ -z "$CARD" ]; then
    echo '{"text":"󰾲 --","class":"normal"}'
    exit
fi
USE=$(cat "$CARD/gpu_busy_percent" 2>/dev/null)
VRAM_USED=$(cat "$CARD/mem_info_vram_used" 2>/dev/null)
VRAM_TOTAL=$(cat "$CARD/mem_info_vram_total" 2>/dev/null)
[ -z "$USE" ] && USE=0
if   (( USE >= 90 )); then cls="critical"
elif (( USE >= 60 )); then cls="warning"
else                        cls="normal"
fi
if [ -n "$VRAM_USED" ] && [ -n "$VRAM_TOTAL" ] && [ "$VRAM_TOTAL" -gt 0 ]; then
    VU=$((VRAM_USED / 1024 / 1024))
    VT=$((VRAM_TOTAL / 1024 / 1024))
    echo "{\"text\":\"󰾲 ${USE}%\",\"class\":\"$cls\",\"tooltip\":\"GPU: ${USE}%\nVRAM: ${VU} / ${VT} MB\"}"
else
    echo "{\"text\":\"󰾲 ${USE}%\",\"class\":\"$cls\",\"tooltip\":\"GPU: ${USE}%\"}"
fi
