#!/bin/bash
T=$(sensors k10temp-pci-00c3 2>/dev/null | awk '/Tctl/ {gsub(/[+°C]/,"",$2); print int($2)}')
[ -z "$T" ] && T=$(sensors 2>/dev/null | awk '/Tctl/ {gsub(/[+°C]/,"",$2); print int($2)}')
[ -z "$T" ] && T=0
if   (( T >= 85 )); then cls="critical"
elif (( T >= 70 )); then cls="warning"
else                      cls="normal"
fi
echo "{\"text\":\" ${T}°\",\"class\":\"$cls\",\"tooltip\":\"CPU: ${T}°C\"}"
