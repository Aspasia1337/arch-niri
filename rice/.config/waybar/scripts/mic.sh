#!/bin/bash
muted=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -c MUTED)
if (( muted )); then
    echo '{"text":"󰍭","class":"muted","tooltip":"Mic: muted"}'
else
    echo '{"text":"󰍬","class":"on","tooltip":"Mic: on"}'
fi
