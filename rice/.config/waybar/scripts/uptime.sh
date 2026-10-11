#!/bin/bash
UP=$(cut -d. -f1 /proc/uptime)
D=$((UP/86400)); H=$(((UP%86400)/3600)); M=$(((UP%3600)/60))
if [ "$D" -gt 0 ]; then
    echo "⏱️ ${D}d ${H}h ${M}m"
elif [ "$H" -gt 0 ]; then
    echo "⏱️ ${H}h ${M}m"
else
    echo "⏱️ ${M}m"
fi
