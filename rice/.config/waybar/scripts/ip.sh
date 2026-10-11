#!/bin/bash
LOCAL=$(ip -4 addr show enp6s0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)
[ -z "$LOCAL" ] && LOCAL=$(ip -4 addr show enp7s0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)
[ -z "$LOCAL" ] && LOCAL="--"
PUB=$(curl -s --max-time 5 https://ifconfig.me 2>/dev/null)
[ -z "$PUB" ] && PUB="?"
echo "{\"text\":\"󰩟 ${LOCAL}\",\"tooltip\":\"Local: ${LOCAL}\nPublic: ${PUB}\"}"
