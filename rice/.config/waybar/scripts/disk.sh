#!/bin/bash
ROOT=$(df -h --output=avail / 2>/dev/null | tail -1 | tr -d ' ')
TIP="/ (Samsung): $(df -h --output=used,size / | tail -1 | tr -s ' ')"
if mountpoint -q /mnt/datos 2>/dev/null; then
    LEXAR=$(df -h --output=avail /mnt/datos 2>/dev/null | tail -1 | tr -d ' ')
    TIP="${TIP}\nLexar: free ${LEXAR}"
fi
echo "{\"text\":\"󰋊 ${ROOT}\",\"tooltip\":\"${TIP}\"}"
