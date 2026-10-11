#!/bin/bash
STATUS=$(playerctl status 2>/dev/null)
if [ -z "$STATUS" ] || [ "$STATUS" = "No players found" ]; then
    echo '{"text":"","class":"stopped"}'
    exit
fi

ARTIST=$(playerctl metadata artist 2>/dev/null)
TITLE=$(playerctl metadata title 2>/dev/null)
[ -z "$TITLE" ] && TITLE=$(playerctl metadata xesam:url 2>/dev/null | sed 's|.*/||; s|%20| |g; s|\.[^.]*$||')
[ -z "$TITLE" ] && { echo '{"text":"","class":"stopped"}'; exit; }

# Progress bar
POS=$(playerctl position 2>/dev/null | cut -d. -f1)
LEN=$(playerctl metadata mpris:length 2>/dev/null)
BAR=""
if [ -n "$POS" ] && [ -n "$LEN" ] && [ "$LEN" -gt 0 ]; then
    LEN_S=$((LEN / 1000000))
    if [ "$LEN_S" -gt 0 ]; then
        PCT=$((POS * 10 / LEN_S))
        (( PCT > 10 )) && PCT=10
        for ((i=0; i<10; i++)); do
            if (( i < PCT )); then BAR+="━"; else BAR+="─"; fi
        done
        MINS_P=$((POS / 60))
        SECS_P=$((POS % 60))
        MINS_L=$((LEN_S / 60))
        SECS_L=$((LEN_S % 60))
        TIME=$(printf "%d:%02d/%d:%02d" "$MINS_P" "$SECS_P" "$MINS_L" "$SECS_L")
        BAR=" $BAR $TIME"
    fi
fi

if [ "$STATUS" = "Paused" ]; then
    ICON="󰏤"
    CLASS="paused"
else
    ICON="󰐊"
    CLASS="playing"
fi

if [ -n "$ARTIST" ]; then
    DISPLAY="$ICON $ARTIST  $TITLE$BAR"
    TIP="$STATUS: $ARTIST - $TITLE"
else
    DISPLAY="$ICON $TITLE$BAR"
    TIP="$STATUS: $TITLE"
fi

printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$DISPLAY" "$CLASS" "$TIP"
