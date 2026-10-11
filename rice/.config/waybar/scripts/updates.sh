#!/bin/bash
official=$(checkupdates 2>/dev/null | wc -l)
aur=$(yay -Qua 2>/dev/null | wc -l)
total=$((official + aur))

if (( total == 0 )); then
    echo '{"text":"","class":"none","tooltip":"System up to date"}'
else
    echo "{\"text\":\" $total\",\"class\":\"pending\",\"tooltip\":\"$official official, $aur AUR\"}"
fi
