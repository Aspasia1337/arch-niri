#!/bin/bash
ROOT=$(df -h --output=avail / 2>/dev/null | tail -1 | tr -d ' ')
TIP="/ root: $(df -h --output=used,size / | tail -1 | tr -s ' ')"
if mountpoint -q /mnt/data 2>/dev/null; then
    DATA=$(df -h --output=avail /mnt/data 2>/dev/null | tail -1 | tr -d ' ')
    TIP="${TIP}\ndata: free ${DATA}"
fi
echo "{\"text\":\"󰋊 ${ROOT}\",\"tooltip\":\"${TIP}\"}"
