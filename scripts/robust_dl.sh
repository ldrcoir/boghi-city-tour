#!/bin/bash
# Robust resumable downloader for flaky connections: restarts on stall
URL="$1"; OUT="$2"; EXPECT="$3"
for i in $(seq 1 60); do
  wget -c -q -T 20 --timeout=20 -O "$OUT" "$URL" &
  WPID=$!
  LAST=0
  for t in $(seq 1 30); do
    sleep 5
    CUR=$(stat -c%s "$OUT" 2>/dev/null || echo 0)
    if [ "$CUR" -ge "$EXPECT" ]; then
      kill $WPID 2>/dev/null
      echo "DONE $CUR"
      exit 0
    fi
    if [ "$CUR" -eq "$LAST" ] && [ $t -gt 2 ]; then
      kill $WPID 2>/dev/null; wait $WPID 2>/dev/null
      break  # stalled -> restart
    fi
    LAST=$CUR
  done
done
echo "GAVE_UP"
exit 1
