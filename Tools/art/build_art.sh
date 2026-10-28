#!/bin/bash
# Renders every room's background and the sprite set into Game/Resources/Art3D.
#   Tools/art/build_art.sh [rooms|sprites|all] [room ids...]   (default: all, every room)
# Backgrounds: bg_<room>.jpg + bg_<room>.json (pixel origin of the room's top-left ground corner, pixels per cell).
set -e
cd "$(dirname "$0")/../.."
OUT=Game/Resources/Art3D
mkdir -p "$OUT"
what=${1:-all}; shift || true
SAMPLES=${SAMPLES:-24}
if [ "$what" = sprites ] || [ "$what" = all ]; then
  python3 Tools/art/sprites3d.py "$OUT" --samples 48
fi
if [ "$what" = rooms ] || [ "$what" = all ]; then
  rooms="$*"
  [ -z "$rooms" ] && rooms=$(python3 -c "import json;print(' '.join(json.load(open('Game/Resources/rooms.json'))['rooms']))")
  for r in $rooms; do
    t0=$(date +%s)
    python3 Tools/art/scene3d.py "$r" "$OUT/bg_$r.jpg" --bg --samples "$SAMPLES" > /tmp/art_$r.log 2>&1 || { echo "FAIL $r"; tail -5 /tmp/art_$r.log; continue; }
    echo "$r $(( $(date +%s) - t0 ))s"
  done
fi
