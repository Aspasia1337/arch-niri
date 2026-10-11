#!/bin/bash
LOC="YOUR_CITY"
DATA=$(curl -s --max-time 10 "https://wttr.in/${LOC}?format=%c%t" 2>/dev/null | tr -d ' ')
if [ -z "$DATA" ]; then
    echo " --"
else
    echo " $DATA"
fi
