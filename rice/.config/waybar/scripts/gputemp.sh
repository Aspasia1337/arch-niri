#!/bin/bash
T=$(sensors amdgpu-pci-* 2>/dev/null | awk '/edge/ {gsub(/[+°C]/,"",$2); print int($2); exit}')
[ -z "$T" ] && T=$(sensors 2>/dev/null | awk '/edge/ {gsub(/[+°C]/,"",$2); print int($2); exit}')
[ -z "$T" ] && T=0
if   (( T >= 90 )); then cls="critical"
elif (( T >= 75 )); then cls="warning"
else                      cls="normal"
fi
echo "{\"text\":\"󰢮 ${T}°\",\"class\":\"$cls\",\"tooltip\":\"GPU: ${T}°C\"}"
