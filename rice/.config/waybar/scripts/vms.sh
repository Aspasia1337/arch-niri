#!/bin/bash
RUNNING=$(sudo -n virsh list --name --state-running 2>/dev/null | grep -v '^$')
if [ -z "$RUNNING" ]; then
    RUNNING=$(virsh -c qemu:///system list --name --state-running 2>/dev/null | grep -v '^$')
fi
if [ -z "$RUNNING" ]; then
    echo "{\"text\":\"🖥️ 0\",\"tooltip\":\"No VMs running\"}"
else
    COUNT=$(echo "$RUNNING" | wc -l)
    LIST=$(echo "$RUNNING" | paste -sd ', ')
    echo "{\"text\":\"🖥️ ${COUNT}\",\"tooltip\":\"Running: ${LIST}\"}"
fi
